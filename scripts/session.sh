#!/usr/bin/env bash
# session.sh start|ctx|end [msg]|refs — session bookends and the context digest.
#   start : git fetch, then the digest (Claude Code runs this via the SessionStart hook)
#   ctx   : the digest without network — mid-session or post-compaction refresh
#   end   : commit (if a message is given), back-fill changelog, gate on check.sh, push
#   refs  : the reference URLs from project.json (kept out of the digest to save tokens)
# The digest replaces reading project.json / ROADMAP.md / TODO.txt / CHANGELOG.txt.
# It is paid for on every session: keep it under ~6000 chars (the Claude Code hook cap is 10000; it is ~4300 today).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
. scripts/lib.sh
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"
BR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
HOOK=0; for a in "$@"; do [ "$a" = "--hook" ] && HOOK=1; done

facts() {
  python3 - <<'PY'
import json
c = json.load(open("CLAUDE/project.json"))
g = c.get("git", {}); rt = c.get("runtime", {})
print(f"PROJECT {c.get('name')} — {c.get('purpose')}")
print(f"TYPE {c.get('type')}/{c.get('subtype')}  LANG {c.get('lang')}  VIS {c.get('visibility')}  SYNC {c.get('sync')}  TRUNK {g.get('trunk')}")
print(f"EDITORS primary: {rt.get('primary')} | secondary: {rt.get('secondary')}")
hz = c.get("hazards", [])
if hz:
    print("HAZARDS")
    for h in hz: print(f"  - {h}")
sk = [s["name"] for s in c.get("skills", []) if s.get("name")]
if sk: print("SKILLS " + ", ".join(sk) + "  (.claude/skills/<name>/SKILL.md; /<name> in Claude Code)")
print(f"REFS {len(c.get('docs_refs', []))} reference URLs: bash scripts/session.sh refs")
PY
}

gitstate() {
  local ahead behind dirty
  ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')
  behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo '?')
  dirty=$(git status --porcelain | wc -l | tr -d ' ')
  echo "GIT branch=$BR ahead=$ahead behind=$behind dirty=$dirty"
  [ "$dirty" != "0" ] && git status --short | head -10 | sed 's/^/  /'
  if [ "$ahead" != '?' ] && [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    echo "  ! DIVERGED from origin — report it; never resolve with a force push"
  fi
  git log --oneline --no-merges -3 2>/dev/null | sed 's/^/  /'
}

drift() {
  local n=0
  w() { echo "  ! $1"; n=$((n+1)); }
  echo "DRIFT"
  { [ -L CLAUDE.md ] && [ -e CLAUDE.md ]; } || w "CLAUDE.md is not a working symlink"
  [ -f doc/mikevim.txt ] || w "doc/mikevim.txt missing (make doc)"
  doc_stale && w "README.md changed after doc/mikevim.txt was generated (make doc)"
  [ -f .claude/settings.json ] || w ".claude/settings.json missing (Claude Code hook + permissions)"
  { [ -L CLAUDE/skills ] && [ -d CLAUDE/skills ]; } || w "CLAUDE/skills should be a symlink to ../.claude/skills"
  [ "$n" -eq 0 ] && echo "  ok"
}

digest() {
  echo "=== SESSION $(date '+%Y-%m-%d %H:%M') host=$(hostname -s) ==="
  if [ "$HOOK" = 1 ]; then
    echo "NOTE this digest was injected by the Claude Code SessionStart hook, so"
    echo "     scripts/session.sh start has already run for this session."
    echo "     Refresh later with: bash scripts/session.sh ctx   (or /ctx)"
  fi
  facts
  echo "RULES CLAUDE.md (-> CLAUDE/CLAUDE.md) is the invariant rule set. In Claude Code it is"
  echo "      loaded automatically and the shell is built in; its Desktop Commander section (§6)"
  echo "      applies only to claude.ai Project chats."
  echo
  gitstate
  drift
  echo "CHANGELOG unlogged=$(python3 scripts/changelog.py pending)"
  echo
  echo "ROADMAP.NOW"
  sed -n '/^## Now/,/^## /p' ROADMAP.md | grep '^- ' | sed 's/^/  /'
  echo
  python3 scripts/todo.py list 2>/dev/null || echo "TODO: todo.py failed"
  echo "=== END DIGEST ==="
}

refs() {
  python3 - <<'PY'
import json
for r in json.load(open("CLAUDE/project.json")).get("docs_refs", []):
    print(f"{r.get('what')}\n    {r.get('url')}")
PY
}

end() {
  local msg="${1:-}"
  echo "=== SESSION END $(date '+%Y-%m-%d %H:%M') branch=$BR ==="
  if [ -n "$(git status --porcelain)" ]; then
    if [ -n "$msg" ]; then
      git add -A && git commit -q -m "$msg" && echo "committed: $msg"
    else
      echo "uncommitted changes left as-is (pass a message to commit them: session.sh end \"msg\"):"
      git status --short | sed 's/^/  /'
    fi
  fi
  python3 scripts/changelog.py from-git
  if ! git diff --quiet -- CHANGELOG.txt; then
    git add CHANGELOG.txt && git commit -q -m "docs: back-fill changelog" && echo "committed: changelog back-fill"
  fi
  bash scripts/check.sh || { echo "check.sh FAILED — fix before closing; nothing pushed"; return 1; }
  if T 30 git push --follow-tags origin "$BR" >/tmp/session-push.$$ 2>&1; then
    echo "pushed $BR ($(tail -1 /tmp/session-push.$$))"
  else
    echo "push FAILED (offline?):"; tail -3 /tmp/session-push.$$
  fi
  rm -f /tmp/session-push.$$
  echo "unlogged=$(python3 scripts/changelog.py pending)"
}

case "${1:-start}" in
  start)
    T 25 git fetch --quiet --prune origin 2>/dev/null || echo "(fetch skipped — remote unreachable)"
    digest ;;
  ctx)   digest ;;
  end)   shift; end "${1:-}" ;;
  refs)  refs ;;
  *) echo "usage: session.sh start|ctx|end [\"commit message\"]|refs" >&2; exit 2 ;;
esac
