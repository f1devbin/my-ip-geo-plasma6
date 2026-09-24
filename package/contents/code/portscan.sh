#!/bin/bash
# My IP & Geo - TCP port check for one host on the local network (Scanner -> Ports).
# Plain unprivileged TCP connect through bash's /dev/tcp: no root, nmap, netcat or extra
# packages. It only reports whether a port accepts a connection; it sends no data.
#
#   portscan.sh <host> <spec> [runid]
#     spec: common | 1-1024 | <from>-<to>
#
# Output:
#   SCAN <host> <ports_scanned>
#   OPEN <port> <service>          one line per open port, lowest first
#   DONE <open_count>
#   ERROR <message>                on bad input
# runid only makes the command string unique so the executable engine re-runs it.

host=$1
spec=$2

# Only a bare IPv4/IPv6 literal is ever accepted, so the value can carry nothing but an address.
case "$host" in
    ''|*[!0-9.:a-fA-F]*) echo "ERROR invalid host"; exit 0 ;;
esac

CONNECT_TIMEOUT=0.35    # seconds to wait for one port
MAX_PORTS=2048         # hard cap, so the widget can never hang on a huge range
CONCURRENCY=200        # parallel connects

# Well-known service ports, checked in "common" mode
COMMON="20 21 22 23 25 53 67 80 110 111 123 135 139 143 161 389 443 445 465 514 515 587 \
631 993 995 1080 1194 1433 1521 1723 1883 2049 2222 3000 3306 3389 5000 5060 5432 5900 \
5985 6379 8000 8006 8080 8081 8443 8888 9000 9090 9100 9200 10000 11211 27017"

ports=""
case "$spec" in
    common)
        ports=$COMMON ;;
    *-*)
        from=${spec%%-*}; to=${spec##*-}
        case "$from" in ''|*[!0-9]*) echo "ERROR bad range"; exit 0 ;; esac
        case "$to" in ''|*[!0-9]*) echo "ERROR bad range"; exit 0 ;; esac
        [ "$from" -lt 1 ] && from=1
        [ "$to" -gt 65535 ] && to=65535
        if [ "$from" -gt "$to" ]; then tmp=$from; from=$to; to=$tmp; fi
        [ $((to - from + 1)) -gt "$MAX_PORTS" ] && to=$((from + MAX_PORTS - 1))
        ports=$(seq "$from" "$to") ;;
    *)
        echo "ERROR bad spec"; exit 0 ;;
esac

count=$(printf '%s\n' $ports | grep -c .)
echo "SCAN $host $count"

# One TCP connect attempt; prints the port number if the connection is accepted.
probe() {
    if timeout "$CONNECT_TIMEOUT" bash -c "exec 3<>/dev/tcp/$MYIPGEO_HOST/$1" 2>/dev/null; then
        echo "$1"
    fi
}
export -f probe
export MYIPGEO_HOST="$host" CONNECT_TIMEOUT

# Scan in parallel, then report the open ports in numeric order with their service name.
open_count=0
for p in $(printf '%s\n' $ports | xargs -P "$CONCURRENCY" -I{} bash -c 'probe "$@"' _ {} | sort -n); do
    svc=$(getent services "$p/tcp" 2>/dev/null | awk '{print $1; exit}')
    echo "OPEN $p ${svc:-}"
    open_count=$((open_count + 1))
done
echo "DONE $open_count"
