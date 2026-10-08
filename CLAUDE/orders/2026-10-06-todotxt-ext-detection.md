---
id: 2026-10-06-todotxt-ext-detection
status: done
created: 2026-10-06
from: external-claude-code-session
branch: master
updated: 2026-10-08
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

Worked on `dev` (not `master` — that's where the session found the repo; the
order's `branch:` field predates the merge to dev).

Resolved the open question: **guarded**, matching `todo.txt-vim`'s own gate
in `plugins.vim` (`if g:vim_minimal == 0`). Minimal mode now gets no
`filetype=todo` on `*.todotxt` at all, consistent with the plugin not being
loaded there.

Verified non-interactively in both editors, both modes, via `redir`-captured
`&filetype`:
- `nvim --headless` default → `todo`; `VIM_MINIMAL=true` → empty.
- `vim -N -u init.vim -es` default → `todo`; `VIM_MINIMAL=true` → empty.

Committed as `863f1bb` (`feat(filetypes): gate *.todotxt detection behind
VIM_MINIMAL`). `check.sh` passes (only pre-existing WARNs: public remote,
empty `layout.mirrors`, missing `fd`/`rg` — none related to this change).

Nothing remains; nothing for Mike to verify beyond the normal "does
`*.todotxt` highlight as expected" smoke test next time he opens one.
