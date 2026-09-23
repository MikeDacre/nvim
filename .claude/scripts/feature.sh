#!/usr/bin/env bash
# feature.sh status|new <slug> [--force]|finish [branch]|merge-dev|list|ideas|ideas-merge
# Enforces the one-feature-per-branch rule and the "ask before switching" guard.
# git.session_worktrees (CLAUDE/project.json) backs each branch with its own
# git worktree instead of switching the current checkout, so concurrent chats
# never collide over one directory. Off by default; every command below
# degrades to the original single-checkout behavior when it's false.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
PROOT=$(proot)
cd "$PROOT" || exit 1
have_git || { echo "no repository at the project root (git.vcs=none) — there are no branches here."; exit 0; }

cfg_init

DEVB=$(cfg git.dev_branch dev)
MAINB=$(cfg git.release_branch main)
PFX=$(cfg git.feature_prefix "feat/")
FIXP=$(cfg git.fix_prefix "fix/")
HOTP=$(cfg git.hotfix_prefix "hotfix/")
WT=$(cfg git.session_worktrees false)
WTDIR=$(cfg git.worktree_dir "")
TYPE_=$(cfg type code)
CMODE=$(cfg claude_repo.mode tracked)
# Session worktrees are a code-type feature (Mike, 2026-09-19): a document
# tree (writing, administrative, knowledge-base) is edited by the user in
# place and a second copy of it per chat is a trap, not a convenience.
if [[ "$WT" == "true" && "$TYPE_" != code ]]; then
  WT=false; WT_NOTE="git.session_worktrees is ignored for type=$TYPE_ (worktrees are for code projects)"
fi

BR=$(git rev-parse --abbrev-ref HEAD)

is_session_branch() { case "$1" in "$PFX"*|"$FIXP"*|chore/*|"$HOTP"*|ideas) return 0;; *) return 1;; esac; }

wtroot() { [[ -n "$WTDIR" ]] && printf '%s\n' "$WTDIR" || printf '%s\n' "$PROOT/.worktrees"; }

wtpath_for_branch() {  # print the worktree path already attached to a branch, if any
  git worktree list --porcelain | awk -v want="refs/heads/$1" '
    /^worktree /{p=$2} /^branch /{if ($2==want) print p}'
}

dev_base() {  # the newer of local dev and origin/dev — never silently the older
  # After an offline or unpushed session local dev is AHEAD of origin/dev;
  # basing a new branch on the remote then starts it behind, and the previous
  # session's work reappears as a merge conflict at finish time.
  if git rev-parse --verify -q "refs/remotes/origin/$DEVB" >/dev/null 2>&1; then
    if git merge-base --is-ancestor "origin/$DEVB" "$DEVB" 2>/dev/null; then
      echo "$DEVB"          # local contains the remote: local is newer or equal
    else
      echo "origin/$DEVB"   # remote is ahead (or diverged — a fetch just ran)
    fi
  else
    echo "$DEVB"
  fi
}

# link_shared <worktree-dir> — a linked worktree carries only tracked files.
# In claude_repo.mode=subrepo the parent gitignores CLAUDE/ and CLAUDE.md, so
# the worktree has no rulebook and no project.json at all; link them to the
# main checkout's (they are one repo, and the notes are meant to be shared).
# The per-machine files are gitignored in every mode: say what is absent so
# the session does not discover it at the first secret read.
link_shared() {
  local dir="$1" f
  if [[ "$CMODE" == subrepo ]]; then
    [[ -e "$dir/CLAUDE" ]]    || ln -s "$PROOT/CLAUDE" "$dir/CLAUDE"
    [[ -e "$dir/CLAUDE.md" ]] || ln -s "CLAUDE/CLAUDE.md" "$dir/CLAUDE.md"
    echo "linked  CLAUDE/ and CLAUDE.md to the main checkout (claude_repo.mode=subrepo — the parent does not track them)"
  fi
  # same machine, same user: the gitignored per-machine files travel with it
  for f in project.yaml .claude/settings.local.json CLAUDE/.kit-path; do
    [[ -f "$PROOT/$f" && ! -e "$dir/$f" ]] || continue
    mkdir -p "$dir/$(dirname "$f")" && cp -p "$PROOT/$f" "$dir/$f" && echo "copied  $f (per-machine, gitignored)"
  done
  return 0
}

active() {  # feature branches with commits not yet in dev
  git for-each-ref --format='%(refname:short)' "refs/heads/${PFX}*" "refs/heads/${FIXP}*" "refs/heads/chore/*" "refs/heads/${HOTP}*" "refs/heads/ideas" |
  while read -r b; do
    n=$(git rev-list --count "$DEVB..$b" 2>/dev/null || echo 0)
    [[ "$n" -gt 0 ]] && printf '%s\t%s\t%s\n' "$b" "$n" "$(git log -1 --format=%cr "$b")"
  done
}

status() {
  echo "FEATURE STATE"
  echo "  current: $BR$( [[ -n $(git status --porcelain) ]] && echo '  (dirty)' )"
  if is_session_branch "$BR"; then
    local behind; behind=$(git rev-list --count "$BR..$DEVB" 2>/dev/null || echo 0)
    [[ "$behind" -gt 0 ]] && echo "  $DEVB is $behind commit(s) ahead of $BR — ask the user: 'feature.sh merge-dev' to catch up?"
  fi
  local a; a=$(active)
  if [[ -z "$a" ]]; then
    echo "  active feature branches: none"
    echo "  → safe to start a new feature."
  else
    echo "  active feature branches (unmerged into $DEVB):"
    echo "$a" | while IFS=$'\t' read -r b n t; do
      local wt=""; [[ "$WT" == "true" ]] && wt=$(wtpath_for_branch "$b")
      printf "    %-32s %s commits, last %s%s\n" "$b" "$n" "$t" "${wt:+ — worktree: $wt}"
    done
    case "$BR" in
      "$PFX"*|"$FIXP"*)
        echo "  → you are ON a feature branch. A request for a DIFFERENT feature"
        echo "    must be put to the user: continue here, or branch anew?";;
      ideas)
        echo "  → you are on the persistent ideas/notes branch. Merge into $DEVB"
        echo "    often with 'feature.sh ideas-merge' — it is never 'finish'ed.";;
      *)
        echo "  → not on a feature branch; other work is parked, that is fine.";;
    esac
  fi
}

new() {
  local slug="${1:?usage: feature.sh new <slug> [--force]}"
  local b="${PFX}${slug}"
  if [[ "$WT" == "true" ]]; then
    local wt; wt=$(wtpath_for_branch "$b")
    if [[ -n "$wt" ]]; then
      echo "already has a worktree: $b -> $wt"
      echo "cd there and continue"
      exit 0
    fi
    local dir; dir="$(wtroot)/${slug}"
    if git show-ref --verify -q "refs/heads/$b"; then
      git worktree add -q "$dir" "$b" || exit 1
    else
      git fetch -q origin "$DEVB" 2>/dev/null || true
      git worktree add -q -b "$b" "$dir" "$(dev_base)" || exit 1
    fi
    link_shared "$dir"
    echo "on $b (from $DEVB) in its own worktree: $dir"
    echo "cd there for the rest of this session — Bash, and absolute paths for Read/Write/Edit"
    exit 0
  fi
  [[ -n "${WT_NOTE:-}" ]] && echo "note: $WT_NOTE"
  git show-ref --verify -q "refs/heads/$b" && { echo "exists: $b — switching"; git checkout -q "$b"; exit 0; }
  case "$BR" in
    "$PFX"*|"$FIXP"*)
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

ideas() {
  local b="ideas"
  if [[ "$WT" == "true" ]]; then
    local wt; wt=$(wtpath_for_branch "$b")
    if [[ -n "$wt" ]]; then
      echo "already has a worktree: $b -> $wt"
      echo "cd there and continue"
      exit 0
    fi
    local dir; dir="$(wtroot)/ideas"
    if git show-ref --verify -q "refs/heads/$b"; then
      git worktree add -q "$dir" "$b" || exit 1
    else
      git fetch -q origin "$DEVB" 2>/dev/null || true
      git worktree add -q -b "$b" "$dir" "$(dev_base)" || exit 1
    fi
    link_shared "$dir"
    echo "on $b (from $DEVB) in its own worktree: $dir"
    echo "cd there for the rest of this session — Bash, and absolute paths for Read/Write/Edit"
    echo "persistent notes branch — commit freely, merge into $DEVB often with 'feature.sh ideas-merge'"
    exit 0
  fi
  git show-ref --verify -q "refs/heads/$b" && { echo "exists: $b — switching"; git checkout -q "$b"; exit 0; }
  [[ -n "$(git status --porcelain)" ]] && { echo "commit or stash first"; exit 3; }
  git checkout -q "$DEVB" && git pull -q --ff-only 2>/dev/null
  git checkout -q -b "$b"
  echo "on $b (from $DEVB) — persistent notes branch, merge into $DEVB often with 'feature.sh ideas-merge'"
}

ideas_merge() {
  local b="ideas"
  git show-ref --verify -q "refs/heads/$b" || { echo "no ideas branch yet — run 'feature.sh ideas' first"; exit 2; }
  if [[ "$WT" == "true" ]] && in_worktree; then
    local main; main=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
    echo "run ideas-merge from the main checkout, not from inside a session worktree: cd $main"
    exit 3
  fi
  [[ -n "$(git status --porcelain)" ]] && { echo "commit first"; exit 3; }
  git checkout -q "$DEVB" && git pull -q --ff-only 2>/dev/null
  git merge --no-ff -q "$b" -m "merge: $b into $DEVB" || { echo "CONFLICT — resolve, then re-run"; exit 1; }
  echo "merged $b -> $DEVB (branch kept — ideas is never finished/deleted)"
  echo "push when ready: git push origin $DEVB"
}

finish() {
  local b="${1:-$BR}"
  [[ "$b" == "ideas" ]] && { echo "ideas is a persistent branch — use 'feature.sh ideas-merge', not finish"; exit 2; }
  case "$b" in "$PFX"*|"$FIXP"*|chore/*|"$HOTP"*) :;; *) echo "not a feature/fix/chore branch: $b"; exit 2;; esac
  if [[ "$WT" == "true" ]] && in_worktree; then
    local main; main=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
    echo "run finish from the main checkout, not from inside a session worktree: cd $main"
    exit 3
  fi
  [[ -n "$(git status --porcelain)" ]] && { echo "commit first"; exit 3; }
  git checkout -q "$DEVB" && git pull -q --ff-only 2>/dev/null
  git merge --no-ff -q "$b" -m "merge: $b into $DEVB" || { echo "CONFLICT — resolve, then re-run"; exit 1; }
  echo "merged $b -> $DEVB"
  local wt; wt=$(wtpath_for_branch "$b")
  if [[ -n "$wt" ]]; then
    echo "Ask before deleting: git worktree remove '$wt' && git branch -d $b && git push origin --delete $b"
  else
    echo "Ask before deleting: git branch -d $b && git push origin --delete $b"
  fi
}

merge_dev() {
  is_session_branch "$BR" || { echo "not on a feature/fix/chore branch: $BR"; exit 2; }
  [[ -n "$(git status --porcelain)" ]] && { echo "commit or stash first"; exit 3; }
  git fetch -q origin "$DEVB" 2>/dev/null || true
  local base; base=$(dev_base)
  git merge --no-ff -q "$base" -m "merge: $base into $BR" || { echo "CONFLICT — resolve, then commit"; exit 1; }
  echo "merged $base -> $BR"
}

case "${1:-status}" in
  status)      status;;
  list)        active;;
  new)         shift; new "$@";;
  finish)      shift; finish "$@";;
  merge-dev)   merge_dev;;
  ideas)       ideas;;
  ideas-merge) ideas_merge;;
  *) echo "usage: feature.sh status|list|new <slug> [--force]|finish [branch]|merge-dev|ideas|ideas-merge" >&2; exit 2;;
esac
