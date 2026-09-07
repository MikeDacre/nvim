---
name: docs-regen
description: Regenerate doc/mikevim.txt and doc/tags from README.md with panvimdoc, so `:help mikevim` is the in-editor cheatsheet in both Vim and Neovim. Use when Mike says "update the cheatsheet", "regenerate the help", "the help is stale", "I can't remember my keymaps", or after any edit to README.md. Trigger before hand-editing anything under doc/, because doc/mikevim.txt is generated and hand edits are silently destroyed on the next build.
---

# Docs regeneration

## The contract
`README.md` is the source. `doc/mikevim.txt` and `doc/tags` are generated and
committed. Recall works in Vim 9 and Neovim alike because both read vimdoc.

## Regenerate
    make doc

Which runs `deps/panvimdoc/panvimdoc.sh` (pandoc required) then `:helptags doc/`.
The generated file is committed so a fresh clone on a server needs no pandoc.

## Rules
- Never hand-edit `doc/mikevim.txt` or `doc/tags`. Edit `README.md`, rerun.
- Keymap and workflow sections in `README.md` are the cheatsheet. When a mapping
  changes in `init.vim` or `functions.vim`, update the README table in the same
  commit — a mapping that is not in the README does not exist as far as recall
  is concerned.
- `scripts/check.sh` fails if `README.md` is newer than `doc/mikevim.txt`.
  That failure means "run make doc", not "edit the txt".
- Heading levels drive the help tags. Keep `## Section` for top-level topics so
  tags stay stable; renaming a heading breaks any `:help` tag Mike has memorised.
- If pandoc is missing, say so and stop. Do not fake the output.
