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
