#!/usr/bin/env bash
# Gate. Must exit 0 before hand-over or session end.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
fail=0
ok()   { printf "PASS  %s\n" "$1"; }
bad()  { printf "FAIL  %s\n" "$1"; fail=1; }

# 1. no unreplaced placeholders in tracked scaffold files
if git grep -qlE '\{\{[A-Z_]+\}\}' -- CLAUDE README.md ROADMAP.md TODO.txt CHANGELOG.txt Makefile 2>/dev/null; then
  bad "placeholders remain: $(git grep -lE '\{\{[A-Z_]+\}\}' -- CLAUDE README.md ROADMAP.md TODO.txt CHANGELOG.txt Makefile | tr '\n' ' ')"
else ok "no placeholders"; fi

# 2. project.json parses
jq -e . CLAUDE/project.json >/dev/null 2>&1 && ok "project.json valid" || bad "project.json invalid"

# 3. CLAUDE.md symlink
[ -L CLAUDE.md ] && [ -e CLAUDE.md ] && ok "CLAUDE.md symlink" || bad "CLAUDE.md symlink broken"

# 4. changelog shape
grep -q '^## \[0.1.0\]' CHANGELOG.txt && ok "changelog seeded" || bad "changelog missing [0.1.0]"

# 5. priv/ never tracked
if git ls-files --error-unmatch priv >/dev/null 2>&1; then bad "priv/ is tracked"; else ok "priv/ untracked"; fi
git ls-files | grep -q '^vim-project-config' && bad "vim-project-config tracked in parent" || ok "vim-project-config not in parent"

# 6. vimscript + lua parse (nvim is authoritative, vim is the compat gate)
# -es starts Vim in compatible mode, which disables \\ line continuations and
# produces a bogus E10/E697 cascade. --cmd 'set nocompatible' is mandatory here.
timeout 20 vim -es --cmd 'set nocompatible' -u init.vim -c q </dev/null >/dev/null 2>&1 \
  && ok "vim loads init.vim" || bad "vim cannot load init.vim"
for f in plugins.vim functions.vim linters.vim; do
  timeout 15 vim -es --cmd 'set nocompatible' -u NONE -c "silent! source $f" -c q </dev/null >/dev/null 2>&1 \
    && ok "vim parses $f" || bad "vim cannot parse $f"
done
if command -v luajit >/dev/null 2>&1; then LUA=luajit; else LUA=""; fi
if [ -n "$LUA" ]; then
  for f in $(git ls-files 'lua/*.lua'); do
    $LUA -bl "$f" >/dev/null 2>&1 && ok "lua parses $f" || bad "lua syntax error $f"
  done
fi

# 7. generated docs present and not stale
[ -f doc/mikevim.txt ] && ok "doc/mikevim.txt present" || bad "doc/mikevim.txt missing (make doc)"
[ -f doc/tags ] && ok "doc/tags present" || bad "doc/tags missing (make doc)"
[ -f doc/mikevim.txt ] && [ README.md -nt doc/mikevim.txt ] && bad "doc stale vs README.md" || true

exit $fail
