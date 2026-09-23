#!/usr/bin/env bash
# lib.sh — shared helpers, sourced by the kit scripts before they cd anywhere.
# No side effects, no dependencies beyond git. 3.2-safe.

# proot — print the project root. The nearest ancestor holding CLAUDE/CLAUDE.md
# wins; failing that the git top level; failing that $PWD.
# CLAUDE/ is asked FIRST on purpose. `git rev-parse --show-toplevel` answers
# with an ANCESTOR repository when the project root is not one itself
# (git.vcs = none inside a tree that is a repo), which would silently point
# every script at somebody else's project.
# The walk also STOPS at a repository boundary (a .git file or directory):
# a linked worktree in claude_repo.mode=subrepo has no CLAUDE/ of its own
# (the parent gitignores it), and walking past its root landed every script
# on the MAIN checkout — session.sh end then committed and pushed the wrong
# tree and reported it clean.
proot() {
  local d="$PWD"
  # ${d%/*} rather than dirname: cfg.sh calls this on every key lookup and a
  # fork per ancestor is a real cost in the session digest.
  while [ -n "$d" ]; do
    [ -f "$d/CLAUDE/CLAUDE.md" ] && { printf '%s\n' "$d"; return 0; }
    [ -e "$d/.git" ] && { printf '%s\n' "$d"; return 0; }
    [ "$d" = "/" ] && break
    d="${d%/*}"; [ -z "$d" ] && d=/
  done
  d=$(git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$d" ] && { printf '%s\n' "$d"; return 0; }
  printf '%s\n' "$PWD"
}

# cfg_init / cfg — CLAUDE/project.json read ONCE per script. cfg.sh costs a
# python start-up per key (~0.3 s on a Mac mini); check.sh asked 17 times and
# the digest 20+, which was most of a session start and of every check.sh
# run. Call cfg_init after cd-ing to proot; cfg then answers from memory with
# cfg.sh's exact semantics (dotted keys, lists space-joined, bools lowercase,
# default when the key is absent). Scripts that run before cfg_init, or
# outside a project, fall back to cfg.sh itself.
CFG_FLAT=""
cfg_init() {
  CFG_FLAT=$(python3 - <<'PY' 2>/dev/null
import json
def walk(v, pre):
    if isinstance(v, dict):
        for k, x in v.items(): walk(x, pre + k + ".")
        return
    key = pre[:-1]
    if isinstance(v, list): val = " ".join(map(str, v))
    elif isinstance(v, bool): val = str(v).lower()
    elif v is None: return
    else: val = str(v)
    print(key + "\t" + val.replace("\n", " "))
try: walk(json.load(open("CLAUDE/project.json")), "")
except Exception: pass
PY
)
  CFG_LOADED=1
}
cfg() {  # cfg <dotted.key> [default]
  if [ "${CFG_LOADED:-0}" = 1 ]; then
    local line
    line=$(printf '%s\n' "$CFG_FLAT" | grep -m1 "^$1	")
    if [ -n "$line" ]; then printf '%s\n' "${line#*	}"; else printf '%s\n' "${2:-}"; fi
  else
    bash "$(dirname "${BASH_SOURCE[0]}")/cfg.sh" "$1" "${2:-}" 2>/dev/null || printf '%s\n' "${2:-}"
  fi
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

# kit_root — locate the claude_init kit this project was built from, for the
# "resource library" lookups and the periodic release check (project.yaml).
# Git-locked, not path-locked (project-instructions.txt): never a committed
# path, so the order is
#   1. $CLAUDE_INIT_KIT env var
#   2. project.yaml kit.path (this machine's copy — never committed)
#   3. CLAUDE/.kit-path — the older one-line local override
#   4. a short list of conventional locations
# Prints the path and returns 0 when found; prints nothing and returns 1
# otherwise — callers decide whether that is fatal.
kit_root() {
  local c p
  if [ -n "${CLAUDE_INIT_KIT:-}" ] && [ -f "$CLAUDE_INIT_KIT/scripts/bootstrap.sh" ]; then
    printf '%s\n' "$CLAUDE_INIT_KIT"; return 0
  fi
  if [ -f project.yaml ]; then
    p=$(bash "$(dirname "${BASH_SOURCE[0]}")/ycfg.sh" kit.path "" 2>/dev/null)
    [ -n "$p" ] && [ -f "$p/scripts/bootstrap.sh" ] && { printf '%s\n' "$p"; return 0; }
  fi
  if [ -f CLAUDE/.kit-path ]; then
    p=$(tr -d ' \n' < CLAUDE/.kit-path 2>/dev/null)
    [ -n "$p" ] && [ -f "$p/scripts/bootstrap.sh" ] && { printf '%s\n' "$p"; return 0; }
  fi
  for c in "$HOME/code/my_code/claude_init" "$HOME/.claude_init" "$HOME/code/claude_init"; do
    [ -f "$c/scripts/bootstrap.sh" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
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

# in_worktree — true when the current directory is a LINKED worktree, not the
# main checkout. A linked worktree's .git is a file pointing elsewhere, so
# --git-dir and --git-common-dir diverge; in the main checkout they match.
in_worktree() { [ "$(git rev-parse --git-dir 2>/dev/null)" != "$(git rev-parse --git-common-dir 2>/dev/null)" ]; }
