"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                              Plugins for NVIM                               "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:vim_mini = system('if [ -n "$VIM_MINIMAL" ] && $VIM_MINIMAL; then echo true; else echo false; fi')
if g:vim_mini == 'true'
  let g:vim_minimal = 1
else
  let g:vim_minimal = 0
endif

" Plugins with [vim-plug](https://github.com/junegunn/vim-plug)
call plug#begin(g:vimdir_path . '/plugged')

" Plugins that work everywhere
Plug 'tpope/vim-sensible'
Plug 'xolox/vim-misc'
Plug 'jlanzarotta/bufexplorer', { 'on': 'BufExplorer' }

Plug 'MikeDacre/tmux-zsh-vim-titles'

" NerdTree
if has('nvim')
  Plug 'michaelb/sniprun'
  Plug 'MunifTanjim/nui.nvim'
  Plug 'rest-nvim/rest.nvim'
else
  Plug 'preservim/nerdtree'
endif
Plug 'preservim/nerdcommenter'

" Extra targets and actions
Plug 'tpope/vim-repeat'    " Select within surrounding with cin<surround>
Plug 'wellle/targets.vim'
if has('nvim')
  Plug 'kylechui/nvim-surround'
else
  Plug 'tpope/vim-surround'  " Change surroundings with cs<surround>
endif


if g:vim_minimal == 0
  Plug 'editorconfig/editorconfig-vim'
  Plug 'freitass/todo.txt-vim'
  " Plug 'AndrewRadev/linediff.vim'
  " Plug 'tpope/vim-speeddating'  " Increment dates and times
  Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
  Plug 'vim-scripts/taglist.vim'
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'junegunn/vim-easy-align'
  Plug 'godlygeek/tabular'
  Plug 'dhruvasagar/vim-table-mode', { 'on': 'TableModeToggle' }
  Plug 'jamessan/vim-gnupg'

  " Projects
  Plug 'leafOfTree/vim-project'

  Plug 'mhinz/vim-startify'

  " Languages
  if has('nvim')
    Plug 'GCBallesteros/jupytext.nvim'
  endif
  Plug 'python-mode/python-mode' , { 'for': 'python' }
  Plug 'phelipetls/vim-hugo'
  Plug 'maksimr/vim-jsbeautify'
  Plug 'othree/html5.vim'

  " Markdown writing
  " Plug 'reedes/vim-pencil'
  " Plug 'junegunn/goyo.vim', { 'on': 'Goyo' }
  " Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
  Plug 'ravibrock/spellwarn.nvim'
  if has('nvim')
    Plug 'epwalsh/obsidian.nvim'
  endif
  Plug 'vimoutliner/vimoutliner'
  Plug 'MikeDacre/vim-checkbox'
  Plug 'vimwiki/vimwiki'

  " RST
  Plug 'gu-fan/riv.vim', { 'for': 'rst' }

  " Color schemes
  Plug 'lifepillar/vim-solarized8'
endif

" FZF searching
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'sharkdp/fd'
Plug 'BurntSushi/ripgrep'

" NeoVim Only
if has('nvim')
  " Linters
  Plug 'neomake/neomake'
  " Debugging
  Plug 'mfussenegger/nvim-dap'
  " Tree-Sitter
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
  Plug 'ValdezFOmar/tree-sitter-editorconfig'
  Plug 'tree-sitter/tree-sitter-go'
  Plug 'tree-sitter-grammars/tree-sitter-gpg-config'
  Plug 'nvim-treesitter/nvim-treesitter-refactor'
  Plug 'nvim-treesitter/nvim-treesitter-textobjects'
  Plug 'folke/twilight.nvim'
  Plug 'folke/zen-mode.nvim'

  " NeoVim terminal
  Plug 'hkupty/iron.nvim', { 'do': ':UpdateRemotePlugins' }
  Plug 'vimlab/split-term.vim'
  " Linters
  " Leap movement
  Plug 'ggandor/leap.nvim'
  " Telescope
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim', { 'branch': '0.1.x' }
  " Code runner
  Plug 'CRAG666/code_runner.nvim'
else
  Plug 'scrooloose/syntastic'
endif

" Completion
Plug 'Valloric/YouCompleteMe'

" Status bar
if has('nvim')
  Plug 'nvim-lualine/lualine.nvim'
else
  Plug 'bling/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  " Plug 'edkolev/tmuxline.vim'
endif

" Tmux integration
if has('nvim')
  Plug 'aserowy/tmux.nvim'
  Plug 'nvim-focus/focus.nvim'
else
  Plug 'tmux-plugins/vim-tmux'
  Plug 'tmux-plugins/vim-tmux-focus-events'
  Plug 'benmills/vimux'
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'roxma/vim-tmux-clipboard'
endif

" Go language
Plug 'MikeDacre/vim-go'

" Git support
Plug 'tpope/vim-fugitive'
" Git Realtime Info
Plug 'airblade/vim-gitgutter'
" Plug 'itchyny/vim-gitbranch'

" Vim in the browser
if has('nvim')
  Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }
endif

if has('nvim')
  Plug 'nvim-tree/nvim-web-devicons'
else
  Plug 'ryanoasis/vim-devicons'
  Plug 'vwxyutarooo/nerdtree-devicons-syntax'
  Plug 'lambdalisue/vim-nerdfont'
  " Plug 'ryanoasis/nerd-fonts'
  Plug 'lambdalisue/vim-glyph-palette'
endif
set guifont=DejaVuSansMNFM
set guifontwide=DejaVuSansMNFP
set encoding=UTF-8
" Initialize plugin system
call plug#end()
