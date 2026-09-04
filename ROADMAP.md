# Roadmap

## Now — v0.1.0 (adoption)
- Scaffold the repo as a managed project without touching editor behaviour
- Stand up `PLUGINS.md` as the audit table and backlog
- Generate `doc/mikevim.txt` so `:help mikevim` is the cheatsheet in both editors
- Move `vim-project-config/` to a private subrepo, branch per machine

## Next — v0.2.0 (stop the bleeding)
- Remove ONI (`config.js`) — confirmed dead
- Repoint `MikeDacre/vim-go` to upstream `fatih/vim-go` — fork has no reason left
- P1 rows in `PLUGINS.md`: drop the `system()` call at startup, de-duplicate the
  `nvim-treesitter` declaration, guard `spellwarn.nvim`, remove `fd`/`ripgrep`
  as fake plugins, resolve nerdtree vs nvim-tree
- Pin the plugin set with `:PlugSnapshot` and commit the lockfile
- Set an explicit `mapleader` (currently the unset default `\`) and record the
  decision — a breaking change to muscle memory, so it needs a decision before
  it needs code

## Later — v0.3.0+ (consolidation)
- nvim-treesitter migration off the archived repo onto core treesitter
- Collapse three linting stacks (syntastic + neomake + `linters.vim`) into one
  dual-editor answer
- Collapse the note stack (vimwiki / vimoutliner / riv / obsidian.nvim)
- fzf everywhere rather than telescope-on-nvim — with Vim primary, the dual
  answer wins on principle, not just on taste
- Add `desc` to every mapping as the machine-readable cheatsheet source
- Re-evaluate `vim.pack` if the Vim 9 constraint is ever dropped

## Non-goals
- Migrating to lazy.nvim, LazyVim, or any Neovim-only framework. Vim is the
  primary editor; Neovim-only infrastructure is off the table, not deferred
- Dropping, degrading or "temporarily" breaking the Vim path for any reason
- Rewriting working Vimscript into Lua for its own sake
- Shell entry points: everything Mike runs is inside the editor
- Committing `plugged/` (2.6 GB) or any per-machine state

## Open questions
- Which Neovim macOS GUI, if any, closes the gap with MacVim? That gap is what
  actually gates the migration — not plugins, not Lua
- Is `VIM_MINIMAL` still the right switch for server installs?
- Should `linters.vim` collapse onto ALE, the one linter that serves both editors?
