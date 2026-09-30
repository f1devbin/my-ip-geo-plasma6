const assert = require('assert');
const fs = require('fs');
const { load } = require('./extract');
const qml = process.argv[2];
const root = load(qml, ['ipToInt', 'scanLabel', 'parseScan', 'parseSpeedPing', 'parseSpeedDown', 'parseSpeedUp', 'formatSpeed', 'gaugeFraction']);
root.localItems = [{iface: 'br77', mac: 'aa:bb:cc:00:11:22', ipv4: ['10.77.0.1'], ipv4Prefix: ['24']}];
root.gatewayMap = {br77: '10.77.0.10'};
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

// ---- scanner ----
t('ipToInt handles high octets', () => { assert.strictEqual(root.ipToInt('192.168.1.1'), 3232235777); assert.strictEqual(root.ipToInt('255.255.255.255'), 4294967295); });
t('real sim-LAN scan: ping + ARP-only devices, departed device excluded', () => {
  const r = root.parseScan(fs.readFileSync('capture-scan-simlan.txt', 'utf8'), '10.77.0.0/24');
  assert.strictEqual(r.error, '');
  assert.deepStrictEqual(r.hosts.map(h => [h.ip, h.via]), [['10.77.0.1', 'ping'], ['10.77.0.10', 'ping'], ['10.77.0.20', 'arp'], ['10.77.0.40', 'arp']]);
  assert.strictEqual(r.hosts[0].mac, 'AA:BB:CC:00:11:22', 'own MAC from local interface');
  assert.ok(/^[0-9A-F:]{17}$/.test(r.hosts[1].mac) && /^[0-9A-F:]{17}$/.test(r.hosts[2].mac));
  console.log('      ' + r.hosts.map(h => h.ip + ' ' + h.mac + ' ' + h.via).join(' | '));
});
t('other subnets and non-alive states are ignored', () => {
  const out = ['__INFO__ 254', '__NEIGH__',
    '192.0.2.1 dev eth0 lladdr 02:fc:00:00:00:05 REACHABLE',
    '10.77.0.60 dev br77 lladdr 02:00:00:00:00:60 STALE',
    '10.77.0.61 dev br77 lladdr 02:00:00:00:00:61 DELAY',
    '10.77.0.62 dev br77 lladdr 02:00:00:00:00:62 PROBE',
    '10.77.0.63 dev br77 FAILED',
    '10.77.0.64 dev br77 INCOMPLETE',
    '10.77.0.65 dev br77 lladdr 02:00:00:00:00:65 PERMANENT',
    '10.77.0.66 dev br77 lladdr 02:00:00:00:00:66 router REACHABLE', ''].join('\n');
  const r = root.parseScan(out, '10.77.0.0/24');
  assert.deepStrictEqual(r.hosts.map(h => h.ip), ['10.77.0.65', '10.77.0.66']);
});
t('ping-only host in a routed subnet keeps "—" MAC; STALE MAC fills a ping-confirmed host', () => {
  const out = ['UP 10.77.0.70', 'UP 10.77.0.71', '__NEIGH__', '10.77.0.71 dev br77 lladdr 02:00:00:00:00:71 STALE', ''].join('\n');
  const r = root.parseScan(out, '10.77.0.0/24');
  assert.deepStrictEqual(r.hosts.map(h => [h.ip, h.mac, h.via]), [['10.77.0.70', '—', 'ping'], ['10.77.0.71', '02:00:00:00:00:71', 'ping']]);
});
t('errors', () => {
  assert.strictEqual(root.parseScan('__BADCIDR__\n', '1.2.3.4/24').error, 'Invalid network address');
  assert.ok(/too large/.test(root.parseScan('__TOOBIG__ 65534\n', '10.0.0.0/16').error));
  assert.strictEqual(root.parseScan('', '10.77.0.0/24').error, 'Scan failed');
});
t('labels: This device / Router', () => {
  assert.strictEqual(root.scanLabel('10.77.0.1'), 'This device');
  assert.strictEqual(root.scanLabel('10.77.0.10'), 'Router');
  assert.strictEqual(root.scanLabel('10.77.0.20'), '');
});

// ---- speed test ----
const pingOut = fs.readFileSync('capture-speed-ping.txt', 'utf8');
t('ping: median TTFB minus server time, jitter, colo from cf-ray', () => {
  const p = root.parseSpeedPing(pingOut);
  assert.ok(p && p.ping > 19 && p.ping < 25, JSON.stringify(p));
  assert.ok(p.jitter >= 0 && p.jitter < 5);
  assert.strictEqual(p.colo, 'FRA');
  console.log('      ' + JSON.stringify(p));
});
t('ping: failures -> null', () => {
  assert.strictEqual(root.parseSpeedPing(''), null);
  assert.strictEqual(root.parseSpeedPing('PING 0.1 0.2 403 |\nPING 0.1 0.2 403 |\nPING 0.1 0.2 403 |\n'), null);
});
t('ping: works without Server-Timing and cf-ray headers', () => {
  const out = 'PING 0.050 0.080 200 |\nPING 0.001 0.031 200 |\nPING 0.001 0.029 200 |\n';
  const p = root.parseSpeedPing(out);
  assert.strictEqual(Math.round(p.ping), 30);
  assert.strictEqual(p.colo, '');
});
t('download: bytes of all streams over the longest transfer', () => {
  const out = fs.readFileSync('capture-speed-down.txt', 'utf8');
  const d = root.parseSpeedDown(out);
  assert.ok(d > 55 && d < 62, 'expected ~60 Mbps, got ' + d);
  console.log('      download ' + d.toFixed(2) + ' Mbps (server throttled to 4 x 15)');
  assert.strictEqual(root.parseSpeedDown('DOWN 0 0 0 000\n'), -1);
});
t('upload: completed requests only, per-stream rates summed', () => {
  const out = fs.readFileSync('capture-speed-up.txt', 'utf8');
  const u = root.parseSpeedUp(out);
  assert.ok(u > 18 && u < 21, 'expected ~20 Mbps, got ' + u);
  console.log('      upload ' + u.toFixed(2) + ' Mbps (server throttled to 4 x 5)');
  assert.strictEqual(root.parseSpeedUp(''), -1);
});
t('formatSpeed / gaugeFraction', () => {
  assert.strictEqual(root.formatSpeed(-1), '—');
  assert.strictEqual(root.formatSpeed(7.845), '7.84');
  assert.strictEqual(root.formatSpeed(94.23), '94.2');
  assert.strictEqual(root.formatSpeed(312.6), '313');
  assert.strictEqual(root.gaugeFraction(0), 0);
  assert.strictEqual(root.gaugeFraction(1000), 1);
  assert.strictEqual(root.gaugeFraction(5000), 1);
});
console.log(`\n${passed} passed`);
