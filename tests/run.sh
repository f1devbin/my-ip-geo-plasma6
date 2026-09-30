#!/bin/bash
# Unit tests against the shipped package (needs Node.js). Each test extracts the functions it
# checks from package/contents/ui/main.qml, so the tested code is exactly the code that ships.
cd "$(dirname "$0")"
qml=../package/contents/ui/main.qml
fail=0
for t in test_*.js; do
    if out=$(node "$t" "$qml" 2>&1); then
        printf 'ok    %-22s %s\n' "$t" "$(printf '%s\n' "$out" | tail -n 1)"
    else
        printf 'FAIL  %s\n' "$t"; printf '%s\n' "$out" | tail -n 25; fail=1
    fi
done
if out=$(bash test_vpn_detect.sh ../package/contents/code/netdiag.sh 2>&1); then
    printf 'ok    %-22s %s passed\n' test_vpn_detect.sh "$(printf '%s\n' "$out" | grep -c '^ok')"
else
    printf 'FAIL  test_vpn_detect.sh\n'; printf '%s\n' "$out" | tail -n 25; fail=1
fi
exit $fail
