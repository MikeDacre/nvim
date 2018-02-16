"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                              Plugins for NVIM                               "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Plugins with [vim-plug](https://github.com/junegunn/vim-plug)
call plug#begin(g:vimdir_path . '/plugged')

" Plugins that work everywhere
Plug 'tpope/vim-sensible'
Plug 'mhinz/vim-startify'
Plug 'jlanzarotta/bufexplorer', { 'on': 'BufExplorer' }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'scrooloose/nerdcommenter'

if !$VIM_MINIMAL
  Plug 'tpope/vim-speeddating'  " Increment dates and times
  Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
  Plug 'vim-scripts/taglist.vim'
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'junegunn/vim-easy-align'
  Plug 'godlygeek/tabular'
  Plug 'dhruvasagar/vim-table-mode', { 'on': 'TableModeToggle' }
  Plug 'jamessan/vim-gnupg'
  Plug 'othree/html5.vim'
  Plug 'milkypostman/vim-togglelist'

  " Multiple cursor edits with <C-n>, <C-x>, and <C-p>
  Plug 'terryma/vim-multiple-cursors'

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
    " Git Realtime Info
    Plug 'airblade/vim-gitgutter'
  else
    Plug 'scrooloose/syntastic'
  endif

  " Git support
  Plug 'tpope/vim-fugitive'

  " Completion
  if $VIM_YCM
    Plug 'Valloric/YouCompleteMe'
  else
    if has('nvim')
      Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
      Plug 'zchee/deoplete-jedi', { 'do': ':UpdateRemotePlugins' } 
    else
      Plug 'ajh17/VimCompletesMe'
    endif
  endif
 
  " Markdown writing
  Plug 'junegunn/goyo.vim', { 'for': 'markdown' }
  Plug 'reedes/vim-pencil', { 'for': 'markdown' }
  Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
 
  " Markdown Composer
  if $VIM_MARKDOWN
    function! BuildComposer(info)
      if a:info.status != 'unchanged' || a:info.force
        if has('nvim')
          !cargo build --release
        else
          !cargo build --release --no-default-features --features json-rpc
        endif
      endif
    endfunction

    Plug 'euclio/vim-markdown-composer', { 'for': 'markdown', 'do': function('BuildComposer') }
  endif
endif
   
" Status bar
Plug 'bling/vim-airline'

" Tmux integration
Plug 'benmills/vimux'
Plug 'tmux-plugins/vim-tmux-focus-events'
Plug 'christoomey/vim-tmux-navigator'
Plug 'roxma/vim-tmux-clipboard'
 
" Initialize plugin system
call plug#end()
