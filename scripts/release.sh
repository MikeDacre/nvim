#!/usr/bin/env bash
# release.sh major|minor|patch [--dry-run] [--yes]
#
# SemVer 2.0.0 + Keep a Changelog 1.1.0. Run from dev with a clean tree.
# MINOR/MAJOR additionally publish a GitHub release with assets — that step
# always prompts, because it publishes publicly (CLAUDE.md §3).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

LEVEL="${1:?usage: release.sh major|minor|patch [--dry-run] [--yes]}"; shift || true
DRY=0; YES=0
for a in "$@"; do [[ "$a" == "--dry-run" ]] && DRY=1; [[ "$a" == "--yes" ]] && YES=1; done
run() { if [[ $DRY -eq 1 ]]; then echo "DRY: $*"; else eval "$@"; fi; }

cfg() { bash scripts/cfg.sh "$1" "${2:-}" 2>/dev/null || echo "${2:-}"; }

DEVB=$(cfg git.dev_branch dev)
MAINB=$(cfg git.release_branch main)
ASSETS=$(cfg release.assets "dist/*")

BR=$(git rev-parse --abbrev-ref HEAD)
[[ "$BR" == "$DEVB" ]] || { echo "must be on $DEVB (on $BR)"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree dirty"; exit 1; }
[[ $DRY -eq 1 ]] || bash scripts/check.sh || { echo "check.sh FAILED — fix before releasing"; exit 1; }

CUR=$(cat VERSION 2>/dev/null || echo 0.0.0)
IFS=. read -r MA MI PA <<<"$CUR"
case "$LEVEL" in
  major) MA=$((MA+1)); MI=0; PA=0;;
  minor) MI=$((MI+1)); PA=0;;
  patch) PA=$((PA+1));;
  *) echo "level must be major|minor|patch"; exit 2;;
esac
NEW="$MA.$MI.$PA"; TAG="v$NEW"
echo "release: $CUR -> $NEW ($LEVEL)"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "tag $TAG exists"; exit 1; }

# 1. changelog + version -------------------------------------------------------
run "python3 scripts/changelog.py from-git"
run "python3 scripts/changelog.py release '$NEW'"
run "echo '$NEW' > VERSION"
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
run "git add -A && git commit -q -m 'chore(release): $TAG'"

# 2. merge to main + tag -------------------------------------------------------
run "git checkout -q $MAINB"
run "git merge --no-ff -q $DEVB -m 'release: $TAG'"
NOTES=$(mktemp); python3 scripts/changelog.py show "$NEW" > "$NOTES" 2>/dev/null || echo "$TAG" > "$NOTES"
run "git tag -a '$TAG' --cleanup=whitespace -F '$NOTES'"

# 3. push ----------------------------------------------------------------------
if git remote get-url origin >/dev/null 2>&1; then
  run "git push -q origin $MAINB" || echo "!! push of $MAINB failed — tag is local; resolve and push manually"
  run "git push -q origin '$TAG'"  || echo "!! push of $TAG failed"
else
  echo "no remote — local tag only"
fi

# 4. back-merge so dev contains the merge commit -------------------------------
run "git checkout -q $DEVB"
run "git merge --no-ff -q $MAINB -m 'chore: back-merge $TAG'"
git remote get-url origin >/dev/null 2>&1 && { run "git push -q origin $DEVB" || echo "!! push of $DEVB failed"; }

# 5. GitHub release for MINOR/MAJOR --------------------------------------------
if [[ "$LEVEL" == "patch" ]]; then
  echo "patch → tag only, no GitHub release."
elif [[ $DRY -eq 1 ]]; then
  echo "DRY: would prompt before publishing GitHub release $TAG (assets: $ASSETS)"
elif ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1; then
  echo "gh unavailable/unauthenticated → tag pushed, GitHub release SKIPPED."
else
  echo
  echo "Ready to publish GitHub release $TAG with assets: $ASSETS"
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
  if [[ ${#files[@]} -gt 0 ]]; then
    gh release create "$TAG" --verify-tag --title "$TAG" --notes-file "$NOTES" "${files[@]}"
  else
    gh release create "$TAG" --verify-tag --title "$TAG" --notes-file "$NOTES"
  fi
  echo "published: $(gh release view "$TAG" --json url -q .url 2>/dev/null || echo "$TAG")"
fi

rm -f "$NOTES"
echo "done: $TAG on $MAINB, back-merged to $DEVB"
