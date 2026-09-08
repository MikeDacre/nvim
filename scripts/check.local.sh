#!/usr/bin/env bash
# check.local.sh — this project's own gate, called by the kit's check.sh and by
# `make test`: both editors must load init.vim cleanly and every lua file must
# parse. Exit codes are honest. v:errmsg is reported as WARN because silent!-
# suppressed plugin errors can land there — a WARN is a lead, not a failure.
# (The E216/E488 WARNs this comment used to cite as examples are resolved:
# nvim-tree.lua and vim-glyph-palette were both dropped in the 2026-09-07
# plugin audit.)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
. scripts/lib.sh
fail=0
ok()   { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
warn() { printf '  WARN  %s\n' "$1"; }
skip() { printf '  SKIP  %s\n' "$1"; }

# -N (= --cmd 'set nocompatible') is mandatory: -es starts in compatible mode,
# which disables \ line continuations and produces a bogus E10/E697 cascade.
tmp=$(mktemp)
T 45 vim -es -N -u init.vim -c "redir! > $tmp" -c 'silent echo v:errmsg' -c 'redir END' -c 'qa!' </dev/null >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "vim loads init.vim" || bad "vim cannot load init.vim (exit $rc)"
e=$(tr -d '\n' < "$tmp" 2>/dev/null); rm -f "$tmp"
[ -n "$e" ] && warn "vim v:errmsg after startup: $e"

if command -v nvim >/dev/null 2>&1; then
  err=$(mktemp)
  e=$(T 90 nvim --headless -u init.vim -c 'lua io.stdout:write(vim.v.errmsg)' -c 'qa!' </dev/null 2>"$err")
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE '\bE[0-9]+:' "$err"; then ok "nvim loads init.vim"
  else bad "nvim init.vim errors: $(grep -E '\bE[0-9]+:' "$err" | head -2 | tr '\n' ' ')(exit $rc)"; fi
  rm -f "$err"
  [ -n "$e" ] && warn "nvim v:errmsg after startup: $e"
else skip "nvim not installed on this machine"; fi

if command -v luajit >/dev/null 2>&1; then
  for f in $(git ls-files 'lua/*.lua'); do
    luajit -bl "$f" >/dev/null 2>&1 && ok "lua parses $f" || bad "lua syntax error $f"
  done
elif command -v nvim >/dev/null 2>&1; then
  out=$(nvim -l /dev/stdin <<'LUA'
for _, f in ipairs(vim.fn.split(vim.fn.system("git ls-files 'lua/*.lua'"), "\n")) do
  local fn = loadfile(f); print((fn and "ok" or "FAIL") .. " " .. f)
end
LUA
)
  while read -r st f; do [ -z "$f" ] && continue; [ "$st" = ok ] && ok "lua parses $f" || bad "lua syntax error $f"; done <<< "$out"
else skip "no luajit or nvim: lua files not syntax-checked"; fi

# fzf.vim shells out to these; they're binaries, not vim plugins, so vim-plug
# can't install them — brew install fd ripgrep
declare -A bin_pkg=([fd]=fd [rg]=ripgrep)
for bin in fd rg; do
  command -v "$bin" >/dev/null 2>&1 && ok "$bin on PATH" || warn "$bin not found — brew install ${bin_pkg[$bin]} (fzf.vim degrades without it)"
done
exit $fail
