#!/bin/bash
# v6.1.50: netdiag.sh path to the internet (status) and DNS lists without IPv4-mapped repeats
S=${1:?netdiag.sh}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/net/enp0s31f6" "$T/net/tun0" "$T/net/CloudflareWARP"
echo 2 > "$T/net/enp0s31f6/ifindex"
echo 12 > "$T/net/tun0/ifindex"
echo 7 > "$T/net/CloudflareWARP/ifindex"
cat > "$T/bin/ip" <<'IP'
#!/bin/bash
case "$*" in
    "-4 route get "*) cat "$FAKE/egress" 2>/dev/null || { echo "RTNETLINK answers: Network is unreachable" >&2; exit 2; } ;;
esac
IP
chmod +x "$T/bin/ip"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok  - $1"; else echo "FAIL- $1: got [$2] want [$3]"; fail=1; fi; }
run() { FAKE=$T PATH="$T/bin:$PATH" MYIPGEO_SYSFS_NET="$T/net" bash -c "source \"$S\" __source; $1"; }

printf '1.1.1.1 via 192.0.2.1 dev enp0s31f6 src 192.0.2.10 uid 1000 \n    cache \n' > "$T/egress"
check "net_path: Ethernet with gateway" "$(run net_path)" "enp0s31f6#2/192.0.2.1/192.0.2.10"
printf '1.1.1.1 via 10.138.192.1 dev tun0 src 10.138.192.18 uid 1000 \n    cache \n' > "$T/egress"
check "net_path: OpenVPN" "$(run net_path)" "tun0#12/10.138.192.1/10.138.192.18"
printf '1.1.1.1 dev CloudflareWARP table 65743 src 172.16.0.2 uid 1000 \n    cache \n' > "$T/egress"
check "net_path: WARP, no gateway" "$(run net_path)" "CloudflareWARP#7/-/172.16.0.2"
rm -f "$T/egress"
check "net_path: no route" "$(run net_path)" "-#0/-/-"

check "dns_clean: mapped IPv4 becomes IPv4, repeats dropped, order kept" \
    "$(printf 'Link 5 (CloudflareWARP): 127.0.2.2 127.0.2.3 ::ffff:127.0.2.2 ::ffff:127.0.2.3\n' | run dns_clean)" \
    "Link 5 (CloudflareWARP): 127.0.2.2 127.0.2.3"
check "dns_clean: a mapped address alone, IPv6 servers and DoT names stay" \
    "$(printf 'Link 3 (wlp2s0): ::FFFF:192.0.2.53 2001:db8::53 fe80::1%%3 1.1.1.1#cloudflare-dns.com\n' | run dns_clean)" \
    "Link 3 (wlp2s0): 192.0.2.53 2001:db8::53 fe80::1%3 1.1.1.1#cloudflare-dns.com"
check "dns_clean: Global line, empty link, plain list unchanged" \
    "$(printf 'Global: 1.1.1.1 ::ffff:1.1.1.1\nLink 4 (docker0):\nLink 2 (enp0s31f6): 10.255.255.1 192.0.2.1\n' | run dns_clean | tr '\n' '|')" \
    "Global: 1.1.1.1|Link 4 (docker0):|Link 2 (enp0s31f6): 10.255.255.1 192.0.2.1|"
exit $fail
