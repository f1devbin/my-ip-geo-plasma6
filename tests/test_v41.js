// v6.1.41: VPN detection fallback, IPv6 behind a VPN, VPN names, public IP providers
const assert = require('assert');
const { load } = require('./extract');
const names = ['parseDiag', 'parsePing', 'parseRouteLine', 'splitTerse', 'wifiQuality', 'parseDiagLink', 'parseDiagGateway',
  'parseDiagDns', 'parseDiagInternet', 'parseDiagWeb', 'parseDiagIpv6', 'parseDiagMtu', 'parseDiagRoute', 'fmtMs',
  'diagMainIface', 'diagVpnName', 'diagEvaluate', 'parsePublicIp'];
const root = load(process.argv[2], names);
root.diagChecks = ['link', 'gateway', 'dns', 'internet', 'web', 'ipv6', 'mtu', 'route'];
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const tile = (v, title) => v.tiles.find(s => s.title === title);

const pingOk = (ip, ms) => `PING ${ip} (${ip}) 56(84) bytes of data.\n64 bytes from ${ip}: icmp_seq=1 ttl=57 time=${ms} ms\n64 bytes from ${ip}: icmp_seq=2 ttl=57 time=${ms} ms\n\n--- ${ip} ping statistics ---\n2 packets transmitted, 2 received, 0% packet loss, time 200ms\nrtt min/avg/max/mdev = ${ms}/${ms}/${ms}/0.000 ms\n`;
const pingFail = ip => `PING ${ip} 56 data bytes\n\n--- ${ip} ping statistics ---\n4 packets transmitted, 0 received, 100% packet loss, time 603ms\n`;
// RiseupVPN (OpenVPN, tun0) as in the screenshot: IPv4 through tun0, IPv6 blocked by the VPN
const riseupLink = [
  'ROUTE4 default via 192.168.1.1 dev wlp2s0 proto dhcp src 192.168.1.5 metric 600 ',
  'EGRESS 1.1.1.1 via 10.42.0.1 dev tun0 src 10.42.0.5 uid 1000 ',
  'IFACE wlp2s0 kind=wifi devtype=wlan operstate=up mtu=1500 speed= duplex= mac=aa:bb:cc:dd:ee:ff',
  'ADDR wlp2s0 inet 192.168.1.5/24',
  'IFACE tun0 kind=vpn devtype=ovpn operstate=unknown mtu=1500 speed= duplex= mac=',
  'ADDR tun0 inet 10.42.0.5/22'].join('\n');
const base = () => ({
  gateway: root.parseDiagGateway('GW 192.168.1.1 wlp2s0\n__PING__ 192.168.1.1\n' + pingOk('192.168.1.1', '3.1') + '__NEIGH__\n192.168.1.1 dev wlp2s0 lladdr 11:22:33:44:55:66 REACHABLE\n'),
  dns: root.parseDiagDns('SERVERS Link 3 (wlp2s0): 192.168.1.1\nLOOKUP rc=0 ms=4 addr=104.16.124.96\nNXLOOKUP rc=2 ms=40 addr=\nDOH ok\n'),
  internet: root.parseDiagInternet('__PING__ 1.1.1.1\n' + pingOk('1.1.1.1', '45.0') + '__PING__ 8.8.8.8\n' + pingOk('8.8.8.8', '47.0')),
  web: root.parseDiagWeb('WEBRC 0\nWEB 200 0.004 0.050 0.110 0.160 0.161 104.16.124.96\nPORTAL 204 \nTRACE ip=51.158.8.9\nTRACE loc=NL\nTRACE colo=AMS\nTRACE warp=off\n'),
  mtu: root.parseDiagMtu('DEVMTU tun0 1500\n__PMTU__\n' + pingOk('1.1.1.1', '45') + '__SIZES__\nOK 1472\n'),
  route: []
});

t('VPN missed by the script is taken from the route (tun0 carries the traffic)', () => {
  const d = base();
  d.link = root.parseDiagLink(riseupLink);
  d.ipv6 = root.parseDiagIpv6('ADDR6 2a02:1:2:3::5/64\nROUTE6 default via fe80::1 dev wlp2s0 proto ra metric 600\nEGRESS6 2606:4700:4700::1111 from :: via fe80::1 dev wlp2s0 proto ra src 2a02:1:2:3::5 metric 600 pref medium\n__PING__ 2606:4700:4700::1111\n' + pingFail('2606:4700:4700::1111'));
  const v = root.diagEvaluate(d, {}, false);
  assert.deepStrictEqual([tile(v, 'VPN').status, tile(v, 'VPN').value, tile(v, 'VPN').detail], ['ok', 'VPN · tun0', 'Internet traffic goes through the VPN']);
  assert.deepStrictEqual([tile(v, 'IPv6').status, tile(v, 'IPv6').value], ['info', 'Blocked by VPN']);
  assert.strictEqual(v.verdict.title, 'Everything works');
  assert.strictEqual(v.steps[0].value, 'Wi-Fi', 'the connection step shows the Wi-Fi adapter, not the tunnel');
});

t('VPN reported by the script: OpenVPN (kernel DCO), WireGuard, NetworkManager name', () => {
  const d = base();
  d.link = root.parseDiagLink(riseupLink + '\nVPN tun0 vpn openvpn');
  assert.strictEqual(tile(root.diagEvaluate(d, {}, false), 'VPN').value, 'OpenVPN · tun0');
  d.link = root.parseDiagLink(riseupLink.replace(/tun0/g, 'wg0') + '\nVPN wg0 vpn wireguard');
  assert.strictEqual(tile(root.diagEvaluate(d, {}, false), 'VPN').value, 'WireGuard · wg0');
  d.link = root.parseDiagLink(riseupLink + '\nVPN tun0 vpn tun\nNMACTIVE wlp2s0:Home\nNMACTIVE tun0:Office VPN');
  assert.strictEqual(tile(root.diagEvaluate(d, {}, false), 'VPN').value, 'Office VPN');
});

t('IPv6 going around a full-tunnel VPN is a leak warning', () => {
  const d = base();
  d.link = root.parseDiagLink(riseupLink + '\nVPN tun0 vpn openvpn');
  d.ipv6 = root.parseDiagIpv6('ADDR6 2a02:1:2:3::5/64\nROUTE6 default via fe80::1 dev wlp2s0 proto ra metric 600\nEGRESS6 2606:4700:4700::1111 from :: via fe80::1 dev wlp2s0 proto ra src 2a02:1:2:3::5 metric 600\n__PING__ 2606:4700:4700::1111\n' + pingOk('2606:4700:4700::1111', '15') + 'PUBLIC6 2a02:1:2:3::5\n');
  const v = root.diagEvaluate(d, {}, false);
  assert.deepStrictEqual([tile(v, 'IPv6').status, tile(v, 'IPv6').value, tile(v, 'IPv6').detail], ['warn', 'Bypasses VPN', 'IPv6 leaves through wlp2s0, not the VPN']);
  assert.strictEqual(v.verdict.title, 'IPv6 bypasses the VPN');
  // IPv6 through the tunnel is fine
  d.ipv6 = root.parseDiagIpv6('ADDR6 fd00::5/64\nROUTE6 default dev tun0 metric 50\nEGRESS6 2606:4700:4700::1111 from :: dev tun0 src fd00::5 metric 50\n__PING__ 2606:4700:4700::1111\n' + pingOk('2606:4700:4700::1111', '48'));
  const v2 = root.diagEvaluate(d, {}, false);
  assert.strictEqual(tile(v2, 'IPv6').status, 'ok');
  assert.strictEqual(v2.verdict.title, 'Everything works');
  // without a VPN a dead IPv6 is still a warning
  d.link = root.parseDiagLink(riseupLink.replace(/^EGRESS .*$/m, 'EGRESS 1.1.1.1 via 192.168.1.1 dev wlp2s0 src 192.168.1.5 uid 1000'));
  d.ipv6 = root.parseDiagIpv6('ADDR6 2a02:1:2:3::5/64\nROUTE6 default via fe80::1 dev wlp2s0\n__PING__ 2606:4700:4700::1111\n' + pingFail('2606:4700:4700::1111'));
  assert.strictEqual(root.diagEvaluate(d, {}, false).verdict.title, 'IPv6 does not work');
});

t('public IP: ipwho.is, ipapi.co, Cloudflare trace, nothing', () => {
  const w = root.parsePublicIp('__SRC__ ipwho.is\n{"ip":"203.0.113.24","success":true,"type":"IPv4","country":"Netherlands","country_code":"NL","region":"North Holland","city":"Amsterdam","latitude":52.3676,"longitude":4.9041,"connection":{"asn":64500,"org":"Example Networks","isp":"Example Networks B.V."},"timezone":{"id":"Europe/Amsterdam"}}\n');
  assert.deepStrictEqual([w.ok, w.ip, w.country, w.countryCode, w.city, w.asn, w.tz, w.lat.toFixed(4)], [true, '203.0.113.24', 'Netherlands', 'NL', 'Amsterdam', 'AS64500', 'Europe/Amsterdam', '52.3676']);
  const a = root.parsePublicIp('__SRC__ ipapi.co\n{\n    "ip": "203.0.113.24",\n    "city": "Amsterdam",\n    "region": "North Holland",\n    "country_code": "NL",\n    "country_name": "Netherlands",\n    "latitude": 52.37,\n    "longitude": 4.90,\n    "timezone": "Europe/Amsterdam",\n    "asn": "AS64500",\n    "org": "Example Networks"\n}\n');
  assert.deepStrictEqual([a.ok, a.src, a.ip, a.country, a.countryCode, a.isp, a.asn, a.tz], [true, 'ipapi.co', '203.0.113.24', 'Netherlands', 'NL', 'Example Networks', 'AS64500', 'Europe/Amsterdam']);
  const c = root.parsePublicIp('__SRC__ cloudflare\nfl=12f34\nh=www.cloudflare.com\nip=203.0.113.24\nts=1.0\nloc=NL\ntls=TLSv1.3\n');
  assert.deepStrictEqual([c.ok, c.ip, c.countryCode, c.country, isNaN(c.lat)], [true, '203.0.113.24', 'NL', 'NL', true]);
  const n = root.parsePublicIp('__SRC__ none\n');
  assert.deepStrictEqual([n.ok, n.error], [false, 'No connection to the IP services (ipwho.is, ipapi.co, Cloudflare)']);
  const bad = root.parsePublicIp('__SRC__ ipwho.is\n<html>');
  assert.deepStrictEqual([bad.ok, bad.error], [false, 'Unreadable answer from ipwho.is']);
});

console.log(`\n${passed} passed`);
