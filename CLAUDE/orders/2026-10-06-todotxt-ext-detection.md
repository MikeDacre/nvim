---
id: 2026-10-06-todotxt-ext-detection
status: done
created: 2026-10-06
from: external-claude-code-session
branch: master
updated: 2026-10-07
---
# Goal

Commit the already-made `*.todotxt` filetype-detection change in `init.vim`, and
decide/implement how it should behave under `VIM_MINIMAL`.

## Context

A sibling Claude Code session (working in an unrelated dotfiles worktree, no
git access to this repo) added one line to `init.vim`, just above the
Snakemake block (~line 220):

```vim
" Todo.txt (freitass/todo.txt-vim ftdetect covers todo.txt/done.txt already;
" this adds the *.todotxt extension on top of that)
au BufNewFile,BufRead *.todotxt set filetype=todo
```

Requested behavior: recognize both `todo.txt` and `*.todotxt` with full
syntax highlighting and todo.txt-vim's convenience commands, in both Vim and
Neovim.

`freitass/todo.txt-vim` (`plugins.vim`) already ships its own `ftdetect` for
`[Tt]odo.txt`, `*.[Tt]odo.txt`, `[Dd]one.txt`, `*.[Dd]one.txt` — that part was
untouched. It did not match `*.todotxt` (no dot before "todo"), which is what
the new line fixes.

Verified already (by the sibling session, via `nvim --headless` and `vim`,
non-interactively): a `*.todotxt` buffer gets `filetype=todo` in both editors.
Not verified: minimal-mode behavior (see Open question).

## Open question — resolve before committing

`freitass/todo.txt-vim` only loads `if g:vim_minimal == 0` in `plugins.vim`.
The new `au` line in `init.vim` is unconditional, so in `VIM_MINIMAL=true`
mode a `*.todotxt` buffer gets `filetype=todo` set but the plugin (and its
syntax/commands) never loaded — likely plain-text rendering, silently
inconsistent with the non-minimal case.

Pick one and implement it:
- **Guard the new line** the same way (`if g:vim_minimal == 0`), matching
  todo.txt-vim's own gating — minimal mode gets no todo filetype at all.
- **Leave it unconditional** if minimal mode having bare `filetype=todo` with
  no plugin loaded is acceptable (harmless no-op, just no highlighting).

Either is defensible; this file doesn't make the call. Pick based on how
`g:vim_minimal` is meant to be used elsewhere in this config — check other
`if g:vim_minimal == 0` blocks in `plugins.vim`/`init.vim` for precedent
before deciding.

## Constraints

- Do not edit anything under `plugged/` (vendored by vim-plug; overwritten on
  next `:PlugUpdate`).
- Conventional Commits.
- Approval gates in CLAUDE.md §3 still apply: stop and report rather than
  cross one.

## Done when

- The `*.todotxt` detection line in `init.vim` is committed (amend/rewrite the
  line in place if the minimal-mode decision changes it from what's quoted
  above — it was never committed, so there's nothing to preserve verbatim).
- The `VIM_MINIMAL` question above is resolved one way, consistently, and
  stated in the commit message.
- `bash .claude/scripts/check.sh` exits 0 and the work is committed on the
  current branch.

## Result

Executed from the `worktree-todotxt` worktree (its branch, also named
`worktree-todotxt`, currently points at the same commit as `master`; the order
said `branch: master` but no commit happens directly on `master` per
CLAUDE.md §2 — this branch is the correct place). The line did not exist here:
the sibling session had edited `~/nvim/init.vim` (the main checkout) directly
on disk, outside git, so this worktree's copy never saw it. Re-applied it here
instead of copying bytes, same effect.

**Minimal-mode decision:** guarded. `freitass/todo.txt-vim` itself only loads
`if g:vim_minimal == 0` (`plugins.vim`), and existing plugin-dependent config
in `init.vim` follows the same gating (e.g. the prose block at the old line
254). Added:

```vim
if g:vim_minimal == 0
  au BufNewFile,BufRead *.todotxt set filetype=todo
endif
```

placed after the Python block / before Snakemake, matching the sibling
session's intended location. `g:vim_minimal` is defined by `plugins.vim`,
sourced at `init.vim:14`, well before this point.

**Verified** non-interactively, both editors, both modes (`*.todotxt` buffer):
- default: `filetype=todo` in both vim and nvim
- `VIM_MINIMAL=true`: filetype empty (no plugin loaded) in both

**Unrelated blocker found and fixed first:** the shared `.git/hooks/pre-commit`
shells out to `.claude/scripts/hooks/pre-commit`, which exists on `dev` but not
on this branch (added to the kit after this branch's base commit) — every
commit here was failing with "No such file or directory", regardless of this
order's change. Restored it verbatim from `dev` (no other changes) in its own
commit rather than bypassing the hook. Pre-existing, not caused by this order;
flagging in case other worktrees based on the same pre-kit-update point hit it
too.

**`check.sh`:** still reports one FAIL (`check.local.sh`) — `nvim-treesitter`
E5108, the hazard already documented in the project digest
("nvim-treesitter was archived 2026-04-03 ... needs a designed migration, not
a bump"). Confirmed pre-existing: reproduces identically with `init.vim`
reverted to its committed state, before this order's change. Out of scope
here. The `plugged/` WARNs are just this worktree never having run
`:PlugInstall`.

**Commits** (on `worktree-todotxt`, oldest first):
1. `chore(hooks): restore missing .claude/scripts/hooks/pre-commit`
2. `feat(ftdetect): recognize *.todotxt extension, gated by vim_minimal`

**What Mike should verify**
- Agrees with the minimal-mode call (guarded vs. unconditional) — easy to flip
  if not.
- The sibling session's uncommitted edit still sits in `~/nvim/init.vim` (the
  main checkout) and in `~/nvim/CLAUDE/orders/2026-10-06-todotxt-ext-detection.md`
  (this order file, copied into this worktree to action it) — both untracked
  there. Safe to discard/revert in that checkout now that the real commit
  exists here; I didn't touch that checkout myself (worktree-isolated from
  git ops there).
- Whether `.claude/scripts/hooks/pre-commit` is missing on other active
  branches/worktrees cut from the same pre-kit-update point, and if so whether
  this should be back-merged rather than re-applied per-branch.
- Run `:PlugInstall` here if you want to interact with this worktree's vim/nvim
  normally (unrelated pre-existing gap, not blocking).
