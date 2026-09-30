// v6.1.47: status colours keep their hue (red stays red on dark themes) instead of turning white
const assert = require('assert');
global.Qt = { rgba: (r, g, b, a) => ({ r, g, b, a }) };
const { load } = require('./extract');
const root = load(process.argv[2], ['luminance', 'contrastText', 'statusColor']);
let passed = 0;
function t(name, fn) { fn(); passed++; console.log('ok  -', name); }
const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255, a: 1 });
const toHex = c => '#' + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join('');
const diff = (a, b) => Math.abs(root.luminance(a) - root.luminance(b));

const breezeDarkBgs = ['#202326', '#1b1e20', '#141618'];   // window / view / alternate backgrounds
const red = hex('#da4453'), green = hex('#27ae60');

t('Breeze Dark red: the old rule made it white; now it stays red and readable', () => {
  for (const b of breezeDarkBgs) {
    const bg = hex(b);
    const old = root.contrastText(bg, red);
    assert.deepStrictEqual([old.r, old.g, old.b], [1, 1, 1], 'contrastText turns the red white (the bug)');
    const c = root.statusColor(bg, red);
    assert.ok(diff(bg, c) >= 0.34, 'readable on ' + b);
    assert.ok(c.r > c.g + 0.25 && c.r > c.b + 0.25, 'still red on ' + b + ': ' + toHex(c));
    console.log('      ' + b + ' -> ' + toHex(c));
  }
});

t('green already readable on dark: unchanged', () => {
  for (const b of breezeDarkBgs) assert.deepStrictEqual(root.statusColor(hex(b), green), green);
});

t('light theme: Breeze red is readable, unchanged; a too-light colour is darkened, hue kept', () => {
  const light = hex('#eff0f1');
  assert.deepStrictEqual(root.statusColor(light, red), red);
  const yellow = hex('#ffe680');
  const c = root.statusColor(light, yellow);
  assert.ok(diff(light, c) >= 0.34);
  assert.ok(c.r > c.b && c.g > c.b, 'still yellowish: ' + toHex(c));
});
console.log(`\n${passed} passed`);
