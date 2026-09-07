#!/usr/bin/env bash
# feature.sh status|new <slug>|finish [slug]|list
# Enforces the one-feature-per-branch rule and the "ask before switching" guard.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

cfg() { # cfg <dotted.key> <default>  — reads CLAUDE/project.json, no eval
  python3 -c 'import json,sys
try: c=json.load(open("CLAUDE/project.json"))
except Exception: print(sys.argv[2]); raise SystemExit
v=c
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v,dict) else None
    if v is None: print(sys.argv[2]); raise SystemExit
print(" ".join(v) if isinstance(v,list) else v)' "$1" "$2" 2>/dev/null || echo "$2"
}

DEVB=$(cfg git.dev_branch dev)
MAINB=$(cfg git.release_branch main)
PFX=$(cfg git.feature_prefix "feat/")

BR=$(git rev-parse --abbrev-ref HEAD)

active() {  # feature branches with commits not yet in dev
  git for-each-ref --format='%(refname:short)' "refs/heads/${PFX}*" "refs/heads/fix/*" |
  while read -r b; do
    n=$(git rev-list --count "$DEVB..$b" 2>/dev/null || echo 0)
    [[ "$n" -gt 0 ]] && printf '%s\t%s\t%s\n' "$b" "$n" "$(git log -1 --format=%cr "$b")"
  done
}

status() {
  echo "FEATURE STATE"
  echo "  current: $BR$( [[ -n $(git status --porcelain) ]] && echo '  (dirty)' )"
  local a; a=$(active)
  if [[ -z "$a" ]]; then
    echo "  active feature branches: none"
    echo "  → safe to start a new feature."
  else
    echo "  active feature branches (unmerged into $DEVB):"
    echo "$a" | awk -F'\t' '{printf "    %-32s %s commits, last %s\n",$1,$2,$3}'
    case "$BR" in
      "$PFX"*|fix/*)
        echo "  → you are ON a feature branch. A request for a DIFFERENT feature"
        echo "    must be put to the user: continue here, or branch anew?";;
      *)
        echo "  → not on a feature branch; other work is parked, that is fine.";;
    esac
  fi
}

new() {
  local slug="${1:?usage: feature.sh new <slug>}"
  local b="${PFX}${slug}"
  git show-ref --verify -q "refs/heads/$b" && { echo "exists: $b — switching"; git checkout -q "$b"; exit 0; }
  case "$BR" in
    "$PFX"*|fix/*)
      local n; n=$(git rev-list --count "$DEVB..$BR" 2>/dev/null || echo 0)
      if [[ "$n" -gt 0 || -n "$(git status --porcelain)" ]]; then
        echo "BLOCKED: on $BR with $n unmerged commit(s)$( [[ -n $(git status --porcelain) ]] && echo ' and uncommitted changes')."
        echo "Ask the user: start '$b', or keep working on '$BR'?  Re-run with --force to proceed."
        [[ "${2:-}" == "--force" ]] || exit 3
      fi;;
  esac
  [[ -n "$(git status --porcelain)" ]] && { echo "commit or stash first"; exit 3; }
  git checkout -q "$DEVB" && git pull -q --ff-only 2>/dev/null
  git checkout -q -b "$b"
  echo "on $b (from $DEVB)"
}

finish() {
  local b="${1:-$BR}"
  case "$b" in "$PFX"*|fix/*) :;; *) echo "not a feature branch: $b"; exit 2;; esac
  [[ -n "$(git status --porcelain)" ]] && { echo "commit first"; exit 3; }
  git checkout -q "$DEVB" && git pull -q --ff-only 2>/dev/null
  git merge --no-ff -q "$b" -m "merge: $b into $DEVB" || { echo "CONFLICT — resolve, then re-run"; exit 1; }
  echo "merged $b -> $DEVB"
  echo "Ask before deleting: git branch -d $b && git push origin --delete $b"
}

case "${1:-status}" in
  status) status;;
  list)   active;;
  new)    shift; new "$@";;
  finish) shift; finish "$@";;
  *) echo "usage: feature.sh status|list|new <slug> [--force]|finish [branch]" >&2; exit 2;;
esac
