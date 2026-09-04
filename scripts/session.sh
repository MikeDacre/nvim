#!/usr/bin/env bash
# Session digest. `start` prints full context; `end` closes out.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
P=CLAUDE/project.json
j() { jq -r "$1" "$P" 2>/dev/null; }

start() {
  echo "=== SESSION START $(date '+%Y-%m-%d %H:%M') host=$(hostname -s) ==="
  echo "PROJECT $(j .name) — $(j .purpose)"
  echo "TYPE $(j .type)/$(j .subtype)  LANG $(j .lang)  VIS $(j .visibility)  SYNC $(j .sync)"
  echo "RULES read CLAUDE.md once before acting (symlink -> CLAUDE/CLAUDE.md)"
  echo
  git fetch --quiet --prune origin 2>/dev/null
  local br ahead behind dirty
  br=$(git rev-parse --abbrev-ref HEAD)
  ahead=$(git rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
  behind=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
  dirty=$(git status --porcelain | wc -l | tr -d ' ')
  echo "GIT branch=$br ahead=$ahead behind=$behind dirty=$dirty"
  if [ "$dirty" != "0" ]; then git status --short | sed 's/^/  /'; fi
  echo
  echo "DRIFT"
  [ -L CLAUDE.md ] || echo "  ! CLAUDE.md is not a symlink"
  [ -f doc/mikevim.txt ] || echo "  ! doc/mikevim.txt missing (make doc)"
  if [ -f doc/mikevim.txt ] && [ README.md -nt doc/mikevim.txt ]; then
    echo "  ! README.md newer than doc/mikevim.txt (make doc)"
  fi
  git diff --quiet HEAD -- plugins.vim 2>/dev/null || echo "  ! plugins.vim modified"
  echo "  ok"
  echo
  echo "CHANGELOG unlogged=$(python3 scripts/changelog.py pending)"
  echo
  echo "ROADMAP.NOW"
  sed -n '/^## Now/,/^## /p' ROADMAP.md | grep '^- ' | sed 's/^/  /'
  echo
  local open
  open=$(grep -cvE '^(x |#|$)' TODO.txt 2>/dev/null || echo 0)
  echo "TODO open=$open"
  grep -vE '^(x |#|$)' TODO.txt 2>/dev/null | head -8 | sed 's/^/  /'
  echo
  echo "=== END DIGEST ==="
}

end() {
  echo "=== SESSION END $(date '+%Y-%m-%d %H:%M') ==="
  bash scripts/check.sh || { echo "check.sh FAILED — fix before closing"; exit 1; }
  local dirty
  dirty=$(git status --porcelain | wc -l | tr -d ' ')
  [ "$dirty" != "0" ] && { echo "uncommitted changes:"; git status --short; }
  git push --quiet origin "$(git rev-parse --abbrev-ref HEAD)" 2>&1 | tail -2
  echo "pushed $(git rev-parse --abbrev-ref HEAD); unlogged=$(python3 scripts/changelog.py pending)"
}

case "${1:-start}" in
  start) start ;;
  end)   end ;;
  *) echo "usage: session.sh {start|end}"; exit 2 ;;
esac
