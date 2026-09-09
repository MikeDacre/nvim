#!/usr/bin/env bash
# CLAUDE/patches/2026-09-09-treesitter-data-dir.sh
#
# Root cause found in review after today's PlugClean/PlugInstall: on this
# machine ~/.local/share/nvim (Neovim's stdpath('data')) was symlinked
# straight at the repo checkout itself, same as ~/.config/nvim. Every plugin
# that writes to stdpath('data') was therefore writing into the git working
# tree. nvim-treesitter's ensure_installed/auto_install (lua/plugin_config.lua)
# made this visible: it also set prefer_git = true one line AFTER calling
# .configs.setup{}, which already kicks off the installs synchronously — so
# every install used the curl+tar download path (not git clone) and left
# tree-sitter-*.tar.gz sitting in stdpath('data'), i.e. the repo root. The
# same bug earlier committed a redundant site/autoload/plug.vim into git.
#
# This script:
#   1. fixes the prefer_git ordering in lua/plugin_config.lua
#   2. removes the debris (stray tarballs + the wrongly-committed site/ copy)
#      and gitignores the tarball pattern as a backstop
#   3. adds scripts/link-data-dir.sh, wired into `make init`, so every
#      machine's ~/.local/share/nvim points at a gitignored nvimdata/ inside
#      the checkout instead of the repo root or nothing at all — same
#      convention plugged/ already uses: repo-relative so it's identical on
#      every machine, gitignored so it's never part of git status.
#   4. records the fix in CLAUDE/project.json hazards and CHANGELOG.txt
#
# Idempotent; commits as it goes on `dev`; never touches master.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain -- lua/ .gitignore Makefile scripts/ CLAUDE/project.json CHANGELOG.txt site/)" ]; then
  echo "!! tracked changes already pending in files this script touches — commit or stash first:"
  git status --short -- lua/ .gitignore Makefile scripts/ CLAUDE/project.json CHANGELOG.txt site/
  exit 1
fi
[ "$(git rev-parse --abbrev-ref HEAD)" = master ] && { echo "!! refusing to run on master"; exit 1; }

commit() {
  local m="$1"; shift
  # -A on a pathspec with nothing to match (already-committed no-op re-run)
  # is a fatal error in some git versions; tolerate it, the diff check below
  # is what actually decides whether there is anything to commit.
  git add -A -- "$@" 2>/dev/null || true
  if git diff --cached --quiet; then echo "   (no change) $m"; else
    git commit -q -m "$m"; echo "   committed: $m"
  fi
}

echo "== 1. lua/plugin_config.lua: set prefer_git before configs.setup{} runs installs"
python3 - <<'PY'
import re
p = "lua/plugin_config.lua"
src = open(p).read()
marker = 'require("nvim-treesitter.install").prefer_git = true\n'
if marker not in src:
    print("   marker line not found — already fixed or file changed, skipping"); raise SystemExit
src = src.replace("\n" + marker, "\n")  # drop the trailing occurrence
note = (
    "-- Must run before .configs.setup{} below: ensure_installed installs\n"
    "-- run synchronously inside setup(), using whatever prefer_git is at that\n"
    "-- exact moment. Setting it after setup() (as this used to) means the\n"
    "-- first run always takes the curl+tar download path instead of git\n"
    "-- clone, and — if stdpath('data') ever points somewhere unexpected —\n"
    "-- leaves tree-sitter-*.tar.gz sitting wherever that curl ran.\n"
    + marker + "\n"
)
target = "require'nvim-treesitter.configs'.setup {"
if target not in src:
    print("   setup{} call not found — skipping"); raise SystemExit
src = src.replace(target, note + target, 1)
open(p, "w").write(src)
print("   reordered")
PY
commit "fix(treesitter): set prefer_git before configs.setup() kicks off installs" lua/plugin_config.lua

echo "== 2. drop debris the bug already produced"
rm -f ./tree-sitter-*.tar.gz
if git ls-files --error-unmatch site/autoload/plug.vim >/dev/null 2>&1; then
  git rm -q -f site/autoload/plug.vim
  echo "   git rm site/autoload/plug.vim (redundant copy the same bug committed)"
fi
rm -rf site
grep -qxF 'tree-sitter-*.tar.gz' .gitignore || {
  printf '%s\n' 'tree-sitter-*.tar.gz' >> .gitignore
  echo "   added tree-sitter-*.tar.gz to .gitignore"
}
grep -qxF 'nvimdata' .gitignore || {
  printf '%s\n' 'nvimdata' >> .gitignore
  echo "   added nvimdata to .gitignore"
}
commit "chore(git): drop the site/ copy the bug committed" site/autoload/plug.vim
commit "chore(gitignore): ignore treesitter tarball debris and nvimdata/" .gitignore

echo "== 3. scripts/link-data-dir.sh + make init wiring"
cat > scripts/link-data-dir.sh <<'EOF_SCRIPT'
#!/usr/bin/env bash
# link-data-dir.sh — point Neovim's data dir (stdpath('data'), normally
# ~/.local/share/nvim) at nvimdata/ inside this checkout instead of leaving it
# unset (defaults to a bare ~/.local/share/nvim) or aliased to the repo root
# itself (the bug this fixes: every plugin that writes to stdpath('data') was
# writing straight into the git working tree). Same convention as plugged/:
# repo-relative so the path is identical on every machine, gitignored so
# nothing it holds ever shows up in git status.
#
# Idempotent — run by `make init` on every machine, safe to re-run. Never
# deletes pre-existing data: a real directory or a symlink pointing anywhere
# else is moved aside, never overwritten in place.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
data_dir="$repo_root/nvimdata"
target="$HOME/.local/share/nvim"

mkdir -p "$data_dir"
mkdir -p "$(dirname "$target")"

if [ -L "$target" ]; then
  current="$(readlink "$target")"
  if [ "$current" = "$data_dir" ]; then
    echo "link-data-dir: already linked ($target -> $data_dir)"
    exit 0
  fi
  backup="$target.bak-$(date +%Y%m%d%H%M%S 2>/dev/null || echo old)"
  mv "$target" "$backup"
  echo "link-data-dir: $target was a symlink to $current — moved to $backup"
elif [ -e "$target" ]; then
  if [ -z "$(ls -A "$data_dir" 2>/dev/null)" ]; then
    rmdir "$data_dir"
    mv "$target" "$data_dir"
    echo "link-data-dir: migrated existing $target into $data_dir"
  else
    echo "link-data-dir: $target exists and $data_dir is already populated — refusing to merge automatically."
    echo "  Resolve by hand: move what you need from $target into $data_dir, remove $target, re-run."
    exit 1
  fi
fi

ln -s "$data_dir" "$target"
echo "link-data-dir: linked $target -> $data_dir"
EOF_SCRIPT
chmod +x scripts/link-data-dir.sh
echo "   wrote scripts/link-data-dir.sh"

grep -qF 'link-data-dir.sh' Makefile || python3 - <<'PY'
p = "Makefile"
src = open(p).read()
old = "init:  ## install plugins in both editors\n"
if old not in src:
    print("   init: target not found in expected form — leaving Makefile untouched, wire link-data-dir.sh by hand")
else:
    src = src.replace(old, old + "\tbash scripts/link-data-dir.sh\n", 1)
    open(p, "w").write(src)
    print("   wired link-data-dir.sh into `make init` (runs first)")
PY
commit "feat(init): auto-link ~/.local/share/nvim to gitignored nvimdata/ on every machine" scripts/link-data-dir.sh Makefile

echo "== 4. record the fix"
python3 - <<'PY'
import json
p = "CLAUDE/project.json"
c = json.load(open(p))
note = ("Fixed 2026-09-09: ~/.local/share/nvim was symlinked to the repo checkout on "
        "some machines, so nvim-treesitter's parser installs littered "
        "tree-sitter-*.tar.gz into the repo root and one redundant plug.vim copy got "
        "committed under site/. scripts/link-data-dir.sh (run by `make init`) now "
        "points ~/.local/share/nvim at gitignored nvimdata/ instead — re-run `make "
        "init` on any machine still showing the old symlink.")
if note not in c.get("hazards", []):
    c.setdefault("hazards", []).append(note)
    json.dump(c, open(p, "w"), indent=2)
    open(p, "a").write("\n")
    print("   noted in project.json hazards")
else:
    print("   already noted")
PY
python3 scripts/changelog.py add Fixed \
  "Neovim's data directory (stdpath('data')) no longer aliases the repo checkout: nvim-treesitter was littering tree-sitter-*.tar.gz into the repo root on every startup and never actually finishing parser installs. \`make init\` now runs scripts/link-data-dir.sh, which points ~/.local/share/nvim at a gitignored nvimdata/ inside the checkout, and prefer_git is set before nvim-treesitter's install kicks off so future installs use git clone, not tarball download." \
  >/dev/null 2>&1 || echo "   changelog.py add failed — check manually"
commit "docs: record the treesitter data-dir fix" CLAUDE/project.json CHANGELOG.txt

echo "== 5. adopt the fix on this machine and verify"
bash scripts/link-data-dir.sh
bash scripts/check.sh
