# CLAUDE.md — invariant rules

Ships verbatim in every project. Nothing project-specific belongs here; that
lives in `CLAUDE/project.json`. Read once per session, before acting.

## 1. Session protocol
- Start: `bash scripts/session.sh start`. The digest is the read — do not open
  `project.json`, `ROADMAP.md`, `TODO.txt` or `CHANGELOG.txt` to get context.
- End: `bash scripts/session.sh end`. It gates on `check.sh` and pushes.
- Open every session with three lines: branch, uncommitted files, back-fills.

## 2. Repo location
Git-locked, not path-locked. Find the working copy by remote, not by path. Ask
once if it cannot be found. Never scaffold over existing files.

## 3. Approval gates — ask, then wait
Publishing anything public · deleting user files · destructive git (force push,
history rewrite, branch/tag deletion) · merging to trunk · adding a dependency ·
touching `priv/`. Approval is per-action, per-session.

## 4. Ownership
The user edits code, `README.md`, `ROADMAP.md`, `TODO.txt` directly and does
not maintain `CHANGELOG.txt`. If the digest reports unlogged commits, run
`python3 scripts/changelog.py from-git` without asking.

## 5. Edit economy
Four or more edits go in one idempotent script, not many tool calls. Commit as
you go: a session that hits a usage cap must lose nothing.

## 6. Tool failure
If Desktop Commander stops responding: retry once, then ask the user to run
`bash scripts/mcp-fix.sh` and retry. Still hung → say so, drop to read-only
file access, and hand over ONE script that applies the change. Shell-heavy work
belongs in Claude Code.

## 7. Secrets
Never write a secret value outside `priv/`, and never into chat. `priv/` is
gitignored and carries `*.example` templates only.

## 8. Dependencies
Package-manager deps go in the build manifest, pinned. Anything the user must
read or patch goes in `deps/` as a submodule, recorded in `project.json` with
name, url, commit, licence and **why**. Prefer boring and well-maintained.

## 9. Honesty
Never invent a library, version, API or connector. If a search did not confirm
it, say so. Label non-authoritative sources (forums, blogs) as such.

## 10. Generated files
Never hand-edit a generated artefact. Edit its source and regenerate. The
generated/source pairs are listed in `project.json .generated`.

## 11. Connectors
Read `project.json .connectors`. Each entry carries `use` and `fallback`. A
connector that is down must never stall a session — take the fallback.

## 12. Reference documentation
Read `project.json .docs_refs` before reasoning from memory about this stack.
Fetch the URL when the answer must be current.

## 13. Skills
`CLAUDE/skills/<name>/SKILL.md` covers recurring work that has a wrong way to
do it. Consult the matching skill before starting that kind of task.
