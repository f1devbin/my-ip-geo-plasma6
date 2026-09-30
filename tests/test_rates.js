const assert = require('assert');
const fs = require('fs');
const { load } = require('./extract');
const root = load(process.argv[2], ['appDisplayName', 'appEndpoint', 'parseAppConnections', 'toggleAppExpanded', 'parseAppRates']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }

t('helper missing -> state missing', () => assert.deepStrictEqual(root.parseAppRates('__RATES__\n'), {state: 'missing', rates: {}}));
t('no __RATES__ section at all -> missing', () => assert.strictEqual(root.parseAppRates('').state, 'missing'));
t('capture not permitted (helper exit 1) -> failed', () => assert.strictEqual(root.parseAppRates('__RATES__\n__RC__1\n').state, 'failed'));
t('only the start-up stamp -> nodata', () => assert.strictEqual(root.parseAppRates('__RATES__\n10:01:24\n__RC__124\n').state, 'nodata'));
t('average over windows after the first; pid -1 ignored; first window skipped', () => {
  const out = ['__RATES__',
    '10:01:24|PID|347805|IN|999999|OUT|999999',      // start-up window: ignored
    '10:01:25|PID|347805|IN|1224|OUT|1156',
    '10:01:25|PID|-1|IN|5000|OUT|5000',
    '10:01:26|PID|347805|IN|1293117|OUT|37825',
    '10:01:26|PID|568991|IN|105999|OUT|2323',
    '10:01:27',                                      // a quiet second still counts as a window
    '__RC__124', ''].join('\n');
  const r = root.parseAppRates(out);
  assert.strictEqual(r.state, 'ok');
  assert.deepStrictEqual(r.rates, {
    '347805': {rx: Math.round((1224 + 1293117) / 3), tx: Math.round((1156 + 37825) / 3)},
    '568991': {rx: Math.round(105999 / 3), tx: Math.round(2323 / 3)},
  });
});
for (const file of process.argv.slice(3)) {
  t('real helper capture ' + file, () => {
    const r = root.parseAppRates(fs.readFileSync(file, 'utf8'));
    assert.strictEqual(r.state, 'ok');
    assert.ok(Object.keys(r.rates).length > 0);
    for (const [pid, v] of Object.entries(r.rates)) assert.ok(/^\d+$/.test(pid) && v.rx >= 0 && v.tx >= 0);
    console.log('      ' + JSON.stringify(r.rates));
  });
}
console.log(`\n${passed} passed`);
