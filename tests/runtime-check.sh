#!/bin/bash
# Runs the widget for real (plasmoidviewer on a virtual display) and checks what unit tests cannot:
# QML errors at run time, CPU load, memory growth and the number of processes it starts.
# Both leaks fixed in 6.1.57 and 6.1.59 would have failed this check within minutes.
#
#   tests/runtime-check.sh [seconds, default 180]
# Needs Plasma 6 (plasmoidviewer from plasma-sdk, kpackagetool6), Xvfb and dbus-run-session, and a
# normal user (not root). Budgets, overridable from the environment:
#   MAX_CPU=6           % of one core, average over the run
#   MAX_FORKS=160       processes started per minute, above the idle level of the machine
#   MAX_RSS_GROWTH=25   MB between the first and the last quarter of the run
#   MAX_CPU_DRIFT=3     percentage points: the second half may not be busier than the first
# Writes runtime-check.png (screenshot, when ImageMagick is installed) and runtime-check.log next to the script.
set -u
cd "$(dirname "$0")"
secs=${1:-180}
MAX_CPU=${MAX_CPU:-6}; MAX_FORKS=${MAX_FORKS:-160}; MAX_RSS_GROWTH=${MAX_RSS_GROWTH:-25}; MAX_CPU_DRIFT=${MAX_CPU_DRIFT:-3}
[ "$(id -u)" != 0 ] || { echo "run as a normal user"; exit 2; }
for t in plasmoidviewer kpackagetool6 Xvfb dbus-run-session; do command -v $t >/dev/null || { echo "missing: $t"; exit 2; }; done

work=$(mktemp -d)
export HOME=$work/home XDG_RUNTIME_DIR=$work/run DISPLAY=:${RUNTIME_CHECK_DISPLAY:-96}
export XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 QT_QPA_PLATFORMTHEME=kde LANG=C.UTF-8
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
log=$PWD/runtime-check.log
cleanup() { [ -n "${viewer:-}" ] && kill "$viewer" 2>/dev/null; [ -n "${xvfb:-}" ] && kill "$xvfb" 2>/dev/null; pkill -u "$(id -u)" -x plasmoidviewer 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

forks() { awk '/^processes/ { print $2 }' /proc/stat; }
hz=$(getconf CLK_TCK)
Xvfb "$DISPLAY" -screen 0 1000x1100x24 >/dev/null 2>&1 & xvfb=$!
sleep 2
a=$(forks); sleep 15; b=$(forks); idle=$(( (b - a) * 4 ))            # processes per minute without the widget

kpackagetool6 -t Plasma/Applet -i ../package >/dev/null 2>&1 || { echo "FAIL: the package does not install"; exit 1; }
dbus-run-session -- plasmoidviewer -a com.f1devbin.myipgeo -s 600x1000 > "$log" 2>&1 & viewer=$!
sleep 30                                                              # start-up is not measured
pid=$(pgrep -u "$(id -u)" -x plasmoidviewer | head -n 1)
[ -n "$pid" ] || { echo "FAIL: plasmoidviewer did not start"; tail -n 20 "$log"; exit 1; }

cpu() { awk '{ print $14 + $15 }' "/proc/$pid/stat"; }
rss() { awk '/^VmRSS/ { print $2 }' "/proc/$pid/status"; }
q=$((secs / 4)); f0=$(forks); c0=$(cpu); r_first=0; r_last=0
sleep "$q"; r_first=$(rss)
sleep "$q"; c_half=$(cpu)
sleep "$q"
sleep "$q"; r_last=$(rss); c1=$(cpu); f1=$(forks)
[ -d "/proc/$pid" ] || { echo "FAIL: plasmoidviewer died"; tail -n 20 "$log"; exit 1; }
command -v import >/dev/null && import -window root runtime-check.png 2>/dev/null

half=$((q * 2))
cpu_avg=$(awk -v d=$((c1 - c0)) -v hz="$hz" -v s=$((q * 4)) 'BEGIN { printf "%.1f", d * 100 / hz / s }')
cpu_a=$(awk -v d=$((c_half - c0)) -v hz="$hz" -v s="$half" 'BEGIN { printf "%.1f", d * 100 / hz / s }')
cpu_b=$(awk -v d=$((c1 - c_half)) -v hz="$hz" -v s="$half" 'BEGIN { printf "%.1f", d * 100 / hz / s }')
fpm=$(( (f1 - f0) * 60 / (q * 4) - idle )); [ "$fpm" -ge 0 ] || fpm=0
growth=$(( (r_last - r_first) / 1024 ))
errors=$(grep -c 'com.f1devbin.myipgeo/contents/ui/.*\(Error\|is not defined\|is not a function\|Unable to assign\|Cannot read property\|Binding loop\)' "$log")
dropped=$(grep -c 'dropped a command' "$log")

fail=0
check() { if awk -v v="$2" -v m="$3" 'BEGIN { exit !(v <= m) }'; then echo "ok    $1: $2 (limit $3)"; else echo "FAIL  $1: $2 (limit $3)"; fail=1; fi; }
check "QML errors of the widget" "$errors" 0
check "commands stopped as stuck" "$dropped" 0
check "CPU, % of one core" "$cpu_avg" "$MAX_CPU"
check "CPU drift, second half minus first" "$(awk -v a="$cpu_a" -v b="$cpu_b" 'BEGIN { printf "%.1f", b - a }')" "$MAX_CPU_DRIFT"
check "processes started per minute" "$fpm" "$MAX_FORKS"
check "memory growth, MB" "$growth" "$MAX_RSS_GROWTH"
echo "      memory: $((r_last / 1024)) MB, idle machine: $idle processes/min, run: $((q * 4)) s"
[ "$errors" = 0 ] || grep 'com.f1devbin.myipgeo/contents/ui/' "$log" | head -n 10
exit $fail
