#!/bin/bash
VIDEO_NAME="DP-1"
VIDEO_MODE="15"
POS="0,900"
EVENTS="event13 event16 event17"

# Жестко прописываем окружение Wayland и Plasma 6 для всех команд внутри скрипта
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR="/run/user/1000"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
export QT_QPA_PLATFORM=wayland
export XDG_SESSION_TYPE=wayland

# Возвращаем статус в Go
if [ "$1" == "status" ]; then
    IS_ENABLED=$(kscreen-doctor -o | grep -A 1 "Output:.* $VIDEO_NAME" | grep "enabled")
    if [ -n "$IS_ENABLED" ]; then echo "on"; else echo "off"; fi
    exit 0
fi

# Включение экрана
if [ "$1" == "on" ]; then
    kscreen-doctor output.$VIDEO_NAME.enable output.$VIDEO_NAME.mode.$VIDEO_MODE output.$VIDEO_NAME.position.$POS
    for EV in $EVENTS; do
        dbus-send --session --type=method_call --dest=org.kde.KWin /org/kde/KWin/InputDevice/$EV org.freedesktop.DBus.Properties.Set string:org.kde.KWin.InputDevice string:enabled variant:boolean:true
    done
    exit 0
fi

# Выключение экрана
if [ "$1" == "off" ]; then
    for EV in $EVENTS; do
        dbus-send --session --type=method_call --dest=org.kde.KWin /org/kde/KWin/InputDevice/$EV org.freedesktop.DBus.Properties.Set string:org.kde.KWin.InputDevice string:enabled variant:boolean:false
    done
    kscreen-doctor output.$VIDEO_NAME.disable
    exit 0
fi