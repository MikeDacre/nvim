#!/usr/bin/env bash
# sync.sh auto|pull|push-all|status
# Keeps the repo portable across machines. Mode from CLAUDE/project.json:
#   synced -> every branch is pushed;  local -> main+dev, plus the current branch.
# adopt-backup-* branches are never pushed: they are local revert points.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
. scripts/lib.sh 2>/dev/null || true
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"

cfg() { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

MODE=$(cfg sync synced)
DEVB=$(cfg git.dev_branch dev)
MAINB=$(cfg git.release_branch main)

has_remote() { git remote get-url origin >/dev/null 2>&1; }
BR=$(git rev-parse --abbrev-ref HEAD)

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
  if [[ "$MODE" == "synced" ]]; then
    branches=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '^adopt-backup-')
  else
    branches="$MAINB $DEVB $BR"
  fi
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
  echo "sync mode: $MODE"
  git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/ | sed 's/^/  /'
}

case "${1:-auto}" in
  auto) pull; push;;
  pull) pull;;
  push-all) push;;
  status) status;;
  *) echo "usage: sync.sh auto|pull|push-all|status" >&2; exit 2;;
esac
