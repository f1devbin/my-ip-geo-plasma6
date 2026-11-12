#!/bin/bash
# My IP & Geo - the 2-second sample for the main view: CPU, memory, swap, traffic counters and a
# signature of the block devices. One bash process and shell builtins only: the widget used to
# start about 400 processes a minute for the same data (head, grep, df, lsblk, awk every 2-3 s).
#
#   sample.sh <parts> [run-id]      parts: s = CPU/memory/swap, k = system disk (df, the only
#                                   external command, asked for every 30 s), t = traffic,
#                                   d = drives signature; the run-id only makes the command unique
# Output (parsed in main.qml):
#   cpu  ...                        first line of /proc/stat
#   MemTotal: / MemAvailable: / SwapTotal: / SwapFree: lines of /proc/meminfo
#   <df -P -B1 / output>
#   NET <rx-bytes> <tx-bytes>       physical adapters; without any, every interface but lo
#   DRV <signature>                 changes when a disk, partition or mount appears or goes away
parts=${1:-st}
NET=${MYIPGEO_SYSFS_NET:-/sys/class/net}

case "$parts" in *s*)
    IFS= read -r line < /proc/stat && printf '%s\n' "$line"
    while read -r key value _; do
        case "$key" in MemTotal:|MemAvailable:|SwapTotal:|SwapFree:) printf '%s %s kB\n' "$key" "$value" ;; esac
    done < /proc/meminfo ;;
esac

case "$parts" in *k*) timeout 2 df -P -B1 / 2>/dev/null ;; esac

case "$parts" in *t*)
    rx=0; tx=0; n=0
    # VPN tunnels, bridges and veth carry the same bytes a second time: adapters with a device only
    for d in "$NET"/*; do
        [ -e "$d/device" ] || continue
        read -r r < "$d/statistics/rx_bytes" && read -r t < "$d/statistics/tx_bytes" || continue
        rx=$((rx + r)); tx=$((tx + t)); n=$((n + 1))
    done 2>/dev/null
    if [ "$n" -eq 0 ]; then
        for d in "$NET"/*; do
            [ "${d##*/}" = lo ] && continue
            read -r r < "$d/statistics/rx_bytes" && read -r t < "$d/statistics/tx_bytes" || continue
            rx=$((rx + r)); tx=$((tx + t))
        done 2>/dev/null
    fi
    echo "NET $rx $tx" ;;
esac

case "$parts" in *d*)
    sig=""
    while read -r _ _ blocks name; do
        case "$name" in sd*|nvme*|mmcblk*|vd*|sr*) sig="$sig$name:$blocks," ;; esac
    done < /proc/partitions
    while read -r dev mnt _; do
        case "$dev" in /dev/loop*) ;; /dev/*) sig="$sig$dev@$mnt," ;; esac
    done < /proc/self/mounts
    echo "DRV $sig" ;;
esac
exit 0
