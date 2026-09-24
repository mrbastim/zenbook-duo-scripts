#!/bin/bash

# Слушаем сигналы блокировки экрана через DBus
dbus-monitor --session "type='signal',interface='org.freedesktop.ScreenSaver',member='ActiveChanged'" | \
while read line; do
    # Если в строке появилось 'boolean true' - экран заблокирован
    if echo "$line" | grep -q "boolean true"; then
        echo "Система заблокирована - выключаю ScreenPad"
        # Проверяем, включен ли он сейчас, чтобы не выключать уже выключенное
        if kscreen-doctor -o | grep -A 1 "Output:.* DP-1" | grep -q "enabled"; then
             /home/timur/Scripts/screenpad_final.sh
        fi

    # Если появилось 'boolean false' - экран разблокирован
    elif echo "$line" | grep -q "boolean false"; then
        echo "Система разблокирована - включаю ScreenPad"
        # Если он выключен - включаем
        if ! kscreen-doctor -o | grep -A 1 "Output:.* DP-1" | grep -q "enabled"; then
             /home/timur/Scripts/screenpad_final.sh
        fi
    fi
done
