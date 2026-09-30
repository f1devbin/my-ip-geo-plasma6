// v6.1.42: the user's real RiseupVPN output (Kubuntu 26.04, OpenVPN DCO), Wi-Fi from iw + nmcli,
// IPv6 fallback delay, "_gateway" names, ULA-only IPv6
const assert = require('assert');
const fs = require('fs');
const { load } = require('./extract');
const names = ['parseDiag', 'parsePing', 'parseRouteLine', 'splitTerse', 'wifiQuality', 'parseDiagLink', 'parseDiagGateway',
  'parseDiagDns', 'parseDiagInternet', 'parseDiagWeb', 'parseDiagIpv6', 'parseDiagMtu', 'parseDiagRoute', 'fmtMs',
  'diagMainIface', 'diagVpnName', 'diagEvaluate'];
const root = load(process.argv[2], names);
root.diagChecks = ['link', 'gateway', 'dns', 'internet', 'web', 'ipv6', 'mtu', 'route'];
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const tile = (v, title) => v.tiles.find(s => s.title === title);
const step = (v, key) => v.steps.find(s => s.key === key);
const pingOk = (ip, ms) => `PING ${ip} (${ip}) 56(84) bytes of data.\n64 bytes from ${ip}: icmp_seq=1 ttl=57 time=${ms} ms\n64 bytes from ${ip}: icmp_seq=2 ttl=57 time=${ms} ms\n\n--- ${ip} ping statistics ---\n2 packets transmitted, 2 received, 0% packet loss, time 200ms\nrtt min/avg/max/mdev = ${ms}/${ms}/${ms}/0.000 ms\n`;
const linkText = fs.readFileSync(__dirname + '/capture-openvpn-link.txt', 'utf8');
const ipv6Text = fs.readFileSync(__dirname + '/capture-openvpn-ipv6.txt', 'utf8');
function world(extraLink, web) {
  return {
    link: root.parseDiagLink(linkText + (extraLink || '')),
    gateway: root.parseDiagGateway('GW 192.168.1.1 wlp2s0\n__PING__ 192.168.1.1\n' + pingOk('192.168.1.1', '2.4') + '__NEIGH__\n192.168.1.1 dev wlp2s0 lladdr 02:aa:bb:cc:dd:ee REACHABLE\n'),
    dns: root.parseDiagDns('SERVERS Link 3 (wlp2s0): 1.1.1.1 9.9.9.9 8.8.8.8 fe80::1\nSERVERS Link 6 (tun0): 10.42.0.1\nSTUB systemd-resolved\nLOOKUP rc=0 ms=5 addr=104.16.124.96\nNXLOOKUP rc=2 ms=60 addr=\nDOH ok\n'),
    internet: root.parseDiagInternet('__PING__ 1.1.1.1\n' + pingOk('1.1.1.1', '66.0') + '__PING__ 8.8.8.8\n' + pingOk('8.8.8.8', '70.0')),
    web: root.parseDiagWeb(web || 'WEBRC 0\nWEB 200 0.005 0.060 0.130 0.140 0.141 104.16.124.96\nWEB4 200 0.004 0.058 0.128 0.137 0.138 104.16.124.96\nPORTAL 204 \nTRACE ip=212.83.165.160\nTRACE loc=NL\nTRACE colo=AMS\nTRACE warp=off\n'),
    ipv6: root.parseDiagIpv6(ipv6Text),
    mtu: root.parseDiagMtu('DEVMTU tun0 1500\n__PMTU__\n' + pingOk('1.1.1.1', '66') + '__SIZES__\nOK 1472\n'),
    route: root.parseDiagRoute('HOP 1 10.42.0.1 - 0\nHOP 2 51.158.144.1 - 0\nHOP 3 1.1.1.1 48.1 1\nRTT 10.42.0.1 41\nRTT 51.158.144.1 48\nNAME 51.158.144.1 51-158-144-1.rev.poneytelecom.eu\n')
  };
}

t('real output: Wi-Fi from iw and NetworkManager (applet percentage, live dBm, channel, link rate)', () => {
  const v = root.diagEvaluate(world(), {}, false);
  assert.deepStrictEqual([step(v, 'link').status, step(v, 'link').value, step(v, 'link').detail],
    ['ok', 'Wi-Fi 71%', '“HomeWiFi” · 2.4 GHz ch 11 · -50 dBm · 78 Mbit/s · wlp2s0 192.168.1.12/24']);
});

t('real output: OpenVPN DCO tunnel, named after the running RiseupVPN application', () => {
  assert.strictEqual(tile(root.diagEvaluate(world(), {}, false), 'VPN').value, 'OpenVPN · tun0');
  const v = root.diagEvaluate(world('VPNAPP riseup-vpn\n'), {}, false);
  assert.deepStrictEqual([tile(v, 'VPN').value, tile(v, 'VPN').detail], ['RiseupVPN · tun0', 'Internet traffic goes through the VPN']);
});

t('real output: IPv6 blocked by the VPN, DNS of the tunnel listed first, verdict ok', () => {
  const v = root.diagEvaluate(world(), {}, false);
  assert.deepStrictEqual([tile(v, 'IPv6').status, tile(v, 'IPv6').value], ['info', 'Blocked by VPN']);
  assert.strictEqual(step(v, 'dns').detail, 'Servers: 10.42.0.1, 1.1.1.1, 9.9.9.9 …');
  assert.strictEqual(v.verdict.title, 'Everything works');
  assert.match(v.verdict.hint, /^Quality: Fair · 66 ms/);
});

t('failed IPv6 attempts before IPv4 are measured and reported', () => {
  const w = 'WEBRC 0\nWEB 200 0.005 0.254 0.324 0.329 0.330 104.16.124.96\nWEB4 200 0.004 0.052 0.121 0.126 0.127 104.16.124.96\nPORTAL 204 \nTRACE ip=212.83.165.160\n';
  const v = root.diagEvaluate(world('', w), {}, false);
  assert.strictEqual(step(v, 'web').status, 'warn');
  assert.match(step(v, 'web').detail, / · failed IPv6 attempts \+201 ms$/);
  assert.strictEqual(v.verdict.title, 'IPv6 slows down new connections');
  assert.match(v.verdict.hint, /\+201 ms\. The VPN blocks IPv6/);
  // connected over IPv6 or no real difference: nothing to report
  const same = 'WEBRC 0\nWEB 200 0.005 0.070 0.130 0.140 0.141 104.16.124.96\nWEB4 200 0.004 0.052 0.121 0.126 0.127 104.16.124.96\n';
  assert.strictEqual(step(root.diagEvaluate(world('', same), {}, false), 'web').status, 'ok');
  const v6 = 'WEBRC 0\nWEB 200 0.005 0.354 0.430 0.440 0.441 2606:4700::6810:7c60\nWEB4 200 0.004 0.052 0.121 0.126 0.127 104.16.124.96\n';
  assert.strictEqual(step(root.diagEvaluate(world('', v6), {}, false), 'web').status, 'ok');
});

t('"_gateway" (systemd-resolved placeholder) is not shown as a router name', () => {
  const r = root.parseDiagRoute('HOP 1 192.168.1.1 - 0\nHOP 2 1.1.1.1 12 1\nNAME 192.168.1.1 _gateway\nNAME 1.1.1.1 one.one.one.one\nRTT 192.168.1.1 2.1\n');
  assert.deepStrictEqual(r.map(h => h.name), ['', 'one.one.one.one']);
});

t('only a local (ULA) IPv6 address and no VPN: not provided, no warning', () => {
  const d = world();
  d.link = root.parseDiagLink(linkText.replace(/^EGRESS .*$/m, 'EGRESS 1.1.1.1 via 192.168.1.1 dev wlp2s0 src 192.168.1.12 uid 1000').replace(/^VPN .*$/m, '').replace(/^IFACE tun0.*$/m, ''));
  d.ipv6 = root.parseDiagIpv6('ADDR6 fd12:3456::5/64\nROUTE6 default via fe80::1 dev wlp2s0\nEGRESS6 2606:4700:4700::1111 from :: via fe80::1 dev wlp2s0 src fd12:3456::5\n__PING__ 2606:4700:4700::1111\n\n--- x ---\n4 packets transmitted, 0 received, 100% packet loss, time 603ms\n');
  const v = root.diagEvaluate(d, {}, false);
  assert.deepStrictEqual([tile(v, 'IPv6').status, tile(v, 'IPv6').value, tile(v, 'IPv6').detail], ['info', 'Not provided', 'Only a local address (fd12:3456::5)']);
  assert.strictEqual(tile(v, 'VPN').value, 'Off');
  assert.strictEqual(v.verdict.title, 'Everything works');
});

console.log(`\n${passed} passed`);
