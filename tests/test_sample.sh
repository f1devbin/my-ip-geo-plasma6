#!/bin/bash
# sample.sh: traffic totals from a fake sysfs, parts on request, no child processes without "k"
S=${1:?sample.sh}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mk() { mkdir -p "$T/net/$1/statistics"; echo "$2" > "$T/net/$1/statistics/rx_bytes"; echo "$3" > "$T/net/$1/statistics/tx_bytes"; [ -n "$4" ] && mkdir -p "$T/net/$1/device"; }
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok  - $1"; else echo "FAIL- $1: got [$2] want [$3]"; fail=1; fi; }
mk lo 999 999; mk enp0s31f6 1000 200 dev; mk wlp2s0 50 5 dev; mk tun0 700 70
check "traffic: physical adapters only" "$(MYIPGEO_SYSFS_NET=$T/net bash "$S" t 1)" "NET 1050 205"
rm -rf "$T/net/enp0s31f6/device" "$T/net/wlp2s0/device"
check "traffic: without physical adapters everything but lo" "$(MYIPGEO_SYSFS_NET=$T/net bash "$S" t 1)" "NET 1750 275"
out=$(bash "$S" s 1)
check "system part: cpu line and four memory lines" "$(printf '%s\n' "$out" | grep -cE '^(cpu |MemTotal:|MemAvailable:|SwapTotal:|SwapFree:)')" 5
check "system part only: no traffic or drives line" "$(printf '%s\n' "$out" | grep -cE '^(NET|DRV) ')" 0
check "disk part: the df line of /" "$(bash "$S" k 1 | grep -cE '^[^ ]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+% +/$')" 1
check "drives part: one signature line" "$(bash "$S" d 1 | grep -c '^DRV ')" 1
if command -v strace >/dev/null 2>&1; then
    n=$(strace -f -e trace=execve,clone,clone3,fork,vfork bash "$S" std 1 2>&1 >/dev/null | grep -cE '^(\[pid +[0-9]+\] )?(execve|clone|clone3|fork|vfork)\(')
    check "std starts no other process (1 = bash itself)" "$n" 1
fi
exit $fail
