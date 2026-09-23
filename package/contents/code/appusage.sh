#!/bin/sh
# My IP & Geo - per-application traffic accounting for the Apps tab.
# Runs KDE System Monitor's ksgrd_network_helper (installed with cap_net_raw by the distro package)
# for <seconds> and prints how many bytes each process received/sent in that time.
#
#   appusage.sh <seconds>   first line __OK__ | __MISSING__ | __FAILED__, then "<pid> <rx> <tx> <comm>"
#
# The widget runs it back to back, so the totals cover the whole time Plasma is running.

secs=${1:-120}
case "$secs" in ''|*[!0-9]*) secs=120 ;; esac

helper=""
for h in /usr/lib/*/libexec/ksysguard/ksgrd_network_helper /usr/libexec/ksysguard/ksgrd_network_helper /usr/lib/libexec/ksysguard/ksgrd_network_helper; do
    if [ -x "$h" ]; then helper=$h; break; fi
done
if [ -z "$helper" ]; then echo __MISSING__; exit 0; fi

# Helper lines: "HH:MM:SS|PID|<pid>|IN|<bytes>|OUT|<bytes>" once per second; pid -1 = socket of another user.
# Process names are read by the shell loop as soon as a pid shows up, while the process still exists
# (awk reads the pipe in blocks, a short-lived process would be gone by then).
timeout "$secs" "$helper" 2>/dev/null | {
    seen=" "
    while IFS= read -r line; do
        printf '%s\n' "$line"
        case "$line" in
            *'|PID|'*)
                pid=${line#*|PID|}
                pid=${pid%%|*}
                case "$pid" in ''|*[!0-9]*) continue ;; esac
                case "$seen" in *" $pid "*) continue ;; esac
                seen="$seen$pid "
                name=$(cat "/proc/$pid/comm" 2>/dev/null)
                printf 'NAME|%s|%s\n' "$pid" "${name:-?}"
                ;;
        esac
    done
} | awk -F'|' '
    { lines++ }
    $1 == "NAME" { name[$2] = substr($0, length($1 "|" $2 "|") + 1); next }
    NF >= 7 && $3 > 0 { rx[$3] += $5; tx[$3] += $7 }
    END {
        print (lines > 0 ? "__OK__" : "__FAILED__")
        for (p in rx) if (rx[p] + tx[p] > 0) printf "%s %.0f %.0f %s\n", p, rx[p], tx[p], ((p in name) ? name[p] : "?")
    }'
