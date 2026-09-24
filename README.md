# ASUS ZenBook Duo — хоткеи и ScreenPad под Linux

Набор скриптов, чтобы на **ASUS ZenBook Duo (UX482EG)** под **KDE Plasma 6 (Wayland)** работали фирменные клавиши, которые из коробки ничего не делают:

| Клавиша (scancode) | Что делает |
|---|---|
| Кнопка ScreenPad (`0x6a`) | Включает/выключает второй экран (ScreenPad): видео, тач и подсветку. Запоминает яркость перед выключением. |
| Кнопка Swap (`0x9c`) | Перекидывает активное окно на другой экран (KDE-шорткат «Window to Next Screen»). |
| `Fn+F` (`0x9d`) | Переключает профиль вентилятора/питания через `asusctl` (Quiet → Balanced → Performance) и показывает уведомление. |

Демон читает события напрямую из устройства ввода `Asus WMI hotkeys` (`/dev/input/eventN`, ищется автоматически), поэтому работает от root, а команды для графической сессии запускает от имени пользователя.

## Файлы

| Файл | Что это | Статус |
|---|---|---|
| `asus_hotkeys.go` | Основной демон на Go. Слушает клавиши и вызывает скрипты ниже. | **Используется** |
| `screenpad_final.sh` | Управление ScreenPad: `status` / `on` / `off` (через `kscreen-doctor` и KWin DBus). Вызывается демоном. | **Используется** |
| `swap_windows.sh` | Перекидывает окно на соседний экран. Вызывается демоном. | **Используется** |
| `lock_system.sh` | Слушает блокировку экрана и гасит ScreenPad при блокировке, включает при разблокировке. | Автозапуск KDE (см. ниже) |
| `asus_daemon.py` | Старая версия демона на Python (`evdev`). Заменена Go-версией. | Устарел |
| `screenpad-toggle.sh` | Старый вариант переключателя ScreenPad (сам определяет состояние, яркость через `sudo`). | Устарел |
| `hotkeys.log` | Лог из journald времён отладки Python-версии. | Мусор |

## Зависимости

- KDE Plasma 6, сессия Wayland
- `asusctl` (профили питания)
- `brightnessctl` (подсветка ScreenPad, устройство `asus_screenpad`)
- `kscreen-doctor`, `dbus-send`, `notify-send`
- Go — чтобы собрать демон

## Установка и запуск

### 1. Собрать демон и положить в `/usr/local/bin`

```bash
cd ~/Scripts
go build -o asus_hotkeys asus_hotkeys.go
sudo install -m 755 asus_hotkeys /usr/local/bin/asus_hotkeys
```

### 2. Создать systemd-сервис

Файл `/etc/systemd/system/asus-hotkeys.service`:

```ini
[Unit]
Description=ASUS ZenBook Duo Hotkey Daemon
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/asus_hotkeys
Restart=always

[Install]
WantedBy=multi-user.target
```

Включить и запустить:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now asus-hotkeys
```

Проверить, что работает, и смотреть лог нажатий:

```bash
systemctl status asus-hotkeys
journalctl -u asus-hotkeys -f
```

### 3. (Опционально) Гасить ScreenPad при блокировке экрана

Добавить `lock_system.sh` в автозапуск KDE: *Параметры системы → Автозапуск → Добавить → Сценарий входа* и выбрать `~/Scripts/lock_system.sh`. Либо создать `~/.config/autostart/lock_system.sh.desktop`:

```ini
[Desktop Entry]
Exec=/home/timur/Scripts/lock_system.sh
Name=lock_system.sh
Terminal=False
Type=Application
```

> Скрипт работает в пользовательской сессии и вызывает `screenpad_final.sh off` при блокировке и `on` при разблокировке. После изменения скрипта нужно перезайти в сессию (или перезапустить его вручную).

### После изменений

- Поменял `.sh` скрипты — ничего делать не нужно, демон вызывает их по пути `~/Scripts/...` при каждом нажатии.
- Поменял `asus_hotkeys.go` — пересобрать и перезапустить:
  ```bash
  go build -o asus_hotkeys asus_hotkeys.go && sudo install -m 755 asus_hotkeys /usr/local/bin/ && sudo systemctl restart asus-hotkeys
  ```

## Что захардкожено (править под себя)

В `asus_hotkeys.go` и скриптах жёстко прописано:

- пользователь `timur`, UID/GID `1000`, пути `/home/timur/Scripts/...`;
- окружение сессии: `DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0`, `/run/user/1000`;
- в `screenpad_final.sh`: выход ScreenPad `DP-1`, режим `15`, позиция `0,900` (под основным экраном);
- тач-устройства ScreenPad: `event13 event16 event17`. **Номера могут поменяться** после обновления ядра или подключения устройств — тогда тач на ScreenPad перестанет включаться/выключаться. Актуальные номера смотреть так:
  ```bash
  grep -H . /sys/class/input/event*/device/name
  ```

Проверить scancode любой клавиши (если хочется добавить новую):

```bash
sudo evtest   # выбрать "Asus WMI hotkeys", нажать клавишу, смотреть MSC_SCAN value
```
