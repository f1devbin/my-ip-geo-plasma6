// Hardware tab: hardware.sh records -> sections with rows and tiles
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['formatBytes', 'memSize', 'driveSize', 'cacheSize', 'parseHardware', 'hardwareReport']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const T = '\t';
const laptop = [
  ['SYS', 'LENOVO', '20N2000KRT', 'ThinkPad T490', 'Laptop'], ['BOARD', 'LENOVO', '20N2000KRT', ''],
  ['BIOS', 'LENOVO', 'N2IET97W (1.75 )', '02/21/2024', 'UEFI'], ['OS', 'Kubuntu 26.04', '6.18.0-12-generic', 'x86_64'],
  ['CPU', 'Intel(R) Core(TM) i5-8265U CPU @ 1.60GHz', '1', '4', '8', '3900', '256K', '6144K'],
  ['MEM', '8052015104', '2', '68719476736', 'yes'],
  ['DIMM', 'ChannelA-DIMM0', '8589934592', 'DDR4', '2400', 'Samsung', 'M471A1K43DB1-CTD', 'SODIMM'],
  ['DIMM', 'ChannelB-DIMM0', '0', 'Unknown', '', '', '', 'SODIMM'],
  ['GPU', 'Intel WhiskeyLake-U GT2 [UHD Graphics 620]', 'i915'], ['DISPLAY', 'eDP-1', '1920x1080'],
  ['DISK', 'sda', '512110190592', 'SSD', 'sata', 'KINGSTON OM8P0S3512Q-A0', '0'], ['DISK', 'sdb', '8053063680', 'USB drive', 'usb', 'ProductCode', '1'],
  ['NET', 'wlp0s20f3', 'Wi-Fi', 'Intel Cannon Point-LP CNVi [Wireless-AC]', 'iwlwifi', ''], ['NET', 'enp0s31f6', 'Ethernet', 'Intel I219-V', 'e1000e', '1000'],
  ['BAT', 'BAT0', 'SMP', '02DL008', 'Li-poly', '50.5', '41.2', '312', 'Discharging', '76'], ['AUDIO', 'HDA Intel PCH'],
].map(r => r.join(T)).join('\n') + '\n';
const by = (s, title) => s.find(x => x.title === title);
const val = (sec, k) => (sec.rows.find(r => r.k === k) || {}).v;

t('sizes: memory binary, disks decimal, cache', () => {
  assert.strictEqual(root.memSize(8589934592), '8 GB');
  assert.strictEqual(root.memSize(536870912), '512 MB');
  assert.strictEqual(root.memSize(0), '');
  assert.strictEqual(root.driveSize(512110190592), '512 GB');
  assert.strictEqual(root.driveSize(1000204886016), '1 TB');
  assert.strictEqual(root.driveSize(2500000000000), '2.5 TB');
  assert.strictEqual(root.cacheSize('6144K'), '6 MB');
  assert.strictEqual(root.cacheSize('256K'), '256 KB');
});

t('sections in order, with icons', () => {
  const s = root.parseHardware(laptop);
  assert.deepStrictEqual(s.map(x => x.title), ['Computer', 'Processor', 'Memory', 'Graphics', 'Storage', 'Network adapters', 'Battery', 'Audio']);
  assert.ok(s.every(x => x.icon && Array.isArray(x.rows) && Array.isArray(x.tiles)));
});

t('computer: Lenovo name from the version field, firmware, system', () => {
  const c = by(root.parseHardware(laptop), 'Computer');
  assert.strictEqual(val(c, 'Model'), 'LENOVO ThinkPad T490 (20N2000KRT)');
  assert.strictEqual(val(c, 'Type'), 'Laptop');
  assert.strictEqual(val(c, 'Motherboard'), 'LENOVO 20N2000KRT');
  assert.strictEqual(val(c, 'Firmware'), 'UEFI · LENOVO N2IET97W (1.75 ) · 02/21/2024');
  assert.strictEqual(val(c, 'Kernel'), '6.18.0-12-generic · x86_64');
  const d = by(root.parseHardware('SYS\tASUS\tPRIME B450\tRev 1.xx\tDesktop\n'), 'Computer');
  assert.strictEqual(val(d, 'Model'), 'ASUS PRIME B450');
});

t('processor', () => {
  const p = by(root.parseHardware(laptop), 'Processor');
  assert.strictEqual(val(p, 'Model'), 'Intel Core i5-8265U @ 1.60GHz');
  assert.strictEqual(val(p, 'Cores'), '4 cores · 8 threads');
  assert.strictEqual(val(p, 'Max frequency'), '3.90 GHz');
  assert.strictEqual(val(p, 'Cache'), 'L2 256 KB · L3 6 MB');
});

t('memory: totals, slots, a tile per slot', () => {
  const m = by(root.parseHardware(laptop), 'Memory');
  assert.strictEqual(val(m, 'Installed'), '8 GB DDR4');
  assert.strictEqual(val(m, 'Slots'), '1 of 2 used · 1 free');
  assert.strictEqual(val(m, 'Maximum'), '64 GB');
  assert.deepStrictEqual(m.tiles[0], {title: 'ChannelA-DIMM0', line1: '8 GB DDR4 SODIMM', line2: '2400 MT/s · Samsung M471A1K43DB1-CTD', dim: false});
  assert.deepStrictEqual(m.tiles[1], {title: 'ChannelB-DIMM0', line1: 'Empty slot', line2: 'SODIMM', dim: true});
});

t('memory without module data says so', () => {
  const m = by(root.parseHardware('MEM\t8052015104\t\t\tno\n'), 'Memory');
  assert.strictEqual(val(m, 'Total'), '7.50 GB');
  assert.ok(/without root/.test(val(m, 'Modules')));
  assert.strictEqual(m.tiles.length, 0);
});

t('graphics, storage, network, battery, audio', () => {
  const s = root.parseHardware(laptop);
  assert.strictEqual(val(by(s, 'Graphics'), 'Adapter'), 'Intel WhiskeyLake-U GT2 [UHD Graphics 620] · driver i915');
  assert.strictEqual(val(by(s, 'Graphics'), 'Display'), 'eDP-1 · 1920 × 1080');
  const st = by(s, 'Storage');
  assert.strictEqual(val(st, 'Disks'), '2 disks · 1 internal, 1 external · 520 GB in total');
  assert.deepStrictEqual(st.tiles[0], {title: 'sda · 512 GB', line1: 'SSD', line2: 'KINGSTON OM8P0S3512Q-A0', dim: false});
  assert.strictEqual(val(by(s, 'Network adapters'), 'enp0s31f6'), 'Ethernet · Intel I219-V · driver e1000e · 1000 Mbit/s');
  const b = by(s, 'Battery');
  assert.strictEqual(val(b, 'Capacity'), '41.2 of 50.5 Wh · 82% of new');
  assert.strictEqual(val(b, 'State'), 'Discharging · 76%');
  assert.strictEqual(val(by(s, 'Audio'), 'Card'), 'HDA Intel PCH');
});

t('empty or junk output gives no sections', () => {
  assert.deepStrictEqual(root.parseHardware(''), []);
  assert.deepStrictEqual(root.parseHardware('bash: hardware.sh: No such file\n'), []);
});

t('temperatures and disk health', () => {
  const s = root.parseHardware(laptop + 'TEMP\tcpu\t52\nHEALTH\tsda\t34\tok\t4320\t0\nHEALTH\tsdb\t\tfailing\t\t12\n');
  assert.strictEqual(val(by(s, 'Processor'), 'Temperature'), '52 °C');
  const st = by(s, 'Storage');
  assert.strictEqual(st.tiles[0].line1, 'SSD · 34 °C');
  assert.strictEqual(val(st, 'sda health'), 'Healthy · 4320 h powered on · 0 bad sectors');
  assert.strictEqual(val(st, 'sdb health'), 'FAILING: back up your data · 12 bad sectors');
  const t2 = by(root.parseHardware(laptop + 'HEALTH\tsda\t39\t\t\t\n'), 'Storage');
  assert.strictEqual(t2.tiles[0].line1, 'SSD · 39 °C');
  assert.strictEqual(val(t2, 'sda health'), undefined);
});

t('hardwareReport: plain text for the clipboard', () => {
  const r = root.hardwareReport(root.parseHardware(laptop));
  assert.ok(r.startsWith('Computer\n  Model: LENOVO ThinkPad T490 (20N2000KRT)\n'));
  assert.ok(r.includes('\nMemory\n  Installed: 8 GB DDR4\n'));
  assert.ok(r.includes('  - ChannelA-DIMM0, 8 GB DDR4 SODIMM, 2400 MT/s · Samsung M471A1K43DB1-CTD\n'));
  assert.ok(r.includes('  - ChannelB-DIMM0, Empty slot, SODIMM\n'));
  assert.ok(r.endsWith('Audio\n  Card: HDA Intel PCH\n'));
  assert.strictEqual(root.hardwareReport([]), '');
});

console.log(`\n${passed} passed`);
