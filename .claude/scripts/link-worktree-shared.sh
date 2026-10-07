#!/usr/bin/env bash
# link-worktree-shared.sh — make a git worktree able to actually RUN the
# editors, by symlinking the gitignored per-machine directories that live in
# the main checkout into it.
#
# The checkout IS the runtimepath, and the heavy parts of it are deliberately
# not tracked: plugged/ (2.6GB of vim-plug plugins) and .venv/ (the python3
# host prog). `git worktree add` therefore produces a tree where every plugin
# is missing, so vim dies with E117 on the first airline call and nvim throws
# E5108 on the first `require` of a plugin module. That is why the hazard used
# to say a worktree cannot run the editors at all.
#
# Both are reachable from the editor only as `g:vimdir_path . '/<name>'`
# (init.vim:11 and plugins.vim:8), and g:vimdir_path is resolve()d from
# init.vim's own location — so in a worktree it is the worktree. A symlink at
# that path is all it takes: one shared plugin store, no second 2.6GB copy,
# and no per-worktree :PlugInstall.
#
# nvimdata/ is deliberately NOT linked: Neovim reaches it through the fixed
# ~/.local/share/nvim symlink (see link-data-dir.sh), which points at the main
# checkout no matter which tree nvim was launched from.
#
# Idempotent and safe: a no-op in the main checkout, a no-op when the links
# are already right, and it never replaces a real directory or a symlink that
# points somewhere else — those are reported and left alone.
#
# Run by the SessionStart hook in .claude/settings.json, and fine to run by
# hand in a worktree made outside Claude Code:
#   bash .claude/scripts/link-worktree-shared.sh
#
# CAUTION: because the store is shared, :PlugClean run inside a worktree
# deletes from the MAIN checkout's plugged/ — and plugins.vim's has('nvim')
# branches mean running it from the wrong editor culls the other editor's
# plugins (bit us 2026-09-07). That hazard is unchanged by this script, but a
# worktree is now one more place it can be triggered from.
set -euo pipefail

# Resolve from this script's own location, not $PWD: the hook's working
# directory is not guaranteed, and `scripts` is a symlink to .claude/scripts,
# so a lexical "$(dirname "$0")/.." lands in the wrong place when it is used.
# pwd -P resolves that symlink before git is asked anything.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$here"

# No git, or not a repo: nothing to do, and never fail a session hook over it.
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

tree_root="$(git rev-parse --show-toplevel)"

# --git-common-dir is the ONE .git shared by the main checkout and every
# worktree, so its parent is always the main checkout. A worktree reports it
# absolute; the main checkout reports it RELATIVE TO $PWD (from here that is
# "../../.git", not ".git") — resolve it against $PWD, never against
# $tree_root, or the main checkout resolves two levels too high and never
# takes the no-op branch below.
common="$(git rev-parse --git-common-dir)"
case "$common" in
  /*) ;;
   *) common="$PWD/$common" ;;
esac
main_root="$(cd "$(dirname "$common")" && pwd -P)"

# In the main checkout the directories are the real thing; leave them be.
[ "$tree_root" = "$main_root" ] && exit 0

linked=0
for name in plugged .venv; do
  src="$main_root/$name"
  dst="$tree_root/$name"

  # Not provisioned in the main checkout yet (fresh clone): nothing to share.
  if [ ! -e "$src" ]; then
    echo "link-worktree-shared: $name absent in $main_root — skipped (run scripts/install.sh there first)"
    continue
  fi

  if [ -L "$dst" ]; then
    current="$(readlink "$dst")"
    [ "$current" = "$src" ] && continue
    echo "link-worktree-shared: $dst is a symlink to $current, not $src — left alone"
    continue
  fi

  if [ -e "$dst" ]; then
    echo "link-worktree-shared: $dst is a real directory — left alone (remove it to share the main checkout's)"
    continue
  fi

  ln -s "$src" "$dst"
  echo "link-worktree-shared: linked $name -> $src"
  linked=$((linked + 1))
done

[ "$linked" -gt 0 ] && echo "link-worktree-shared: this worktree can now run vim and nvim"
exit 0
