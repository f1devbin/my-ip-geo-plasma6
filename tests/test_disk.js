// System disk row: df -P -B1 / parsed from the system sample, shown as used / size like memory
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['parseSysStat', 'usageText', 'sysRow']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const df = 'Filesystem         1-blocks        Used   Available Capacity Mounted on\n/dev/sda5      105089261568 75161927680 24563322880      76% /\n';

t('parseSysStat: size, used and available of / from df -P -B1', () => {
  const r = root.parseSysStat('MemTotal: 100 kB\nMemAvailable: 50 kB\n' + df, null);
  assert.strictEqual(r.diskSize, 105089261568);
  assert.strictEqual(r.diskUsed, 75161927680);
  assert.strictEqual(r.diskAvail, 24563322880);
  assert.strictEqual(r.memUsed, 50 * 1024);
});

t('parseSysStat: no df output or another mount point gives no disk value', () => {
  assert.strictEqual(root.parseSysStat('cpu  1 2 3 4\n', null).diskUsed, -1);
  assert.strictEqual(root.parseSysStat('/dev/sdb1 100 50 50 50% /media/x\n', null).diskUsed, -1);
});

t('sysRow 3: Disk shows used / size like memory and swap', () => {
  const r = root.sysRow(3, 0, 0, 0, 0, 0, 75161927680, 24563322880, 105089261568);
  assert.strictEqual(r.label, 'Disk');
  assert.strictEqual(Math.round(r.pct), 72);
  assert.strictEqual(r.text, '70.0 / 97.9 GB · 72%');
  assert.strictEqual(r.text.replace(/^[\d.]+ \/ [\d.]+ GB · \d+%$/, 'x'), 'x');
  assert.strictEqual(root.sysRow(1, 0, 4.9 * 1024 ** 3, 7.5 * 1024 ** 3, 0, 0).text.replace(/^[\d.]+ \/ [\d.]+ GB · \d+%$/, 'x'), 'x');
});

t('sysRow 3: no df value yet', () => {
  assert.strictEqual(root.sysRow(2, -1, 1, 2, 0, 0, 0, 0).label, 'Swap');
  assert.strictEqual(root.sysRow(3, 0, 0, 0, 0, 0, -1, -1, 0).text, '—');
});

console.log(`\n${passed} passed`);
