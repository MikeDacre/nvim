"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                          Fix Issues in Vanilla Vim                          "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
 
"General
if has("gui_running") || &term == "xterm-256color" || &term == "screen-256color"
  set t_Co=256
  colo wombatmikemod
else
  colo wombat
endif

syntax enable
syntax on
syntax sync fromstart

set guioptions-=b
set guioptions-=r
set guioptions-=R
set guioptions-=l
set guioptions-=L
set guioptions-=T
set guicursor=

set encoding=utf-8

set ai "autoindent
set si "smartindent

set ofu=syntaxcomplete#Complete
 
""Tell vim to remember certain things when we exit
"  '10  :  marks will be remembered for up to 10 previously edited files
"  "100 :  will save up to 100 lines for each register
"  :20  :  up to 20 lines of command-line history will be remembered
"  %    :  saves and restores the buffer list
"  n... :  where to save the viminfo files
set viminfo='10,\"1000,:90,%,n~/.temp/viminfo"'
set foldmethod=syntax
set foldlevelstart=20

" In many terminal emulators the mouse works just fine, thus enable it.
set ttymouse=xterm2 
 
set cursorline
set smartcase
 
set tabstop=4
set shiftwidth=4
set cindent shiftwidth=4

" Enable CTRL-A/CTRL-X to work on octal and hex numbers, as well as characters
set nrformats=octal,hex,alpha
set expandtab

" Set Number format to null(default is octal) , when press CTRL-A on number
" like 007, it would not become 010
set nf=
    
set cursorline
set smartcase

set shellredir=>%s\ 2>&1

set lazyredraw

set showfulltag
          
