#!/usr/bin/env bash
# ycfg.sh <dotted.key> [default] — read one value from project.yaml.
# PyYAML-backed (see CLAUDE.md "Dependency policy" / doctor.sh); mirrors
# cfg.sh's ergonomics for CLAUDE/project.json. Lists are space-joined.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh" 2>/dev/null
cd "$(proot 2>/dev/null || echo .)" || cd .
# PyYAML missing is worth a visible warning (unlike "key not found", which is
# routine) — surfaced on real stderr, not swallowed by the python call's own
# 2>/dev/null below.
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "ycfg.sh: PyYAML not installed — pip install pyyaml (bash scripts/doctor.sh)" >&2
  echo "${2:-}"
  exit 0
fi
python3 -c 'import sys
import yaml
try:
    with open("project.yaml") as fh:
        c = yaml.safe_load(fh) or {}
except Exception:
    print(sys.argv[2] if len(sys.argv) > 2 else "")
    raise SystemExit
v = c
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v, dict) else None
    if v is None:
        print(sys.argv[2] if len(sys.argv) > 2 else "")
        raise SystemExit
print(" ".join(map(str, v)) if isinstance(v, list) else v)' "$1" "${2:-}" 2>/dev/null
