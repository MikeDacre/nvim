#!/usr/bin/env bash
# release.sh <x.y.z> — move [Unreleased] into a version, tag, commit. Never pushes:
# pushing the tag and `gh release create` are publishing actions that need approval.
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V="${1:?usage: release.sh <x.y.z>}"
[[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not SemVer x.y.z: $V"; exit 2; }
[ -z "$(git status --porcelain)" ] || { echo "working tree dirty:"; git status --short; exit 1; }
git rev-parse -q --verify "refs/tags/v$V" >/dev/null && { echo "tag v$V already exists"; exit 1; }
python3 scripts/changelog.py from-git
bash scripts/check.sh
DATE=$(date +%Y-%m-%d)
python3 - "$V" "$DATE" <<'PY'
import sys, pathlib
v, d = sys.argv[1], sys.argv[2]
p = pathlib.Path("CHANGELOG.txt"); t = p.read_text()
t = t.replace("## [Unreleased]", f"## [Unreleased]\n\n## [{v}] - {d}", 1)
p.write_text(t)
PY
python3 scripts/changelog.py sync
git add -A CHANGELOG.txt
git commit -q -m "Release v$V"
git tag -a "v$V" -m "v$V"
echo "tagged v$V — after approval: git push --follow-tags origin $(git rev-parse --abbrev-ref HEAD)"
echo "GitHub release (ask first): gh release create v$V --title v$V --notes-from-tag"
