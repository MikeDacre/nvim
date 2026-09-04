#!/usr/bin/env bash
# Toolchain + auth check.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
fail=0
for t in git gh jq python3 pandoc nvim vim; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "ok    %-8s %s\n" "$t" "$(command -v "$t")"
  else
    printf "MISS  %-8s\n" "$t"; fail=1
  fi
done
gh auth status >/dev/null 2>&1 && echo "ok    gh-auth" || { echo "MISS  gh-auth"; fail=1; }
git ls-remote --exit-code origin >/dev/null 2>&1 && echo "ok    remote" || { echo "MISS  remote"; fail=1; }
[ -d plugged ] && echo "ok    plugged  $(ls plugged | wc -l | tr -d ' ') plugins" || echo "warn  plugged missing (run :PlugInstall)"
exit $fail
