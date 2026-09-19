#!/usr/bin/env bash
# lib.sh — shared helpers, sourced by the kit scripts before they cd anywhere.
# No side effects, no dependencies beyond git. 3.2-safe.

# proot — print the project root. The nearest ancestor holding CLAUDE/CLAUDE.md
# wins; failing that the git top level; failing that $PWD.
# CLAUDE/ is asked FIRST on purpose. `git rev-parse --show-toplevel` answers
# with an ANCESTOR repository when the project root is not one itself
# (git.vcs = none inside a tree that is a repo), which would silently point
# every script at somebody else's project.
proot() {
  local d="$PWD"
  # ${d%/*} rather than dirname: cfg.sh calls this on every key lookup and a
  # fork per ancestor is a real cost in the session digest.
  while [ -n "$d" ]; do
    [ -f "$d/CLAUDE/CLAUDE.md" ] && { printf '%s\n' "$d"; return 0; }
    [ "$d" = "/" ] && break
    d="${d%/*}"; [ -z "$d" ] && d=/
  done
  d=$(git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$d" ] && { printf '%s\n' "$d"; return 0; }
  printf '%s\n' "$PWD"
}

# have_git — true when the current directory is itself a repository root.
# Call it after cd-ing to proot. Projects with git.vcs = none answer false, and
# every git-shaped step (branches, push, release, changelog back-fill) stands
# down rather than acting on an enclosing repo.
have_git() { [ -e .git ]; }

# T <secs> <cmd...> — run under a timeout when one exists. GNU coreutils on
# macOS installs it as gtimeout; stock macOS has neither, so fall through.
T() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else shift; "$@"; fi
}

# uncommitted <path> — true when a path differs from HEAD in any way, including
# being untracked. `git diff HEAD -- <path>` never reports an untracked file, so
# it calls a brand-new artifact "clean" and stale() then declares it out of
# date; git status does see it.
uncommitted() { [ -n "$(git status --porcelain -- "$1" 2>/dev/null)" ]; }

# stale <source> <artifact> — exit 0 when <artifact> needs regenerating.
# Git-based, not mtime-based: `git pull` writes both files in arbitrary order,
# so `[ src -nt artifact ]` gives false answers on every other machine.
#   source edited but uncommitted  -> stale unless the artifact is dirty too
#   both committed                 -> stale if source's last commit is not an
#                                     ancestor of the artifact's last commit
stale() {
  local src="$1" art="$2" r d
  [ -f "$src" ] || return 1
  [ -f "$art" ] || return 0
  # No repository: mtime is all there is, and without a `git pull` to write
  # the two files in arbitrary order it is honest enough.
  if ! have_git; then
    [ "$src" -nt "$art" ] && return 0
    return 1
  fi
  if uncommitted "$src"; then
    uncommitted "$art" && return 1
    return 0
  fi
  r=$(git log -1 --format=%H -- "$src" 2>/dev/null)
  d=$(git log -1 --format=%H -- "$art" 2>/dev/null)
  { [ -z "$r" ] || [ -z "$d" ]; } && return 1
  git merge-base --is-ancestor "$r" "$d" 2>/dev/null && return 1
  return 0
}

# generated_pairs — print "source<TAB>artifact" for every project.json
# build.generated entry, plus README -> man page when build.man is set.
generated_pairs() {
  python3 - <<'PY' 2>/dev/null
import json
try:
    c = json.load(open("CLAUDE/project.json"))
except Exception:
    raise SystemExit
b = c.get("build", {})
for g in b.get("generated", []) or []:
    if g.get("source") and g.get("artifact"):
        print(f"{g['source']}\t{g['artifact']}")
if b.get("man"):
    print(f"README.md\t{b['man']}")
PY
}
