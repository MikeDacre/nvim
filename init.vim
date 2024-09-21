"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                   Mike Dacre's Dual Vim/NeoVim Config                       "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get our location
let g:vimdir_path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

exec "source " . g:vimdir_path . "/plugins.vim"

set encoding=UTF-8

" Fundamental settings
set fileencoding=utf-8
set fileencodings=utf-8,latin-1,ucs-bom,gbk,cp936
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
    set guifont=DejaVuSansMNFM:w13
    set guifontwide=DejaVuSansMNFP:w13
    colo wombatmikemod
  else
    colo wombat
  endif
endif

let g:airline_powerline_fonts = 1

" Mouse support
if has('mouse')
  set mouse=a
endif

" Some useful settings
" set title
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
au BufRead,BufNewFile *.pbs set filetype=rst
au FileType pandoc setlocal tw=80 tabstop=4 shiftwidth=4 softtabstop=4
au FileType markdown setlocal tw=80 tabstop=4 shiftwidth=4 softtabstop=4
au FileType rst setlocal tw=80 tabstop=4 shiftwidth=4 softtabstop=4
au BufRead,BufNewFile *.rst set filetype=rst

" HTML
au FileType hugo setlocal et sw=2 ts=2 tw=160 spell spelllang=en_us
au FileType html setlocal et sw=2 ts=2 tw=160 spell spelllang=en_us
au FileType css  setlocal et sw=2 ts=2 tw=120

" Tmux
au BufRead,BufNewFile *.tmux set filetype=sh

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

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Tmux-ZSH-Vim-Titles
" let g:vim_include_path = 0
" let g:vim_include_path = 'zsh'
let g:vim_path_width = '20'

" editorconfig
let g:EditorConfig_exclude_patterns = ['fugitive://.*']

" deoplete
" if !$VIM_YCM && has('nvim') && g:vim_minimal == 0
  " let g:deoplete#enable_at_startup = 1
  " inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"
  " " Enter: complete&close popup if visible (so next Enter works); else: break undo
  " inoremap <silent><expr> <Cr> pumvisible() ?
              " \ deoplete#mappings#close_popup() : "<C-g>u<Cr>"
" endif

" Tmux clipboard
map <Leader>tp let @" = system('tmux show-buffer')

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
let g:pymode_lint               = 1
let g:pymode_lint_on_write      = 0
let g:pymode_lint_checkers      = ['pyflakes']
let g:pymode_lint_ignore        = "F0002,W0612,C0301,C901,C0326,W0611,E221,E501,E116"

" Buffer Explorer
let g:bufExplorerFindActive=1
map <leader>be :BufExplorer<CR>

" Comment plugin
let NERDSpaceDelims=1
let NERDCustomDelimiters = { 'py': { 'left': '#' }, 'snakemake' : { 'left': '#' , 'leftAlt': '#' } }
let g:NERDCustomDelimiters = { 'py': { 'left': '#' }, 'snakemake' : { 'left': '#' , 'leftAlt': '#' } }
map <Leader>cv <plug>NERDCommenterToggle

" SnipMate/UltiSnpis
let g:snips_author = 'Mike Dacre'
let g:ultisnips_python_style = 'NORMAL'
let g:UltiSnipsExpandTrigger="<c-a>"
let g:UltiSnipsEditSplit = "vertical"

if g:vim_minimal == 0
  " Pencil and markdown
  let g:pencil#autoformat = 0
  let g:vim_markdown_frontmatter = 1
  let g:vim_markdown_toc_autofit = 1

  " Indent guides
  let g:indent_guides_enable_on_vim_startup = 1
  let g:indent_guides_auto_colors           = 0
  autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=8
  autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=darkgrey

  " Startify
  let g:startify_bookmarks = systemlist("cut -sd' ' -f 2- ~/.NERDTreeBookmarks")
  let g:startify_fortune_use_unicode = 1
  let g:startify_session_autoload = 1
  let g:startify_session_delete_buffers = 1
  let g:startify_session_persistence = 1
  " function! GetUniqueSessionName()
    " let path = fnamemodify(getcwd(), ':~:t')
    " let path = empty(path) ? 'no-project' : path
    " let branch = gitbranch#name()
    " let branch = empty(branch) ? '' : '-' . branch
    " return substitute(path . branch, '/', '-', 'g')
  " endfunction

  " autocmd User        StartifyReady silent execute 'SLoad '  . GetUniqueSessionName()
  " autocmd VimLeavePre *             silent execute 'SSave! ' . GetUniqueSessionName()

  " returns all modified files of the current git repo
  " `2>/dev/null` makes the command fail quietly, so that when we are not
  " in a git repo, the list will be empty
  function! s:gitModified()
      let files = systemlist('git ls-files -m 2>/dev/null')
      return map(files, "{'line': v:val, 'path': v:val}")
  endfunction

  " same as above, but show untracked files, honouring .gitignore
  function! s:gitUntracked()
      let files = systemlist('git ls-files -o --exclude-standard 2>/dev/null')
      return map(files, "{'line': v:val, 'path': v:val}")
  endfunction

  " \ { 'type': 'dir',       'header': ['   MRU '. getcwd()] },
  let g:startify_lists = [
          \ { 'type': 'files',     'header': ['   Recent']         },
          \ { 'type': 'sessions',  'header': ['   Sessions']       },
          \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      },
          \ { 'type': function('s:gitModified'),  'header': ['   git modified']},
          \ { 'type': function('s:gitUntracked'), 'header': ['   git untracked']},
          \ { 'type': 'commands',  'header': ['   Commands']       },
          \ ]

  " vim-project
  let g:vim_project_config = {
      \'config_home':                   '~/.vim/vim-project-config',
      \'project_base':                  ['~/.vim/projects'],
      \'use_session':                   0,
      \'open_root_when_use_session':    0,
      \'check_branch_when_use_session': 0,
      \'project_root':                  './',
      \'auto_load_on_start':            1,
      \'include':                       ['./'],
      \'exclude':                       ['.git', 'node_modules', '.DS_Store', '.github', '.next'],
      \'search_include':                [],
      \'find_in_files_include':         [],
      \'search_exclude':                [],
      \'find_in_files_exclude':         [],
      \'auto_detect':                   'yes',
      \'auto_detect_file':              ['.git', '.svn'],
      \'ask_create_directory':          'no',
      \'project_views':                 [],
      \'file_mappings':                 {},
      \'tasks':                         [],
      \'new_tasks':                     [
        \{ 'name': 'git', 'cmd': 'git clone', 'args': 'url' },
        \{ 'name': 'empty', 'cmd': 'mkdir' },
        \{ 'name': 'existing', 'cmd': 'cd .' },
      \],
      \'new_project_base':              '',
      \'new_tasks_post_cmd':            '',
      \'commit_message':                '',
      \'debug':                         0,
      \}

  " Keymappings for list prompt
  let g:vim_project_config.list_mappings = {
        \'open':                 "\<cr>",
        \'close_list':           "\<esc>",
        \'clear_char':           ["\<bs>", "\<c-a>"],
        \'clear_word':           "\<c-w>",
        \'clear_all':            "\<c-u>",
        \'prev_item':            ["\<c-k>", "\<up>"],
        \'next_item':            ["\<c-j>", "\<down>"],
        \'first_item':           ["\<c-h>", "\<left>"],
        \'last_item':            ["\<c-l>", "\<right>"],
        \'scroll_up':            "\<c-p>",
        \'scroll_down':          "\<c-n>",
        \'paste':                "\<c-b>",
        \'switch_to_list':       "\<c-o>",
        \}
  let g:vim_project_config.list_mappings_projects = {
        \'prev_view':            "\<s-tab>",
        \'next_view':            "\<tab>",
        \}
  let g:vim_project_config.list_mappings_search_files = {
        \'open_split':           "\<c-s>",
        \'open_vsplit':          "\<c-v>",
        \'open_tabedit':         "\<c-t>",
        \}
  let g:vim_project_config.list_mappings_find_in_files = {
        \'open_split':           "\<c-s>",
        \'open_vsplit':          "\<c-v>",
        \'open_tabedit':         "\<c-t>",
        \'replace_prompt':       "\<c-r>",
        \'replace_dismiss_item': "\<c-d>",
        \'replace_confirm':      "\<cr>",
        \}
  let g:vim_project_config.list_mappings_run_tasks = {
        \'run_task':              "\<cr>",
        \'stop_task':             "\<c-q>",
        \'open_task_terminal':    "\<c-o>",
        \}

  let g:vim_project_config.list_mappings_git = {
        \'checkout_revision':     "\<c-o>",
        \}

  let g:vim_project_config.git_diff_mappings = {
        \'jump_to_source': "\<cr>",
        \}
  let g:vim_project_config.git_changes_mappings = {
        \'open_file': "\<cr>",
        \}
  let g:vim_project_config.git_local_changes_mappings = {
        \'commit': 'c',
        \'rollback_file': 'R',
        \'open_changelist_or_file': "\<cr>",
        \'new_changelist': 'a',
        \'move_to_changelist': 'm',
        \'rename_changelist': 'r',
        \'delete_changelist': 'd',
        \'pull': 'u',
        \'push': 'p',
        \'pull_and_push': 'P',
        \}

  function! GetTitle()
    if exists('g:vim_project') && !empty(g:vim_project)
      return g:vim_project.name.' - '.expand('%')
    else
      return expand('%:p').' - '.expand('%')
    endif
  endfunction

  if exists('g:vim_project') && !empty(g:vim_project)
    set title titlestring=%{GetTitle()}
  endif

  if !has('nvim')
    " NERDtree
    noremap <F5> :NERDTree<CR>

    " Mirror the NERDTree before showing it. This makes it the same on all tabs.
    nnoremap <C-n> :NERDTreeMirror<CR>:NERDTreeFocus<CR>

    " New tree
    nnoremap <leader>nnt :NERDTreeMirror<CR>:NERDTreeFocus<CR>

    " Toggle
    nnoremap <leader>nt :NERDTreeToggle<CR>
    nnoremap <leader>nf :NERDTreeFocus<CR>
    nnoremap <leader>ns :NERDTreeFind<CR>

    let g:NERDTreeWinPos = "left"

    " Start NERDTree when Vim is started without file arguments.
    autocmd StdinReadPre * let s:std_in=1
    autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | wincmd p | endif

    " Exit Vim if NERDTree is the only window remaining in the only tab.
    autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | call feedkeys(":quit\<CR>:\<BS>") | endif

    " Close the tab if NERDTree is the only window remaining in it.
    autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | call feedkeys(":quit\<CR>:\<BS>") | endif
  endif

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
endif

set guifont=DejaVuSansMNFM:w13
set guifontwide=DejaVuSansMNFP:w13
set encoding=UTF-8
