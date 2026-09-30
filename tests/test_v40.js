// Diagnostics parsers and verdicts (v6.1.40) against outputs captured in the simulated network
const assert = require('assert');
const fs = require('fs');
const { load } = require('./extract');
const names = ['parseDiag', 'parsePing', 'parseRouteLine', 'splitTerse', 'wifiQuality', 'parseDiagLink', 'parseDiagGateway',
  'parseDiagDns', 'parseDiagInternet', 'parseDiagWeb', 'parseDiagIpv6', 'parseDiagMtu', 'parseDiagRoute', 'fmtMs',
  'diagMainIface', 'diagVpnName', 'diagEvaluate', 'parsePublicIp'];
const root = load(process.argv[2], names);
root.diagChecks = ['link', 'gateway', 'dns', 'internet', 'web', 'ipv6', 'mtu', 'route'];
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

function scenario(mode) {
  const text = fs.readFileSync(__dirname + '/diag-' + mode + '.txt', 'utf8');
  const d = {};
  const re = /^===== (\w+)\n([\s\S]*?)^===== end \1/gm;
  let m;
  while ((m = re.exec(text)) !== null) if (m[1] !== 'status') d[m[1]] = root.parseDiag(m[1], m[2]);
  return { d, v: root.diagEvaluate(d, {}, false), status: (text.match(/===== status\n(.*)\n/) || [])[1] };
}
const step = (v, key) => v.steps.find(s => s.key === key);
const tile = (v, title) => v.tiles.find(s => s.title === title);

t('parsePing: summary, errors, times, jitter', () => {
  const p = root.parsePing('PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.\n64 bytes from 1.1.1.1: icmp_seq=1 ttl=57 time=12.0 ms\n64 bytes from 1.1.1.1: icmp_seq=2 ttl=57 time=14.0 ms\n64 bytes from 1.1.1.1: icmp_seq=3 ttl=57 time=13.0 ms\n\n--- 1.1.1.1 ping statistics ---\n4 packets transmitted, 3 received, +1 duplicates, 25% packet loss, time 603ms\nrtt min/avg/max/mdev = 12.000/13.000/14.000/0.816 ms\n');
  assert.deepStrictEqual([p.sent, p.recv, p.loss, p.min, p.avg, p.max], [4, 3, 25, 12, 13, 14]);
  assert.deepStrictEqual(p.times, [12, 14, 13]);
  assert.strictEqual(p.jitter, 1.5);
  const e = root.parsePing('PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.\nFrom 100.64.0.1 icmp_seq=1 Destination Net Unreachable\n\n--- 1.1.1.1 ping statistics ---\n10 packets transmitted, 0 received, +1 errors, 100% packet loss, time 1836ms\n');
  assert.deepStrictEqual([e.sent, e.recv, e.errors, e.loss, e.avg], [10, 0, 1, 100, -1]);
  assert.strictEqual(e.from, '100.64.0.1: Destination Net Unreachable');
  const u = root.parsePing('ping: connect: Network is unreachable\n');
  assert.deepStrictEqual([u.sent, u.recv, u.error], [0, 0, 'Network is unreachable']);
});

t('splitTerse / wifiQuality', () => {
  assert.deepStrictEqual(root.splitTerse('*:My\\:Net:36:5180 MHz:540 Mbit/s:84'), ['*', 'My:Net', '36', '5180 MHz', '540 Mbit/s', '84']);
  assert.deepStrictEqual([-40, -58, -70, -80, -100, -30].map(root.wifiQuality), [100, 70, 50, 33, 0, 100]);
});

t('Wi-Fi link from iw, nmcli and /proc/net/wireless', () => {
  const text = [
    'ROUTE4 default via 192.168.1.1 dev wlp2s0 proto dhcp src 192.168.1.5 metric 600 ',
    'EGRESS 1.1.1.1 dev CloudflareWARP table 65743 src 172.16.0.2 uid 1000 ',
    'IFACE wlp2s0 kind=wifi devtype=wlan operstate=up mtu=1500 speed= duplex= mac=aa:bb:cc:dd:ee:ff',
    'ADDR wlp2s0 inet 192.168.1.5/24',
    'ADDR wlp2s0 inet6 fe80::1/64',
    'IW wlp2s0 Connected to 11:22:33:44:55:66 (on wlp2s0)',
    'IW wlp2s0 \tSSID: Home Net',
    'IW wlp2s0 \tfreq: 5180.0',
    'IW wlp2s0 \tsignal: -58 dBm',
    'IW wlp2s0 \trx bitrate: 780.0 MBit/s VHT-MCS 8 80MHz short GI VHT-NSS 2',
    'IW wlp2s0 \ttx bitrate: 866.7 MBit/s VHT-MCS 9 80MHz short GI VHT-NSS 2',
    'NMWIFI wlp2s0 *:Home Net:36:5180 MHz:540 Mbit/s:70',
    'PROCWL wlp2s0: 0000   52.  -58.  -256        0      0      0      0      0        0',
    'IFACE CloudflareWARP kind=vpn devtype=- operstate=unknown mtu=1280 speed= duplex= mac=',
    'ADDR CloudflareWARP inet 172.16.0.2/32',
    'VPN CloudflareWARP tun',
    'NMCONN full'].join('\n');
  const L = root.parseDiagLink(text);
  const w = L.ifaces.wlp2s0.wifi;
  assert.deepStrictEqual([w.ssid, w.freq, w.dbm, w.rate, w.signal, w.chan], ['Home Net', 5180, -58, 866.7, 70, '36']);
  assert.deepStrictEqual(L.ifaces.wlp2s0.addrs6, []);
  assert.strictEqual(root.diagMainIface(L).dev, 'wlp2s0');
  const v = root.diagEvaluate({link: L}, {}, false);
  assert.strictEqual(step(v, 'link').value, 'Wi-Fi 70%');
  assert.strictEqual(step(v, 'link').detail, '“Home Net” · 5 GHz ch 36 · -58 dBm · 867 Mbit/s · wlp2s0 192.168.1.5/24');
  assert.strictEqual(tile(v, 'VPN').value, 'Cloudflare WARP');
  assert.strictEqual(tile(v, 'VPN').detail, 'Internet traffic goes through the VPN');
  // only nmcli (no iw): signal percentage from NetworkManager
  const L2 = root.parseDiagLink(text.split('\n').filter(l => !/^IW |^PROCWL /.test(l)).join('\n'));
  const v2 = root.diagEvaluate({link: L2}, {}, false);
  assert.strictEqual(step(v2, 'link').value, 'Wi-Fi 70%');
  assert.strictEqual(step(v2, 'link').detail, '“Home Net” · 5 GHz ch 36 · 540 Mbit/s · wlp2s0 192.168.1.5/24');
  // weak signal
  const weak = root.parseDiagLink(text.replace('signal: -58 dBm', 'signal: -81 dBm'));
  const v3 = root.diagEvaluate({link: weak}, {}, false);
  assert.strictEqual(step(v3, 'link').status, 'warn');
});

t('scenario ok: everything works, route, tiles', () => {
  const { d, v, status } = scenario('ok');
  assert.match(status, /^ONLINE [\d.]+$/);
  assert.deepStrictEqual(v.steps.map(s => s.status), ['ok', 'ok', 'ok', 'ok', 'ok']);
  assert.strictEqual(step(v, 'link').value, 'Ethernet 10 Gbit/s');
  assert.strictEqual(step(v, 'link').detail, 'enp3s0 10.77.1.2/24');
  assert.strictEqual(step(v, 'gateway').detail, '10.77.1.1 · 0% loss');
  assert.strictEqual(step(v, 'dns').detail, 'Servers: 10.77.1.1');
  assert.match(step(v, 'internet').detail, /^1\.1\.1\.1|^8\.8\.8\.8/);
  assert.match(step(v, 'web').detail, /^HTTPS · DNS \d+ · connect \d+ · TLS \d+ · reply \d+ ms$/);
  assert.strictEqual(v.verdict.status, 'ok');
  assert.strictEqual(v.verdict.title, 'Everything works');
  assert.match(v.verdict.hint, /^Quality: Excellent · <1 ms · jitter <1 ms · 0% loss$/);
  assert.deepStrictEqual(v.route.map(h => [h.ttl, h.ip, h.name, h.reached]), [[1, '10.77.1.1', 'router.lan', 0], [2, '100.64.0.1', 'gw.isp.example.net', 0], [3, '1.1.1.1', 'one.one.one.one', 1]]);
  assert.ok(v.route.every(h => h.rtt >= 0), 'every hop timed');
  assert.deepStrictEqual(v.tiles.map(x => [x.title, x.value]), [['Public IP', '10.77.1.2'], ['IPv6', 'Not provided'], ['VPN', 'Off'], ['Path MTU', '1500 bytes']]);
  assert.strictEqual(tile(v, 'Public IP').detail, 'BY · Cloudflare WAW');
});

t('scenario router-noping: router reachable but silent', () => {
  const { v } = scenario('router-noping');
  assert.strictEqual(step(v, 'gateway').status, 'ok');
  assert.strictEqual(step(v, 'gateway').detail, '10.77.1.1 · does not answer ping, but is reachable');
  assert.strictEqual(v.verdict.status, 'ok');
  assert.strictEqual(v.route[0].rtt, -1, 'router does not answer direct pings: no time');
});

t('scenario dns-down: DNS fails, DoH works', () => {
  const { v, status } = scenario('dns-down');
  assert.strictEqual(status, 'OFFLINE');
  assert.strictEqual(step(v, 'dns').status, 'fail');
  assert.strictEqual(step(v, 'dns').value, 'No answer');
  assert.strictEqual(step(v, 'dns').detail, 'DNS server does not answer · 10.77.1.1 · 1.1.1.1 works');
  assert.strictEqual(step(v, 'internet').status, 'ok');
  assert.strictEqual(step(v, 'web').status, 'fail');
  assert.strictEqual(v.verdict.title, 'DNS does not work');
  assert.match(v.verdict.hint, /1\.1\.1\.1 works/);
});

t('scenario dns-slow and dns-hijack: warnings', () => {
  const slow = scenario('dns-slow').v;
  assert.strictEqual(step(slow, 'dns').status, 'warn');
  assert.strictEqual(slow.verdict.title, 'Slow DNS');
  const hij = scenario('dns-hijack').v;
  assert.strictEqual(step(hij, 'dns').status, 'warn');
  assert.strictEqual(hij.verdict.title, 'DNS gives fake answers');
});

t('scenario no-internet: router ok, internet fails', () => {
  const { v } = scenario('no-internet');
  assert.strictEqual(step(v, 'gateway').status, 'ok');
  assert.strictEqual(step(v, 'internet').status, 'fail');
  assert.strictEqual(step(v, 'internet').detail, '1.1.1.1 and 8.8.8.8 do not answer · 100.64.0.1: Destination Net Unreachable');
  assert.strictEqual(v.verdict.title, 'No internet access');
  assert.strictEqual(step(v, 'web').detail, 'Failed to connect to www.cloudflare.com port 443: Could not connect to server');
  assert.strictEqual(tile(v, 'Path MTU').value, '—');
});

t('scenario portal: sign-in page detected, ping blocked, TCP works', () => {
  const { v } = scenario('portal');
  assert.deepStrictEqual([step(v, 'internet').status, step(v, 'internet').value, step(v, 'internet').detail], ['warn', 'Blocked', 'Traffic is held by the sign-in page']);
  assert.strictEqual(step(v, 'web').value, 'Sign-in');
  assert.strictEqual(v.verdict.title, 'Sign-in required');
});

t('scenario loss: unstable connection', () => {
  const { v } = scenario('loss');
  assert.strictEqual(step(v, 'internet').status, 'warn');
  assert.strictEqual(v.verdict.title, 'Unstable connection');
});

t('scenario mtu: path MTU from the router message', () => {
  const { v } = scenario('mtu');
  assert.strictEqual(tile(v, 'Path MTU').value, '1420 bytes');
  assert.strictEqual(tile(v, 'Path MTU').detail, 'enp3s0 MTU 1500');
  assert.strictEqual(v.verdict.status, 'ok');
});

t('scenario offline', () => {
  const { v, status } = scenario('offline');
  assert.strictEqual(status, 'OFFLINE');
  assert.strictEqual(step(v, 'link').status, 'fail');
  assert.strictEqual(v.verdict.title, 'No network connection');
  assert.deepStrictEqual([step(v, 'gateway').status, step(v, 'gateway').detail], ['info', 'No default gateway']);
});

t('scenario vpn / warp', () => {
  const vpn = scenario('vpn');
  assert.match(vpn.status, /^VPN /);
  assert.strictEqual(tile(vpn.v, 'VPN').value, 'Cloudflare WARP');
  assert.strictEqual(tile(vpn.v, 'VPN').detail, 'Internet traffic goes around the VPN');
  const warp = scenario('warp');
  assert.strictEqual(tile(warp.v, 'Public IP').detail, 'BY · Cloudflare WAW · WARP on');
});

t('running state: steps spin, verdict waits', () => {
  const { d } = scenario('ok');
  const partial = { link: d.link, dns: d.dns };
  const v = root.diagEvaluate(partial, { gateway: true, internet: true, web: true, ipv6: true, mtu: true, route: true }, true);
  assert.deepStrictEqual(v.steps.map(s => s.status), ['ok', 'running', 'ok', 'running', 'running']);
  assert.deepStrictEqual(v.verdict, { status: 'running', title: 'Checking the connection…', hint: '2 of 8 checks done' });
  const none = root.diagEvaluate({}, {}, false);
  assert.strictEqual(none.verdict.status, 'pending');
  assert.deepStrictEqual(none.steps.map(s => s.status), ['pending', 'pending', 'pending', 'pending', 'pending']);
});

t('IPv6 working / broken', () => {
  const ok6 = root.parseDiagIpv6('ADDR6 2a02:1:2:3::5/64\nROUTE6 default via fe80::1 dev wlp2s0 proto ra metric 600 pref medium\n__PING__ 2606:4700:4700::1111\nPING 2606:4700:4700::1111(2606:4700:4700::1111) 56 data bytes\n64 bytes from 2606:4700:4700::1111: icmp_seq=1 ttl=57 time=15.2 ms\n\n--- 2606:4700:4700::1111 ping statistics ---\n4 packets transmitted, 4 received, 0% packet loss, time 603ms\nrtt min/avg/max/mdev = 15.100/15.300/15.600/0.200 ms\nPUBLIC6 2a02:1:2:3::5\n');
  let v = root.diagEvaluate({ ipv6: ok6 }, {}, false);
  assert.deepStrictEqual([tile(v, 'IPv6').status, tile(v, 'IPv6').value, tile(v, 'IPv6').detail], ['ok', 'Works · 15 ms', '2a02:1:2:3::5']);
  const bad6 = root.parseDiagIpv6('ADDR6 2a02:1:2:3::5/64\nROUTE6 default via fe80::1 dev wlp2s0\n__PING__ 2606:4700:4700::1111\n\n--- x ---\n4 packets transmitted, 0 received, 100% packet loss, time 603ms\n');
  v = root.diagEvaluate({ ipv6: bad6 }, {}, false);
  assert.strictEqual(tile(v, 'IPv6').status, 'warn');
});

console.log(`\n${passed} passed`);
