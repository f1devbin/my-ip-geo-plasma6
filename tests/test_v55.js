// v6.1.55: current traffic speed and the external drives list
const assert = require('assert');
const { load } = require('./extract');
const root = load(process.argv[2], ['formatBytes', 'formatRate', 'trafficRate', 'decodeLsblk', 'parseDrives', 'driveDetails']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('trafficRate: bytes per second between two samples', () => {
  assert.deepStrictEqual(root.trafficRate({rx: 1000, tx: 500, t: 10000}, {rx: 5000, tx: 1500, t: 12000}), {rx: 2000, tx: 500});
  assert.strictEqual(root.formatRate(2000), '2.0 KB/s');
  assert.strictEqual(root.formatRate(0), '0 B/s');
  assert.strictEqual(root.formatRate(-1), '—');
});

t('trafficRate: no previous sample, no time passed or a counter going back give no speed', () => {
  assert.strictEqual(root.trafficRate(null, {rx: 1, tx: 1, t: 1}), null);
  assert.strictEqual(root.trafficRate({rx: 1, tx: 1, t: 5}, {rx: 2, tx: 2, t: 5}), null);
  assert.strictEqual(root.trafficRate({rx: 9000, tx: 1, t: 0}, {rx: 10, tx: 2, t: 2000}), null);
});

t('decodeLsblk: \\xNN escapes, UTF-8 and a literal percent', () => {
  assert.strictEqual(root.decodeLsblk('/media/max/My\\x20Disk'), '/media/max/My Disk');
  assert.strictEqual(root.decodeLsblk('\\xd0\\x94\\xd0\\xb8\\xd1\\x81\\xd0\\xba'), 'Диск');
  assert.strictEqual(root.decodeLsblk('100%\\x20free'), '100% free');
  assert.strictEqual(root.decodeLsblk('bad\\xff'), 'badÿ');
  assert.strictEqual(root.decodeLsblk(''), '');
});

t('parseDrives: mounted and not mounted volumes, junk ignored', () => {
  const out = root.parseDrives('sdb1\t31003246592\tKINGSTON\tvfat\t/media/max/KINGSTON\tusb\tDataTraveler 3.0\t1000\t3000\n' +
                               'sde\t8053063680\tCAMERA\texfat\t\tusb\tFlash \t-1\t-1\n' +
                               '__NOLSBLK__\n\nrm -rf\tx\n');
  assert.strictEqual(out.length, 2);
  assert.deepStrictEqual(out[0], {name: 'sdb1', size: 31003246592, label: 'KINGSTON', fstype: 'vfat', mount: '/media/max/KINGSTON',
    mounted: true, tran: 'usb', model: 'DataTraveler 3.0', used: 1000, avail: 3000});
  assert.strictEqual(out[1].mounted, false);
  assert.strictEqual(out[1].model, 'Flash');
  assert.deepStrictEqual(root.parseDrives(''), []);
});

t('driveDetails: tooltip says where it is mounted or that it is not', () => {
  const [a, b] = root.parseDrives('sdc5\t500106813440\tMy\\x20Disk\tntfs\t/media/max/My\\x20Disk\tusb\tElements\t120000000000\t380000000000\n' +
                                  'sde\t8053063680\t\texfat\t\tusb\t\t-1\t-1\n');
  assert.strictEqual(root.driveDetails(a), 'sdc5 · My Disk · 465.76 GB\nElements (USB)\nFilesystem: ntfs\nMounted at /media/max/My Disk\nUsed 111.76 GB · free 353.90 GB\nClick to open');
  assert.strictEqual(root.driveDetails(b), 'sde · 7.50 GB\nFilesystem: exfat\nNot mounted');
});

console.log(`\n${passed} passed`);
