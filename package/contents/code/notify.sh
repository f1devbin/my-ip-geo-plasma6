#!/bin/sh
# My IP & Geo - desktop notification for Monitor (device went online/offline).
#   notify.sh <title> <body> [icon]
# notify-send when installed, else the freedesktop notification service over D-Bus
# (busctl comes with systemd, gdbus with GLib), so no extra package is needed.
title=$1
body=$2
icon=${3:-network-wired}
app='My IP & Geo'
if command -v notify-send >/dev/null 2>&1 && notify-send -a "$app" -i "$icon" -u normal "$title" "$body" 2>/dev/null; then exit 0; fi
# "--" ends option parsing: the last argument (-1 = default timeout) would be taken for an option
if command -v busctl >/dev/null 2>&1 && busctl --user call -- org.freedesktop.Notifications /org/freedesktop/Notifications \
    org.freedesktop.Notifications Notify 'susssasa{sv}i' "$app" 0 "$icon" "$title" "$body" 0 0 -1 >/dev/null 2>&1; then exit 0; fi
if command -v gdbus >/dev/null 2>&1 && gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify "$app" 0 "$icon" "$title" "$body" '[]' '{}' 'int32 -1' >/dev/null 2>&1; then exit 0; fi
exit 1
