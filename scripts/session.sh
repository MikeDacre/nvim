#!/usr/bin/env bash
# session.sh start|ctx|end [msg]|refs — session bookends.
#   start : fetch + full context digest (facts, git, drift, todos, roadmap)
#   ctx   : same digest, no network — cheap mid-session refresh
#   end   : commit (if a message is given), back-fill changelog, docs, gate, push
#   refs  : the reference URLs from project.json (kept out of the digest)
# The digest is designed to REPLACE reading project.json / ROADMAP.md /
# TODO.txt / CHANGELOG.txt. It is paid for on every session: keep it compact
# and under ~6000 chars (the Claude Code SessionStart hook caps stdout at 10000).
# `--hook` marks a run launched by that hook; the digest then says so, so the
# model does not run `start` a second time.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
. scripts/lib.sh
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"

cfg() { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }
SYNC=$(cfg sync synced); DEVB=$(cfg git.dev_branch dev); MAINB=$(cfg git.release_branch main)
BR=$(git rev-parse --abbrev-ref HEAD)
HOOK=0; for a in "$@"; do [[ "$a" == "--hook" ]] && HOOK=1; done
hr() { printf -- '----------------------------------------------------------------\n'; }

facts() {
  [[ -f CLAUDE/project.json ]] || { echo "PROJECT  (no project.json — using defaults)"; return; }
  python3 - <<'PY'
import json
try: c = json.load(open("CLAUDE/project.json"))
except Exception as e: print(f"PROJECT  !! project.json unreadable: {e}"); raise SystemExit
def d(*path, default=""):
    v = c
    for p in path:
        v = v.get(p) if isinstance(v, dict) else None
        if v is None: return default
    return v
rt = d('runtime'); rt = rt if isinstance(rt, str) else rt.get('primary', '') if isinstance(rt, dict) else ''
print(f"PROJECT  {d('name')} v{d('version')} — {d('purpose')}")
print(f"  type   {d('type')}/{d('subtype')} · {d('lang')}/{rt} · {d('visibility')} · sync={d('sync')}"
      f" · trunk={d('git','release_branch', default='main')} · kit v{d('kit_version', default='?')}")
ep = d('entrypoint')
if ep: print(f"  entry  {ep}")
b = d('build', default={})
if b: print("  build  " + " · ".join(f"{k}={v}" for k, v in b.items()
                                     if k in ('install','test','lint','dist','docs')))
deps = [x for x in d('deps', default=[]) if x.get('name') and not x['name'].startswith('{{')]
if deps: print("  deps   " + ", ".join(f"{x['name']}({x.get('kind','pkg')})" for x in deps))
con = [x for x in d('connectors', default=[]) if x.get('name') and not x['name'].startswith('{{')]
if con: print("  conn   " + ", ".join(x['name'] for x in con))
rules = d('rules', default=[])
if rules:
    print("  RULES  project-specific, in force every session:")
    for r in rules[:10]: print(f"         - {r}")
hz = d('hazards', default=[])
if hz:
    print("  HAZARDS")
    for h in hz[:8]: print(f"         - {h}")
cm = d('claude_repo','mode', default='tracked')
if cm == 'subrepo': print("  claude CLAUDE/ is a separate repo — needs its own push")
sk = [x['name'] for x in d('skills', default=[]) if x.get('name') and not x['name'].startswith('{{')]
if sk: print("  skills " + ", ".join(sk) + "  (.claude/skills/<name>; /<name> in Claude Code)")
dr = d('docs_refs', default=[])
if dr: print(f"  refs   {len(dr)} reference URLs: bash scripts/session.sh refs")
PY
}

roadmap() {
  [[ -f ROADMAP.md ]] || return
  local now
  now=$(awk '/^## (Now|In progress)/{f=1;next} /^## /{f=0} f' ROADMAP.md \
        | grep -E '^\s*-' | head -6)
  [[ -n "$now" ]] && { echo "ROADMAP (now)"; echo "$now" | sed 's/^/  /'; }
}

unreleased() {
  local cl; cl=$(cfg release.changelog CHANGELOG.txt)
  [[ -f "$cl" ]] || return
  local u
  u=$(awk '/^## \[Unreleased\]/{f=1;next}/^## \[/{f=0}f' "$cl" \
      | grep -E '^(- |### )' | grep -v 'Nothing yet' \
      | awk '/^### /{h=$0;next} {if(h){print h;h=""} print}' | head -8)
  [[ -n "$u" ]] && { echo "CHANGELOG [Unreleased]"; echo "$u" | sed 's/^/  /'; }
}

gitstate() {
  echo "GIT      $BR @ $(git rev-parse --short HEAD) (release=$MAINB dev=$DEVB) · v$(cat VERSION 2>/dev/null || echo '?')"
  local dirty; dirty=$(git status --porcelain)
  [[ -n "$dirty" ]] && { echo "  dirty  $(echo "$dirty" | wc -l | tr -d ' ') file(s):"; echo "$dirty" | head -8 | sed 's/^/         /'; }
  git log --oneline --no-merges -3 2>/dev/null | sed 's/^/         /'
  if git remote get-url origin >/dev/null 2>&1; then
    local a b
    a=$(git rev-list --count "@{u}..HEAD" 2>/dev/null || echo '?')
    b=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || echo '?')
    echo "  remote ahead $a / behind $b"
    [[ "$a" != '?' && "$a" -gt 0 && "$b" -gt 0 ]] && echo "  !! DIVERGED — stop and report. Never resolve with a force push."
  else
    echo "  remote none"
  fi
  if [[ -d CLAUDE/.git ]]; then
    local cd_; cd_=$(cd CLAUDE && git status --porcelain 2>/dev/null)
    [[ -n "$cd_" ]] && echo "  CLAUDE/ sub-repo has uncommitted changes"
  fi
  local n; n=$(python3 scripts/changelog.py pending 2>/dev/null || echo '?')
  if [[ "$n" != 0 ]]; then
    echo "  !! $n user-visible commit(s) not in CHANGELOG — the user edited outside Claude."
    echo "     Back-fill without asking: python3 scripts/changelog.py from-git"
  fi
}

drift() {
  local n=0
  w() { echo "  ! $1"; n=$((n+1)); }
  echo "DRIFT"
  { [[ -L CLAUDE.md && -e CLAUDE.md ]]; } || w "CLAUDE.md is not a working symlink"
  [[ -f .claude/settings.json ]] || w ".claude/settings.json missing (Claude Code hook + permissions)"
  [[ -d CLAUDE/legacy ]] && w "CLAUDE/legacy/ still present — adoption merge not finished (adopt.md Phase 3)"
  while IFS=$'\t' read -r src art; do
    [[ -n "$src" ]] || continue
    stale "$src" "$art" && w "$art is older than $src (regenerate: make docs)"
  done < <(generated_pairs)
  [[ $n -eq 0 ]] && echo "  ok"
}

digest() {
  hr; echo "SESSION $(date '+%F %H:%M') host=$(hostname -s)"; hr
  if [[ $HOOK -eq 1 ]]; then
    echo "This digest was injected by the Claude Code SessionStart hook; scripts/session.sh"
    echo "start has already run for this session. /ctx or 'bash scripts/session.sh ctx' refreshes it."
  fi
  facts; echo
  gitstate; drift; echo
  [[ -f TODO.txt ]] && { python3 scripts/todo.py summary 2>/dev/null; echo; }
  [[ -d CLAUDE/orders ]] && { python3 scripts/order.py summary 2>/dev/null; }
  roadmap; unreleased
  bash scripts/feature.sh status 2>/dev/null | sed -n '2,6p'
  hr
  echo "This digest replaces reading project.json / ROADMAP.md / TODO.txt / CHANGELOG.txt;"
  echo "those files are opened only to edit them. Rules: CLAUDE.md (loaded automatically in Claude Code)."
}

refs() {
  python3 - <<'PY'
import json
for r in json.load(open("CLAUDE/project.json")).get("docs_refs", []):
    print(f"{r.get('what') or r.get('name')}\n    {r.get('url')}")
PY
}

end() {
  local msg="${1:-}"
  hr; echo "SESSION END $(date '+%F %H:%M') branch=$BR"; hr
  if [[ "$BR" == "$MAINB" ]]; then
    echo "!! on $MAINB — releases only. Move work to $DEVB or a feature branch."; exit 1
  fi
  if [[ -n "$(git status --porcelain)" ]]; then
    if [[ -n "$msg" ]]; then
      git add -A
      if git commit -q -m "$msg"; then echo "-> committed: $msg"
      else
        echo "!! COMMIT REFUSED (see hook output above). Nothing was committed."
        echo "   Fix the cause and re-run. Do not bypass the hook."; exit 1
      fi
    else
      echo "-> uncommitted changes left as-is (session.sh end \"msg\" commits them):"
      git status --short | head -8 | sed 's/^/   /'
    fi
  else echo "-> nothing to commit"; fi
  echo "-> changelog"; python3 scripts/changelog.py from-git
  echo "-> docs";      make docs >/dev/null 2>&1 || echo "   (make docs unavailable — regenerate manually)"
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A && git commit -q -m "docs: back-fill changelog, regenerate docs" && echo "-> committed docs/changelog"
  fi
  if [[ -d CLAUDE/.git ]] && [[ -n "$(cd CLAUDE && git status --porcelain)" ]]; then
    (cd CLAUDE && git add -A && git commit -q -m "docs: update project documentation")
    echo "-> CLAUDE/ committed"
  fi
  echo "-> check"
  local out rc; out=$(bash scripts/check.sh 2>&1); rc=$?
  echo "$out" | grep -E '^\s*(FAIL|check:)' | sed 's/^/   /'
  [[ $rc -eq 0 ]] || { echo "!! check.sh FAILED — fix before pushing. Nothing pushed."; exit 1; }
  bash scripts/sync.sh auto
  hr; echo "$(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD) · unlogged=$(python3 scripts/changelog.py pending)"
}

case "${1:-start}" in
  start)
    git remote get-url origin >/dev/null 2>&1 && \
      { T 25 git fetch --all --prune -q 2>/dev/null || echo "(offline — remote unreachable, digest from local state)"; }
    digest;;
  ctx)  digest;;
  end)  shift; end "${1:-}";;
  refs) refs;;
  *) echo "usage: session.sh start|ctx|end [\"commit message\"]|refs" >&2; exit 2;;
esac
