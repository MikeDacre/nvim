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

# plugins.vim's has('nvim') branches only register with whichever editor is
# currently running, so :PlugClean run from the wrong editor silently deletes
# the OTHER editor's plugins (bit us once, 2026-09-07). Diff plugged/ against
# both branches so that recurs as a WARN here, not a mystery later.
#
# A version-guarded Plug — wiki.vim's has('nvim-0.10') || has('patch-9.1.0') —
# is attributed to BOTH editors, since only has('nvim') branches are classified.
# On a Vim 9.0 machine that means a false "vim missing: wiki.vim". Expected.
if command -v python3 >/dev/null 2>&1 && [ -f plugins.vim ]; then
  parity=$(python3 - <<'PY'
import re, os
cond_stack = []
def active_for(editor):
    for c in cond_stack:
        if c == 'nvim' and editor != 'nvim': return False
        if c == 'vim' and editor != 'vim': return False
    return True
vim_dirs, nvim_dirs = set(), set()
for raw in open('plugins.vim'):
    line = raw.strip()
    if not line or line.startswith('"'):
        continue
    if line.startswith('if has(') and "'nvim'" in line:
        cond_stack.append('nvim'); continue
    if line.startswith('if !has(') and "'nvim'" in line:
        cond_stack.append('vim'); continue
    if line == 'else':
        if cond_stack:
            last = cond_stack.pop()
            cond_stack.append('vim' if last == 'nvim' else 'nvim')
        continue
    if line == 'endif':
        if cond_stack: cond_stack.pop()
        continue
    # Any other `if` (g:vim_minimal, the wiki.vim version guard, ...) is not
    # editor-specific, but it must still push so its `endif` pops the right
    # frame — otherwise the enclosing has('nvim') guard is dropped early.
    if re.match(r'^if\b', line):
        cond_stack.append(None); continue
    for m in re.finditer(r"Plug '([^']+)'", line):
        name = m.group(1).split('/')[-1]
        if active_for('vim'): vim_dirs.add(name)
        if active_for('nvim'): nvim_dirs.add(name)

current = set(os.listdir('plugged')) if os.path.isdir('plugged') else set()
missing_vim = sorted(vim_dirs - current)
missing_nvim = sorted(nvim_dirs - current)
if missing_vim:
    print("vim missing: " + ", ".join(missing_vim))
if missing_nvim:
    print("nvim missing (" + str(len(missing_nvim)) + "): " + ", ".join(missing_nvim[:6]) + (", ..." if len(missing_nvim) > 6 else ""))
PY
)
  if [ -n "$parity" ]; then
    while IFS= read -r line; do warn "plugged/ out of sync — $line — run :PlugInstall from the affected editor"; done <<< "$parity"
  else
    ok "plugged/ matches plugins.vim for both editors"
  fi
fi
exit $fail
