"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                              Plugins for NVIM                               "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:vim_minimal = $VIM_MINIMAL ==# 'true' ? 1 : 0

" Plugins with [vim-plug](https://github.com/junegunn/vim-plug)
call plug#begin(g:vimdir_path . '/plugged')

" Plugins that work everywhere
if !has('nvim')
  Plug 'tpope/vim-sensible'  " nvim's own defaults already cover most of this
endif
Plug 'jlanzarotta/bufexplorer', { 'on': 'BufExplorer' }

Plug 'MikeDacre/tmux-zsh-vim-titles'

" NerdTree — the single dual file-tree answer (nvim-tree.lua dropped)
Plug 'preservim/nerdtree'
if has('nvim')
  " Plug 'j\-hui/fidget.nvim'   " needs MunifTanjim/nui.nvim if re-enabled
  " Plug 'rest-nvim/rest.nvim'  " needs MunifTanjim/nui.nvim if re-enabled
endif
if !has('nvim')
  Plug 'preservim/nerdcommenter'  " nvim 0.10+ has built-in gc commenting
endif

" Extra targets and actions
Plug 'tpope/vim-repeat'    " Select within surrounding with cin<surround>
Plug 'wellle/targets.vim'
if has('nvim')
  Plug 'kylechui/nvim-surround'
else
  Plug 'tpope/vim-surround'  " Change surroundings with cs<surround>
endif

" Linting — the single dual answer, replaces syntastic (archived) and neomake
" (dropped 2026-09-07, see PLUGINS.md)
Plug 'dense-analysis/ale'

if g:vim_minimal == 0
  if !has('nvim')
    Plug 'editorconfig/editorconfig-vim'  " built into nvim since 0.9
  endif
  Plug 'freitass/todo.txt-vim'
  " Plug 'AndrewRadev/linediff.vim'
  " Plug 'tpope/vim-speeddating'  " Increment dates and times
  Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
  Plug 'preservim/tagbar'  " maintained fork of vim-scripts/taglist.vim
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'godlygeek/tabular'  " kept: vim-markdown's table support depends on it
  Plug 'dhruvasagar/vim-table-mode', { 'on': 'TableModeToggle' }
  Plug 'jamessan/vim-gnupg'

  Plug 'mhinz/vim-startify'

  " Languages
  if !has('nvim')
    Plug 'python-mode/python-mode', { 'for': 'python' }  " nvim side: native LSP
  endif
  " Plug 'phelipetls/vim-hugo'

  " JSON
  Plug 'elzr/vim-json'
  " Markdown writing
  Plug 'reedes/vim-pencil'
  " Plug 'junegunn/goyo.vim', { 'on': 'Goyo' }
  Plug 'preservim/vim-markdown', { 'for': 'markdown' }  " plasticboy transferred here
  if has('nvim')
    Plug 'ravibrock/spellwarn.nvim'
    Plug 'epwalsh/obsidian.nvim'
  endif
  Plug 'vimoutliner/vimoutliner'
  Plug 'MikeDacre/vim-checkbox'
  Plug 'vimwiki/vimwiki'

  " Color schemes
  Plug 'lifepillar/vim-solarized8'
endif

" FZF searching — the dual answer
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" NeoVim Only
if has('nvim')
  " Debugging
  Plug 'mfussenegger/nvim-dap'
  " Tree-Sitter — upstream archived 2026-04-03; 'main' is an incompatible
  " rewrite and became GitHub's default branch, so 'master' must stay pinned
  " explicitly or a fresh clone silently grabs the wrong one (bit us 2026-09-07)
  Plug 'nvim-treesitter/nvim-treesitter', {'branch': 'master', 'do': ':TSUpdate'}
  Plug 'ValdezFOmar/tree-sitter-editorconfig'
  Plug 'tree-sitter/tree-sitter-go'
  Plug 'tree-sitter-grammars/tree-sitter-gpg-config'
  Plug 'nvim-treesitter/nvim-treesitter-textobjects'
  Plug 'folke/twilight.nvim'
  Plug 'folke/zen-mode.nvim'

  " NeoVim terminal / REPL — the single code-execution answer (sniprun and
  " code_runner.nvim dropped 2026-09-07, see PLUGINS.md)
  Plug 'hkupty/iron.nvim', { 'do': ':UpdateRemotePlugins' }
endif


if !has('nvim')
  Plug 'wincent/terminus'  " nvim handles cursor shape/focus natively
endif

" Status bar
if has('nvim')
  Plug 'nvim-lualine/lualine.nvim'
else
  Plug 'vim-airline/vim-airline'  " bling/vim-airline is the old redirect
  Plug 'vim-airline/vim-airline-themes'
  " Plug 'edkolev/tmuxline.vim'
endif

" Tmux integration
if has('nvim')
  Plug 'aserowy/tmux.nvim'
  Plug 'nvim-focus/focus.nvim'
else
  " Completion / language intelligence — replaces YouCompleteMe
  Plug 'yegappan/lsp'
  Plug 'tmux-plugins/vim-tmux-focus-events'
  Plug 'benmills/vimux'
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'roxma/vim-tmux-clipboard'
endif

" Go language
Plug 'fatih/vim-go'  " upstream; MikeDacre/vim-go fork had no remaining reason

" Git support
Plug 'tpope/vim-fugitive'
" Git Realtime Info
Plug 'airblade/vim-gitgutter'
" Plug 'itchyny/vim-gitbranch'

if has('nvim')
  Plug 'nvim-tree/nvim-web-devicons'
else
  Plug 'ryanoasis/vim-devicons'  " single icon plugin now (was 4)
endif
" set encoding=UTF-8
" set guifont=DejaVuSansMNFM:h12
" Initialize plugin system
call plug#end()
