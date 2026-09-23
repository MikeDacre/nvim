# CLAUDE.md

Behaviour rules. **Invariant — identical in every project built from this kit.**
All project-specific facts live in `CLAUDE/project.json`; nothing here needs
editing per project. Specs live in the files that use them, not here.

## 0. Session protocol
```
bash scripts/session.sh start      # digest: facts, rules, git, drift, todos, roadmap
<work>
bash scripts/session.sh end "msg"  # commit, changelog, docs, gate, push
```
`start` prints everything you need to begin. **Do not open project.json,
ROADMAP.md, TODO.txt, or CHANGELOG.txt unless the digest says something is
missing or you are about to edit them** — the digest is the read. In Claude
Code the SessionStart hook has already injected it: do not run `start` again;
`bash scripts/session.sh ctx` (or `/ctx`) refreshes it without network.

If the digest reports UNLOGGED commits, the user changed things outside Claude:
`python3 scripts/changelog.py from-git` writes the entries; review the diff it
made. Don't ask.

When `git.session_worktrees` is true (`CLAUDE/project.json`), `start` also
reports whether the current branch is a feature/fix/hotfix branch. If it is
not, this is a brand-new chat: ask the user what to work on, then run
`bash scripts/feature.sh new <slug>`. It creates the branch AND its own git
worktree — a directory the rest of the repo never touches — and prints the
path. Treat that path as this chat's project root for the rest of the
session: `cd` there before any further shell command, and read/write/edit
under it, not the original checkout.

## 0b. Two surfaces, one rulebook
- **Claude Project (chat)** — scoping, research, review, anything needing the
  web or connectors. Its settings box holds `CLAUDE/project-instructions.txt`.
  Its shell is Desktop Commander, which can hang (§12).
- **Claude Code** — the execution surface. Runs in the repo, reads this file
  automatically, and has a real shell. `.claude/settings.json` (tracked) holds
  its SessionStart digest hook and a permission allow/deny list that mirrors
  §3; per-machine overrides go in `.claude/settings.local.json` (ignored).
  Project skills live in `.claude/skills/<name>/SKILL.md` and are invoked as
  `/<name>` (`CLAUDE/skills` is a symlink to the same directory). `/end`,
  `/ctx` and `/release` ship with every project. `.claude/rules/*.md` with a
  `paths:` list holds rules that load only when matching files are read.

Both obey this file; it is the only rulebook. Normal arc: initialise and plan
in the Project, hand off to Claude Code to build, return to the Project for
review and research. If the Project's shell is hung and the work is
shell-heavy, say so and recommend moving to Claude Code rather than stalling.

Kit machinery lives in `.claude/`: `.claude/scripts` (a verbatim copy of the
kit's scripts; the root `scripts` is a symlink to it, so every command in this
file works unchanged) and `.claude/Makefile` (no root Makefile — run it as
`make -f .claude/Makefile <target>`; each target wraps a script).
Never rewrite a kit script per project: if it does not fit, use it as-is and
note the gap in the kit's TODO. `bash <kit>/scripts/adopt.sh --update`
refreshes them from a newer kit and runs any schema migrations; `--dry-run`
shows what it would change first. `project.yaml` (§8) carries the kit's
upgrade policy, and `start` reports a newer kit release when one is out.
`CLAUDE/data/` and `CLAUDE/reports/` are where anything you generate lands —
never the user's own tree.

## 0c. Types
`type` in `CLAUDE/project.json` is this project's **type**, chosen at
initialisation and rarely changed. `subtype` records the shape within it
(`tool`, `environment`, `notes`, ...); some types have none.

| type | what it is |
|---|---|
| `code` | software: built, tested, released like software |
| `writing` | the user's prose is the product; edits need naming and a backup |
| `website` | content, layout code and deploy config in one tree |
| `config` | machine and service configuration; the tree mirrors a live system |
| `administrative` | running a life or a business: finance, legal, planning |
| `knowledge-base` | a research corpus of papers, notes and manuscripts |
| `workspace` | a super-repo organising other projects |
| `other` | a loosely-governed working folder, connector-heavy |

`CLAUDE/TYPE.md` is that type's rulebook — kit-owned, shipped verbatim like
this file, refreshed by `adopt.sh --update`. Its `## Always` block prints in
every session digest; read the whole file once per session before touching
content. A type may relax §4, §5 and §6 and may add rules of its own; it can
never relax §3 (approval gates), §8 (secrets) or §10 (stop and report). On
anything else, `CLAUDE/TYPE.md` wins — it is the more specific statement.

Not every project root is a git repository: `git.vcs` is `git` or `none`.
Under `none` (a synced vault, a folder inside someone else's tree) the digest,
`check.sh`, `todo.py` and `backup.sh` still run, while `feature.sh`,
`sync.sh` and `release.sh` say there is nothing for them to do. `CLAUDE/` is
a repo either way, so notes and rules are always versioned.

## 1. Facts
`CLAUDE/project.json` is the single source of truth for: name, type, language,
entrypoint, branches, sync mode, remotes, build commands, generated files,
paths, dependencies, connectors, skills, reference docs, secret keys, `rules`
— project-specific rules with no other home ("never edit generated/") — and
`hazards`, things that bite. The digest prints both; obey them alongside this
file. A `CLAUDE/legacy/` directory means this project was adopted and its old
docs are not yet merged (see adopt.md) — do not treat them as current rules.
Read one value with `bash scripts/cfg.sh <dotted.key>`. If a fact changes,
edit that file — never restate it in prose.

`CLAUDE/` holds this file, project.json and the skills symlink. Its layout is
`claude_repo.mode`: **tracked** (an ordinary directory in the main repo — it
commits and pushes with everything else) or **subrepo** (its own git repo with
its own remote, gitignored by the parent — used to keep notes private inside a
public repo, and it needs a second push, which `sync.sh` handles).

## 2. Git
`main` = releases only, never commit directly. `dev` = integration.
`feat/<slug>` = one feature. `fix/`, `hotfix/` likewise. An adopted repo may
record a different release branch in `git.release_branch`; the rule is the same.

Before a new feature: `bash scripts/feature.sh status`.
- Clean, or on dev/main -> `bash scripts/feature.sh new <slug>`. Proceed silently.
- On a feature branch with unmerged work and the user asks for a *different*
  feature -> **stop and ask**: continue here, or branch anew? The script blocks
  you; do not use `--force` without an answer.
- Merge with `--no-ff`, always. `feature.sh finish` merges to dev.

With `git.session_worktrees` true, `feature.sh new <slug>` creates the
worktree described in §0 instead of switching the current checkout, so
concurrent chats never collide over one directory. `finish` still merges to
dev and must run from the main checkout, not from inside a session's own
worktree — it refuses and says so otherwise. After a successful merge, ask
before removing the worktree (`git worktree remove <path>`), same as asking
before deleting the branch. `feature.sh status` (in every digest) also flags
when `dev` has advanced past the current branch; ask the user, then
`feature.sh merge-dev` catches it up — still `--no-ff`, never rebase.

With `git.session_worktrees` true, a single persistent `ideas` branch exists
per project for notes and cross-cutting ideas that do not belong to any one
feature. `feature.sh ideas` creates or re-attaches its worktree the same way
`new` does, but with no slug and no prefix. Commit to it freely and merge it
into `dev` often with `feature.sh ideas-merge` (still `--no-ff`, run from the
main checkout) — unlike `finish`, the branch and worktree are never deleted,
so the next chat that runs `feature.sh ideas` picks up where the last one
left off.

Commits are automatic — no approval needed, commit at each coherent unit.
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):
`feat|fix|docs|style|refactor|perf|test|build|ci|chore(scope): imperative`.
`feat`->MINOR, `fix`/`perf`->PATCH, `!` or `BREAKING CHANGE:`->MAJOR. The
changelog is drafted from these subjects, so write them for a reader.

Push per `git.push_branches` in project.json; `scripts/sync.sh auto` handles it.
Never force-push. A diverged remote is a **stop and report**, never a force fix.

## 3. Approval gates
Free: read, branch, commit, push to feature/dev, create files, run tests, docs.

**Ask first:** deleting or overwriting user-authored files - destructive git
(`reset --hard`, force push, history rewrite, deleting unmerged branches,
removing submodules) - merging to the release branch or cutting a release -
**publishing anything public** (`gh release create`, public repo, deploy,
package push) - adding a runtime dependency - editing `project.yaml` -
writing outside the repo root. Approval for one action never covers the next.
The Claude Code deny list enforces the destructive-git and `project.yaml`
gates mechanically; the rest are yours to keep.

## 4. Release
[SemVer 2.0.0](https://semver.org/spec/v2.0.0.html); `VERSION` is authoritative.
`bash scripts/release.sh {major|minor|patch}` from a clean `dev` does everything:
check.sh gate, changelog back-fill and roll, version bump, `--no-ff` merge to
the release branch, annotated tag, push, back-merge. Minor/major then prompt
before publishing a GitHub release with the assets named in `release.assets`.
Patch = tag only. `--dry-run` is safe and non-interactive.

## 5. The four documents
| File | Owner | Your role |
|---|---|---|
| `CHANGELOG.txt` | you | Keep a Changelog 1.1.0. Every user-visible change, same session, via `scripts/changelog.py add <Cat> "..."` or `from-git`. Never edit a released section. The user does not maintain this. |
| `ROADMAP.md` | user | Intent. Move shipped items to Done with their version. Propose, never reword or delete. |
| `TODO.txt` | user | todo.txt format (legend is in the file). Use `scripts/todo.py`. Add on request, mark what you finished, flag overdue/stale. Never reword, reprioritise, or delete. `rm` needs explicit approval. |
| `README.md` | shared | Human-facing; the man page is generated from it. Update when behaviour changes. |

Milestone -> ROADMAP. Task -> TODO. Shipped behaviour change -> CHANGELOG. They
are not substitutes.

## 6. Code
Modular where it earns its keep: one class per file, cohesive modules, file
named for its main export. >400-line file or >50-line function = refactor
signal, not a rule. Public API gets types + docstring; entrypoint parses args
and delegates. Errors raise, never swallow. New feature => new test in `tests/`.
Formatter/linter is authoritative — `build.lint` in project.json. Config from
file/env; paths resolved from the repo root at runtime, never hardcoded.

## 7. Dependencies — reuse before rebuild
Before writing >50 lines of general-purpose code, search for a library, then
**present 2-3 candidates with maintenance status, licence and glue-code cost
and let the user choose**. Never silently add a dep or silently reimplement a
known one. Package deps -> build manifest, pinned. Source you must read or patch
-> `git submodule add <https-url> deps/<name>`, recorded in `project.json:deps`
with its licence and *why*. Submodule URLs are https, never SSH: a public
repo must clone on a machine with no GitHub key.

## 8. Secrets
Everything secret lives in `project.yaml` at the repo root — this machine's
copy, gitignored, the user's to edit. `project.yaml.example` is tracked and is
the contract: every key present, every value blank. A value is literal, or
`1pw <reference>` resolved from 1Password at read time; read one with
`bash scripts/ycfg.sh keys.<NAME>`. Never print a secret value into chat, a
log, a commit, or the changelog — key names only. New secret => add its NAME
to `project.yaml.example` in the same commit as the code reading it; the value
goes in `project.yaml` only. `bash scripts/secrets-init.sh` provisions a fresh clone. A
committed secret is a stop-and-report: rotate first.

## 9. Every session ends with documentation current
`session.sh end "msg"` commits, back-fills the changelog, regenerates the man
page (if `build.man` is set) and any `build.generated` artefact, gates on
`check.sh`, and pushes. Never
hand-edit a generated artefact: edit its source and regenerate. If a rule, path,
tool, dependency, or connector changed, update `CLAUDE/project.json` too. Docs
drift is a bug, fixed in the session it appears.

## 10. When something goes wrong
Stop. No silent fixes. Report what you did, what broke, files touched, current
branch, last good hash. Offer recovery least-destructive first
(`restore` -> `revert` -> branch from an old hash). Never `reset --hard` or force
push to recover without approval.

## 11. Cost discipline — prefer one script over many edits
Every tool call costs credits and wall-clock. A long session that hits a usage
cap or hangs mid-flow loses everything not yet committed, so the cheapest edit
is the one that survives an interruption.

- **1-3 small edits in one or two files** -> edit directly. A script costs more
  than it saves.
- **4+ edits, or edits spanning several files, or anything you would have to
  redo after a hang** -> write ONE idempotent script and run it in a single
  call. Cheaper, atomic, and re-runnable.
- **Degraded mode (§12)** -> the script is not an optimisation, it is the
  deliverable.

Script rules: idempotent; stages only the paths it touched and commits each
coherent unit as it goes (a re-run then commits nothing); prints what it
changed; ends by running `scripts/check.sh`. Write it to
`CLAUDE/patches/<YYYY-MM-DD>-<slug>.sh` when you have a shell; hand it over as
a file when you do not. Commit useful ones — a patch script is a record of
what changed and why.

Also: commit early and often. An interrupted session with three commits behind
it has lost nothing; one with a large uncommitted edit has lost everything.

## 12. When the shell hangs — degraded mode
Desktop Commander can stop responding: the call returns nothing and times out
after minutes. Do not retry blindly and do not spend the session waiting.

1. **Retry once.** A single failure can be transient.
2. **Still hung** -> ask the user to run `bash scripts/mcp-fix.sh`. It kills the
   MCP server process chain so the client respawns it on the next call. You
   cannot run it yourself — running it needs the tool that is hung. If they are
   in Claude Code, that surface is unaffected; suggest continuing there.
3. **Retry once** after they confirm.
4. **Still hung -> DEGRADED MODE.** Say so in one line, then keep working:
   - Read via the Filesystem MCP (read-only) or from what is already in
     context; ask for a paste only for what you truly lack.
   - Do the full reasoning and write the complete change.
   - **Test it for real where you can:** if the repo is public, clone it in
     your own sandbox, run the script there, verify, then hand over the tested
     script as a downloadable file. A sandbox test beats an untested patch.
   - Verify internally what you cannot run: consistency with `project.json`,
     this file's conventions, and by re-reading anything you can read.
   - Deliver as **one script the user runs** (§11). Never hand over a list of
     manual edits.
   - State plainly what you could not verify without the user's machine.
5. **Never end a session with uncommitted intent.** Either the change is
   applied, or the user is holding a script that applies it.

## 13. Verify
`bash scripts/check.sh` — placeholders, script and JSON syntax, changelog and
VERSION agreement, symlink and skills layout, type agreement (`type` vs
`CLAUDE/TYPE.md`), secrets (`project.yaml` ignored, no value in the example), submodules,
generated-file staleness (git-based), then `scripts/check.local.sh` if the
project has one — that file is project-owned and is where domain checks live
(an editor config loads its own init file, a site builds). It gates
`session.sh end` and `release.sh`; run it whenever something feels off. WARN lines never fail it,
but each one is a lead.
`bash scripts/doctor.sh` — is the toolchain present and authenticated.
