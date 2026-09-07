#!/usr/bin/env bash
# doctor.sh — toolchain + auth check. Required tools fail; optional ones only warn,
# because a remote server legitimately has vim, git and python3 and nothing else.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
. scripts/lib.sh
fail=0
for t in git python3 vim; do
  if command -v "$t" >/dev/null 2>&1; then printf "ok    %-9s %s\n" "$t" "$(command -v "$t")"
  else printf "MISS  %-9s required\n" "$t"; fail=1; fi
done
for t in nvim pandoc gh luajit timeout claude; do
  if command -v "$t" >/dev/null 2>&1; then printf "ok    %-9s %s\n" "$t" "$(command -v "$t")"
  else printf "opt   %-9s not installed (nvim: second editor; pandoc: make doc; gh: releases; luajit: lua check; timeout: coreutils; claude: Claude Code)\n" "$t"; fi
done
if command -v gh >/dev/null 2>&1; then
  gh auth status >/dev/null 2>&1 && echo "ok    gh-auth" || echo "opt   gh-auth   not logged in (needed only for releases)"
fi
if T 15 git ls-remote --exit-code origin >/dev/null 2>&1; then echo "ok    remote"; else echo "warn  remote    unreachable (offline, or no SSH key for github.com on this machine)"; fi
[ -f deps/panvimdoc/panvimdoc.sh ] && echo "ok    panvimdoc submodule" || echo "opt   panvimdoc submodule not initialised (git submodule update --init; needed only for make doc)"
[ -d plugged ] && echo "ok    plugged   $(ls plugged | wc -l | tr -d ' ') plugins" || echo "warn  plugged   missing (run :PlugInstall or make init)"
exit $fail
