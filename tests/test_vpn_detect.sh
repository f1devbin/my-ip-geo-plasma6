#!/bin/bash
# VPN / interface type detection of netdiag.sh against a fake sysfs and a fake "ip"
S=${1:?netdiag.sh}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/net" "$T/bin" "$T/links" "$T/addrs"
cat > "$T/bin/ip" <<'IP'
#!/bin/bash
F=$FAKE
case "$*" in
    "-o link show dev "*) d=${@: -1}; [ -f "$F/links/$d" ] && cat "$F/links/$d" || exit 1 ;;
    "-o addr show dev "*) d=${@: -1}; cat "$F/addrs/$d" 2>/dev/null ;;
    "-4 route show default") cat "$F/route4" 2>/dev/null ;;
    "-6 route show default") cat "$F/route6" 2>/dev/null ;;
    "-4 route get "*) cat "$F/egress" 2>/dev/null ;;
esac
IP
chmod +x "$T/bin/ip"
# dev devtype type tun_flags(0/1) flags addr
mk() {
    local d=$1
    mkdir -p "$T/net/$d"
    { [ "$2" != - ] && echo "DEVTYPE=$2"; echo "INTERFACE=$d"; } > "$T/net/$d/uevent"
    echo "$3" > "$T/net/$d/type"
    [ "$4" = 1 ] && echo 0x1001 > "$T/net/$d/tun_flags"
    echo "7: $d: <$5> mtu 1500 qdisc fq_codel state UNKNOWN mode DEFAULT group default qlen 500\\    link/none" > "$T/links/$d"
    : > "$T/addrs/$d"
    [ "$6" != - ] && echo "7: $d    inet $6 scope global $d\\       valid_lft forever preferred_lft forever" > "$T/addrs/$d"
}
mk wlp2s0 wlan 1 0 BROADCAST,MULTICAST,UP,LOWER_UP 192.168.1.5/24
mkdir -p "$T/net/wlp2s0/phy80211"
mk tun0 ovpn 65534 0 POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP 10.42.0.5/22
mk dco0 ovpn-dco 65534 0 POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP 10.8.0.2/24
mk tun1 - 65534 1 POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP 10.9.0.2/24
mk wg0 wireguard 65534 0 POINTOPOINT,NOARP,UP,LOWER_UP 10.66.0.2/32
mk wwan0 wwan 65534 0 POINTOPOINT,NOARP,UP,LOWER_UP 100.70.1.2/30
mk tun2 - 65534 1 POINTOPOINT,MULTICAST,NOARP,UP 10.10.0.2/24
mk tun3 - 65534 1 POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP -
mk vnet0 - 1 1 BROADCAST,MULTICAST,UP,LOWER_UP -
mk docker0 bridge 1 0 NO-CARRIER,BROADCAST,MULTICAST,UP 172.17.0.1/16
mk tailscale0 - 65534 1 POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP 100.101.1.2/32
mk enp3s0 - 1 0 BROADCAST,MULTICAST,UP,LOWER_UP 192.168.0.9/24
mk lo - 772 0 LOOPBACK,UP,LOWER_UP 127.0.0.1/8
mk ppp0 - 512 0 POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP 172.20.0.2/32
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok  - $1"; else echo "FAIL- $1: got [$2] want [$3]"; fail=1; fi; }
run() { FAKE=$T PATH="$T/bin:$PATH" MYIPGEO_SYSFS_NET="$T/net" bash -c "source "$S" __source; $1"; }

echo "default via 192.168.1.1 dev wlp2s0 proto dhcp metric 600" > "$T/route4"
check "kinds" "$(run 'for d in wlp2s0 tun0 dco0 tun1 wg0 wwan0 docker0 tailscale0 enp3s0 lo ppp0 vnet0; do printf "%s=%s " $d $(iface_kind $d); done')" \
    "wlp2s0=wifi tun0=vpn dco0=vpn tun1=vpn wg0=vpn wwan0=mobile docker0=bridge tailscale0=vpn enp3s0=ethernet lo=loopback ppp0=ppp vnet0=vpn "
check "active VPNs: ovpn, ovpn-dco, tun, WireGuard, Tailscale, PPTP-style ppp; not down/addressless tun, wwan, tap without IP" \
    "$(run 'vpn_ifaces | sort | tr "\n" " "')" "dco0 vpn openvpn ppp0 ppp ppp tailscale0 vpn tun tun0 vpn openvpn tun1 vpn tun wg0 vpn wireguard "
# An OpenVPN DCO device without LOWER_UP still counts when internet traffic goes through it
mk ovpn1 ovpn 65534 0 POINTOPOINT,NOARP,UP 10.43.0.2/24
check "no carrier flag, not the route: ignored" "$(run 'vpn_ifaces | grep -c ^ovpn1')" "0"
echo "1.1.1.1 via 10.43.0.1 dev ovpn1 src 10.43.0.2 uid 1000" > "$T/egress"
check "no carrier flag, but the route to the internet: active" "$(run 'vpn_ifaces | grep ^ovpn1')" "ovpn1 vpn openvpn"
rm -f "$T/egress"
echo "default dev ppp0 proto static scope link metric 50" > "$T/route4"
check "PPPoE as the only route is the connection, not a VPN" "$(run 'vpn_ifaces | grep -c ^ppp0')" "0"
exit $fail
