#!/bin/bash
# My IP & Geo - network checks for the Diagnostics tab and the header indicators.
# Runs as a normal user with standard tools only: ip, ping, getent, curl.
# iw, nmcli, resolvectl and timedatectl add details when they are installed.
#
#   netdiag.sh <check> [run-id]        the run-id only makes every command string unique
#     status    ONLINE <s> | VPN <s> | OFFLINE (header indicators)
#     dnsmap    DNS servers per interface as "Link N (dev): servers" (Local IPs tab)
#     link      default routes, adapter type, Wi-Fi link, VPN interfaces
#     gateway   5 pings to the router and its ARP entry
#     dns       DNS servers, a normal and an uncached lookup, both timed
#     internet  10 pings to 1.1.1.1 and to 8.8.8.8, TCP connect when ICMP is blocked
#     web       HTTPS request with timings, captive portal check, clock sync
#     ipv6      global IPv6 address, route, ping and public IPv6 address
#     mtu       path MTU towards 1.1.1.1
#     route     hops towards 1.1.1.1 and their reverse names
#
# Output is "KEY value" lines and raw tool output after "__NAME__" markers, parsed in main.qml.

export LC_ALL=C
TARGET=1.1.1.1
TRACE_URL=https://www.cloudflare.com/cdn-cgi/trace
PORTAL_URL=http://connectivitycheck.gstatic.com/generate_204

tmp=$(mktemp -d 2>/dev/null) || { tmp=/tmp/myipgeo-diag.$$; mkdir -p "$tmp"; }
trap 'rm -rf "$tmp"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }

# Network interfaces in sysfs (overridable only for tests)
NET=${MYIPGEO_SYSFS_NET:-/sys/class/net}

# Microseconds from bash's $EPOCHREALTIME (no extra process per time stamp)
now_us() { local t=${EPOCHREALTIME/./}; echo $((10#$t)); }

# Interface type from sysfs: wifi | ethernet | vpn | ppp | mobile | bridge | loopback | other
iface_kind() {
    local p=$NET/$1 devtype type
    devtype=$(sed -n 's/^DEVTYPE=//p' "$p/uevent" 2>/dev/null)
    type=$(cat "$p/type" 2>/dev/null)
    case "$devtype" in
        wlan) echo wifi; return ;;
        # WireGuard; OpenVPN with data channel offload (kernel "ovpn" driver, ovpn-dco module)
        wireguard|ovpn*) echo vpn; return ;;
        wwan) echo mobile; return ;;
        bridge) echo bridge; return ;;
    esac
    if [ -d "$p/wireless" ] || [ -e "$p/phy80211" ]; then echo wifi; return; fi
    # tun/tap: OpenVPN, Cloudflare WARP, Tailscale, ZeroTier, wireguard-go
    if [ -e "$p/tun_flags" ]; then echo vpn; return; fi
    case "$type" in
        772) echo loopback ;;
        512) echo ppp ;;
        65534) echo vpn ;;  # no link layer: tunnels
        *) case "$1" in
               wg*|tun*|tap*|nordlynx|proton*|CloudflareWARP|tailscale*|zt*|ipsec*|vti*|gpd*|vpn*) echo vpn ;;
               *) if [ "$type" = 1 ]; then echo ethernet; else echo other; fi ;;
           esac ;;
    esac
}

# What carries a VPN interface: wireguard | openvpn (kernel data channel offload) | tun | ppp | tunnel
vpn_type() {
    local p=$NET/$1 devtype
    devtype=$(sed -n 's/^DEVTYPE=//p' "$p/uevent" 2>/dev/null)
    case "$devtype" in wireguard) echo wireguard; return ;; ovpn*) echo openvpn; return ;; esac
    if [ -e "$p/tun_flags" ]; then echo tun; return; fi
    if [ "$(cat "$p/type" 2>/dev/null)" = 512 ]; then echo ppp; return; fi
    echo tunnel
}

# Active VPN interfaces: "<dev> <kind> <type>". Tunnels report operstate "unknown", so the UP and
# LOWER_UP flags plus an assigned address decide. PPP is a VPN (PPTP, L2TP) only when the
# internet also has a route through another interface; otherwise it is the connection itself.
vpn_ifaces() {
    local p dev kind flags other egress
    other=$({ ip -4 route show default; ip -6 route show default; } 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | grep -v '^ppp' | head -n 1)
    egress=$(ip -4 route get "$TARGET" 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n 1)
    for p in "$NET"/*; do
        dev=${p##*/}
        kind=$(iface_kind "$dev")
        case "$kind" in
            vpn) ;;
            ppp) [ -n "$other" ] || continue ;;
            *) continue ;;
        esac
        # Internet traffic goes through it: active whatever the flags say
        if [ "$dev" = "$egress" ]; then echo "$dev $kind $(vpn_type "$dev")"; continue; fi
        flags=$(ip -o link show dev "$dev" 2>/dev/null) || continue
        flags=${flags#*<}; flags=",${flags%%>*},"
        case "$flags" in *,UP,*) ;; *) continue ;; esac
        case "$flags" in *,LOWER_UP,*) ;; *) continue ;; esac
        ip -o addr show dev "$dev" 2>/dev/null | awk '$3 == "inet" || ($3 == "inet6" && $4 !~ /^fe80/) { f = 1 } END { exit !f }' || continue
        echo "$dev $kind $(vpn_type "$dev")"
    done
}

check_status() {
    local route=0 t="" url conn
    ip -4 route show default 2>/dev/null | grep -q . && route=1
    ip -6 route show default 2>/dev/null | grep -q . && route=1
    if [ "$route" = 1 ]; then
        for url in https://www.google.com/generate_204 https://www.gstatic.com/generate_204 https://www.msftconnecttest.com/connecttest.txt "$TRACE_URL"; do
            # curl prints -w output also for failed requests: only a successful exit counts
            if t=$(curl -fsS --connect-timeout 3 --max-time 5 -o /dev/null -w '%{time_total}' "$url" 2>/dev/null); then break; fi
            t=""
        done
    fi
    if [ -z "$t" ]; then
        # All probes failed (or no route): trust NetworkManager only if it just saw full connectivity
        conn=$(nmcli -t -f CONNECTIVITY networking connectivity check 2>/dev/null | head -n 1)
        [ "$conn" = full ] || { echo OFFLINE; return; }
    fi
    if [ -n "$(vpn_ifaces)" ]; then echo "VPN ${t:-0}"; else echo "ONLINE ${t:-0}"; fi
}

# resolvectl when systemd-resolved runs, else NetworkManager, else /etc/resolv.conf
check_dnsmap() {
    if have resolvectl && resolvectl --no-pager dns > "$tmp/r" 2>/dev/null && grep -q '): [^ ]' "$tmp/r"; then
        cat "$tmp/r"
        return
    fi
    if have nmcli; then
        nmcli -t -f GENERAL.DEVICE,IP4.DNS,IP6.DNS device show 2>/dev/null | awk '
            { i = index($0, ":"); key = substr($0, 1, i - 1); val = substr($0, i + 1); gsub(/\\:/, ":", val) }
            key == "GENERAL.DEVICE" { if (dev != "" && dns != "") print "Link 0 (" dev "): " dns; dev = val; dns = ""; next }
            key ~ /^IP[46]\.DNS/ && val != "" { dns = dns (dns == "" ? "" : " ") val }
            END { if (dev != "" && dns != "") print "Link 0 (" dev "): " dns }' > "$tmp/n"
        if [ -s "$tmp/n" ]; then cat "$tmp/n"; return; fi
    fi
    local ns dev
    ns=$(sed -n 's/^[[:space:]]*nameserver[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p' /etc/resolv.conf 2>/dev/null | tr '\n' ' ')
    [ -n "$ns" ] || return
    for dev in $({ ip -4 route show default; ip -6 route show default; } 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | sort -u); do
        echo "Link 0 ($dev): $ns"
    done
}

iface_info() {
    local dev=$1 p=$NET/$1 kind devtype
    [ -d "$p" ] || return
    kind=$(iface_kind "$dev")
    devtype=$(sed -n 's/^DEVTYPE=//p' "$p/uevent" 2>/dev/null)
    echo "IFACE $dev kind=$kind devtype=${devtype:--} operstate=$(cat "$p/operstate" 2>/dev/null) mtu=$(cat "$p/mtu" 2>/dev/null) speed=$(cat "$p/speed" 2>/dev/null) duplex=$(cat "$p/duplex" 2>/dev/null) mac=$(cat "$p/address" 2>/dev/null)"
    ip -o addr show dev "$dev" 2>/dev/null | awk -v d="$dev" '$3 == "inet" || $3 == "inet6" { print "ADDR", d, $3, $4 }'
    if [ "$kind" = wifi ]; then
        have iw && iw dev "$dev" link 2>/dev/null | sed "s/^/IW $dev /"
        have nmcli && nmcli -t -f IN-USE,SSID,CHAN,FREQ,RATE,SIGNAL device wifi list ifname "$dev" --rescan no 2>/dev/null | grep '^\*' | head -n 1 | sed "s/^/NMWIFI $dev /"
        grep -s "^ *$dev:" /proc/net/wireless | sed "s/^ */PROCWL /"
    fi
}

check_link() {
    local egress devs dev seen=" "
    ip -4 route show default 2>/dev/null | sed 's/^/ROUTE4 /'
    ip -6 route show default 2>/dev/null | sed 's/^/ROUTE6 /'
    egress=$(ip -4 route get "$TARGET" 2>/dev/null | head -n 1)
    [ -n "$egress" ] && echo "EGRESS $egress"
    devs=$({ ip -4 route show default; ip -6 route show default; echo "$egress"; } 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p')
    for dev in $devs; do
        case "$seen" in *" $dev "*) continue ;; esac
        seen="$seen$dev "
        iface_info "$dev"
    done
    vpn_ifaces | sed 's/^/VPN /'
    # Process names are readable for everyone: a running VPN application names the tunnel
    cat /proc/[0-9]*/comm 2>/dev/null | sort -u | grep -Ex 'riseup-vpn|calyx-vpn|bitmask|mullvad-daemon|nordvpnd|expressvpnd|windscribe|protonvpn-app|protonvpn|AmneziaVPN|amnezia-vpn|hiddify|openconnect|openfortivpn' | sed 's/^/VPNAPP /'
    if have nmcli; then
        nmcli -t -f CONNECTIVITY general 2>/dev/null | head -n 1 | sed 's/^/NMCONN /'
        nmcli -t -f DEVICE,NAME connection show --active 2>/dev/null | sed 's/^/NMACTIVE /'
    fi
}

check_gateway() {
    local gw dev
    read -r gw dev <<EOF
$(ip -4 route show default 2>/dev/null | awk '{ g = ""; d = ""; for (i = 1; i < NF; i++) { if ($i == "via") g = $(i + 1); if ($i == "dev") d = $(i + 1) } if (g != "") { print g, d; exit } }')
EOF
    if [ -z "$gw" ]; then echo "NOGW"; return; fi
    echo "GW $gw $dev"
    echo "__PING__ $gw"
    ping -n -c 5 -i 0.2 -W 1 "$gw" 2>&1
    echo "__NEIGH__"
    ip neigh show "$gw" 2>/dev/null
}

lookup() { # <name> <tag>
    local out
    # Timed inside: "timeout" itself adds up to 100 ms when the command ends (uutils coreutils)
    out=$(timeout 5 bash -c 't0=${EPOCHREALTIME/./}; a=$(getent ahostsv4 "$1"); rc=$?; t1=${EPOCHREALTIME/./}
        echo "rc=$rc ms=$(( (10#$t1 - 10#$t0) / 1000 )) addr=${a%%[[:space:]]*}"' lookup "$1" 2>/dev/null)
    echo "$2 ${out:-rc=124 ms=5000 addr=}"
}

check_dns() {
    check_dnsmap | sed 's/^/SERVERS /'
    grep -qs '^[[:space:]]*nameserver[[:space:]]\{1,\}127\.0\.0\.53' /etc/resolv.conf && echo "STUB systemd-resolved"
    lookup www.cloudflare.com LOOKUP > "$tmp/l1" &
    # A name that cannot be in any cache: the time of a real round trip through the resolvers
    lookup "myipgeo-$RANDOM$RANDOM.example.com" NXLOOKUP > "$tmp/l2" &
    # DNS over HTTPS to 1.1.1.1 tells a broken DNS server from a missing internet connection
    { curl -s --max-time 5 -H 'accept: application/dns-json' "https://$TARGET/dns-query?name=www.cloudflare.com&type=A" 2>/dev/null \
        | grep -q '"Answer"' && echo "DOH ok" || echo "DOH fail"; } > "$tmp/l3" &
    wait
    cat "$tmp/l1" "$tmp/l2" "$tmp/l3"
}

check_internet() {
    local t
    for t in 1.1.1.1 8.8.8.8; do ping -n -c 10 -i 0.2 -W 1 "$t" > "$tmp/ping-$t" 2>&1 & done
    wait
    for t in 1.1.1.1 8.8.8.8; do echo "__PING__ $t"; cat "$tmp/ping-$t"; done
    # ICMP is blocked on some networks: TCP connect time instead
    if ! grep -qs ' bytes from ' "$tmp"/ping-*; then
        curl -s -o /dev/null --max-time 4 -w 'TCP %{time_connect} %{http_code}\n' "http://$TARGET/" 2>/dev/null
    fi
}

check_web() {
    curl -s -o /dev/null --max-time 5 -w 'PORTAL %{http_code} %{redirect_url}\n' "$PORTAL_URL" > "$tmp/portal" 2>/dev/null &
    # The same request over IPv4 only: a much slower connect above means failed IPv6 attempts first
    curl -4 -s -o /dev/null --max-time 8 -w 'WEB4 %{http_code} %{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{remote_ip}\n' "$TRACE_URL" > "$tmp/web4" 2>/dev/null &
    curl -sS --max-time 8 -o "$tmp/trace" -w 'WEB %{http_code} %{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{remote_ip}\n' "$TRACE_URL" > "$tmp/web" 2> "$tmp/err"
    echo "WEBRC $?"
    wait
    cat "$tmp/web" "$tmp/web4" "$tmp/portal"
    head -n 1 "$tmp/err" | sed 's/^/WEBERR /'
    grep -Es '^(ip|loc|colo|warp|tls|http)=' "$tmp/trace" | head -n 8 | sed 's/^/TRACE /'
    have timedatectl && timedatectl show -p NTPSynchronized --value 2>/dev/null | head -n 1 | sed 's/^/NTP /'
}

check_ipv6() {
    ip -6 addr show scope global 2>/dev/null | awk '$1 == "inet6" { print "ADDR6", $2 }'
    ip -6 route show default 2>/dev/null | sed 's/^/ROUTE6 /'
    # Which interface IPv6 traffic leaves through (does it go around a VPN?)
    ip -6 route get 2606:4700:4700::1111 2>/dev/null | head -n 1 | sed 's/^/EGRESS6 /'
    if ip -6 route show default 2>/dev/null | grep -q . && ip -6 addr show scope global 2>/dev/null | grep -q inet6; then
        ping -6 -n -c 4 -i 0.2 -W 1 2606:4700:4700::1111 > "$tmp/ping6" 2>&1 &
        curl -6 -s --max-time 5 "$TRACE_URL" 2>/dev/null | sed -n 's/^ip=/PUBLIC6 /p' > "$tmp/pub6" &
        wait
        echo "__PING__ 2606:4700:4700::1111"
        cat "$tmp/ping6" "$tmp/pub6"
    fi
}

check_mtu() {
    local dev s
    dev=$(ip -4 route get "$TARGET" 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n 1)
    [ -n "$dev" ] && echo "DEVMTU $dev $(cat "$NET/$dev/mtu" 2>/dev/null)"
    # A full-size packet that must not be fragmented: a smaller link on the way answers with its MTU
    echo "__PMTU__"
    ping -n -M do -s 1472 -c 2 -i 0.2 -W 1 "$TARGET" 2>&1 | head -n 6
    echo "__SIZES__"
    # Largest packet that still gets an answer, for paths that drop big packets silently
    for s in 1472 1452 1432 1412 1392 1372 1352 1332 1312 1292 1272 1252; do
        ( ping -n -M do -s "$s" -c 1 -W 1 "$TARGET" > /dev/null 2>&1 && echo "OK $s" ) &
    done
    wait
}

hop() { # <ttl>: one probe with this TTL
    local out
    out=$(ping -n -c 1 -W 1 -t "$1" "$TARGET" 2>&1)
    if [[ $out =~ bytes\ from\ ([0-9.]+):.*time=([0-9.]+) ]]; then
        echo "HOP $1 ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} 1"
    elif [[ $out =~ From\ ([0-9.]+)\ icmp_seq=[0-9]+\ Time\ to\ live\ exceeded ]]; then
        echo "HOP $1 ${BASH_REMATCH[1]} - 0"
    elif [[ $out =~ From\ ([0-9.]+)\ icmp_seq=[0-9]+\ Destination ]]; then
        # "Destination ... Unreachable": the route ends at this router
        echo "HOP $1 ${BASH_REMATCH[1]} - 2"
    else
        echo "HOP $1 * - 0"
    fi
}

check_route() {
    local ttl ip
    # Routers on the way: one probe per TTL, all at once (about 1 s)
    for ttl in $(seq 1 15); do hop "$ttl" > "$tmp/hop-$ttl" & done
    wait
    for ttl in $(seq 1 15); do
        cat "$tmp/hop-$ttl"
        grep -q ' [12]$' "$tmp/hop-$ttl" && break
    done > "$tmp/hops"
    cat "$tmp/hops"
    # ping does not time TTL errors: each router is pinged directly, ping measures the round trip
    for ip in $(awk '$1 == "HOP" && $3 != "*" && $5 != 1 { print $3 }' "$tmp/hops" | sort -u); do
        ( ping -n -c 3 -i 0.2 -W 1 "$ip" 2>/dev/null | awk -v ip="$ip" -F 'time=' 'NF > 1 { v = $2 + 0; if (min == "" || v < min) min = v } END { if (min != "") print "RTT", ip, min }' ) &
    done
    for ip in $(awk '$1 == "HOP" && $3 != "*" { print $3 }' "$tmp/hops" | sort -u); do
        ( name=$(timeout 2 getent hosts "$ip" 2>/dev/null | awk '{ print $2; exit }'); [ -n "$name" ] && echo "NAME $ip $name" ) &
    done
    wait
}

case "$1" in
    status) check_status ;;
    dnsmap) check_dnsmap ;;
    link) check_link ;;
    gateway) check_gateway ;;
    dns) check_dns ;;
    internet) check_internet ;;
    web) check_web ;;
    ipv6) check_ipv6 ;;
    mtu) check_mtu ;;
    route) check_route ;;
    __source) ;;  # tests load the functions only
    *) echo "usage: netdiag.sh status|dnsmap|link|gateway|dns|internet|web|ipv6|mtu|route" >&2; exit 2 ;;
esac
