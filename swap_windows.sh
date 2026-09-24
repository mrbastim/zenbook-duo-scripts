#!/bin/bash

# Окружение
export XDG_RUNTIME_DIR="/run/user/1000"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

# Вызываем глобальный хоткей KDE через DBus
dbus-send --session --type=method_call --dest=org.kde.kglobalaccel \
/component/kwin org.kde.kglobalaccel.Component.invokeShortcut string:"Window to Next Screen"
