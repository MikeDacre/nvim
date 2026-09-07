---
name: release
description: Cut a release — bump VERSION, roll [Unreleased] into a version, merge dev to the release branch with --no-ff, tag, back-merge. Use when Mike says "cut a release", "tag a version", "release minor/patch/major".
disable-model-invocation: true
---

# Release

1. Must be on `dev` with a clean tree; `release.sh` runs `check.sh` and refuses
   on a FAIL. Preview first: `bash scripts/release.sh $ARGUMENTS --dry-run`.
2. Merging to the release branch, pushing the tag, and `gh release create` are
   approval gates (CLAUDE.md §3). Ask, then run
   `bash scripts/release.sh $ARGUMENTS` (major|minor|patch). It prompts before
   publishing a GitHub release; never pass `--yes` on Mike's behalf.
3. `project.json .release.assets` lists the files it attaches.
