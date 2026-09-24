#!/bin/bash

# --- НАСТРОЙКИ ---
VIDEO_NAME="DP-1"  # Теперь ищем строго " DP-1"
VIDEO_MODE="15"
POS="0,900"
BACKLIGHT="asus_screenpad"

# --- 1. ОПРЕДЕЛЯЕМ СОСТОЯНИЕ (СТРОГО ДЛЯ DP-1) ---
# Добавили пробел перед именем, чтобы не цеплять eDP-1
IS_ENABLED=$(kscreen-doctor -o | grep -A 1 "Output:.* $VIDEO_NAME" | grep "enabled")

# --- 2. НАХОДИМ EVENT-УСТРОЙСТВА ---
# ВНИМАНИЕ: Если event6 это основной экран, подставь сюда правильные номера!
# Можно просто перечислить их через пробел, например: EVENTS="event10 event11"
EVENTS="event13 event16 event17"

if [ -z "$IS_ENABLED" ]; then
    echo ">>> ОБНАРУЖЕНО: ScreenPad ВЫКЛЮЧЕН. ВКЛЮЧАЮ..."

    # 1. Видео
    kscreen-doctor output.$VIDEO_NAME.enable output.$VIDEO_NAME.mode.$VIDEO_MODE output.$VIDEO_NAME.position.$POS

    # 2. Подсветка (через sudo без пароля, если настроил visudo)
    sudo brightnessctl --device=$BACKLIGHT set 100%

    # 3. Тач
    for EV in $EVENTS; do
        dbus-send --session --type=method_call --dest=org.kde.KWin /org/kde/KWin/InputDevice/$EV org.freedesktop.DBus.Properties.Set string:org.kde.KWin.InputDevice string:enabled variant:boolean:true
    done

    echo "ГОТОВО: ScreenPad активен"
else
    echo ">>> ОБНАРУЖЕНО: ScreenPad ВКЛЮЧЕН. ВЫКЛЮЧАЮ..."

    # 1. Тач (сначала гасим ввод)
    for EV in $EVENTS; do
        dbus-send --session --type=method_call --dest=org.kde.KWin /org/kde/KWin/InputDevice/$EV org.freedesktop.DBus.Properties.Set string:org.kde.KWin.InputDevice string:enabled variant:boolean:false
    done

    # 2. Подсветка
    sudo brightnessctl --device=$BACKLIGHT set 0

    # 3. Видео
    kscreen-doctor output.$VIDEO_NAME.disable

    echo "ГОТОВО: ScreenPad полностью отключен"
fi
