"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                         Mike Dacre's NeoVim Config                          "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get our location
let g:vimdir_path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

exec "source " . g:vimdir_path . "/plugins.vim"

filetype plugin indent on
 
" Fix issues with vanilla vim
if !has('nvim')
  exec "source " . g:vimdir_path . "/vim_fixes.vim"
else
  set termguicolors
endif
 
" Color
set background = "dark"
colo wombatmikemod

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

" Custom Functions
exec "source " . g:vimdir_path . "/functions.vim"

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
if has('nvim')
  let g:iron_repl_open_cmd = 'vsplit'

  augroup ironmapping
    autocmd!
    autocmd Filetype python nmap <buffer> <localleader>t <Plug>(iron-send-motion)
    autocmd Filetype python vmap <buffer> <localleader>t <Plug>(iron-send-motion)
    autocmd Filetype python nmap <buffer> <localleader>p <Plug>(iron-repeat-cmd)
  augroup END
endif

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

" Neomake and Syntastic
exec "source " . g:vimdir_path . "/linters.vim"
