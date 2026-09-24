#!/bin/sh
# My IP & Geo - Monitor: is each watched device online?
#   monitor.sh <ip>...   prints "<ip><TAB>UP<TAB>ping", "<ip><TAB>UP<TAB>arp" or "<ip><TAB>DOWN"
# A device that ignores ping (phones, Windows with a firewall) still answers ARP when it is on
# the local network: the ping makes the kernel ask, the neighbour entry then turns REACHABLE.
# Cached entries are re-checked by the kernel first (DELAY/PROBE), so up to 7 s are waited for.
check() {
    ip=$1
    if ping -n -c 1 -W 1 "$ip" >/dev/null 2>&1; then printf '%s\tUP\tping\n' "$ip"; return; fi
    n=0
    while :; do
        state=$(ip neigh show "$ip" 2>/dev/null | awk '{ print $NF; exit }')
        case "$state" in
            REACHABLE|PERMANENT) printf '%s\tUP\tarp\n' "$ip"; return ;;
            DELAY|PROBE|INCOMPLETE) [ "$n" -lt 7 ] || break; sleep 1; n=$((n + 1)) ;;
            *) break ;;
        esac
    done
    printf '%s\tDOWN\n' "$ip"
}
for ip in "$@"; do
    case "$ip" in *[!0-9a-fA-F:.]*|'') continue ;; esac
    check "$ip" &
done
wait
