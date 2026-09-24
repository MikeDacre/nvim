# CLAUDE.md

Behaviour rules, identical in every project built from this kit. Facts live in
`CLAUDE/project.json`, the type's rules in `CLAUDE/TYPE.md`; nothing here is
edited per project.

## 0. Session protocol
```
bash .claude/scripts/session.sh start      # digest: facts, rules, git, drift, todos, roadmap
<work>
bash .claude/scripts/session.sh end "msg"  # commit, changelog, docs, gate, push
```
The digest replaces reading project.json, ROADMAP.md, TODO.txt and
CHANGELOG.txt — open them only to edit them. In Claude Code the SessionStart
hook has already injected it: do not run `start` again; `/ctx` refreshes it
offline. UNLOGGED commits in the digest → `python3
.claude/scripts/changelog.py from-git`, review the diff, don't ask.

`git.session_worktrees` true (code projects): when `start` says you are not
on a feature branch, ask what to work on, run `bash
.claude/scripts/feature.sh new <slug>`, and treat the worktree path it prints
as the project root for the rest of the session (cd there; absolute paths for
edits).

## 0b. Surfaces and layout
**Claude Project (chat)** — scoping, research, review; its settings box holds
`CLAUDE/project-instructions.txt`; its shell (Desktop Commander) can hang
(§12). **Claude Code** — the execution surface: `.claude/settings.json` holds
the digest hook and the permission lists that mirror §3;
`.claude/skills/<name>/SKILL.md` is `/<name>` (`/end`, `/ctx`, `/release`
everywhere); `.claude/rules/*.md` with `paths:` loads on read of matching
files only.

Kit machinery is `.claude/`: `.claude/scripts` (verbatim kit scripts; a root
`scripts` symlink when that name is free) and `.claude/Makefile`
(`make -f .claude/Makefile <target>`; no root Makefile). Never rewrite a kit
script per project — note the gap in the kit's TODO; `bash
<kit>/scripts/adopt.sh --update` refreshes them and runs migrations
(`--dry-run` first). Anything you generate goes under `CLAUDE/data/` or
`CLAUDE/reports/`, never the user's own tree.

## 0c. Types
`type` picks the rulebook `CLAUDE/TYPE.md` (kit-owned, refreshed by
`--update`); its `## Always` block prints in every digest, and the whole file
is read once per session before touching content. Types: code · writing ·
website · config · administrative · knowledge-base · workspace · other;
`subtype` is the shape within one. A type may relax §4–§6 and add rules;
never §3, §8 or §10. Where they differ, TYPE.md wins. `git.vcs: none` means
no repository at the root (a synced vault): digest, check, todo and backup
still run; feature, sync and release stand down; `CLAUDE/` is a repo either
way.

## 1. Facts
`CLAUDE/project.json` is the single source of truth (name, type, entrypoint,
branches, remotes, build, paths, deps, connectors, skills, refs, secret key
names, `rules`, `hazards`). The digest prints `rules` and `hazards`; obey
them. `bash .claude/scripts/cfg.sh <dotted.key>` reads one value. A fact
changes → edit that file, never restate it in prose. `CLAUDE/legacy/` is an
unfinished adoption, not current rules. `claude_repo.mode`: `tracked`
(CLAUDE/ in the main repo) or `subrepo` (its own repo, gitignored by the
parent; sync.sh does the second push).

## 2. Git
`main` releases only; `dev` integration; `feat/`, `fix/`, `hotfix/<slug>` one
change each (an adopted repo may record another release branch). Before a
new feature: `feature.sh status`, then `feature.sh new <slug>`. On a feature
branch with unmerged work and asked for a *different* feature → stop and
ask; never `--force` without an answer. Merge `--no-ff` always
(`feature.sh finish`, from the main checkout when worktrees are on; ask
before removing the worktree or deleting the branch). `feature.sh merge-dev`
catches a branch up when the digest says dev moved — never rebase. `ideas`
is a persistent notes branch (`feature.sh ideas` / `ideas-merge`), never
finished.

Commit at each coherent unit without asking, Conventional Commits
(`feat|fix|docs|style|refactor|perf|test|build|ci|chore(scope): imperative`;
feat→MINOR, fix/perf→PATCH, `!`→MAJOR) — the changelog is drafted from the
subjects. Push per `git.push_branches` (`sync.sh auto`). Never force-push; a
diverged remote is stop-and-report.

## 3. Approval gates
Free: read, branch, commit, push feature/dev, create files, tests, docs.
**Ask first:** deleting or overwriting user-authored files · destructive git
(reset --hard, force push, history rewrite, deleting unmerged branches,
removing submodules) · merging to the release branch or cutting a release ·
publishing anything public (gh release, public repo, deploy, package push) ·
adding a runtime dependency · editing `project.yaml` · writing outside the
repo root. One approval never covers the next. The deny list enforces the
destructive-git and project.yaml gates mechanically; the rest are yours.

## 4. Release
SemVer; `VERSION` is authoritative. `bash .claude/scripts/release.sh
major|minor|patch` from a clean dev: check.sh gate, changelog roll, bump,
`--no-ff` merge to the release branch, tag, push, back-merge; minor/major
then prompt before a GitHub release. `release.sh pre alpha|beta|rc [bump]`
tags a pre-release on dev only. `--dry-run` is safe.

## 5. The four documents
`CHANGELOG.txt` — yours: Keep a Changelog; every user-visible change the same
session via `changelog.py add <Cat> "..."` or `from-git`; never edit a
released section. `ROADMAP.md` — the user's intent: move shipped items to
Done with their version; propose, never reword or delete. `TODO.txt` — the
user's, todo.txt format via `todo.py`: add on request, mark done, flag
stale; never reword, reprioritise or delete (`rm` needs approval).
`README.md` — shared, human-facing; update when behaviour changes.
Milestone → ROADMAP, task → TODO, shipped change → CHANGELOG.

## 6. Code
Modular where it earns its keep; a >400-line file or >50-line function is a
refactor signal. Public API gets types and a docstring; the entrypoint parses
args and delegates. Errors raise, never swallow. New feature → new test in
`tests/`. `build.lint` is authoritative. Config from file/env; paths resolved
from the repo root, never hardcoded.

## 7. Dependencies
Before >50 lines of general-purpose code, search; present 2–3 candidates
(maintenance, licence, glue cost) and let the user choose. Never silently
add a dep or reimplement a known one. Packages → the manifest, pinned.
Source to read or patch → `git submodule add <https-url> deps/<name>`
(https, never SSH), recorded in `project.json:deps` with licence and why.

## 8. Secrets
`project.yaml` at the root — this machine's, gitignored, the user's.
`project.yaml.example` is tracked: every key, values blank. A value is
literal or `1pw <reference>` (resolved from 1Password at read time);
`bash .claude/scripts/ycfg.sh keys.<NAME>` reads one. Never print a value
into chat, a log, a commit or the changelog — names only. New secret → its
name in the example, same commit as the code reading it. `secrets-init.sh`
provisions a clone. A committed secret: rotate first, then report.

## 9. Docs stay current
`session.sh end` commits, back-fills the changelog, regenerates `build.man`
and `build.generated` artefacts, gates on check.sh, pushes. Never hand-edit a
generated artefact. A rule, path, tool, dependency or connector changed →
update project.json the same session.

## 10. When something goes wrong
Stop. No silent fixes. Report what you did, what broke, files touched,
branch, last good hash. Recovery least-destructive first (restore → revert →
branch from an old hash); never reset --hard or force-push without approval.

## 11. Cost discipline
1–3 small edits → edit directly. 4+ edits, several files, or anything you
would redo after a hang → one idempotent script, run once: it stages only
what it touched, commits each unit, prints what changed, ends with check.sh;
saved as `CLAUDE/patches/<date>-<slug>.sh` and committed when useful. Commit
early and often.

## 12. Shell hung (Desktop Commander)
Retry once. Still hung → ask the user to run
`bash .claude/scripts/mcp-fix.sh` (you cannot; suggest Claude Code instead),
then retry once. Still hung → say "degraded mode" and keep working: read via
the Filesystem MCP or context, write the complete change, test it in a
sandbox clone when the repo is public, and deliver one script the user runs —
never a list of manual edits — saying what you could not verify. Never end a
session with uncommitted intent.

## 13. Verify
`bash .claude/scripts/check.sh` — placeholders, syntax, changelog/VERSION,
layout, type, secrets, submodules, generated-file staleness, digest size,
then the project-owned `check.local.sh`. It gates `end` and `release`; WARNs
never fail it but each is a lead. `doctor.sh` — toolchain present and
authenticated.
