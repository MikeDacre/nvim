#!/usr/bin/env bash
# lib.sh — shared helpers, sourced by session.sh and check.sh. No side effects.

# T <secs> <cmd...> — run under a timeout if one is installed (GNU coreutils on
# macOS ships it as gtimeout; stock macOS has neither), else run plainly.
T() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else shift; "$@"; fi
}

# doc_stale — exit 0 when doc/mikevim.txt needs regenerating from README.md.
# Git-based, not mtime-based: a `git pull` writes both files in arbitrary
# order, so mtime comparison gives false answers on every other machine.
doc_stale() {
  [ -f doc/mikevim.txt ] || return 1
  if ! git diff --quiet HEAD -- README.md 2>/dev/null; then
    # README edited but not committed: fresh only if the doc was regenerated too
    git diff --quiet HEAD -- doc/mikevim.txt 2>/dev/null && return 0
    return 1
  fi
  local r d
  r=$(git log -1 --format=%H -- README.md 2>/dev/null)
  d=$(git log -1 --format=%H -- doc/mikevim.txt 2>/dev/null)
  { [ -z "$r" ] || [ -z "$d" ]; } && return 1
  git merge-base --is-ancestor "$r" "$d" 2>/dev/null && return 1
  return 0
}
