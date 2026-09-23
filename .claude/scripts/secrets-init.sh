#!/usr/bin/env bash
# secrets-init.sh — provision this machine's project.yaml on a fresh clone.
# Copies project.yaml.example to project.yaml (0600) when it does not exist,
# says which keys are still blank, checks each `1pw <ref>` resolves when the
# 1Password CLI is signed in, and confirms project.yaml is gitignored.
# Never echoes a value. Never writes anything but project.yaml.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(proot)" || exit 1

[[ -f project.yaml.example ]] || { echo "no project.yaml.example — nothing to provision (bash <kit>/scripts/adopt.sh --update seeds one)"; exit 0; }
if [[ -e project.yaml ]]; then echo "keep   project.yaml (already present)"
else cp project.yaml.example project.yaml && chmod 600 project.yaml && echo "wrote  project.yaml from project.yaml.example (0600) — fill in the keys"; fi
chmod 600 project.yaml 2>/dev/null || true

OP=0
command -v op >/dev/null && T 10 op account list >/dev/null 2>&1 </dev/null && OP=1
[[ $OP -eq 1 ]] && echo "1Password CLI: signed in (1pw references will resolve)" || echo "1Password CLI: not signed in — 1pw references resolve once it is"

python3 - "$OP" <<'PY' 2>/dev/null || echo "  (PyYAML missing — cannot list keys: pip install pyyaml)"
import sys, subprocess
import yaml
op = sys.argv[1] == "1"
c = yaml.safe_load(open("project.yaml")) or {}
keys = c.get("keys") or {}
if not keys:
    print("  keys: none declared (add the NAME to project.yaml.example, the VALUE to project.yaml)")
for k, v in keys.items():
    v = "" if v is None else str(v)
    if v == "":
        print(f"  {k}  BLANK — set it in project.yaml")
    elif v.startswith("1pw "):
        if op:
            ok = subprocess.run(["op", "read", v[4:]], capture_output=True, text=True).returncode == 0
            print(f"  {k}  1Password {'ok' if ok else '!! reference does not resolve: ' + v[4:]}")
        else:
            print(f"  {k}  1Password (unchecked)")
    else:
        print(f"  {k}  set")
PY

if have_git; then
  git check-ignore -q project.yaml || { echo "!! project.yaml is NOT gitignored — add /project.yaml to .gitignore before committing"; exit 1; }
  git ls-files --error-unmatch project.yaml >/dev/null 2>&1 && { echo "!! project.yaml is TRACKED — git rm --cached project.yaml, then rotate every key in it"; exit 1; }
fi
[[ -d priv ]] && echo "note   priv/ is the pre-1.12 secrets directory — move each key into project.yaml, then git rm -r priv/"
echo "project.yaml is private to this machine."
