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
Plug 'lambdalisue/vim-nerdfont'
Plug 'sharkdp/fd'
Plug 'BurntSushi/ripgrep'
Plug 'tpope/vim-obsession'
Plug 'xolox/vim-misc'
Plug 'xolox/vim-session'
Plug 'jlanzarotta/bufexplorer', { 'on': 'BufExplorer' }
if !exists('g:gui_oni')
    Plug 'lambdalisue/vim-glyph-palette'
    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
    Plug 'scrooloose/nerdtree-project-plugin'
    nnoremap <leader>nt :NERDTree<CR>
    nnoremap <leader>no :NERDTreeToggle<CR>
    nnoremap <leader>nf :NERDTreeFind<CR>
endif
Plug 'scrooloose/nerdcommenter'

" Extra targets and actions
Plug 'tpope/vim-repeat'    " Select within surrounding with cin<surround>
Plug 'wellle/targets.vim'
Plug 'tpope/vim-surround'  " Change surroundings with cs<surround>
Plug 'MikeDacre/tmux-zsh-vim-titles'

if g:vim_minimal == 0
  Plug 'editorconfig/editorconfig-vim'
  Plug 'freitass/todo.txt-vim'
  Plug 'mhinz/vim-startify'
  Plug 'AndrewRadev/linediff.vim'
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
  Plug 'python-mode/python-mode'
  Plug 'powerman/vim-plugin-AnsiEsc', { 'on': 'AnsiEsc' }
  Plug 'leafOfTree/vim-project'
  Plug 'phelipetls/vim-hugo'

  Plug 'ervandew/supertab'

  Plug 'vimoutliner/vimoutliner'
  Plug 'MikeDacre/vim-checkbox'

  " Markdown writing
  " Plug 'reedes/vim-pencil'
  " Plug 'junegunn/goyo.vim', { 'on': 'Goyo' }
  Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

  " Markdown Composer
  " if $VIM_MARKDOWN && !exists('g:gui_oni')
    " function! BuildComposer(info)
      " if a:info.status != 'unchanged' || a:info.force
        " if has('nvim')
          " !cargo build --release
        " else
          " !cargo build --release --no-default-features --features json-rpc
        " endif
      " endif
    " endfunction

    " Plug 'euclio/vim-markdown-composer', { 'for': 'markdown', 'do': function('BuildComposer') }
  " endif

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
    " if !exists('g:gui_oni')
        " Plug 'cazador481/fakeclip.neovim'
    " endif
    " Git Realtime Info
    Plug 'airblade/vim-gitgutter'
  else
    Plug 'scrooloose/syntastic'
  endif

  " Completion
  if !exists('g:gui_oni')
    if $VIM_YCM
      Plug 'Valloric/YouCompleteMe'
    else
      if has('nvim')
        Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
        Plug 'zchee/deoplete-jedi', { 'do': ':UpdateRemotePlugins' }
      else
        Plug 'https://git.sr.ht/~ackyshake/VimCompletesMe.vim'
      endif
    endif
  endif
endif

" Status bar
Plug 'bling/vim-airline'

" Tmux integration
Plug 'tmux-plugins/vim-tmux'
if $TMUX != ''
  if has('nvim') || v:version >= 700
    Plug 'tmux-plugins/vim-tmux-focus-events'
  endif
  Plug 'benmills/vimux'
  Plug 'christoomey/vim-tmux-navigator'
  Plug 'roxma/vim-tmux-clipboard'
endif

" Git support
Plug 'tpope/vim-fugitive'

" Initialize plugin system
call plug#end()
