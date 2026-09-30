// v6.1.45: Scanner port scan - parse portscan.sh output, sanitize a range (modes removed in v6.1.46)
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['parsePortScan', 'sanitizeRange']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('parsePortScan: SCAN/OPEN/DONE into scanned count and ports with service', () => {
  const out = root.parsePortScan('SCAN 10.77.1.1 55\nOPEN 22 ssh\nOPEN 80 http\nOPEN 8080 http-alt\nDONE 3\n');
  assert.strictEqual(out.scanned, 55);
  assert.strictEqual(out.done, true);
  assert.strictEqual(out.error, '');
  assert.deepStrictEqual(out.ports, [{port: 22, service: 'ssh'}, {port: 80, service: 'http'}, {port: 8080, service: 'http-alt'}]);
});

t('parsePortScan: a port with no service name; ERROR line', () => {
  const out = root.parsePortScan('SCAN 10.0.0.5 4\nOPEN 8006 \nDONE 1\n');
  assert.deepStrictEqual(out.ports, [{port: 8006, service: ''}]);
  assert.strictEqual(root.parsePortScan('ERROR invalid host').error, 'invalid host');
});

t('sanitizeRange: clamp to 1..65535, low value first, reject junk', () => {
  assert.strictEqual(root.sanitizeRange('1-1024'), '1-1024');
  assert.strictEqual(root.sanitizeRange(' 8000 - 9000 '), '8000-9000');
  assert.strictEqual(root.sanitizeRange('90-20'), '20-90', 'swapped so low comes first');
  assert.strictEqual(root.sanitizeRange('0-70000'), '1-65535', 'clamped');
  assert.strictEqual(root.sanitizeRange('abc'), '');
  assert.strictEqual(root.sanitizeRange('443'), '', 'a single value is not a range');
});

console.log(`\n${passed} passed`);
