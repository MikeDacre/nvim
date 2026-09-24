#!/usr/bin/env bash
# kit-check.sh — the periodic "is a new stable claude_init release out?" check
# project.yaml declares (kit.release_check, kit.upgrade). Called from
# `session.sh start` only (never `ctx` — ctx is documented no-network); a
# timestamp file makes every other call an instant, silent no-op. Prints
# nothing unless there is something to report.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh" 2>/dev/null
cd "$(proot 2>/dev/null || echo .)" || cd .
ycfg() { bash "$SDIR/ycfg.sh" "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

[[ -f project.yaml || -f project.yaml.example ]] || exit 0
have_git || exit 0   # no repository at the root: no stamp to anchor, nothing to update into

POLICY=$(ycfg kit.upgrade prompt)
[[ "$POLICY" == never ]] && exit 0

CADENCE=$(ycfg kit.release_check weekly)
case "$CADENCE" in
  daily)   SECS=86400;;
  monthly) SECS=2592000;;
  *)       SECS=604800;;   # weekly, and any unrecognised value
esac

STAMP=.git/claude-init-last-check
if [[ -f "$STAMP" ]]; then
  NOW=$(date +%s)
  LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
  [[ $((NOW - LAST)) -lt $SECS ]] && exit 0   # not due — fast path, no network
fi
date +%s > "$STAMP"   # mark attempted regardless of outcome below: this is a
                      # "brief periodic check", not a retry-until-success loop

KIT_ROOT=$(kit_root) || exit 0   # kit unreachable — quietly skip, try again next cadence
T 5 git -C "$KIT_ROOT" fetch --tags -q 2>/dev/null || true

LATEST=$(git -C "$KIT_ROOT" tag -l 'v*' 2>/dev/null | grep -Ev -- '-(alpha|beta|rc)\.' \
         | sed 's/^v//' | sort -V | tail -1)
[[ -n "$LATEST" ]] || exit 0

CURRENT=$(bash "$SDIR/cfg.sh" kit_version "0.0.0" 2>/dev/null); CURRENT="${CURRENT:-0.0.0}"
[[ "$LATEST" == "$CURRENT" ]] && exit 0
# sort -V: CURRENT is newer or equal unless LATEST sorts strictly after it
NEWER=$(printf '%s\n%s\n' "$CURRENT" "$LATEST" | sort -V | tail -1)
[[ "$NEWER" == "$LATEST" ]] || exit 0

echo "claude_init v$LATEST is available (this project is on v$CURRENT)."
if [[ "$POLICY" == auto ]]; then
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "  policy=auto, but the working tree is dirty — skipped (commit or stash, then it will retry next cadence)."
    exit 0
  fi
  echo "  policy=auto — running adopt.sh --update:"
  bash "$KIT_ROOT/scripts/adopt.sh" --kit "$KIT_ROOT" --update 2>&1 | sed 's/^/  /'
  ON_AUTO=$(ycfg kit.on_auto notify)
  # adopt.sh --update leaves the current branch staged (never a new branch —
  # kit-update-<stamp> is just a pointer at the pre-update commit, for revert).
  if [[ "$ON_AUTO" == commit && -n "$(git status --porcelain)" ]]; then
    git commit -q -m "chore: update to claude_init v$LATEST (auto)" \
      && echo "  committed: chore: update to claude_init v$LATEST (auto)"
  fi
else
  echo "  bash $KIT_ROOT/scripts/adopt.sh --kit $KIT_ROOT --update"
fi
