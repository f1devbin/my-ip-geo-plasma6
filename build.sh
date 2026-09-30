#!/bin/bash
# Builds the installable package from package/ and checks it first.
#   ./build.sh   ->  dist/my-ip-geo-plasma6-v<version>.zip and .plasmoid (the same file),
#                    dist/VERSION, dist/release-notes.md (this version's CHANGELOG section)
# Checks: the version is the same in metadata.json, the footer label, README.md and CHANGELOG.md;
# metadata.json is valid JSON; every helper script parses.
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "build.sh: $*" >&2; exit 1; }

ver=$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' package/metadata.json | head -n 1)
[ -n "$ver" ] || fail "no Version in package/metadata.json"

if command -v python3 >/dev/null; then
    python3 -m json.tool package/metadata.json >/dev/null || fail "package/metadata.json is not valid JSON"
fi
grep -q "\"· v$ver\"" package/contents/ui/main.qml || fail "footer label in main.qml is not \"· v$ver\""
grep -q "^\*\*Version $ver\*\*" README.md || fail "README.md does not say **Version $ver**"
[ "$(grep -m 1 '^## v' CHANGELOG.md)" = "## v$ver" ] || fail "CHANGELOG.md does not start with ## v$ver"
for s in package/contents/code/*.sh; do bash -n "$s" || fail "syntax error in $s"; done

name="my-ip-geo-plasma6-v$ver"
rm -rf dist
mkdir -p dist
if command -v zip >/dev/null; then
    (cd package && zip -X -q -r "../dist/$name.zip" metadata.json contents -x '*.qmlc' '*~')
    zip -X -q "dist/$name.zip" README.md CHANGELOG.md LICENSE
else
    # no zip tool: the same archive with Python's zipfile
    python3 - "dist/$name.zip" <<'PY'
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    z.write("package/metadata.json", "metadata.json")
    for root, dirs, files in os.walk("package/contents"):
        dirs.sort()
        for f in sorted(files):
            if not f.endswith((".qmlc", "~")):
                full = os.path.join(root, f)
                z.write(full, os.path.relpath(full, "package"))
    for f in ("README.md", "CHANGELOG.md", "LICENSE"):
        z.write(f, f)
PY
fi
cp "dist/$name.zip" "dist/$name.plasmoid"

if command -v unzip >/dev/null; then
    unzip -tq "dist/$name.zip" >/dev/null || fail "broken archive"
else
    python3 -c "import sys, zipfile; sys.exit(zipfile.ZipFile(sys.argv[1]).testzip() is not None)" "dist/$name.zip" || fail "broken archive"
fi

echo "$ver" > dist/VERSION
awk -v v="## v$ver" '$0 == v { on = 1; next } /^## v/ && on { exit } on' CHANGELOG.md > dist/release-notes.md
echo "dist/$name.zip"
