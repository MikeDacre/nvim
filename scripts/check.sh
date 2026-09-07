#!/usr/bin/env bash
# check.sh [all|editors] — the gate. Must exit 0 before hand-over or session end.
#   all     : scaffold integrity + both editors (default)
#   editors : only "does init.vim load cleanly in vim and nvim" (what `make test` runs)
# Exit codes are honest: nothing here is wrapped in silent!. WARN lines never fail
# the gate; they are leads (v:errmsg also captures silent!-suppressed plugin errors).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
. scripts/lib.sh
MODE="${1:-all}"
fail=0
ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }
warn() { printf 'WARN  %s\n' "$1"; }
skip() { printf 'SKIP  %s\n' "$1"; }

scaffold() {
  # 1. no unreplaced placeholders in tracked scaffold files
  if git grep -qlE '\{\{[A-Z_]+\}\}' -- CLAUDE .claude README.md ROADMAP.md TODO.txt CHANGELOG.txt Makefile 2>/dev/null; then
    bad "placeholders remain: $(git grep -lE '\{\{[A-Z_]+\}\}' -- CLAUDE .claude README.md ROADMAP.md TODO.txt CHANGELOG.txt Makefile | tr '\n' ' ')"
  else ok "no placeholders"; fi
  # 2. JSON files parse
  python3 -c 'import json; json.load(open("CLAUDE/project.json"))' 2>/dev/null && ok "project.json valid" || bad "project.json invalid"
  if [ -f .claude/settings.json ]; then
    python3 -c 'import json; json.load(open(".claude/settings.json"))' 2>/dev/null && ok ".claude/settings.json valid" || bad ".claude/settings.json invalid"
  else warn ".claude/settings.json missing (no Claude Code hook/permissions)"; fi
  # 3. symlinks
  { [ -L CLAUDE.md ] && [ -e CLAUDE.md ]; } && ok "CLAUDE.md symlink" || bad "CLAUDE.md symlink broken"
  { [ -L CLAUDE/skills ] && [ -d CLAUDE/skills ]; } && ok "CLAUDE/skills -> .claude/skills" || bad "CLAUDE/skills is not a symlink to .claude/skills"
  # 4. changelog shape
  grep -q '^## \[0.1.0\]' CHANGELOG.txt && ok "changelog seeded" || bad "changelog missing [0.1.0]"
  python3 scripts/changelog.py check >/dev/null 2>&1 && ok "changelog [Unreleased] well-formed" || bad "changelog [Unreleased] has duplicate sections (python3 scripts/changelog.py normalize)"
  # 5. private things never tracked
  if git ls-files --error-unmatch priv >/dev/null 2>&1; then bad "priv/ is tracked"; else ok "priv/ untracked"; fi
  git ls-files | grep -q '^vim-project-config' && bad "vim-project-config tracked in parent" || ok "vim-project-config not in parent"
  git ls-files | grep -q '^plugged/' && bad "plugged/ is tracked" || ok "plugged/ untracked"
  # 6. generated docs present and current (git-based, see lib.sh)
  [ -f doc/mikevim.txt ] && ok "doc/mikevim.txt present" || bad "doc/mikevim.txt missing (make doc)"
  [ -f doc/tags ] && ok "doc/tags present" || bad "doc/tags missing (make doc)"
  doc_stale && bad "doc stale: README.md changed after doc/mikevim.txt (make doc)" || ok "doc current vs README.md"
  # 7. scripts executable
  local x=0; for f in scripts/*.sh scripts/*.py; do [ -x "$f" ] || { warn "$f not executable"; x=1; }; done
  [ "$x" = 0 ] && ok "scripts executable"
}

editors() {
  local tmp rc e err
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
  # lua syntax: luajit if present, else nvim's own luajit, else skip
  if command -v luajit >/dev/null 2>&1; then
    for f in $(git ls-files 'lua/*.lua'); do
      luajit -bl "$f" >/dev/null 2>&1 && ok "lua parses $f" || bad "lua syntax error $f"
    done
  elif command -v nvim >/dev/null 2>&1; then
    local out
    out=$(nvim -l /dev/stdin <<'LUA'
for _, f in ipairs(vim.fn.split(vim.fn.system("git ls-files 'lua/*.lua'"), "\n")) do
  local fn = loadfile(f); print((fn and "ok" or "FAIL") .. " " .. f)
end
LUA
)
    while read -r st f; do [ -z "$f" ] && continue; [ "$st" = ok ] && ok "lua parses $f" || bad "lua syntax error $f"; done <<< "$out"
  else skip "no luajit or nvim: lua files not syntax-checked"; fi
}

case "$MODE" in
  all)     scaffold; editors ;;
  editors) editors ;;
  *) echo "usage: check.sh [all|editors]" >&2; exit 2 ;;
esac
exit $fail
