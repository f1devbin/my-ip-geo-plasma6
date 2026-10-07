#!/bin/sh
# My IP & Geo - local network scanner. Runs as a normal user, needs only ping and ip.
#
# Every address of the network is pinged once. To send the ping the kernel first
# resolves the address with ARP, so devices that ignore ping (phones, Windows with
# a firewall) still answer ARP and show up in the neighbour table with their MAC.
#
#   netscan.sh scan <a.b.c.d/prefix> [runid]   prints: __INFO__ <count> | UP <ip> ... | __NEIGH__ + `ip -4 neigh show`
#   netscan.sh names <ip>...            prints "<ip> <hostname>" for addresses with a reverse name

set -f  # no globbing: word splitting below is intentional

scan() {
    cidr=$1
    addr=${cidr%/*}
    bits=${cidr#*/}
    [ "$bits" = "$cidr" ] && bits=32
    case "$bits" in ''|*[!0-9]*) echo __BADCIDR__; return ;; esac
    [ "$bits" -le 32 ] || { echo __BADCIDR__; return; }
    oldifs=$IFS; IFS=.
    set -- $addr
    IFS=$oldifs
    [ $# -eq 4 ] || { echo __BADCIDR__; return; }
    for octet in "$@"; do
        case "$octet" in ''|*[!0-9]*) echo __BADCIDR__; return ;; esac
        [ "$octet" -le 255 ] || { echo __BADCIDR__; return; }
    done

    ip=$(( ($1 << 24) | ($2 << 16) | ($3 << 8) | $4 ))
    if [ "$bits" -eq 0 ]; then mask=0; else mask=$(( (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF )); fi
    net=$(( ip & mask ))
    bcast=$(( net | (~mask & 0xFFFFFFFF) ))
    if [ "$bits" -ge 31 ]; then first=$net; last=$bcast; else first=$(( net + 1 )); last=$(( bcast - 1 )); fi
    count=$(( last - first + 1 ))
    # Up to a /20: a /21 takes about 20 s, a bigger network would take minutes
    [ "$count" -le 4096 ] || { echo "__TOOBIG__ $count"; return; }
    echo "__INFO__ $count"

    # The kernel keeps 1024 neighbour entries by default and drops entries older than 5 s when
    # the table is full. In a big network an early answer to ARP would be gone before the scan
    # ends, so the answered entries are collected every 2 s while the pings run.
    tmp=$(mktemp -d 2>/dev/null) || { tmp=/tmp/myipgeo-scan.$$; mkdir -p "$tmp"; }
    trap 'rm -rf "$tmp"' EXIT
    (
        while [ ! -e "$tmp/stop" ]; do
            ip -4 neigh show nud reachable >> "$tmp/seen" 2>/dev/null
            sleep 2
        done
    ) &
    reader=$!

    i=$first
    while [ "$i" -le "$last" ]; do
        echo "$(( (i >> 24) & 255 )).$(( (i >> 16) & 255 )).$(( (i >> 8) & 255 )).$(( i & 255 ))"
        i=$(( i + 1 ))
    done | xargs -P 128 -n 1 sh -c 'ping -n -q -c 1 -W 1 "$0" >/dev/null 2>&1 && echo "UP $0"'

    # Wait until pending ARP requests and re-validation of cached entries are finished,
    # so the table shows who really answered (REACHABLE) and who is gone (FAILED).
    sleep 1
    n=0
    while [ "$n" -lt 7 ] && ip -4 neigh show | grep -qE ' (INCOMPLETE|DELAY|PROBE) *$'; do
        sleep 1
        n=$(( n + 1 ))
    done
    : > "$tmp/stop"
    wait "$reader" 2>/dev/null
    echo __NEIGH__
    ip -4 neigh show
    sort -u "$tmp/seen" 2>/dev/null
}

names() {
    for host in "$@"; do
        case "$host" in *[!0-9.]*) continue ;; esac
        (
            name=$(timeout 2 getent hosts "$host" 2>/dev/null | awk '{ print $2; exit }')
            [ -n "$name" ] && echo "$host $name"
        ) &
    done
    wait
}

case "$1" in
    scan) scan "$2" ;;
    names) shift; names "$@" ;;
esac
