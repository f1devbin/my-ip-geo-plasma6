// Extracts root-level JS functions from main.qml so tests run the exact shipped code.
const fs = require('fs');
function extract(qmlPath, names) {
  const src = fs.readFileSync(qmlPath, 'utf8');
  const out = [];
  for (const name of names) {
    const start = src.indexOf('\n    function ' + name + '(');
    if (start < 0) throw new Error('function not found: ' + name);
    let i = src.indexOf('{', start), depth = 0, j = i;
    for (; j < src.length; j++) {
      if (src[j] === '{') depth++;
      else if (src[j] === '}') { depth--; if (depth === 0) break; }
    }
    out.push(src.slice(start + 1, j + 1));
  }
  return out.join('\n');
}
function load(qmlPath, names) {
  const code = extract(qmlPath, names || ['appDisplayName', 'appEndpoint', 'parseAppConnections', 'toggleAppExpanded']);
  const root = { appExpanded: {} };
  const f = new Function('root', code + '\nreturn {' + (names || ['appDisplayName', 'appEndpoint', 'parseAppConnections', 'toggleAppExpanded']).join(', ') + '};');
  const api = f(root);
  Object.assign(root, api);
  return root;
}
module.exports = { load, extract };
