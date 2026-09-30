// v6.1.44: Local IPs - subnet mask without the "(/p)" suffix; one flat row list per interface
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['plainMask', 'ifaceAddrRows']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('plainMask: dotted mask, no "(/p)"', () => {
  assert.strictEqual(root.plainMask('21'), '255.255.248.0');
  assert.strictEqual(root.plainMask('24'), '255.255.255.0');
  assert.strictEqual(root.plainMask(16), '255.255.0.0');
  assert.strictEqual(root.plainMask('32'), '255.255.255.255');
  assert.strictEqual(root.plainMask('0'), '0.0.0.0');
  assert.strictEqual(root.plainMask('—'), '', 'unknown prefix -> empty, no mask shown');
});

t('ifaceAddrRows: header rows then one address row each; IPv4 with mask, IPv6 without', () => {
  const item = {
    ipv4: ['10.0.8.15', '192.168.10.15'], ipv4Prefix: ['21', '24'],
    ipv6: ['fe80::a1b2:c3d4:e5f6:7788'], ipv6Prefix: ['64']
  };
  const rows = root.ifaceAddrRows(item);
  assert.deepStrictEqual(rows[0], {header: 'IPv4  ·  2 addresses'});
  assert.deepStrictEqual(rows[1], {addr: '10.0.8.15/21', mask: '255.255.248.0', fam: 4});
  assert.deepStrictEqual(rows[2], {addr: '192.168.10.15/24', mask: '255.255.255.0', fam: 4});
  assert.deepStrictEqual(rows[3], {header: 'IPv6'});
  assert.deepStrictEqual(rows[4], {addr: 'fe80::a1b2:c3d4:e5f6:7788/64', mask: '', fam: 6});
});

t('ifaceAddrRows: single IPv4 uses a plain "IPv4" header; empty families are skipped', () => {
  assert.deepStrictEqual(root.ifaceAddrRows({ipv4: ['172.17.0.1'], ipv4Prefix: ['16'], ipv6: [], ipv6Prefix: []}),
    [{header: 'IPv4'}, {addr: '172.17.0.1/16', mask: '255.255.0.0', fam: 4}]);
  assert.deepStrictEqual(root.ifaceAddrRows({ipv4: [], ipv4Prefix: [], ipv6: ['fd00::2'], ipv6Prefix: ['64']}),
    [{header: 'IPv6'}, {addr: 'fd00::2/64', mask: '', fam: 6}]);
  assert.deepStrictEqual(root.ifaceAddrRows(null), []);
});

console.log(`\n${passed} passed`);
