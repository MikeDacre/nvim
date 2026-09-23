#!/usr/bin/env bash
# ycfg.sh <dotted.key> [default] — read one value from project.yaml.
# PyYAML-backed (see CLAUDE.md "Dependency policy" / doctor.sh); mirrors
# cfg.sh's ergonomics for CLAUDE/project.json. Lists are space-joined.
# project.yaml is this machine's gitignored copy; when it does not exist yet
# the tracked project.yaml.example answers (policies and defaults, no secrets).
# VALUE POLICY: a value of the form `1pw <reference>` is resolved through the
# 1Password CLI (`op read <reference>`) and the result printed — the clear
# value never lives in the file.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh" 2>/dev/null
cd "$(proot 2>/dev/null || echo .)" || cd .
if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "ycfg.sh: PyYAML not installed — pip install pyyaml (bash scripts/doctor.sh)" >&2
  echo "${2:-}"
  exit 0
fi
F=project.yaml; [ -f "$F" ] || F=project.yaml.example
v=$(python3 -c 'import sys
import yaml
try:
    with open(sys.argv[3]) as fh:
        c = yaml.safe_load(fh) or {}
except Exception:
    print(sys.argv[2]); raise SystemExit
v = c
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v, dict) else None
    if v is None:
        print(sys.argv[2]); raise SystemExit
print(" ".join(map(str, v)) if isinstance(v, list) else v)' "$1" "${2:-}" "$F" 2>/dev/null)
case "$v" in
  "1pw "*)
    ref="${v#1pw }"
    if command -v op >/dev/null 2>&1 && r=$(T 15 op read "$ref" 2>/dev/null </dev/null); then printf '%s\n' "$r"
    else echo "ycfg.sh: could not resolve $1 from 1Password ($ref) — op signed in?" >&2; echo "${2:-}"; fi;;
  *) printf '%s\n' "$v";;
esac
