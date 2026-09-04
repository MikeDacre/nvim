# Plugin audit

Standing backlog for `plugins.vim`. **Goal: one plugin that works in both Vim 9
and Neovim wherever possible**; a `has('nvim')/else` pair is the last resort,
because it doubles the maintenance surface.

`Loads` = where the plugin is actually sourced today.
`Pri` = P1 broken or wasteful now · P2 real win · P3 tidy-up.
Nothing here is actioned. Rows get approved one at a time (see
`CLAUDE/skills/plugin-audit/SKILL.md`).

## Structural issues (not plugins)

| Issue | Detail | Change | Pri |
|---|---|---|---|
| `g:vim_mini` shells out at startup | `system('if [ -n "$VIM_MINIMAL" ]...')` spawns `/bin/sh` on **every** launch, in both editors | `let g:vim_minimal = $VIM_MINIMAL ==# 'true'` — pure vimscript, no fork | P1 |
| `nvim-treesitter` declared twice | Once in the early `has('nvim')` block, again in "NeoVim Only" | Delete one; then handle the archive (below) | P1 |
| `spellwarn.nvim` unguarded | Lua/Neovim-only plugin sourced in the `vim_minimal == 0` block with no `has('nvim')` | Move inside a guard, or drop for a dual speller | P1 |
| `autoload/plug.vim.old` | Stale copy of the plugin manager tracked in the repo | Delete | P3 |
| Completion asymmetry | `YouCompleteMe` sits inside the **tmux** `else` branch; Neovim gets no completion plugin at all | Move out of the tmux block; adopt nvim 0.12 native `'autocomplete'` for nvim, keep a light vim option | P2 |

## Everywhere (vim + nvim) — the shared core

| Plugin | Role | Change | Pri |
|---|---|---|---|
| `tpope/vim-sensible` | sane defaults | Neovim defaults already match most of it; guard to vim-only | P3 |
| `xolox/vim-misc` | library | Dependency of vim-session/vim-easytags, **neither installed** — likely orphaned; verify then drop | P2 |
| `jlanzarotta/bufexplorer` | buffer list | Overlaps telescope/fzf buffer pickers on nvim | P3 |
| `MikeDacre/tmux-zsh-vim-titles` | terminal titles | Yours; keep | — |
| `preservim/nerdtree` | file tree | **Loads on nvim too, alongside `nvim-tree.lua`** — pick one per editor, or keep nerdtree alone as the dual answer | P1 |
| `preservim/nerdcommenter` | commenting | Neovim 0.10+ has built-in `gc` commenting → guard to vim-only | P2 |
| `tpope/vim-repeat` | repeat plugin maps | Keep — dual, tiny | — |
| `wellle/targets.vim` | extra text objects | Overlaps treesitter textobjects on nvim; keep as the dual baseline | P3 |
| `editorconfig/editorconfig-vim` | editorconfig | **Built into Neovim since 0.9** → guard to vim-only | P2 |
| `freitass/todo.txt-vim` | TODO.txt syntax | Keep — dual, and this repo now ships a TODO.txt | — |
| `SirVer/ultisnips` + `honza/vim-snippets` | snippets | Needs `+python3`; dual but heavy. Alternative for later: vim9script/Lua snippet engine per editor | P3 |
| `vim-scripts/taglist.vim` | tag browser | Ancient (vim-scripts mirror). Replace with `preservim/tagbar` (dual) or drop | P2 |
| `nathanaelkane/vim-indent-guides` | indent guides | Neovim has `'listchars'`/treesitter options; keep dual for now | P3 |
| `junegunn/vim-easy-align` | alignment | Overlaps `godlygeek/tabular` — **pick one**, easy-align is the maintained choice | P2 |
| `godlygeek/tabular` | alignment | Redundant with easy-align unless vim-markdown needs it (it does, for tables) — verify before dropping | P2 |
| `dhruvasagar/vim-table-mode` | table editing | Overlaps tabular + vim-markdown tables; lazy-loaded on command already | P3 |
| `jamessan/vim-gnupg` | transparent GPG | Keep — dual, no replacement | — |
| `leafOfTree/vim-project` | project switcher | Overlaps your own `vim-project-config/`; decide which owns project state | P2 |
| `mhinz/vim-startify` | start screen | Keep — dual | — |
| `python-mode/python-mode` | python IDE | Very heavy, largely superseded by LSP; `for: python` limits the cost. Replace with native LSP on nvim + minimal on vim | P2 |
| `maksimr/vim-jsbeautify` | JS formatting | Superseded by prettier/LSP formatters | P3 |
| `othree/html5.vim` | HTML syntax | Mostly in-tree now | P3 |
| `elzr/vim-json` | JSON syntax/conceal | Overlaps `jacinto.vim`; **pick one** | P2 |
| `alfredodeza/jacinto.vim` | JSON tools | Overlaps `vim-json` | P2 |
| `reedes/vim-pencil` | prose mode | Keep — dual | — |
| `plasticboy/vim-markdown` | markdown | Repo is quiet; `preservim/vim-markdown` is the maintained fork — verify and switch | P2 |
| `ravibrock/spellwarn.nvim` | spelling diagnostics | **nvim-only but unguarded** (see structural) | P1 |
| `vimoutliner/vimoutliner` | outliner | Overlaps vimwiki + obsidian.nvim | P2 |
| `MikeDacre/vim-checkbox` | checkboxes | Yours; keep | — |
| `vimwiki/vimwiki` | wiki/notes | Overlaps obsidian.nvim (nvim) and vimoutliner — **the note stack is the biggest consolidation win** | P2 |
| `gu-fan/riv.vim` | reStructuredText | `for: rst`; keep if you still write RST, else drop | P3 |
| `lifepillar/vim-solarized8` | colourscheme | Keep — dual; repo also ships `colors/` | — |
| `junegunn/fzf` + `fzf.vim` | fuzzy find | **The dual answer.** Telescope duplicates it on nvim | P2 |
| `sharkdp/fd` | file finder | **Not a vim plugin** — a Rust binary cloned into `plugged/` and never built. Install via brew; remove the `Plug` line | P1 |
| `BurntSushi/ripgrep` | grep | **Not a vim plugin** — same as above | P1 |
| `wincent/terminus` | cursor shape/focus | Neovim handles most of this natively → guard to vim-only | P3 |
| `MikeDacre/vim-go` | Go support | Your fork — record why it's forked, or return to upstream | P3 |
| `tpope/vim-fugitive` | git | Keep — best-in-class, dual | — |
| `airblade/vim-gitgutter` | git signs | Dual; `gitsigns.nvim` is nicer on nvim but fugitive+gitgutter is the honest dual pair — keep | P3 |

## Neovim only

| Plugin | Role | Change | Pri |
|---|---|---|---|
| `nvim-treesitter` (×2) | parsers/highlight | **Upstream archived 2026-04-03**; `master` frozen, `main` an incompatible rewrite; nvim 0.12 has treesitter in core. Needs a designed migration, not a bump | P1 |
| `nvim-treesitter-refactor` | ts module | Deprecated with the rewrite → remove | P1 |
| `nvim-treesitter-textobjects` | ts textobjects | Standalone on `main` now; re-pin during the migration | P1 |
| `ValdezFOmar/tree-sitter-editorconfig`, `tree-sitter/tree-sitter-go`, `tree-sitter-grammars/tree-sitter-gpg-config` | grammars | Grammars, not plugins — belong to whatever parser manager survives the migration | P2 |
| `michaelb/sniprun` | run snippets | Overlaps `code_runner.nvim` and `iron.nvim` — three ways to execute code | P2 |
| `CRAG666/code_runner.nvim` | run code | See above | P2 |
| `hkupty/iron.nvim` | REPL | See above; iron is the one worth keeping for Python REPL work | P2 |
| `MunifTanjim/nui.nvim` | UI library | Dependency only — confirm something still needs it | P3 |
| `nvim-tree/nvim-tree.lua` | file tree | Duplicate of nerdtree (see above) | P1 |
| `Nedra1998/nvim-mdlink` | markdown links | Overlaps obsidian.nvim | P3 |
| `kylechui/nvim-surround` | surround | Correctly guarded against `vim-surround` — keep | — |
| `GCBallesteros/jupytext.nvim` | notebooks | Keep if you still use it | P3 |
| `epwalsh/obsidian.nvim` | Obsidian vault | Repo was renamed/handed over upstream — verify the source before next update | P2 |
| `neomake/neomake` | linting | vim gets `syntastic`, nvim gets `neomake`, and `linters.vim` configures both. Native LSP diagnostics on nvim + ALE as the dual option would collapse three stacks into one | P2 |
| `mfussenegger/nvim-dap` | debugging | Keep — no dual equivalent | — |
| `folke/twilight.nvim` + `zen-mode.nvim` | focus modes | Overlaps `vim-pencil`/goyo; nvim-only | P3 |
| `vimlab/split-term.vim` | terminal splits | Neovim `:term` + `:split` covers most of it | P3 |
| `ggandor/leap.nvim` | motions | nvim-only; the dual equivalent is `justinmk/vim-sneak` if you want parity | P3 |
| `nvim-lua/plenary.nvim` | library | Telescope dependency | — |
| `nvim-telescope/telescope.nvim` | picker | Duplicates fzf.vim. **Choose: fzf everywhere (dual) or telescope on nvim + fzf on vim** | P2 |
| `nvim-lualine/lualine.nvim` | statusline | Correctly paired against airline — keep | — |
| `aserowy/tmux.nvim`, `nvim-focus/focus.nvim` | tmux/focus | Paired against the vim tmux stack — keep | — |
| `glacambre/firenvim` | browser | Keep if still used; heavy install hook | P3 |
| `nvim-tree/nvim-web-devicons` | icons | Correctly paired — keep | — |

## Vim only

| Plugin | Role | Change | Pri |
|---|---|---|---|
| `scrooloose/syntastic` | linting | Long superseded by ALE; `dense-analysis/ale` works in **both** editors and could replace syntastic + neomake | P2 |
| `Valloric/YouCompleteMe` | completion | Heaviest thing in the config, needs compilation. `vim-lsp`+`asyncomplete` or `ALE` completion is lighter; nvim uses native | P2 |
| `bling/vim-airline` + `vim-airline-themes` | statusline | Note: upstream is `vim-airline/vim-airline`, `bling/` is the old redirect — repoint | P3 |
| `tmux-plugins/vim-tmux`, `vim-tmux-focus-events`, `benmills/vimux`, `christoomey/vim-tmux-navigator`, `roxma/vim-tmux-clipboard` | tmux | `vim-tmux-navigator` works in **both** editors and could replace part of `tmux.nvim` for a single dual answer | P2 |
| `ryanoasis/vim-devicons`, `vwxyutarooo/nerdtree-devicons-syntax`, `lambdalisue/vim-nerdfont`, `lambdalisue/vim-glyph-palette` | icons | Four icon plugins for one job; `vim-devicons` alone usually suffices | P2 |
