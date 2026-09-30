// v6.1.46: port scan - range only (default 1-1024), no 2048 cap, scan time, unfinished scan detection
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['parsePortScan', 'sanitizeRange', 'rangeCount', 'portSpec', 'portEntry']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('default entry: range 1-1024, no mode', () => {
  root.portScans = {};
  const e = root.portEntry('10.0.0.1');
  assert.strictEqual(e.range, '1-1024');
  assert.strictEqual(e.mode, undefined);
  assert.strictEqual(root.portSpec('10.0.0.1'), '1-1024');
});

t('the whole range is passed through, not capped', () => {
  root.portScans = {'10.0.0.1': {range: '1-65535', state: 'idle', scanned: 0, ports: [], error: '', secs: 0}};
  assert.strictEqual(root.portSpec('10.0.0.1'), '1-65535');
  root.portScans = {'10.0.0.1': {range: 'junk', state: 'idle', scanned: 0, ports: [], error: '', secs: 0}};
  assert.strictEqual(root.portSpec('10.0.0.1'), '', 'invalid range -> nothing is started');
});

t('rangeCount for "Checking N ports..."', () => {
  assert.strictEqual(root.rangeCount('1-65535'), 65535);
  assert.strictEqual(root.rangeCount('1-1024'), 1024);
  assert.strictEqual(root.rangeCount('90-20'), 71);
  assert.strictEqual(root.rangeCount('443-443'), 1);
  assert.strictEqual(root.rangeCount('abc'), 0);
});

t('parse: scan time from TIME; a scan without DONE is not finished', () => {
  const full = root.parsePortScan('SCAN 10.0.8.1 65535\nOPEN 22 ssh\nOPEN 49152 \nOPEN 65535 \nDONE 3\nTIME 21.0\n');
  assert.strictEqual(full.scanned, 65535);
  assert.strictEqual(full.done, true);
  assert.strictEqual(full.secs, 21);
  assert.deepStrictEqual(full.ports.map(p => p.port), [22, 49152, 65535]);
  const cut = root.parsePortScan('SCAN 10.0.8.1 65535\n');
  assert.strictEqual(cut.done, false);
  assert.strictEqual(cut.error, '');
});

console.log(`\n${passed} passed`);
