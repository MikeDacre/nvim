"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                              Plugins for NVIM                               "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Plugins with [vim-plug](https://github.com/junegunn/vim-plug)
call plug#begin(g:vimdir_path . '/plugged')

Plug 'tpope/vim-sensible'
Plug 'mhinz/vim-startify'

Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'vim-scripts/taglist.vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'junegunn/vim-easy-align'
Plug 'godlygeek/tabular'
Plug 'jlanzarotta/bufexplorer', { 'on': 'BufExplorer' }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'dhruvasagar/vim-table-mode', { 'on': 'TableModeToggle' }
Plug 'scrooloose/nerdcommenter'
Plug 'jamessan/vim-gnupg'
Plug 'othree/html5.vim'
Plug 'milkypostman/vim-togglelist'

" Multiple cursor edits with <C-n>, <C-x>, and <C-p>
Plug 'terryma/vim-multiple-cursors'

" Markdown writing
Plug 'junegunn/goyo.vim', { 'for': 'markdown' }
Plug 'reedes/vim-pencil', { 'for': 'markdown' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" RST
Plug 'gu-fan/riv.vim', { 'for': 'rst' }

" Color schemes
Plug 'lifepillar/vim-solarized8'

" NeoVim Only
if has('nvim')
  " NeoVim terminal
  Plug 'hkupty/iron.nvim', { 'do': ':UpdateRemotePlugins' }
  Plug 'vimlab/split-term.vim'
  " Linters
  Plug 'neomake/neomake' 
  " Clipboard
  Plug 'cazador481/fakeclip.neovim'
else
  Plug 'scrooloose/syntastic'
endif

" Git support
Plug 'tpope/vim-fugitive'

" Completion
if $USE_YCM
  Plug 'Valloric/YouCompleteMe'
else
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
  Plug 'zchee/deoplete-jedi', { 'do': ':UpdateRemotePlugins' } 
endif

" Status bar
Plug 'bling/vim-airline'

" Tmux integration
Plug 'benmills/vimux'
Plug 'tmux-plugins/vim-tmux-focus-events'
Plug 'christoomey/vim-tmux-navigator'

" Initialize plugin system
call plug#end()

