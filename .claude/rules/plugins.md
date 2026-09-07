---
paths:
  - "plugins.vim"
  - "PLUGINS.md"
  - "lua/plugin_config.lua"
---

# Plugin files: facts that apply whenever these are open

- `plugins.vim` is the live runtimepath on every machine. A bad edit breaks the
  editor everywhere at the next `git pull`. Both editors must start cleanly
  after any change: `bash scripts/check.sh editors`.
- `PLUGINS.md` is the audit table and the backlog; a change to `plugins.vim`
  is proposed as a diff to its row first, and Mike approves the row before code.
- Order of preference: one plugin that serves Vim 9 and Neovim → a built-in →
  an `if has('nvim') / else` pair (last resort; the `else` branch is what
  remote servers run).
- `nvim-treesitter` upstream was archived 2026-04-03; `master` is frozen and
  `main` is an incompatible rewrite. It is declared twice. It is never bumped
  casually; it needs a designed migration.
- `:PlugClean` deletes directories under `plugged/` and is run only with
  explicit approval. `plugged/` (2.6 GB) is never committed.
- The full procedure is the `plugin-audit` skill.
