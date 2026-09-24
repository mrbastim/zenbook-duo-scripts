package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

// --- НАСТРОЙКИ ---
const (
	User          = "timur"
	UserId        = "1000"
	TargetDevice  = "Asus WMI hotkeys"
	DebounceDelay = 500 * time.Millisecond
)

var screenpadBrightness string = "100%"

type InputEvent struct {
	Sec   int64
	Usec  int64
	Type  uint16
	Code  uint16
	Value int32
}

// Подготавливает команду для запуска от имени юзера на уровне ядра (БЕЗ sudo и PAM)
func prepareUserCmd(command string, args ...string) *exec.Cmd {
	cmd := exec.Command(command, args...)

	// Нативно сбрасываем права до обычного юзера (UID 1000, GID 1000)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Credential: &syscall.Credential{Uid: 1000, Gid: 1000},
	}

	// Задаем окружение
	cmd.Env = []string{
		"DISPLAY=:0",
		"WAYLAND_DISPLAY=wayland-0",
		"XDG_RUNTIME_DIR=/run/user/" + UserId,
		"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/" + UserId + "/bus",
	}
	return cmd
}

func runUserCmd(command string, args ...string) {
	prepareUserCmd(command, args...).Start()
}

func toggleScreenpad() {
	out, _ := prepareUserCmd("/bin/bash", "/home/timur/Scripts/screenpad_final.sh", "status").Output()
	status := strings.TrimSpace(string(out))

	if status == "on" {
		outBr, _ := exec.Command("brightnessctl", "--device=asus_screenpad", "get").Output()
		screenpadBrightness = strings.TrimSpace(string(outBr))
		if screenpadBrightness == "" || screenpadBrightness == "0" {
			screenpadBrightness = "30%"
		}

		exec.Command("brightnessctl", "--device=asus_screenpad", "set", "0").Run()
		prepareUserCmd("/bin/bash", "/home/timur/Scripts/screenpad_final.sh", "off").Run()

		fmt.Printf("ScreenPad выключен, яркость: %s\n", screenpadBrightness)
	} else {
		prepareUserCmd("/bin/bash", "/home/timur/Scripts/screenpad_final.sh", "on").Run()
		time.Sleep(750 * time.Millisecond)
		exec.Command("brightnessctl", "--device=asus_screenpad", "set", screenpadBrightness).Run()

		fmt.Printf("ScreenPad включен, яркость: %s\n", screenpadBrightness)
	}
}

func switchFanProfile() {
	exec.Command("asusctl", "profile", "next").Run()
	time.Sleep(200 * time.Millisecond)

	out, _ := exec.Command("asusctl", "profile", "get").Output()
	activeProfile := "Unknown"
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "Active profile:") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				activeProfile = strings.TrimSpace(parts[1])
			}
			break
		}
	}

	profileName := activeProfile
	icon := "power-profile-balanced"

	switch activeProfile {
	case "Quiet":
		profileName = "Quiet (Тихий)"
		icon = "power-profile-power-saver"
	case "Performance":
		profileName = "Performance (Мощный)"
		icon = "power-profile-performance"
	}
	runUserCmd("notify-send", "-a", "ASUS", "-i", icon, "-t", "2000", "Режим работы", profileName)
}

func findDevice() string {
	files, _ := filepath.Glob("/sys/class/input/event*")
	for _, f := range files {
		nameBytes, err := os.ReadFile(filepath.Join(f, "device/name"))
		if err == nil {
			name := strings.TrimSpace(string(nameBytes))
			if strings.Contains(name, TargetDevice) {
				return "/dev/input/" + filepath.Base(f)
			}
		}
	}
	return ""
}

func main() {
	devPath := findDevice()
	if devPath == "" {
		log.Fatalf("Критическая ошибка: Устройство '%s' не найдено!", TargetDevice)
	}

	f, err := os.Open(devPath)
	if err != nil {
		log.Fatalf("Ошибка доступа к %s: %v", devPath, err)
	}
	defer f.Close()

	fmt.Printf("Слушаю %s...\n", devPath)

	var event InputEvent
	eventSize := binary.Size(event)
	buffer := make([]byte, eventSize)
	var lastTime time.Time

	for {
		n, err := f.Read(buffer)
		if err != nil || n != eventSize {
			continue
		}

		bufReader := bytes.NewReader(buffer)
		binary.Read(bufReader, binary.LittleEndian, &event)

		if event.Type == 4 && event.Code == 4 {
			if time.Since(lastTime) < DebounceDelay {
				continue
			}
			lastTime = time.Now()

			switch event.Value {
			case 0x6a:
				fmt.Println("Toggle ScreenPad")
				go toggleScreenpad()
			case 0x9c:
				fmt.Println("Swap Windows")
				runUserCmd("/bin/bash", "/home/timur/Scripts/swap_windows.sh")
			case 0x9d:
				fmt.Println("Switch Profile")
				switchFanProfile()
			}
		}
	}
}
