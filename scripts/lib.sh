#!/usr/bin/env bash
# lib.sh — shared helpers, sourced by session.sh / check.sh / doctor.sh.
# No side effects, no dependencies beyond git. 3.2-safe.

# T <secs> <cmd...> — run under a timeout when one exists. GNU coreutils on
# macOS installs it as gtimeout; stock macOS has neither, so fall through.
T() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else shift; "$@"; fi
}

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
  if ! git diff --quiet HEAD -- "$src" 2>/dev/null; then
    git diff --quiet HEAD -- "$art" 2>/dev/null && return 0
    return 1
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
