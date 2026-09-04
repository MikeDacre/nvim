#!/usr/bin/env bash
# release.sh <x.y.z> — move [Unreleased] into a version, tag, push. Never auto-publishes.
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V="${1:?usage: release.sh <x.y.z>}"
git diff --quiet || { echo "working tree dirty"; exit 1; }
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
git commit -m "Release v$V"
git tag -a "v$V" -m "v$V"
echo "tagged v$V — push with: git push origin $(git rev-parse --abbrev-ref HEAD) --tags"
