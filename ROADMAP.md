# Roadmap

## Now — v0.1.0 (adoption)
- Scaffold the repo as a managed project without touching editor behaviour
- Stand up `PLUGINS.md` as the audit table and backlog
- Generate `doc/mikevim.txt` so `:help mikevim` is the cheatsheet in both editors
- Move `vim-project-config/` to a private subrepo, branch per machine

## Next — v0.2.0 (stop the bleeding)
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
- Decide fzf-everywhere vs telescope-on-nvim
- Add `desc` to every mapping as the machine-readable cheatsheet source
- Re-evaluate `vim.pack` if the Vim 9 constraint is ever dropped

## Non-goals
- Migrating to lazy.nvim, LazyVim, or any Neovim-only framework while Vim 9
  support is required
- Rewriting working Vimscript into Lua for its own sake
- Shell entry points: everything Mike runs is inside the editor
- Committing `plugged/` (2.6 GB) or any per-machine state

## Open questions
- Does ONI (`config.js`) still matter, or is it dead weight from 2018?
- Is `MikeDacre/vim-go` forked for a reason that still holds?
- Which machines beyond `rincewind` are in play, and do any run Vim 9 only?
