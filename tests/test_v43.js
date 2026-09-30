// v6.1.43: Network Apps ranking - one row per application, traffic per period, live speed, last activity
const assert = require('assert');
const { load } = require('./extract');
const names = ['appDisplayName', 'appEndpoint', 'parseAppConnections', 'parseAppRates', 'parseUsageChunk', 'hourKey', 'hourStart',
  'addUsageChunk', 'periodUsage', 'appLastSeen', 'mergeConnections', 'buildAppRows', 'clockText', 'appActivity', 'appIdleText', 'formatBytes', 'rebuildApps', 'toggleAppExpanded'];
const root = load(process.argv[2], names);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const H = 3600000;
const empty = () => ({apps: {}, hours: {}, recent: [], seen: {}});

t('chunk: bytes per process name', () => {
  assert.deepStrictEqual(root.parseUsageChunk('__OK__\n4242 5000 70 chrome\n900 11 22 Web Content\n901 1 2 Web Content\n55 9 9 ?\n'),
    {chrome: [5000, 70], 'Web Content': [12, 24], '?': [9, 9]});
  assert.deepStrictEqual(root.parseUsageChunk('__FAILED__\n'), {});
});

t('hour keys are local wall-clock hours', () => {
  const t0 = new Date(2026, 8, 24, 8, 49, 34).getTime();
  assert.strictEqual(root.hourKey(t0), '2026092408');
  assert.strictEqual(root.hourStart('2026092408'), new Date(2026, 8, 24, 8, 0, 0).getTime());
});

t('store: since boot, hour buckets, recent chunks, last seen; old data dropped; input untouched', () => {
  const t0 = new Date(2026, 8, 24, 8, 50, 0).getTime();
  let s = empty();
  s = root.addUsageChunk(s, {curl: [78e6, 66e6], syncthing: [3000, 500]}, t0);
  const before = JSON.stringify(s);
  const s2 = root.addUsageChunk(s, {curl: [1e6, 0], syncthing: [100, 0]}, t0 + 2 * 60000);
  assert.strictEqual(JSON.stringify(s), before, 'previous store not modified');
  assert.deepStrictEqual(s2.apps.curl, {rx: 79e6, tx: 66e6});
  assert.deepStrictEqual(s2.hours['2026092408'].curl, [79e6, 66e6]);
  assert.strictEqual(s2.recent.length, 2);
  assert.strictEqual(s2.seen.curl, t0 + 2 * 60000);
  assert.strictEqual(s2.seen.syncthing, t0, 'a 100-byte keep-alive does not count as activity');
  // 26 hours later: the old hour bucket and the old chunks are gone, since-boot totals stay
  const s3 = root.addUsageChunk(s2, {curl: [5, 5]}, t0 + 26 * H);
  assert.strictEqual(s3.hours['2026092408'], undefined);
  assert.strictEqual(s3.recent.length, 1);
  assert.deepStrictEqual(s3.apps.curl, {rx: 79e6 + 5, tx: 66e6 + 5});
});

t('periods: last hour, 24 hours, since boot; process names grouped per application', () => {
  const now = new Date(2026, 8, 24, 12, 0, 0).getTime();
  let s = empty();
  s = root.addUsageChunk(s, {'Web Content': [5e6, 1e5]}, now - 30 * H);          // outside 24 h
  s.apps = {};                                                                 // (pretend a reboot happened)
  s = root.addUsageChunk(s, {'Web Content': [2e6, 1e5], firefox: [1e6, 0]}, now - 5 * H);
  s = root.addUsageChunk(s, {chrome: [4e6, 2e5], 'warp-svc': [1e5, 1e5], 'warp-taskbar': [1e3, 1e3]}, now - 20 * 60000);
  const hour = root.periodUsage(s, 'hour', now);
  assert.deepStrictEqual(Object.keys(hour).sort(), ['Chromium', 'Cloudflare WARP']);
  assert.deepStrictEqual([hour['Cloudflare WARP'].rx, hour['Cloudflare WARP'].tx], [101000, 101000]);
  const day = root.periodUsage(s, 'day', now);
  assert.deepStrictEqual([day.Firefox.rx, day.Firefox.tx], [3e6, 1e5], 'Firefox processes together, 30-hour-old traffic excluded');
  const boot = root.periodUsage(s, 'boot', now);
  assert.deepStrictEqual(Object.keys(boot).sort(), ['Chromium', 'Cloudflare WARP', 'Firefox']);
});

const ss = [
  '__TCP__',
  '0 0 10.42.0.53:41000 104.16.124.96:443 users:(("curl",pid=124024,fd=5))',
  '0 0 10.42.0.53:41001 104.16.124.96:443 users:(("curl",pid=124025,fd=5))',
  '0 0 10.42.0.53:41002 104.16.123.96:443 users:(("curl",pid=124026,fd=5))',
  '0 0 192.168.1.12:40000 192.168.1.11:22000 users:(("syncthing",pid=4271,fd=9))',
  '0 0 10.42.0.53:40001 198.51.100.92:22067 users:(("syncthing",pid=4271,fd=10))',
  '0 0 10.42.0.53:40002 198.51.100.92:22067 users:(("syncthing",pid=4271,fd=11))',
  '__UDP__', ''].join('\n');
const rates = {state: 'ok', rates: {'124024': {rx: 1200000, tx: 28000}, '124025': {rx: 1400000, tx: 31000}, '124026': {rx: 1300000, tx: 29000}, '4271': {rx: 0, tx: 228}}};

t('one row per application: three curl processes become one row with summed speed', () => {
  const procs = root.parseAppConnections(ss);
  const rows = root.buildAppRows(procs, rates, {curl: {rx: 78.1e6, tx: 66.7e6, seen: 1}, Syncthing: {rx: 11e6, tx: 3e6, seen: 2}});
  assert.deepStrictEqual(rows.map(r => r.display), ['curl', 'Syncthing']);
  const c = rows[0];
  assert.deepStrictEqual(c.pids, ['124024', '124025', '124026']);
  assert.deepStrictEqual([c.tcp, c.rx, c.tx, c.prx, c.ptx, c.share], [3, 3900000, 88000, 78.1e6, 66.7e6, 1]);
  assert.deepStrictEqual(c.connections.map(x => [x.address, x.count]), [['104.16.123.96', 1], ['104.16.124.96', 2]]);
  assert.ok(Math.abs(rows[1].share - 14e6 / 144.8e6) < 1e-9);
  assert.deepStrictEqual(rows[1].connections.map(x => [x.address, x.port, x.count]), [['192.168.1.11', '22000', 1], ['198.51.100.92', '22067', 2]]);
});

t('ranking: traffic of the period first, then who is busy now, then who was active last', () => {
  const procs = root.parseAppConnections(ss);
  // no traffic counted yet: the busy one first
  let rows = root.buildAppRows(procs, rates, {});
  assert.deepStrictEqual(rows.map(r => r.display), ['curl', 'Syncthing']);
  // Syncthing moved more in this period: first, even though curl is faster right now
  rows = root.buildAppRows(procs, rates, {curl: {rx: 1e6, tx: 0, seen: 5}, Syncthing: {rx: 9e6, tx: 0, seen: 4}});
  assert.deepStrictEqual(rows.map(r => r.display), ['Syncthing', 'curl']);
  // applications that are not connected now but used traffic in the period are listed; equal traffic -> latest activity first
  rows = root.buildAppRows([], {state: '', rates: {}}, {A: {rx: 10, tx: 0, seen: 100}, B: {rx: 10, tx: 0, seen: 200}, Z: {rx: 0, tx: 0, seen: 0}});
  assert.deepStrictEqual(rows.map(r => [r.display, r.rx, r.pids.length]), [['B', -1, 0], ['A', -1, 0]], 'no-traffic, not-connected apps are left out');
});

t('last activity text', () => {
  const now = new Date(2026, 8, 24, 12, 0, 0).getTime();
  assert.strictEqual(root.appActivity({rx: 5, tx: 0, seen: now}, now), '', 'busy now: the speed is shown instead');
  assert.strictEqual(root.appActivity({rx: 0, tx: 0, seen: new Date(2026, 8, 24, 8, 41).getTime()}, now), 'last active 08:41');
  assert.strictEqual(root.appActivity({rx: -1, tx: -1, seen: new Date(2026, 8, 23, 22, 5).getTime()}, now), 'last active 23 Sep 22:05');
  assert.strictEqual(root.appActivity({rx: -1, tx: -1, seen: 0}, now), '');
});

t('model rebuilt from the store and the period; summary line; stale expanded rows dropped', () => {
  const now = Date.now();
  let s = empty();
  s = root.addUsageChunk(s, {curl: [3e6, 1e6], syncthing: [1e6, 0]}, now - 10 * 60000);
  root.appStore = s; root.appPeriod = 'hour'; root.appProcs = []; root.appRatesNow = {state: '', rates: {}}; root.appTraffic = [];
  root.appExpanded = {curl: true, Gone: true};
  root.rebuildApps();
  assert.deepStrictEqual(root.appTraffic.map(r => r.display), ['curl', 'Syncthing']);
  assert.strictEqual(root.appPeriodSummary, 'Last hour: ↓ 3.8 MB  ↑ 976.6 KB · 2 apps');
  assert.deepStrictEqual(root.appExpanded, {curl: true});
  root.appPeriod = 'boot'; root.rebuildApps();
  assert.match(root.appPeriodSummary, /^Since boot: /);
  root.appStore = empty(); root.rebuildApps();
  assert.strictEqual(root.appPeriodSummary, 'Since boot: no traffic counted yet');
});

t('connected without traffic in the period: last activity from any time, no rank', () => {
  const now = new Date(2026, 8, 24, 12, 0, 0).getTime();
  let s = empty();
  s = root.addUsageChunk(s, {syncthing: [5e6, 1e6]}, now - 3 * H);          // active 3 hours ago
  s = root.addUsageChunk(s, {curl: [2e6, 0]}, now - 10 * 60000);
  const procs = root.parseAppConnections(ss);
  const hour = root.periodUsage(s, 'hour', now);
  const rows = root.buildAppRows(procs, {state: 'ok', rates: {}}, hour, root.appLastSeen(s));
  assert.deepStrictEqual(rows.map(r => [r.display, r.prx, r.seen]), [['curl', 2e6, now - 10 * 60000], ['Syncthing', 0, now - 3 * H]]);
  assert.strictEqual(root.appIdleText(rows[1], 'hour', now), 'No traffic in the last hour · last active 09:00');
  assert.strictEqual(root.appIdleText({rx: 0, tx: 0, seen: 0}, 'day', now), 'No traffic in the last 24 hours');
  assert.strictEqual(root.appIdleText({rx: 0, tx: 0, seen: 0}, 'boot', now), 'No traffic since boot');
  // last-activity times older than 30 days are dropped
  const old = root.addUsageChunk(s, {curl: [5000, 0]}, now + 31 * 24 * H);
  assert.deepStrictEqual(Object.keys(old.seen), ['curl']);
});

t('short history: the summary says since when it is counted', () => {
  const now = Date.now();
  let s = empty();
  s.start = now - 20 * 60000;
  s = root.addUsageChunk(s, {curl: [3e6, 1e6]}, now - 10 * 60000);
  assert.strictEqual(s.start, now - 20 * 60000, 'start kept by every chunk');
  root.appStore = s; root.appProcs = []; root.appRatesNow = {state: '', rates: {}}; root.appExpanded = {};
  root.appPeriod = 'day'; root.rebuildApps();
  assert.strictEqual(root.appPeriodSummary, 'Last 24 hours (counted since ' + root.clockText(now - 20 * 60000, now) + '): ↓ 2.9 MB  ↑ 976.6 KB · 1 app');
  root.appPeriod = 'boot'; root.rebuildApps();
  assert.match(root.appPeriodSummary, /^Since boot: /);
  root.appStore.start = now - 2 * H; root.appPeriod = 'hour'; root.rebuildApps();
  assert.match(root.appPeriodSummary, /^Last hour: /, 'an hour of history covers the last hour');
  const t0 = new Date(2026, 8, 24, 12, 0, 0).getTime();
  assert.strictEqual(root.clockText(new Date(2026, 8, 24, 9, 5).getTime(), t0), '09:05');
  assert.strictEqual(root.clockText(new Date(2026, 8, 23, 22, 5).getTime(), t0), '23 Sep 22:05');
});

t('display names', () => {
  assert.strictEqual(root.appDisplayName('?'), 'Ended processes');
  assert.strictEqual(root.appDisplayName('Isolated Web Co'), 'Firefox');
  assert.strictEqual(root.appDisplayName('riseup-vpn'), 'RiseupVPN');
  assert.strictEqual(root.appDisplayName('curl'), 'curl');
});

console.log(`\n${passed} passed`);
