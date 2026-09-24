import evdev
import subprocess
import time
import os
import sys

# --- НАСТРОЙКИ ---
USER = "timur"
USER_ID = "1000"
DEBOUNCE_SEC = 0.5
DEVICE_NAME_TARGET = "Asus WMI hotkeys" # Имя устройства, которое мы ищем

# --- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ---
last_time = 0

def find_asus_device():
    """Автоматически ищет устройство по имени и возвращает его путь"""
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for device in devices:
        if DEVICE_NAME_TARGET in device.name:
            return device.path
    return None

def run_user_cmd(cmd_list):
    """
    Запускает команду от имени пользователя через sudo + env.
    """
    wrapper = [
        'sudo', '-u', USER,
        'env',
        'DISPLAY=:0',
        f'XDG_RUNTIME_DIR=/run/user/{USER_ID}',
        f'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{USER_ID}/bus',
        'WAYLAND_DISPLAY=wayland-0'
    ]

    try:
        subprocess.Popen(wrapper + cmd_list)
    except Exception as e:
        print(f"Error running cmd: {e}")

def switch_fan_profile():
    try:
        # 1. Переключаем профиль
        subprocess.run(['asusctl', 'profile', 'next'], check=True)

        # Даем демону долю секунды на применение настроек
        time.sleep(0.2)

        # 2. Получаем текущий статус
        res = subprocess.run(['asusctl', 'profile', 'get'], capture_output=True, text=True)
        raw_output = res.stdout.strip()

        active_profile = "Unknown"

        # Разбираем вывод построчно
        for line in raw_output.split('\n'):
            if line.startswith("Active profile:"):
                active_profile = line.split(":", 1)[1].strip()
                break

        if active_profile == "Quiet":
            profile_name = "Quiet (Тихий)"
            icon = "power-profile-power-saver"
        elif active_profile == "Performance":
            profile_name = "Performance (Мощный)"
            icon = "power-profile-performance"
        elif active_profile == "Balanced":
            profile_name = "Balanced (Сбалансированный)"
            icon = "power-profile-balanced"
        else:
            profile_name = active_profile
            icon = "power-profile-balanced"

        # 3. Уведомление
        run_user_cmd([
            'notify-send',
            '-a', 'ASUS',
            '-i', icon,
            '-t', '2000',
            'Режим работы',
            profile_name
        ])

    except Exception as e:
        print(f"Profile error: {e}")

# --- MAIN LOOP ---
try:
    # Ищем правильный путь к устройству динамически
    dev_path = find_asus_device()
    
    if dev_path is None:
        print(f"Критическая ошибка: Устройство '{DEVICE_NAME_TARGET}' не найдено!")
        sys.exit(1)
        
    device = evdev.InputDevice(dev_path)
    print(f"Listening to {device.name} on {dev_path}...")

    for event in device.read_loop():
        if event.type == evdev.ecodes.EV_MSC and event.code == evdev.ecodes.MSC_SCAN:

            current_time = time.time()
            if (current_time - last_time) < DEBOUNCE_SEC:
                continue
            last_time = current_time

            if event.value == 0x6a: # ScreenPad
                print("Toggle ScreenPad")
                run_user_cmd(["/bin/bash", "/home/timur/Scripts/screenpad_final.sh"])

            elif event.value == 0x9c: # Swap
                print("Swap Windows")
                run_user_cmd(["/bin/bash", "/home/timur/Scripts/swap_windows.sh"])

            elif event.value == 0x9d: # Fn+F
                print("Switch Profile")
                switch_fan_profile()

except Exception as e:
    print(f"Critical: {e}")