"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                         Mike Dacre's NeoVim Config                          "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get our location
let g:vimdir_path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

exec "source " . g:vimdir_path . "/plugins.vim"

" Fundamental settings
set fileencoding=utf-8
set fileencodings=ucs-bom,utf-8,gbk,cp936,latin-1
set fileformat=unix
set fileformats=unix,dos,mac
filetype on
filetype plugin on
filetype plugin indent on
syntax on

" How often to update events
set updatetime=300
set timeoutlen=800 ttimeoutlen=0

" Color and vim mouse
set background=dark
if has('nvim')
  set termguicolors
	let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  colo wombatmikemod
else
	set ttymouse=xterm2
  set viminfo='100,\"1000,:200,%,n~/.temp/viminfo"'
  if has("gui_running") || &term == "xterm-256color" || &term == "screen-256color"
    set t_Co=256
    colo wombatmikemod
  else
    colo wombat
  endif
endif

" Mouse support
if has('mouse')
  set mouse=a
endif

" Some useful settings
set smartindent
set expandtab         " tab to spaces
set foldenable
set foldmethod=syntax " folding by syntax
set ignorecase        " ignore the case when search texts
set smartcase         " if searching text contains uppercase case will not be ignored
set ai                " autoindent
set si                " smartindent

" Lookings
set ruler
set number            " line number
set cursorline        " hilight the line of the cursor
set cursorcolumn      " hilight the column of the cursor
set nowrap            " no line wrapping
set virtualedit=all

" Tab default
set tabstop=4
set shiftwidth=4
set cindent shiftwidth=4

" Enable CTRL-A/CTRL-X to work on octal and hex numbers, as well as characters
set nrformats=octal,hex,alpha
set expandtab

" Enable omnicomplete in all vim versions
set ofu=syntaxcomplete#Complete

" Automatically conceal, particularly for markdown
set conceallevel=2

" Allow continual indent/dedent in visual block
vnoremap < <gv
vnoremap > >gv

" Set backup and undo
:if !isdirectory($HOME . "/.temp")
:  call mkdir($HOME . "/.temp", "")
:  call mkdir($HOME . "/.temp/swap", "")
:  call mkdir($HOME . "/.temp/backup", "")
:  call mkdir($HOME . "/.temp/undo", "")
:endif

set directory=$HOME/.temp/swap
set backupdir=$HOME/.temp/backup
set undodir=$HOME/.temp/undo
set undofile
set undoreload=50000
set undolevels=1000

" Remember last position
autocmd BufReadPost * if @% !~# '\.git[\/\\]COMMIT_EDITMSG$' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" Escape from terminal
if has('nvim')
  :tnoremap <C-t> <C-\><C-n>
endif

" Delete whitespace
noremap <leader>dw :%s/ \+$//g<CR>

" Custom Functions
if !$VIM_MINIMAL
  exec "source " . g:vimdir_path . "/functions.vim"
endif

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
au FileType python setlocal completeopt=menuone,longest
au FileType python setlocal et sw=4 ts=4 tw=79

" Markdown
au BufNewFile,BufReadPost *.md set filetype=markdown
au BufNewFile,BufReadPost *.markdown set filetype=markdown

" Snakemake
au BufNewFile,BufRead Snakefile set syntax=snakemake
au BufNewFile,BufRead *.smk set syntax=snakemake
au BufNewFile,BufRead *.snk set syntax=snakemake
au BufNewFile,BufRead *.snakefile set syntax=snakemake
au FileType snakemake let Comment="#"
au FileType snakemake setlocal completeopt=menuone,longest
au FileType snakemake setlocal tw=79 tabstop=4 shiftwidth=4 softtabstop=4

" Text
au FileType tex setlocal textwidth=80
au BufNewFile,BufRead *.txt setlocal textwidth=80

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                            Plugin Configuration                             "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" deoplete
if !$VIM_YCM && has('nvim')
  let g:deoplete#enable_at_startup = 1
  inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"
endif

" Tmux and IPython
if $TMUX
  let g:VimuxOrientation = "v"
  let g:VimuxHeight = "30"
endif

" Iron Vim
if has('nvim')
  let g:iron_repl_open_cmd = 'vsplit'

  augroup ironmapping
    autocmd!
    autocmd Filetype python nmap <buffer> <localleader>t <Plug>(iron-send-motion)
    autocmd Filetype python vmap <buffer> <localleader>t <Plug>(iron-send-motion)
    autocmd Filetype python nmap <buffer> <localleader>p <Plug>(iron-repeat-cmd)
  augroup END
endif

" Python Mode
let g:pymode                    = 1
let g:pymode_folding            = 1
let g:pymode_syntax             = 1
let g:pymode_rope               = 0
let g:pymode_rope_completion    = 0
if has('python3')
  let g:pymode_python           = 'python3'  " Always use python3
endif
let g:pymode_trim_whitespaces   = 0
let g:pymode_breakpoint         = 1
let g:pymode_breakpoint_bind    = '<leader>bb'
let g:pymode_lint               = 0
let g:pymode_lint_on_write      = 0
let g:pymode_lint_checkers      = ['pyflakes']
let g:pymode_lint_ignore        = "F0002,W0612,C0301,C901,C0326,W0611,E221,E501,E116"

" Pencil and markdown
let g:pencil#autoformat = 0
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_toc_autofit = 1

" Indent guides
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_auto_colors           = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=8
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=darkgrey

" NERDtree
noremap <F5> :NERDTree<CR>
let g:NERDTreeWinPos = "left"

" SnipMate/UltiSnpis
let g:snips_author = 'Mike Dacre'
let g:ultisnips_python_style = 'NORMAL'
let g:UltiSnipsExpandTrigger="<c-a>"
let g:UltiSnipsEditSplit = "vertical"

" Easy Align
xmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

" Tag List
noremap <F6> :TlistToggle<CR>
map <leader>to :TlistSessionLoad .tlist<cr>
map <leader>ts :TlistSessionSave .tlist<cr>y<cr>
let Tlist_GainFocus_On_ToggleOpen = 0
let Tlist_Use_Right_Window = 1
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

" Neomake and Syntastic
if !$VIM_MINIMAL
  exec "source " . g:vimdir_path . "/linters.vim"
endif

" Make allow C-h capture in TMUX nav
if $TMUX != ''
	nnoremap <silent> <BS> :TmuxNavigateLeft<cr>
endif
