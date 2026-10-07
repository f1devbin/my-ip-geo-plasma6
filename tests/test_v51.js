// v6.1.51: Monitor accepts one IP address only; scan progress text; parseScan merges repeated neighbour lines
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['normalizeIp', 'scanProgressText', 'parseScan', 'ipToInt']);
root.localItems = [];
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('normalizeIp: IPv4 with commas or leading zeros, IPv6; junk rejected', () => {
  assert.strictEqual(root.normalizeIp(' 192,168,1,010 '), '192.168.1.10');
  assert.strictEqual(root.normalizeIp('10.2.50.240'), '10.2.50.240');
  assert.strictEqual(root.normalizeIp('FD00::2'), 'fd00::2');
  for (const bad of ['10.2.50.0/24', 'abc', '256.1.1.1', '10.2.50', '', 'host.lan', '1.2.3.4; rm'])
    assert.strictEqual(root.normalizeIp(bad), '', bad);
});

t('scanProgressText: host count of the network', () => {
  assert.strictEqual(root.scanProgressText('10.2.48.0/21'), 'Scanning 2046 addresses…');
  assert.strictEqual(root.scanProgressText('192.168.1.0/24'), 'Scanning 254 addresses…');
  assert.strictEqual(root.scanProgressText('10.0.0.7'), 'Scanning 1 address…');
});

t('parseScan: /21 output with neighbour lines collected twice', () => {
  const out = '__INFO__ 2046\nUP 10.77.1.1\n__NEIGH__\n10.77.7.200 dev e lladdr aa:bb:cc:dd:ee:01 REACHABLE\n10.77.3.3 dev e FAILED\n'
    + '10.77.0.5 dev e lladdr aa:bb:cc:dd:ee:02 REACHABLE\n10.77.7.200 dev e lladdr aa:bb:cc:dd:ee:01 REACHABLE\n10.77.1.1 dev e lladdr aa:bb:cc:dd:ee:03 REACHABLE\n';
  const r = root.parseScan(out, '10.77.0.0/21');
  assert.strictEqual(r.error, '');
  assert.deepStrictEqual(r.hosts.map(h => h.ip + ' ' + h.via + ' ' + h.mac),
    ['10.77.0.5 arp AA:BB:CC:DD:EE:02', '10.77.1.1 ping AA:BB:CC:DD:EE:03', '10.77.7.200 arp AA:BB:CC:DD:EE:01']);
  assert.ok(/max 4096/.test(root.parseScan('__TOOBIG__ 8190', '10.0.0.0/19').error));
});

console.log(`\n${passed} passed`);
