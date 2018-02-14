"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                         Mike Dacre's NeoVim Config                          "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Plugins with [vim-plug](https://github.com/junegunn/vim-plug)
call plug#begin('~/nvim/plugged')

Plug 'neomake/neomake' | Plug 'milkypostman/vim-togglelist'
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

" Markdown writing
Plug 'junegunn/goyo.vim', { 'for': 'markdown' }
Plug 'reedes/vim-pencil', { 'for': 'markdown' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" RST
Plug 'gu-fan/riv.vim', { 'for': 'rst' }

" Color schemes
Plug 'lifepillar/vim-solarized8'

" IPython etc
Plug 'hkupty/iron.nvim', { 'do': ':UpdateRemotePlugins' }

" Git support
Plug 'tpope/vim-fugitive'

" Completion
" Plug 'Valloric/YouCompleteMe'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'zchee/deoplete-jedi', { 'do': ':UpdateRemotePlugins' } 

" Status bar
Plug 'bling/vim-airline'

" Tmux integration
Plug 'benmills/vimux'
Plug 'tmux-plugins/vim-tmux-focus-events'
Plug 'christoomey/vim-tmux-navigator'

" Initialize plugin system
call plug#end()
filetype plugin indent on

" Color
set background = "dark"
set termguicolors
colo wombat256mod

" Some defaults
set ruler
set number
set nowrap
set virtualedit=all

" Mouse support
if has('mouse')
  set mouse=a
endif

" Allow continual indent/dedent in visual block
vnoremap < <gv
vnoremap > >gv

" Set backup and undo
:if !isdirectory($HOME . "/.temp")
:  call mkdir($HOME . "/.temp", "")
:  call mkdir($HOME . "/.temp/nswap", "")
:  call mkdir($HOME . "/.temp/nbackup", "")
:  call mkdir($HOME . "/.temp/nundo", "")
:endif

set directory=$HOME/.temp/nswap
set backupdir=$HOME/.temp/nbackup
set undodir=$HOME/.temp/nundo
set undofile
set undoreload=50000
set undolevels=1000

" Remember last position
autocmd BufReadPost * if @% !~# '\.git[\/\\]COMMIT_EDITMSG$' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif 

" Escape from terminal
:tnoremap <C-t> <C-\><C-n>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                              Custom Functions                               "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Add cmdlst syntax
fun CaptureLine()
  let l = getline('.')
  let c = system( l )
  set paste
  set noexpandtab
  exe "normal o".c
  set nopaste
  set expandtab
  "redraw!
endfun

fun ExecLine()
  let l = getline('.')
  set paste
  set noexpandtab
  exe "normal o###"
  exe "normal o# "
  exe "normal o# Run start: ".strftime("%y-%m-%d %H:%M:%S")
  exe "normal o# "
  exe "normal o###"
  exe "normal o# Output:::"
  exe "normal o# "
  let c = system( l )
  let c = substitute(c, '^', '# ', 'g')
  let c = substitute(c, '\n', '\r# ', 'g')
  exe "normal o".c
  exe "normal o###"
  exe "normal o# "
  exe "normal o# Run end ".strftime("%y-%m-%d %H:%M:%S")
  exe "normal o# "
  exe "normal o###"
  set nopaste
  set expandtab
  redraw!
endfun

noremap <leader>il :call CaptureLine()<CR>
noremap <leader>el :call ExecLine()<CR>

" Date inserting
nnoremap <leader>dd "=strftime("%Y-%m-%d %H:%M:%S")<CR>P
inoremap <leader>dd <C-R>=strftime("%Y-%m-%d %H:%M:%S")<CR>

nnoremap <leader>ds "=strftime("%m/%d/%y")<CR>P
inoremap <leader>ds <C-R>=strftime("%m/%d/%y")<CR>

nnoremap <leader>dt "=strftime("%T")<CR>P
inoremap <leader>dt <C-R>=strftime("%T")<CR>

nnoremap <leader>dl "=strftime("%a %d %b %Y %X %Z")<CR>P
inoremap <leader>dl <C-R>=strftime("%c")<CR>

" My tag
nnoremap <leader>me iMike Dacre
inoremap <leader>me Mike Dacre

" Pasting Mode
map <leader>pp :set paste<CR>:set noexpandtab<CR>
map <leader>PP :set nopaste<CR>:set expandtab<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                         Word Processor/Writing Mode                         "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Handle wrapping
function ToggleWrap()
  if &wrap
    echo "Wrap OFF"
    setlocal nowrap
    set virtualedit=all
    silent! nunmap <buffer> <Up>
    silent! nunmap <buffer> <Down>
    silent! nunmap <buffer> <Home>
    silent! nunmap <buffer> <End>
    silent! iunmap <buffer> <Up>
    silent! iunmap <buffer> <Down>
    silent! iunmap <buffer> <Home>
    silent! iunmap <buffer> <End>
  else
    echo "Wrap ON"
    setlocal wrap linebreak nolist
    set virtualedit=
    setlocal display+=lastline
    noremap  <buffer> <silent> <Up>   gk
    noremap  <buffer> <silent> <Down> gj
    noremap  <buffer> <silent> <Home> g<Home>
    noremap  <buffer> <silent> <End>  g<End>
    inoremap <buffer> <silent> <Up>   <C-o>gk
    inoremap <buffer> <silent> <Down> <C-o>gj
    inoremap <buffer> <silent> <Home> <C-o>g<Home>
    inoremap <buffer> <silent> <End>  <C-o>g<End>
  endif
endfunction
noremap <silent> <Leader>ww :call ToggleWrap()<CR>

" Pencil and Goyo for writing
func! WordProcessorMode() 
  setlocal formatoptions=1 
  setlocal noexpandtab 
  map j gj 
  map k gk
  setlocal spell spelllang=en_us 
  " colorscheme solarized8_light
  set thesaurus+=~/.vim/thesaurus/mthesaur.txt
  set complete+=s
  set formatprg=par
  set number
  " setlocal foldcolumn=12
  " setlocal wm=20
  " let g:pencil#autoformat = 1
  " let g:pencil#wrapModeDefault = 'soft'
  if ! &wrap
    call ToggleWrap()
  endif
  :Goyo
  :PencilSoft
endfu 

com! WordProcessor call WordProcessorMode()

" Iron REPL
fun IronSendLine()
  let c = getline('.')
  if &filetype == 'python'
    call IronSendSpecial(c)
  else
    call IronSend(c)
  endif
endfun

fun IronSendCell()
  :?#%%\|\#^?;/#%%\|\#$/y b
  if &filetype == 'python'
    call IronSendSpecial(@b)
  else
    call IronSend(@b)
  endif
endfun

" Vimux
let g:vimux_running = 0
fun ToggleVimux()
  if g:vimux_running
    call VimuxCloseRunner()
    if &filetype == 'python'
      nunmap <Space>
      vunmap <Space>
      noremap <silent> <Leader>sl :call IronSendLine()<CR>
      noremap <silent> <Leader>sc :call IronSendCell()<CR>
      noremap <silent> <Leader>sb :call IronSendCell()<CR>
    endif
    let g:vimux_running = 0
  else
    if &filetype == 'python'
      " Send the current line in normal and visual mode with space
      nmap <silent> <Space> :call RunTmuxPythonLine()<cr>
      vmap <silent> <Space> :call RunTmuxPythonChunk()<CR>
      smap <silent> <Space> <Nop>
      noremap <silent> <Leader>sl :call RunTmuxPythonLine(0)<CR>
      noremap <silent> <Leader>sc :call RunTmuxPythonCell(0)<CR>
      noremap <silent> <Leader>sb :call RunTmuxPythonCell(1)<CR>

      call VimuxRunCommand('ipython')
    else
      call VimuxRunCommand('zsh')
    endif
    let g:vimux_running = 1
  endif
endfun
map  <silent> <C-e> :call ToggleVimux()<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                           Filetype Configuration                            "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

au BufRead,BufNewFile *.cmdlst set filetype=sh
au BufRead,BufNewFile *.pbs set filetype=sh
au FileType pandoc setlocal tw=99 tabstop=4 shiftwidth=4 softtabstop=4
au FileType rst setlocal tw=99 tabstop=4 shiftwidth=4 softtabstop=4
au BufRead,BufNewFile *.rst set filetype=rst

" Vim
autocmd FileType vim setlocal et sw=2 ts=2 tw=79 

" Python
au BufRead,BufNewFile *.py set filetype=python
autocmd FileType python setlocal completeopt=menuone,longest
autocmd FileType python setlocal et sw=4 ts=4 tw=79 

" Markdown
autocmd BufNewFile,BufReadPost *.md set filetype=markdown
autocmd BufNewFile,BufReadPost *.markdown set filetype=markdown

" Snakemake
au BufNewFile,BufRead Snakefile set syntax=snakemake
au BufNewFile,BufRead *.smk set syntax=snakemake
au BufNewFile,BufRead *.snakefile set syntax=snakemake
au FileType snakemake let Comment="#"
au FileType snakemake setlocal tw=99 tabstop=4 shiftwidth=4 softtabstop=4

" Text
autocmd FileType tex setlocal textwidth=80
autocmd BufNewFile,BufRead *.txt setlocal textwidth=80


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                            Plugin Configuration                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" deoplete
let g:deoplete#enable_at_startup = 1
inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"

" Tmux and IPython
let g:VimuxOrientation = "v"
let g:VimuxHeight = "30"
let g:cellmode_default_mappings='0'
let g:cellmode_tmux_panenumber='1'

" Iron Vim
let g:iron_repl_open_cmd = 'vsplit'

augroup ironmapping
  autocmd!
  autocmd Filetype python nmap <buffer> <localleader>t <Plug>(iron-send-motion)
  autocmd Filetype python vmap <buffer> <localleader>t <Plug>(iron-send-motion)
  autocmd Filetype python nmap <buffer> <localleader>p <Plug>(iron-repeat-cmd)
augroup END

" Pencil and markdown
let g:pencil#autoformat = 0
let g:vim_markdown_frontmatter = 1

" Indent guides
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors           = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=8
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=darkgrey

" NERDtree
noremap <F5> :NERDTree<CR>
let g:NERDTreeWinPos = "right"

" SnipMate/UltiSnpis
let g:snips_author = 'Mike Dacre'
let g:ultisnips_python_style = 'NORMAL'
let g:UltiSnipsExpandTrigger="<c-a>"
let g:UltiSnipsEditSplit = "vertical"

" Tag List
noremap <F6> :TlistToggle<CR>
map <leader>to :TlistSessionLoad .tlist<cr>
map <leader>ts :TlistSessionSave .tlist<cr>y<cr>
let Tlist_GainFocus_On_ToggleOpen = 0
let Tlist_Use_Right_Window = 0
let Tlist_Process_file_Always = 1
let tlist_php_settings = 'php;c:class;d:constant;f:function'
let tlist_python3_settings = 'Python;c:classes;f:functions;m:class_members;v:variables;i:imports'
let tlist_python_settings = 'Python;c:classes;f:functions;m:class_members;v:variables;i:imports'

" Buffer Explorer
let g:bufExplorerFindActive=1
map <leader>be :BufExplorer<CR>

" Comment plugin
let NERDSpaceDelims=1
let NERDCustomDelimiters = { 'py': { 'left': '#' }, 'snakemake' : { 'left': '#' , 'leftAlt': '#' } }
let g:NERDCustomDelimiters = { 'py': { 'left': '#' }, 'snakemake' : { 'left': '#' , 'leftAlt': '#' } }
map <Leader>cv <plug>NERDCommenterToggle

" Toggle error window
let g:toggle_list_no_mappings = 1
nmap <script> <silent> <leader>ll :call ToggleLocationList()<CR>
nmap <script> <silent> <leader>lq :call ToggleQuickfixList()<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                   Neomake                                   "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Python
let g:neomake_python_pylint_maker = {
  \ 'args': [
  \ '-d', 'C0301, C168, bad-whitespace',
  \ '-f', 'text',
  \ '--msg-template="{path}:{line}:{column}:{C}: [{symbol}] {msg}"',
  \ '-r', 'n'
  \ ],
  \ 'errorformat':
  \ '%A%f:%l:%c:%t: %m,' .
  \ '%A%f:%l: %m,' .
  \ '%A%f:(%l): %m,' .
  \ '%-Z%p^%.%#,' .
  \ '%-G%.%#',
  \ }

let g:neomake_python_python_exe = 'python3'
let g:neomake_python_enabled_makers = ['python', 'pyflakes']

" Toggle More Intense Neomake Checkers
let g:neo_on=0
fun ToggleNeomake()
  if g:neo_on
    let g:neomake_python_enabled_makers = ['python', 'pyflakes']
    Neomake
    lclose
    let g:neo_on=0
  else
    let g:neomake_python_enabled_makers = ['python', 'pyflakes', 'pylint', 'vulture']
    Neomake
    let g:neo_on=1
  endif
endfun

" Hide all error messages
fun CleanCheckers()
  call neomake#configure#automake('w')
  NeomakeDisable
  lclose
  sign unplace *
endfun

nmap <silent> <LocalLeader>pk :call ToggleNeomake()<cr>
nmap <silent> <LocalLeader>pu :call CleanCheckers()<cr>

" Initialize neomake
call neomake#configure#automake('rnw', 750)
