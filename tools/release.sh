#!/bin/bash
# Turns the working tree into release <version>: the version in metadata.json, the footer label and
# README.md, and the "## Unreleased" section of CHANGELOG.md becomes "## v<version>".
#   tools/release.sh 6.1.60
# Used by the Release workflow (Actions -> Release -> Run workflow); it does not commit or tag.
set -euo pipefail
cd "$(dirname "$0")/.."
v=${1:?version, e.g. 6.1.60}
case "$v" in *[!0-9.]*|.*|*.|*..*) echo "release.sh: not a version: $v" >&2; exit 1 ;; esac
old=$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' package/metadata.json | head -n 1)
[ -n "$old" ] || { echo "release.sh: no Version in package/metadata.json" >&2; exit 1; }
[ "$old" != "$v" ] || { echo "release.sh: $v is already the version" >&2; exit 1; }
grep -q '^## Unreleased$' CHANGELOG.md || { echo "release.sh: CHANGELOG.md has no '## Unreleased' section to release" >&2; exit 1; }
grep -q "^## v$v\$" CHANGELOG.md && { echo "release.sh: CHANGELOG.md already has v$v" >&2; exit 1; }
esc=${old//./\\.}
sed -i "s/\"Version\": *\"$esc\"/\"Version\": \"$v\"/" package/metadata.json
sed -i "s/\"· v$esc\"/\"· v$v\"/" package/contents/ui/main.qml
sed -i "s/^\*\*Version $esc\*\*/**Version $v**/" README.md
sed -i "0,/^## Unreleased\$/s//## v$v/" CHANGELOG.md
echo "$old -> $v"
