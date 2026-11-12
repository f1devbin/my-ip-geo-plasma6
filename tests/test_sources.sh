#!/bin/bash
# Static check of main.qml: Plasma keeps an entry for every distinct command string a DataSource
# has run (the leak fixed in 6.1.59), so a command may only vary by a rotating runTag(), never by a
# growing counter or the time. Animations that run forever must be tied to something visible.
M=${1:?main.qml}
# all views of the widget in one stream (main.qml and the files next to it)
Q=$(mktemp); trap 'rm -f "$Q"' EXIT
cat "$(dirname "$M")"/*.qml > "$Q"
fail=0
bad=$(grep -n 'connectSource(' "$Q" | grep -v 'disconnectSource' | grep -E 'Date\.now\(\)|Seq\b' | grep -v 'runTag(')
if [ -z "$bad" ]; then echo "ok  - commands vary only by runTag()"; else echo "FAIL- command strings with a counter or the time:"; printf '%s\n' "$bad" | cut -c1-160; fail=1; fi
bad=$(grep -n 'Behavior on \(width\|height\|color\|x\|y\)\b' "$Q")
if [ -z "$bad" ]; then echo "ok  - no Behavior animation on geometry or colour of polled values"; else echo "FAIL- Behavior animations (they kept plasmashell busy in 6.1.52-6.1.56):"; printf '%s\n' "$bad" | cut -c1-160; fail=1; fi
bad=$(awk '{ line[NR] = $0 } /loops: Animation.Infinite/ { hit[NR] = 1 }
    END { for (n in hit) { ok = 0; for (i = n - 1; i <= n + 3; i++) if (line[i] ~ /running:.*(visible|speedPhase)/) ok = 1; if (!ok) print n ": " line[n] } }' "$Q")
if [ -z "$bad" ]; then echo "ok  - every endless animation runs only while it is shown"; else echo "FAIL- endless animations not tied to visibility:"; printf '%s\n' "$bad" | cut -c1-160; fail=1; fi
exit $fail
