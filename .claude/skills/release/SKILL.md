---
name: release
description: Cut a release — move [Unreleased] into a versioned CHANGELOG section, commit, and tag vX.Y.Z. Use when Mike says "cut a release", "tag a version", "release 0.2.0".
disable-model-invocation: true
---

# Release

1. The tree must be clean and `bash scripts/check.sh` must pass; `release.sh`
   enforces both and refuses otherwise.
2. `bash scripts/release.sh $ARGUMENTS` — SemVer `x.y.z`, no leading `v`.
3. Pushing the tag and creating a GitHub release are publishing actions.
   Ask before each of:
       git push --follow-tags origin master
       gh release create vX.Y.Z --title vX.Y.Z --notes-from-tag
4. `project.json .release.assets` lists files to attach; it is empty today.
