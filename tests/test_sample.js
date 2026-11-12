// The 2-second sample: which parts are asked for, and its NET / DRV lines
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['sampleParts', 'parseSample', 'parseSysStat']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('sampleParts: the system disk every 15th tick, only shown blocks', () => {
  assert.strictEqual(root.sampleParts(0, true, true, true), 'sktd');
  assert.strictEqual(root.sampleParts(1, true, true, true), 'std');
  assert.strictEqual(root.sampleParts(15, true, false, false), 'sk');
  assert.strictEqual(root.sampleParts(30, false, true, true), 'td');
  assert.strictEqual(root.sampleParts(7, false, false, false), '');
});

t('parseSample: traffic counters and the drives signature', () => {
  const out = 'cpu  1 2 3 4 5\nMemTotal: 100 kB\nMemAvailable: 40 kB\nNET 4730000000 592700000\nDRV sda:500,sdb1:7,/dev/sda5@/,\n';
  assert.deepStrictEqual(root.parseSample(out), {rx: 4730000000, tx: 592700000, drives: 'sda:500,sdb1:7,/dev/sda5@/,'});
  assert.strictEqual(root.parseSysStat(out, null).memUsed, 60 * 1024);
});

t('parseSample: missing parts stay unknown, an empty signature is a signature', () => {
  assert.deepStrictEqual(root.parseSample('cpu  1 2 3 4\n'), {rx: -1, tx: -1, drives: null});
  assert.strictEqual(root.parseSample('DRV \n').drives, '');
  assert.deepStrictEqual(root.parseSample(''), {rx: -1, tx: -1, drives: null});
});

console.log(`\n${passed} passed`);
