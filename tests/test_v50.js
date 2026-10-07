// v6.1.50: Local IPs badge ignores link-local IPv6; a new path to the internet refreshes the public IP
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['plainMask', 'ifaceAddrRows', 'isLinkLocal6', 'ipBadge', 'netPathChange']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('isLinkLocal6: fe80::/10 only', () => {
  for (const a of ['fe80::4d49:8295:38a8:7712', 'FE80::1', 'fe9a::1', 'febf::1']) assert.strictEqual(root.isLinkLocal6(a), true, a);
  for (const a of ['fd00::2', '2001:db8::1', 'fec0::1', 'fe8::1', '::1', '', null]) assert.strictEqual(root.isLinkLocal6(a), false, String(a));
});

t('ipBadge: an OpenVPN tun0 with IPv4 and only fe80:: is "IPv4"', () => {
  const tun0 = {ipv4: ['10.138.192.18'], ipv4Prefix: ['22'], ipv6: ['fe80::4d49:8295:38a8:7712'], ipv6Prefix: ['64']};
  assert.strictEqual(root.ipBadge(tun0), 'IPv4');
  const rows = root.ifaceAddrRows(tun0);
  assert.deepStrictEqual(rows[3], {addr: 'fe80::4d49:8295:38a8:7712/64', mask: '', fam: 6, note: 'link-local'});
});

t('ipBadge: global or ULA IPv6 counts; only link-local without IPv4 says so', () => {
  assert.strictEqual(root.ipBadge({ipv4: ['192.0.2.10'], ipv6: ['2001:db8::10', 'fe80::1']}), 'IPv4 + IPv6');
  assert.strictEqual(root.ipBadge({ipv4: [], ipv6: ['fd00::2']}), 'IPv6');
  assert.strictEqual(root.ipBadge({ipv4: [], ipv6: ['fe80::1']}), 'IPv6 link-local');
  assert.strictEqual(root.ipBadge({ipv4: ['192.0.2.10'], ipv6: []}), 'IPv4');
  assert.strictEqual(root.ipBadge(null), '');
  // a global address keeps no note
  assert.strictEqual(root.ifaceAddrRows({ipv4: [], ipv4Prefix: [], ipv6: ['2001:db8::10'], ipv6Prefix: ['64']})[1].note, undefined);
});

const lan = 'enp0s31f6#2/192.0.2.1/192.0.2.10';
const ovpn = 'tun0#12/10.138.192.1/10.138.192.18';
const warp = 'CloudflareWARP#7/-/172.16.0.2';

t('netPathChange: the first check only remembers the path', () => {
  const r = root.netPathChange('', 'ONLINE 0.123 ' + lan + '\n');
  assert.deepStrictEqual(r, {state: 'ONLINE', online: true, path: lan, refresh: false});
});

t('netPathChange: VPN on, switched or off refreshes; the same path does not', () => {
  assert.strictEqual(root.netPathChange(lan, 'VPN 0.2 ' + ovpn).refresh, true, 'VPN connected');
  assert.strictEqual(root.netPathChange(warp, 'VPN 0.2 ' + ovpn).refresh, true, 'WARP -> OpenVPN');
  assert.strictEqual(root.netPathChange(ovpn, 'ONLINE 0.1 ' + lan).refresh, true, 'VPN off');
  assert.strictEqual(root.netPathChange(ovpn, 'VPN 0.3 ' + ovpn).refresh, false, 'same path');
  assert.strictEqual(root.netPathChange(ovpn, 'VPN 0.3 tun0#13/10.138.192.1/10.138.192.18').refresh, true, 'reconnected: new interface index');
});

t('netPathChange: offline keeps the last path, so the same path after an outage refreshes nothing', () => {
  const off = root.netPathChange(ovpn, 'OFFLINE\n');
  assert.deepStrictEqual(off, {state: 'OFFLINE', online: false, path: ovpn, refresh: false});
  assert.strictEqual(root.netPathChange(off.path, 'VPN 0.2 ' + ovpn).refresh, false);
  assert.strictEqual(root.netPathChange(off.path, 'ONLINE 0.2 ' + lan).refresh, true);
});

t('netPathChange: empty output and an old two-field line are handled', () => {
  assert.deepStrictEqual(root.netPathChange(lan, ''), {state: 'OFFLINE', online: false, path: lan, refresh: false});
  assert.deepStrictEqual(root.netPathChange(lan, 'VPN 0.2'), {state: 'VPN', online: true, path: lan, refresh: false});
  assert.deepStrictEqual(root.netPathChange('', 'OFFLINE'), {state: 'OFFLINE', online: false, path: '', refresh: false});
});

console.log(`\n${passed} passed`);
