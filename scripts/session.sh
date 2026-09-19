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
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(proot)" || exit 1
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=5 -o BatchMode=yes}"

cfg() { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }
SYNC=$(cfg sync synced); DEVB=$(cfg git.dev_branch dev); MAINB=$(cfg git.release_branch main)
FEATP=$(cfg git.feature_prefix feat/); FIXP=$(cfg git.fix_prefix fix/); HOTP=$(cfg git.hotfix_prefix hotfix/)
# git.vcs = none: no repository at the project root (a synced vault, a folder
# inside somebody else's tree). Everything git-shaped stands down; the digest,
# the todos, the changelog file and CLAUDE/ still work.
GIT=1; have_git || GIT=0
BR=$( [[ $GIT -eq 1 ]] && git rev-parse --abbrev-ref HEAD || echo "-" )
HOOK=0; for a in "$@"; do [[ "$a" == "--hook" ]] && HOOK=1; done
hr() { printf -- '----------------------------------------------------------------\n'; }

# is_trunk_branch <name> — true for the release branch, the dev branch, or an
# ephemeral feat/fix/hotfix branch that merges back into one of those; false
# for a long-lived branch that never merges back (e.g. one per machine).
# CHANGELOG.txt and VERSION belong to the trunk, so the back-fill prompt below
# only fires where back-filling cannot poison a future merge-forward.
is_trunk_branch() {
  local b="$1" p
  [[ "$b" == "$MAINB" || "$b" == "$DEVB" ]] && return 0
  for p in "$FEATP" "$FIXP" "$HOTP"; do
    [[ -n "$p" && "$b" == "$p"* ]] && return 0
  done
  return 1
}

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
# Truncation is never silent: a rule that does not print is a rule that is
# not in force, and the old caps dropped the tail without saying so.
def listing(items, cap, title, where):
    if not items: return
    print(title)
    for x in items[:cap]: print(f"         - {x}")
    if len(items) > cap:
        print(f"         ... and {len(items) - cap} more — read them: {where}")

listing(d('rules', default=[]), 12,
        "  RULES  project-specific, in force every session:",
        "python3 -c \"import json;[print(r) for r in json.load(open('CLAUDE/project.json'))['rules']]\"")
listing(d('hazards', default=[]), 10, "  HAZARDS",
        "python3 -c \"import json;[print(r) for r in json.load(open('CLAUDE/project.json'))['hazards']]\"")
cm = d('claude_repo','mode', default='tracked')
if cm == 'subrepo': print("  claude CLAUDE/ is a separate repo — needs its own push")
sk = [x['name'] for x in d('skills', default=[]) if x.get('name') and not x['name'].startswith('{{')]
if sk: print("  skills " + ", ".join(sk) + "  (.claude/skills/<name>; /<name> in Claude Code)")
dr = d('docs_refs', default=[])
if dr: print(f"  refs   {len(dr)} reference URLs: bash scripts/session.sh refs")
PY
}

# The mode rulebook's non-negotiables, printed every session. The full file is
# CLAUDE/MODE.md; this block is what must be in force before the first edit.
modeblock() {
  [[ -f CLAUDE/MODE.md ]] || return
  local hdr always
  hdr=$(sed -n '1s/^# MODE: *//p' CLAUDE/MODE.md)
  echo "  MODE   ${hdr:-unknown}"
  always=$(awk '/^## Always/{f=1;next} /^## /{f=0} f' CLAUDE/MODE.md | grep -E '^- ' | head -10)
  [[ -n "$always" ]] && printf '%s\n' "$always" | sed 's/^/         /'
  echo "         full rulebook: CLAUDE/MODE.md (read once per session)"
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
  if [[ $GIT -eq 0 ]]; then
    echo "GIT      none — no repository at the project root (git.vcs=none) · v$(cat VERSION 2>/dev/null || echo '?')"
    if [[ -d CLAUDE/.git ]]; then
      local cd_; cd_=$(cd CLAUDE && git status --porcelain 2>/dev/null)
      echo "  CLAUDE $(cd CLAUDE && git log --oneline -1 2>/dev/null)"
      [[ -n "$cd_" ]] && echo "  CLAUDE/ sub-repo has uncommitted changes"
    else
      echo "  !! no repository anywhere — nothing here is recoverable. scripts/backup.sh before every write."
    fi
    return
  fi
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
    if is_trunk_branch "$BR"; then
      echo "  !! $n user-visible commit(s) not in CHANGELOG — the user edited outside Claude."
      echo "     Back-fill without asking: python3 scripts/changelog.py from-git"
    else
      echo "  note   $n commit(s) not in CHANGELOG — CHANGELOG.txt is trunk-only; $BR does not back-fill here."
    fi
  fi
}

drift() {
  local n=0
  w() { echo "  ! $1"; n=$((n+1)); }
  echo "DRIFT"
  { [[ -L CLAUDE.md && -e CLAUDE.md ]]; } || w "CLAUDE.md is not a working symlink"
  [[ -f .claude/settings.json ]] || w ".claude/settings.json missing (Claude Code hook + permissions)"
  local mt; mt=$(cfg type "")
  if [[ ! -f CLAUDE/MODE.md ]]; then
    w "CLAUDE/MODE.md missing — the mode rulebook is not installed (bash <kit>/scripts/adopt.sh --update)"
  elif [[ -n "$mt" ]] && ! head -1 CLAUDE/MODE.md | grep -q "MODE: $mt"; then
    w "CLAUDE/MODE.md is not the rulebook for type=$mt (bash <kit>/scripts/adopt.sh --update)"
  fi
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
  facts; modeblock; echo
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
  # Single-trunk (dev_branch == release_branch) makes the release branch the
  # working branch; refusing there would leave `end` with nothing it can do.
  if [[ $GIT -eq 1 && "$BR" == "$MAINB" && "$MAINB" != "$DEVB" ]]; then
    echo "!! on $MAINB — releases only. Move work to $DEVB or a feature branch."; exit 1
  fi
  if [[ $GIT -eq 0 ]]; then
    echo "-> no repository at the project root (git.vcs=none) — nothing to commit here"
    [[ -n "$msg" ]] && echo "   the message is recorded in the CLAUDE/ sub-repo commit below"
  elif [[ -n "$(git status --porcelain)" ]]; then
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
  if [[ $GIT -eq 1 ]]; then
    echo "-> changelog"; python3 scripts/changelog.py from-git
  fi
  echo "-> docs";      make docs >/dev/null 2>&1 || echo "   (make docs unavailable — regenerate manually)"
  if [[ $GIT -eq 1 && -n "$(git status --porcelain)" ]]; then
    git add -A && git commit -q -m "docs: back-fill changelog, regenerate docs" && echo "-> committed docs/changelog"
  fi
  if [[ -d CLAUDE/.git ]] && [[ -n "$(cd CLAUDE && git status --porcelain)" ]]; then
    # With no repo at the root the CLAUDE/ commit is the session's only record,
    # so the user's message goes there rather than into a generic subject.
    (cd CLAUDE && git add -A && git commit -q -m "${msg:-docs: update project documentation}")
    echo "-> CLAUDE/ committed"
  fi
  echo "-> check"
  local out rc; out=$(bash scripts/check.sh 2>&1); rc=$?
  echo "$out" | grep -E '^\s*(FAIL|check:)' | sed 's/^/   /'
  [[ $rc -eq 0 ]] || { echo "!! check.sh FAILED — fix before pushing. Nothing pushed."; exit 1; }
  bash scripts/sync.sh auto
  hr
  if [[ $GIT -eq 1 ]]; then
    echo "$(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD) · unlogged=$(python3 scripts/changelog.py pending)"
  else
    echo "vcs=none · CLAUDE/ @ $( (cd CLAUDE && git rev-parse --short HEAD) 2>/dev/null || echo '-')"
  fi
}

case "${1:-start}" in
  start)
    [[ $GIT -eq 1 ]] && git remote get-url origin >/dev/null 2>&1 && \
      { T 25 git fetch --all --prune -q 2>/dev/null || echo "(offline — remote unreachable, digest from local state)"; }
    digest;;
  ctx)  digest;;
  end)  shift; end "${1:-}";;
  refs) refs;;
  *) echo "usage: session.sh start|ctx|end [\"commit message\"]|refs" >&2; exit 2;;
esac
