#!/usr/bin/env bash
# release.sh major|minor|patch [--dry-run] [--yes]
# release.sh pre alpha|beta|rc [major|minor|patch] [--dry-run] [--yes]
#
# SemVer 2.0.0 + Keep a Changelog 1.1.0. Run from dev with a clean tree.
# MINOR/MAJOR additionally publish a GitHub release with assets — that step
# always prompts, because it publishes publicly (CLAUDE.md §3).
#
# `pre` tags a pre-release (X.Y.Z-alpha.N / -beta.N / -rc.N) on dev only —
# never merged to the release branch, and the alpha/beta/rc number
# auto-increments on repeat runs. Starting a fresh series needs a bump level
# (release.sh pre alpha minor); once started, the target base version is
# fixed until finalized. Finalize by running the ORIGINAL bump level again
# (release.sh major|minor|patch) once VERSION holds a pre-release suffix —
# that strips the suffix and runs the normal release flow (merge, GitHub
# release per minor/major, tag-only for patch) rather than bumping further.
# Every pre-release publishes to GitHub with --prerelease, gated by the same
# approval prompt minor/major already use.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "$(proot)" || exit 1
# A release is a tag on a merge commit; without a repository there is nothing
# to tag. VERSION and CHANGELOG.txt are still yours to roll by hand.
have_git || { echo "no repository at the project root (git.vcs=none) — release.sh needs git."; exit 2; }

LEVEL="${1:?usage: release.sh major|minor|patch|pre [--dry-run] [--yes]}"; shift || true
case "$LEVEL" in
  major|minor|patch|pre) ;;
  *) echo "level must be major|minor|patch|pre"; exit 2;;
esac

STAGE=""; BUMP=""
if [[ "$LEVEL" == "pre" ]]; then
  STAGE="${1:?usage: release.sh pre alpha|beta|rc [major|minor|patch] [--dry-run] [--yes]}"; shift || true
  case "$STAGE" in
    alpha|beta|rc) ;;
    *) echo "stage must be alpha|beta|rc"; exit 2;;
  esac
  # optional third positional: the bump level, only consumed when it's
  # actually one of major/minor/patch (not a --flag)
  if [[ "${1:-}" =~ ^(major|minor|patch)$ ]]; then BUMP="$1"; shift || true; fi
fi

DRY=0; YES=0
for a in "$@"; do [[ "$a" == "--dry-run" ]] && DRY=1; [[ "$a" == "--yes" ]] && YES=1; done
run() { if [[ $DRY -eq 1 ]]; then echo "DRY: $*"; else eval "$@"; fi; }

cfg() { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

DEVB=$(cfg git.dev_branch dev)
MAINB=$(cfg git.release_branch main)
ASSETS=$(cfg release.assets "dist/*")
CHLOG=$(cfg release.changelog CHANGELOG.txt)

BR=$(git rev-parse --abbrev-ref HEAD)
[[ "$BR" == "$DEVB" ]] || { echo "must be on $DEVB (on $BR)"; exit 1; }
# --untracked-files=no: some projects carry untracked content by design (a
# super-project over other checkouts). Untracked files cannot end up in the
# release commit either — step 1 stages the version files by name, not -A.
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "working tree dirty"; exit 1; }
[[ $DRY -eq 1 ]] || bash scripts/check.sh || { echo "check.sh FAILED — fix before releasing"; exit 1; }

CUR=$(cat VERSION 2>/dev/null || echo 0.0.0)
SEMVER_RE='^([0-9]+)\.([0-9]+)\.([0-9]+)(-(alpha|beta|rc)\.([0-9]+))?$'
[[ "$CUR" =~ $SEMVER_RE ]] || { echo "VERSION '$CUR' is not X.Y.Z or X.Y.Z-alpha|beta|rc.N"; exit 1; }
MA=${BASH_REMATCH[1]}; MI=${BASH_REMATCH[2]}; PA=${BASH_REMATCH[3]}
CURSTAGE=${BASH_REMATCH[5]:-}; CURNUM=${BASH_REMATCH[6]:-0}

stage_rank() { case "$1" in alpha) echo 0;; beta) echo 1;; rc) echo 2;; esac; }

FINALIZE=0
if [[ "$LEVEL" == "pre" ]]; then
  if [[ -n "$CURSTAGE" ]]; then
    [[ -z "$BUMP" ]] || { echo "already mid a pre-release series for $MA.$MI.$PA (currently $CURSTAGE.$CURNUM) — drop the bump argument, or finalize first with 'release.sh major|minor|patch'"; exit 1; }
    CR=$(stage_rank "$CURSTAGE"); SR=$(stage_rank "$STAGE")
    if [[ "$SR" -lt "$CR" ]]; then
      echo "cannot move backward from $CURSTAGE to $STAGE for $MA.$MI.$PA"; exit 1
    elif [[ "$SR" -eq "$CR" ]]; then
      NEWNUM=$((10#$CURNUM + 1))  # force base-10: a leading zero would read as octal
    else
      NEWNUM=1
    fi
  else
    [[ -n "$BUMP" ]] || { echo "starting a new pre-release series needs a bump level: release.sh pre $STAGE major|minor|patch"; exit 1; }
    case "$BUMP" in
      major) MA=$((MA+1)); MI=0; PA=0;;
      minor) MI=$((MI+1)); PA=0;;
      patch) PA=$((PA+1));;
    esac
    NEWNUM=1
  fi
  NEW="$MA.$MI.$PA-$STAGE.$NEWNUM"
elif [[ -n "$CURSTAGE" ]]; then
  echo "finalizing pre-release series $CUR -> $MA.$MI.$PA ('$LEVEL' only selects tag-only vs GitHub-release publish behavior below, no further version bump)"
  NEW="$MA.$MI.$PA"
  FINALIZE=1
else
  case "$LEVEL" in
    major) MA=$((MA+1)); MI=0; PA=0;;
    minor) MI=$((MI+1)); PA=0;;
    patch) PA=$((PA+1));;
  esac
  NEW="$MA.$MI.$PA"
fi
TAG="v$NEW"
echo "release: $CUR -> $NEW ($LEVEL${STAGE:+ $STAGE})"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "tag $TAG exists"; exit 1; }

# 1. changelog + version -------------------------------------------------------
run "python3 scripts/changelog.py from-git"
# Promoting a pre-release to its next stage, or finalizing one, can land here
# with nothing new since the last tag (e.g. "ship this exact alpha.2 as
# beta.1"). changelog.py release refuses an empty [Unreleased], which would
# otherwise abort an honest same-code retag over a formatting rule.
if [[ "$LEVEL" == "pre" || "$FINALIZE" -eq 1 ]]; then
  UNRELEASED=$(python3 scripts/changelog.py show unreleased 2>/dev/null | tr -d '[:space:]')
  if [[ -z "$UNRELEASED" ]]; then
    if [[ "$FINALIZE" -eq 1 ]]; then
      run "python3 scripts/changelog.py add Changed 'Promote $CUR to final release'"
    else
      run "python3 scripts/changelog.py add Changed 'Tag $NEW — no changes since $CUR'"
    fi
  fi
fi
run "python3 scripts/changelog.py release '$NEW'"
run "echo '$NEW' > VERSION"
# CLAUDE/project.json carries the version the session digest prints. Left
# unbumped it silently drifts from VERSION and every digest reports the old one.
if [[ -f CLAUDE/project.json ]]; then
  if [[ $DRY -eq 1 ]]; then
    echo "DRY: bump version to $NEW in CLAUDE/project.json"
  else
    python3 -c 'import json,sys
p = "CLAUDE/project.json"; c = json.load(open(p))
c["version"] = sys.argv[1]
json.dump(c, open(p, "w"), indent=2, ensure_ascii=False); open(p, "a").write("\n")' "$NEW"
  fi
fi
for f in pyproject.toml package.json Cargo.toml; do
  [[ -f $f ]] || continue
  if [[ $DRY -eq 1 ]]; then
    echo "DRY: bump version to $NEW in $f"
  else
    python3 -c 'import re,sys
p,v = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r"(^\s*\"?version\"?\s*[:=]\s*\"?)[0-9]+\.[0-9]+\.[0-9]+",
           lambda m: m.group(1)+v, s, count=1, flags=re.M)
open(p,"w").write(s)' "$f" "$NEW"
  fi
done
# stage the version files by name — a release commit holds the version roll and
# nothing else, and `git add -A` here would sweep up untracked-by-design content
STAGEFILES=""
for f in VERSION "$CHLOG" CLAUDE/project.json pyproject.toml package.json Cargo.toml; do
  [[ -f "$f" ]] && STAGEFILES="$STAGEFILES '$f'"
done
run "git add$STAGEFILES"
run "git commit -q -m 'chore(release): $TAG'"

# 2. merge to main + tag -------------------------------------------------------
# Single-trunk (dev_branch == release_branch): there is nothing to merge and
# nothing to back-merge — the release commit is already on the trunk. Merging a
# branch into itself is a no-op, but skipping says so out loud. A pre-release
# never merges to main either — it tags dev in place, final or not.
if [[ "$DEVB" == "$MAINB" ]]; then
  echo "single-trunk ($MAINB is both dev and release) — tagging in place, no merge"
elif [[ "$LEVEL" == "pre" ]]; then
  echo "pre-release: tagging on $DEVB only, no merge to $MAINB"
else
  run "git checkout -q $MAINB"
  run "git merge --no-ff -q $DEVB -m 'release: $TAG'"
fi
NOTES=$(mktemp); python3 scripts/changelog.py show "$NEW" > "$NOTES" 2>/dev/null || echo "$TAG" > "$NOTES"
run "git tag -a '$TAG' --cleanup=whitespace -F '$NOTES'"

# 3. push ----------------------------------------------------------------------
PUSHBR="$MAINB"; [[ "$LEVEL" == "pre" ]] && PUSHBR="$DEVB"
if git remote get-url origin >/dev/null 2>&1; then
  run "git push -q origin $PUSHBR" || echo "!! push of $PUSHBR failed — tag is local; resolve and push manually"
  run "git push -q origin '$TAG'"  || echo "!! push of $TAG failed"
else
  echo "no remote — local tag only"
fi

# 4. back-merge so dev contains the merge commit -------------------------------
if [[ "$LEVEL" != "pre" && "$DEVB" != "$MAINB" ]]; then
  run "git checkout -q $DEVB"
  run "git merge --no-ff -q $MAINB -m 'chore: back-merge $TAG'"
  git remote get-url origin >/dev/null 2>&1 && { run "git push -q origin $DEVB" || echo "!! push of $DEVB failed"; }
fi

# 5. GitHub release -------------------------------------------------------------
# patch = tag only. minor/major = prompt, real GitHub release. pre = prompt
# every time (alpha/beta/rc alike), published with --prerelease.
GH_SKIP=0; GH_PRERELEASE=0
if [[ "$LEVEL" == "pre" ]]; then
  GH_PRERELEASE=1
elif [[ "$LEVEL" == "patch" ]]; then
  GH_SKIP=1
fi
SUFFIX=""; [[ "$GH_PRERELEASE" -eq 1 ]] && SUFFIX=" (prerelease)"

if [[ "$GH_SKIP" -eq 1 ]]; then
  echo "patch → tag only, no GitHub release."
elif [[ $DRY -eq 1 ]]; then
  echo "DRY: would prompt before publishing GitHub release $TAG$SUFFIX (assets: $ASSETS)"
elif ! git remote get-url origin >/dev/null 2>&1; then
  # gh needs a remote to infer the repo; without one it errors out and takes
  # the exit status of an otherwise complete release with it
  echo "no remote → local tag only, GitHub release SKIPPED."
elif ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1; then
  echo "gh unavailable/unauthenticated → tag pushed, GitHub release SKIPPED."
else
  echo
  echo "Ready to publish GitHub release $TAG$SUFFIX with assets: $ASSETS"
  if [[ $YES -eq 0 ]]; then
    read -r -p "Publish publicly now? [y/N] " ans
    [[ "${ans:-n}" =~ ^[Yy]$ ]] || { echo "skipped (tag is pushed; run 'gh release create $TAG ...' later)"; exit 0; }
  fi
  if [[ -f Makefile ]] && grep -qE '^dist:' Makefile; then
    make dist || echo "make dist failed — releasing without assets"
  else
    echo "no dist target — releasing without assets"
  fi
  # only pass asset paths that exist; an unmatched glob must not reach gh
  files=(); shopt -s nullglob
  for pat in $ASSETS; do for f in $pat; do [[ -f "$f" ]] && files+=("$f"); done; done
  shopt -u nullglob
  GHFLAGS=(--verify-tag --title "$TAG" --notes-file "$NOTES")
  [[ "$GH_PRERELEASE" -eq 1 ]] && GHFLAGS+=(--prerelease)
  if [[ ${#files[@]} -gt 0 ]]; then
    gh release create "$TAG" "${GHFLAGS[@]}" "${files[@]}"
  else
    gh release create "$TAG" "${GHFLAGS[@]}"
  fi
  echo "published: $(gh release view "$TAG" --json url -q .url 2>/dev/null || echo "$TAG")"
fi

rm -f "$NOTES"
if [[ "$DEVB" == "$MAINB" ]]; then echo "done: $TAG on $MAINB"
elif [[ "$LEVEL" == "pre" ]]; then echo "done: $TAG on $DEVB (not merged to $MAINB)"
else echo "done: $TAG on $MAINB, back-merged to $DEVB"; fi
