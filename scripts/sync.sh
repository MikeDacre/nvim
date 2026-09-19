#!/usr/bin/env bash
# sync.sh auto|pull|push-all|status
# Keeps the repo portable across machines. What gets pushed is
# CLAUDE/project.json git.push_branches (CLAUDE.md §2):
#   all    -> every local branch
#   trunk  -> the release branch, the dev branch, and the current one
#   a list -> exactly those branches
# Absent, it falls back to the top-level sync field (synced -> all, local ->
# trunk) so a project.json written before the key existed still behaves.
# adopt-backup-* branches are never pushed: they are local revert points.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(proot)" || exit 1
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"

cfg() { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

MODE=$(cfg sync synced)
DEVB=$(cfg git.dev_branch dev)
MAINB=$(cfg git.release_branch main)
PUSHB=$(cfg git.push_branches "")
[[ -n "$PUSHB" ]] || { [[ "$MODE" == synced ]] && PUSHB=all || PUSHB=trunk; }

has_remote() { git remote get-url origin >/dev/null 2>&1; }
GIT=1; have_git || GIT=0
BR=$( [[ $GIT -eq 1 ]] && git rev-parse --abbrev-ref HEAD || echo "-" )

# git.vcs = none: nothing to pull or push at the root. The CLAUDE/ sub-repo
# still travels, and it is where the notes and rules live, so push it.
push_claude_only() {
  if [[ -d CLAUDE/.git ]] && (cd CLAUDE && git remote get-url origin >/dev/null 2>&1); then
    (cd CLAUDE && T 60 git push -q -u origin HEAD 2>/dev/null) && echo "sync: pushed CLAUDE/" \
      || echo "sync: !! CLAUDE/ push failed"
  else
    echo "sync: vcs=none and CLAUDE/ has no remote — nothing leaves this machine"
  fi
}

pull() {
  has_remote || { echo "sync: no remote"; return 0; }
  T 30 git fetch --all --prune -q || { echo "sync: fetch failed (offline?)"; return 0; }
  for b in "$MAINB" "$DEVB" "$BR"; do
    git show-ref -q --verify "refs/heads/$b" || continue
    git rev-parse -q --verify "origin/$b" >/dev/null || continue
    if [[ "$(git rev-list --count "$b..origin/$b")" -gt 0 ]]; then
      if [[ "$(git rev-list --count "origin/$b..$b")" -gt 0 ]]; then
        echo "sync: !! $b has DIVERGED from origin — resolve manually, no force push."
      else
        git branch -f "$b" "origin/$b" 2>/dev/null \
          || { git checkout -q "$b" && git merge -q --ff-only "origin/$b"; }
        echo "sync: fast-forwarded $b"
      fi
    fi
  done
  git checkout -q "$BR"
}

push() {
  has_remote || { echo "sync: no remote — commits are local only"; return 0; }
  local branches
  case "$PUSHB" in
    all)   branches=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '^adopt-backup-');;
    trunk) branches="$MAINB $DEVB $BR";;
    *)     branches="$PUSHB";;   # an explicit list, space-joined by cfg.sh
  esac
  for b in $(echo "$branches" | tr ' ' '\n' | sort -u); do
    git show-ref -q --verify "refs/heads/$b" || continue
    T 60 git push -q -u origin "$b" 2>/dev/null && echo "sync: pushed $b" \
      || echo "sync: !! push failed for $b (never force)"
  done
  T 60 git push -q --tags origin 2>/dev/null || true
  # CLAUDE sub-repo travels on its own remote
  if [[ -d CLAUDE/.git ]] && (cd CLAUDE && git remote get-url origin >/dev/null 2>&1); then
    (cd CLAUDE && T 60 git push -q -u origin HEAD 2>/dev/null) && echo "sync: pushed CLAUDE/" \
      || echo "sync: !! CLAUDE/ push failed"
  fi
}

status() {
  echo "sync mode: $MODE · push_branches: $PUSHB"
  git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/ | sed 's/^/  /'
}

if [[ $GIT -eq 0 ]]; then
  echo "sync: no repository at the project root (git.vcs=none)"
  case "${1:-auto}" in
    auto|push-all) push_claude_only;;
    pull) echo "sync: nothing to pull";;
    status) echo "sync mode: $MODE · push_branches: n/a (vcs=none)";;
  esac
  exit 0
fi

case "${1:-auto}" in
  auto) pull; push;;
  pull) pull;;
  push-all) push;;
  status) status;;
  *) echo "usage: sync.sh auto|pull|push-all|status" >&2; exit 2;;
esac
