#!/bin/sh
# My IP & Geo - speed test against Cloudflare's public speed test endpoints (curl only).
# Follows Cloudflare's own method: latency = time to first byte of empty requests minus the
# server time reported in Server-Timing; download/upload use 4 parallel streams, max 8 s each.
#
#   speedtest.sh ping   12 x "PING <pretransfer> <starttransfer> <http> <cf-ray>|<server-timing>"
#   speedtest.sh down    4 x "DOWN <bytes> <starttransfer> <total> <http>"
#   speedtest.sh up      "UP <stream> <bytes> <pretransfer> <total>" for every completed upload request

set -f  # no globbing: word splitting below is intentional

base=${MYIPGEO_SPEEDTEST_BASE:-https://speed.cloudflare.com}

case "$1" in
    ping)
        set --
        i=0
        while [ "$i" -lt 12 ]; do
            set -- "$@" -o /dev/null "$base/__down?bytes=0"
            i=$(( i + 1 ))
        done
        # One curl process reuses the connection, so only the first request pays for TCP/TLS setup
        curl -4 -s --max-time 15 -w 'PING %{time_pretransfer} %{time_starttransfer} %{http_code} %header{cf-ray}|%header{server-timing}\n' "$@"
        ;;
    down)
        for stream in 1 2 3 4; do
            curl -4 -s --max-time 8 -o /dev/null \
                -w 'DOWN %{size_download} %{time_starttransfer} %{time_total} %{http_code}\n' \
                "$base/__down?bytes=50000000" &
        done
        wait
        ;;
    up)
        # Only completed requests count: an upload cut off by the time limit would also count
        # bytes still waiting in the local socket buffer. Each stream sends one request after
        # another and doubles the size while a request takes less than a second.
        end=$(( $(date +%s) + 8 ))
        for stream in 1 2 3 4; do
            (
                size=1000000
                while :; do
                    left=$(( end - $(date +%s) ))
                    [ "$left" -gt 0 ] || break
                    # Random data: zeros could be compressed by a VPN and inflate the result
                    out=$(head -c "$size" /dev/urandom | curl -4 -s --max-time "$left" -o /dev/null -X POST \
                        -H 'Content-Type: application/octet-stream' -H 'Expect:' --data-binary @- \
                        -w '%{size_upload} %{time_pretransfer} %{time_total} %{http_code}' "$base/__up")
                    set -- $out
                    [ "$4" = 200 ] || break
                    echo "UP $stream $1 $2 $3"
                    if [ "$size" -lt 25000000 ] && awk "BEGIN { exit !($3 < 1) }"; then size=$(( size * 2 )); fi
                done
            ) &
        done
        wait
        ;;
esac
