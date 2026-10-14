// v6.1.52: CPU / memory / swap bars below the traffic bar
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['parseSysStat', 'usageText', 'sysRow']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const mem = 'MemTotal:       16303580 kB\nMemAvailable:   10869056 kB\nSwapTotal:       4194300 kB\nSwapFree:        4194300 kB\n';

t('parseSysStat: first sample has no CPU value, the second one has', () => {
  const a = root.parseSysStat('cpu  100 0 100 700 100 0 0 0 0 0\n' + mem, null);
  assert.strictEqual(a.cpu, null);
  assert.deepStrictEqual(a.sample, {total: 1000, idle: 800});
  const b = root.parseSysStat('cpu  250 0 150 1300 200 0 0 0 0 0\n' + mem, a.sample);
  assert.strictEqual(Math.round(b.cpu), 22);   // 900 more ticks, 700 of them idle/iowait
});

t('parseSysStat: memory used = total - available, swap used = total - free', () => {
  const r = root.parseSysStat(mem, null);
  assert.strictEqual(r.memTotal, 16303580 * 1024);
  assert.strictEqual(r.memUsed, (16303580 - 10869056) * 1024);
  assert.strictEqual(r.swapTotal, 4194300 * 1024);
  assert.strictEqual(r.swapUsed, 0);
  const none = root.parseSysStat('SwapTotal: 0 kB\nSwapFree: 0 kB\n', null);
  assert.strictEqual(none.swapTotal, 0);
  assert.strictEqual(none.memUsed, -1);
});

t('usageText and sysRow', () => {
  assert.strictEqual(root.usageText(5.1 * 2 ** 30, 15.5 * 2 ** 30), '5.1 / 15.5 GB · 33%');
  assert.strictEqual(root.usageText(300 * 2 ** 20, 900 * 2 ** 20), '300 / 900 MB · 33%');
  assert.strictEqual(root.usageText(-1, 0), '—');
  assert.deepStrictEqual(root.sysRow(0, 42.4, 0, 0, 0, 0), {label: 'CPU', pct: 42.4, text: '42%'});
  assert.strictEqual(root.sysRow(2, -1, 1, 2, 0, 0).text, 'no swap');
  assert.strictEqual(root.sysRow(2, -1, 1, 2, -1, 0).text, '—');
});
console.log(`\n${passed} passed`);
