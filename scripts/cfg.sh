#!/usr/bin/env bash
# cfg.sh <dotted.key> [default] — read one value from CLAUDE/project.json.
# No eval, no jq dependency. Lists are space-joined.
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
python3 -c 'import json,sys
try: c=json.load(open("CLAUDE/project.json"))
except Exception: print(sys.argv[2] if len(sys.argv)>2 else ""); raise SystemExit
v=c
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v,dict) else None
    if v is None: print(sys.argv[2] if len(sys.argv)>2 else ""); raise SystemExit
print(" ".join(map(str,v)) if isinstance(v,list) else v)' "$1" "${2:-}" 2>/dev/null
