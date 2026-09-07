---
name: plugin-audit
description: Audit, cull or replace plugins in plugins.vim while keeping Vim 9 and Neovim both working. Use when Mike says "cull the plugins", "plugin bloat", "do I still need X", "can vim and nvim share this", "replace X with something that works in both", or when a plugin's upstream has been archived or rewritten. Trigger before editing plugins.vim at all, because the checkout is the live runtimepath on every machine and a bad edit breaks the editor everywhere at next pull.
---

# Plugin audit

## Ground rule
`plugins.vim` is not a wishlist, it is the runtimepath of a live editor on every
machine. Every change must leave **both** editors starting cleanly.

## Order of preference
1. One plugin that works in Vim 9 **and** Neovim → put it in the unguarded block.
2. A built-in that removes the plugin entirely (prefer the built-in even if it
   only covers one editor; guard the plugin for the other).
3. Two plugins behind `if has('nvim') / else` → last resort, doubles maintenance.

## Procedure
1. Read `PLUGINS.md`. It is the standing audit table; the `Change` column is the
   backlog. Never start from scratch.
2. Verify upstream before proposing anything: last release, last commit, archived
   flag. `gh api repos/<owner>/<repo> --jq '.archived, .pushed_at, .license.spdx_id'`.
   An archived repo is a removal candidate, not an update candidate.
3. Check whether Neovim core now ships it (`:h news`, `:h vim.pack`, editorconfig,
   comment, treesitter, autocomplete are all core as of 0.12).
4. Propose as a diff to `PLUGINS.md` first, then to `plugins.vim`. Mike approves
   the table row before the code changes.
5. Apply, then verify BOTH editors before committing:
   - `vim  -es -u init.vim -c 'q' ; echo $?`
   - `nvim --headless -u init.vim -c 'q' ; echo $?`
   - `nvim --headless -c 'PlugClean!' -c 'q'` only after explicit approval —
     it deletes directories under `plugged/`.
6. Update the row's `Status` and log it: `python3 scripts/changelog.py from-git`.

## Never
- Never run `:PlugClean` without approval; it is a file deletion.
- Never commit `plugged/`.
- Never remove the `else` branch of a `has('nvim')` guard without checking what
  Vim 9 falls back to — that branch is what remote servers actually run.
- Never bump `nvim-treesitter`: upstream is archived and `main` is an
  incompatible rewrite. It needs a designed migration, not an update.
