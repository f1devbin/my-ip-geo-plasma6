const assert = require('assert');
const fs = require('fs');
const { load } = require('./extract');
const root = load(process.argv[2]);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

// --- endpoint formats (per iproute2 6.19 ss.c inet_addr_print/sock_addr_print) ---
t('IPv4', () => assert.deepStrictEqual(root.appEndpoint('142.250.186.78:443'), {address: '142.250.186.78', port: '443'}));
t('IPv6 bracketed', () => assert.deepStrictEqual(root.appEndpoint('[2a00:1450:4001:82b::200e]:443'), {address: '2a00:1450:4001:82b::200e', port: '443'}));
t('IPv6 full length', () => assert.deepStrictEqual(root.appEndpoint('[2a02:2698:6c24:1f5a:b1d2:44e1:9c0f:7a31]:51820'), {address: '2a02:2698:6c24:1f5a:b1d2:44e1:9c0f:7a31', port: '51820'}));
t('IPv4-mapped IPv6', () => assert.deepStrictEqual(root.appEndpoint('[::ffff:91.108.56.130]:443'), {address: '91.108.56.130', port: '443'}));
t('IPv6 link-local with %iface', () => assert.deepStrictEqual(root.appEndpoint('[fe80::1]%wlp2s0:546'), {address: 'fe80::1', port: '546'}));
t('IPv4 with %iface', () => assert.deepStrictEqual(root.appEndpoint('127.0.0.53%lo:53'), {address: '127.0.0.53', port: '53'}));
t('old unbracketed IPv6', () => assert.deepStrictEqual(root.appEndpoint('2a00:1450::200e:443'), {address: '2a00:1450::200e', port: '443'}));
t('wildcards', () => assert.deepStrictEqual(root.appEndpoint('*:*'), {address: '—', port: '—'}));
t('IPv6 any v6only', () => assert.deepStrictEqual(root.appEndpoint('[::]:*'), {address: '::', port: '—'}));
t('garbage token', () => assert.deepStrictEqual(root.appEndpoint('users'), {address: '—', port: '—'}));

// --- whole-output parsing ---
const synthetic = [
  '__TCP__',
  '0      0      192.168.1.5:43210     142.250.186.78:443   users:(("chrome",pid=4242,fd=31))',
  '0      0      [2a02:2698:6c24:1f5a::5]:52000 [2a00:1450:4001:82b::200e]:443 users:(("chrome",pid=4242,fd=40))',
  '0      0      [::ffff:192.168.1.5]:40000 [::ffff:91.108.56.130]:443 users:(("telegram-deskto",pid=777,fd=12))',
  '0      0      192.168.1.5:40001     91.108.56.130:80     users:(("Web Content",pid=900,fd=5),("Web Content",pid=901,fd=5))',
  '0      0      10.8.0.2:40002        1.1.1.1:443',          // no process info (other user's socket) -> skipped
  '__UDP__',
  '0      0      192.168.1.5:55555     142.250.186.78:443   users:(("chrome",pid=4242,fd=50))',
  '0      0      [2a02:2698:6c24:1f5a::5]:5353 [2a00:1450:4001:82b::200e]:443 users:(("chrome",pid=4242,fd=51))',
  ''
].join('\n');
t('synthetic: grouping, counts, peers, states', () => {
  const rows = root.parseAppConnections(synthetic);
  assert.strictEqual(rows.length, 3);
  const chrome = rows[0];
  assert.strictEqual(chrome.display, 'Chromium');
  assert.strictEqual(chrome.pid, '4242');
  assert.deepStrictEqual([chrome.tcp, chrome.udp, chrome.total], [2, 2, 4]);
  assert.deepStrictEqual(chrome.connections.map(c => [c.protocol, c.address, c.port, c.state]), [
    ['TCP', '142.250.186.78', '443', 'ESTABLISHED'],
    ['TCP', '2a00:1450:4001:82b::200e', '443', 'ESTABLISHED'],
    ['UDP', '142.250.186.78', '443', 'ACTIVE'],
    ['UDP', '2a00:1450:4001:82b::200e', '443', 'ACTIVE'],
  ]);
  const tg = rows.find(r => r.pid === '777');
  assert.strictEqual(tg.display, 'Telegram Desktop');
  assert.deepStrictEqual(tg.connections[0], {protocol: 'TCP', address: '91.108.56.130', port: '443', state: 'ESTABLISHED', count: 1});
  const wc = rows.find(r => r.pid === '900');
  assert.strictEqual(wc.process, 'Web Content');
  assert.strictEqual(wc.connections[0].address, '91.108.56.130');
});
t('State/Netid columns present (ss -Htunp / all states) are handled', () => {
  const out = ['__TCP__',
    'tcp ESTAB 0 0 192.168.1.5:43210 142.250.186.78:443 users:(("chrome",pid=1,fd=3))',
    'CLOSE-WAIT 1 0 192.168.1.5:43211 142.250.186.79:443 users:(("chrome",pid=1,fd=4))',
    '__UDP__',
    'udp ESTAB 0 0 192.168.1.5:5000 8.8.8.8:53 users:(("resolver",pid=2,fd=3))', ''].join('\n');
  const rows = root.parseAppConnections(out);
  const c = rows.find(r => r.pid === '1').connections;
  assert.deepStrictEqual(c.map(x => [x.address, x.port, x.state]), [['142.250.186.78', '443', 'ESTABLISHED'], ['142.250.186.79', '443', 'CLOSE-WAIT']]);
  assert.deepStrictEqual(rows.find(r => r.pid === '2').connections[0], {protocol: 'UDP', address: '8.8.8.8', port: '53', state: 'ACTIVE', count: 1});
});
t('failed command output -> null (keep previous data)', () => {
  assert.strictEqual(root.parseAppConnections(''), null);
  assert.strictEqual(root.parseAppConnections(undefined), null);
  assert.strictEqual(root.parseAppConnections('sh: 1: ss: not found'), null);
  assert.strictEqual(root.parseAppConnections('__TCP__\n__FAIL__\n__UDP__\n__FAIL__\n'), null, 'ss missing/failed');
  assert.strictEqual(root.parseAppConnections('__TCP__\n0 0 1.2.3.4:5 6.7.8.9:443 users:(("a",pid=1,fd=3))\n__UDP__\n__FAIL__\n'), null, 'partial failure keeps old list');
});
t('no connections -> empty list (valid result)', () => assert.deepStrictEqual(root.parseAppConnections('__TCP__\n__UDP__\n'), []));
t('30-connection cap, counts keep the real total, stable order', () => {
  const lines = ['__TCP__'];
  for (let i = 45; i >= 1; i--) lines.push(`0 0 10.0.0.2:${40000 + i} 10.0.0.${i}:443 users:(("chrome",pid=5,fd=${i}))`);
  lines.push('__UDP__');
  const a = root.parseAppConnections(lines.join('\n'));
  const b = root.parseAppConnections([lines[0], ...lines.slice(1, -1).reverse(), '__UDP__'].join('\n'));
  assert.strictEqual(a[0].total, 45);
  assert.strictEqual(a[0].connections.length, 30);
  assert.strictEqual(JSON.stringify(a), JSON.stringify(b), 'input order must not change output');
});
t('toggleAppExpanded: multi-row, reassigns a new object', () => {
  root.appExpanded = {};
  const before = root.appExpanded;
  root.toggleAppExpanded('chrome|1');
  assert.notStrictEqual(root.appExpanded, before);
  root.toggleAppExpanded('telegram-deskto|2');
  assert.deepStrictEqual(root.appExpanded, {'chrome|1': true, 'telegram-deskto|2': true});
  root.toggleAppExpanded('chrome|1');
  assert.deepStrictEqual(root.appExpanded, {'telegram-deskto|2': true});
});

// --- v6.1.39: identical rows merged ---
t('identical endpoints merged into one row with count, totals unchanged', () => {
  const out = ['__TCP__',
    '0 0 192.168.1.5:41000 198.51.100.87:22067 users:(("syncthing",pid=3000,fd=10))',
    '0 0 192.168.1.5:41001 192.168.1.11:22000 users:(("syncthing",pid=3000,fd=11))',
    '0 0 192.168.1.5:41002 198.51.100.87:22067 users:(("syncthing",pid=3000,fd=12))',
    '0 0 192.168.1.5:41003 198.51.100.87:22067 users:(("syncthing",pid=3000,fd=13))',
    '0 0 192.168.1.5:41004 198.51.100.87:443 users:(("syncthing",pid=3000,fd=14))',
    '__UDP__',
    '0 0 192.168.1.5:5000 198.51.100.87:22067 users:(("syncthing",pid=3000,fd=20))',
    '0 0 192.168.1.5:5001 198.51.100.87:22067 users:(("syncthing",pid=3000,fd=21))', ''].join('\n');
  const rows = root.parseAppConnections(out);
  assert.strictEqual(rows.length, 1);
  const s = rows[0];
  assert.deepStrictEqual([s.tcp, s.udp, s.total], [5, 2, 7], 'header counts every socket');
  assert.deepStrictEqual(s.connections.map(c => [c.protocol, c.address, c.port, c.state, c.count]), [
    ['TCP', '192.168.1.11', '22000', 'ESTABLISHED', 1],
    ['TCP', '198.51.100.87', '443', 'ESTABLISHED', 1],
    ['TCP', '198.51.100.87', '22067', 'ESTABLISHED', 3],
    ['UDP', '198.51.100.87', '22067', 'ACTIVE', 2],
  ]);
  assert.strictEqual(s.connections.reduce((n, c) => n + c.count, 0), s.total, 'counts add up to Total');
  const keys = s.connections.map(c => [c.protocol, c.address, c.port, c.state].join('|'));
  assert.strictEqual(new Set(keys).size, keys.length, 'no identical rows left');
});
t('same endpoint, different state -> separate rows, state order stable', () => {
  const mk = order => ['__TCP__', ...order.map((st, i) => `tcp ${st} 0 0 10.0.0.2:${50000 + i} 1.2.3.4:443 users:(("app",pid=9,fd=${i + 3}))`), '__UDP__', ''].join('\n');
  const a = root.parseAppConnections(mk(['ESTAB', 'CLOSE-WAIT', 'ESTAB', 'CLOSE-WAIT', 'ESTAB']));
  const b = root.parseAppConnections(mk(['CLOSE-WAIT', 'ESTAB', 'ESTAB', 'ESTAB', 'CLOSE-WAIT']));
  assert.deepStrictEqual(a[0].connections.map(c => [c.state, c.count]), [['CLOSE-WAIT', 2], ['ESTABLISHED', 3]]);
  assert.strictEqual(JSON.stringify(a), JSON.stringify(b), 'input order must not change output');
});
t('cap applies to unique rows: 40 sockets to 35 endpoints -> 30 rows', () => {
  const lines = ['__TCP__'];
  for (let i = 1; i <= 35; i++) lines.push(`0 0 10.0.0.2:${40000 + i} 10.0.1.${i}:443 users:(("chrome",pid=5,fd=${i}))`);
  for (let i = 1; i <= 5; i++) lines.push(`0 0 10.0.0.2:${41000 + i} 10.0.1.1:443 users:(("chrome",pid=5,fd=${100 + i}))`);
  lines.push('__UDP__');
  const rows = root.parseAppConnections(lines.join('\n'));
  assert.strictEqual(rows[0].total, 40);
  assert.strictEqual(rows[0].connections.length, 30);
  assert.strictEqual(rows[0].connections[0].address, '10.0.1.1');
  assert.strictEqual(rows[0].connections[0].count, 6);
});

// --- real ss captures (files passed as extra args) ---
for (const file of process.argv.slice(3)) {
  t('real capture ' + file, () => {
    const text = fs.readFileSync(file, 'utf8');
    const rows = root.parseAppConnections(text);
    assert.ok(Array.isArray(rows) && rows.length > 0);
    let socketLines = 0;
    for (const l of text.split('\n')) if (l.includes('users:((')) socketLines++;
    assert.strictEqual(rows.reduce((s, r) => s + r.total, 0), socketLines, 'every socket line counted once');
    for (const r of rows) for (const c of r.connections) {
      assert.ok(c.address !== '—' && /^[0-9a-f.:]+$/i.test(c.address), 'bad address ' + JSON.stringify(c));
      assert.ok(/^\d+$/.test(c.port), 'bad port ' + JSON.stringify(c));
      assert.ok(c.state === 'ESTABLISHED' || c.state === 'ACTIVE', 'bad state ' + JSON.stringify(c));
      assert.ok(Number.isInteger(c.count) && c.count >= 1, 'bad count ' + JSON.stringify(c));
    }
    for (const r of rows) {
      const keys = r.connections.map(c => [c.protocol, c.address, c.port, c.state].join('|'));
      assert.strictEqual(new Set(keys).size, keys.length, 'identical rows in ' + r.process);
      if (r.connections.length < 30) assert.strictEqual(r.connections.reduce((n, c) => n + c.count, 0), r.total, 'counts add up in ' + r.process);
    }
    console.log('      ' + rows.map(r => `${r.display}(pid ${r.pid}) tcp=${r.tcp} udp=${r.udp} -> ${r.connections[0].protocol} ${r.connections[0].address}:${r.connections[0].port} ${r.connections[0].state}`).join('\n      '));
  });
}
console.log(`\n${passed} passed`);
