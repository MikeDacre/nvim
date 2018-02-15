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

map <leader>il :call CaptureLine()<CR>
map <leader>el :call ExecLine()<CR>

" Date inserting
nmap <leader>dd "=strftime("%Y-%m-%d %H:%M:%S")<CR>P
imap <leader>dd <C-R>=strftime("%Y-%m-%d %H:%M:%S")<CR>

nmap <leader>ds "=strftime("%m/%d/%y")<CR>P
imap <leader>ds <C-R>=strftime("%m/%d/%y")<CR>

nmap <leader>dt "=strftime("%T")<CR>P
imap <leader>dt <C-R>=strftime("%T")<CR>

nmap <leader>dl "=strftime("%a %d %b %Y %X %Z")<CR>P
imap <leader>dl <C-R>=strftime("%c")<CR>

" My tag
nmap <leader>me iMike Dacre
imap <leader>me Mike Dacre

" Pasting Mode
map <leader>pp :set paste<CR>:set noexpandtab<CR>
map <leader>PP :set nopaste<CR>:set expandtab<CR>

" Iron REPL
if has('nvim')
  fun IronSendLine()
    let c = getline('.')
    if &filetype == 'python'
      call IronSend(c)
      " call IronSendSpecial(c)
    else
      call IronSend(c)
    endif
  endfun

  fun IronSendCell()
    :?#%%\|##\|\#^?;/#%%\|##\|\#$/y b
    if &filetype == 'python'
      " call IronSendSpecial(@b)
      call IronSend(@b)
    else
      call IronSend(@b)
    endif
  endfun

  fun StartIron()
    :IronRepl
    nmap <silent> <Space> :call IronSendLine()<cr>
    vmap <silent> <Space> :call IronSendLine()<CR>
    smap <silent> <Space> <Nop>
    map <silent> <Leader>sl :call IronSendLine()<CR>
    map <silent> <Leader>sc :call IronSendCell()<CR>
    map <silent> <Leader>sb :call IronSendCell()<CR>
  endfun

  map <silent> <LocalLeader>fl :<C-\><C-n><C-w><C-r>
  map <silent> <LocalLeader>rl :call StartIron()<CR>
endif

fun VimuxSendLine()
  let c = getline('.')
  call VimuxSendText(c)
  call VimuxSendKeys("Enter")
endfun

fun VimuxSendCell()
  :?#%%\|##\|\#^?;/#%%\|##\|\#$/y b
  call VimuxSendText(@b)
  call VimuxSendKeys("Enter")
endfun
       

" Vimux
let g:vimux_running = 0
fun ToggleVimux()
  if g:vimux_running
    call VimuxCloseRunner()
    if &filetype == 'python'
      nunmap <Space>
      vunmap <Space>
      if has('nvim')
        map <silent> <Leader>sl :call IronSendLine()<CR>
        map <silent> <Leader>sc :call IronSendCell()<CR>
        map <silent> <Leader>sb :call IronSendCell()<CR>
      else
        unmap <Leader>sl
        unmap <Leader>sc
        unmap <Leader>sb
      endif
    endif
    let g:vimux_running = 0
  else
    if &filetype == 'python'
      " Send the current line in normal and visual mode with space
      nmap <silent> <Space> :call VimuxSendLine()<cr>
      vmap <silent> <Space> :call VimuxSendLine()<CR>
      smap <silent> <Space> <Nop>
      map <silent> <Leader>sl :call VimuxSendLine()<CR>
      map <silent> <Leader>sc :call VimuxSendCell()<CR>

      " nmap <silent> <Space> :call RunTmuxPythonLine()<cr>
      " vmap <silent> <Space> :call RunTmuxPythonChunk()<CR>
      " smap <silent> <Space> <Nop>
      " map <silent> <Leader>sl :call RunTmuxPythonLine(0)<CR>
      " map <silent> <Leader>sc :call RunTmuxPythonCell(0)<CR>
      " map <silent> <Leader>sb :call RunTmuxPythonCell(1)<CR>

      call VimuxRunCommand('ipython')
    else
      nmap <silent> <Space> :call RunTmuxPythonLine()<cr>
      vmap <silent> <Space> :call RunTmuxPythonChunk()<CR>
      smap <silent> <Space> <Nop>
      map <silent> <Leader>sl :call RunTmuxPythonLine(0)<CR>
      map <silent> <Leader>sc :call RunTmuxPythonCell(0)<CR>
      map <silent> <Leader>sb :call RunTmuxPythonCell(1)<CR>

      call VimuxRunCommand('ipython')
      call VimuxRunCommand('zsh')
    endif
    let g:vimux_running = 1
  endif
endfun
map  <silent> <C-e> :call ToggleVimux()<cr>

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
    map  <buffer> <silent> <Up>   gk
    map  <buffer> <silent> <Down> gj
    map  <buffer> <silent> <Home> g<Home>
    map  <buffer> <silent> <End>  g<End>
    imap <buffer> <silent> <Up>   <C-o>gk
    imap <buffer> <silent> <Down> <C-o>gj
    imap <buffer> <silent> <Home> <C-o>g<Home>
    imap <buffer> <silent> <End>  <C-o>g<End>
  endif
endfunction
noremap <silent> <Leader>ww :call ToggleWrap()<CR>

" Pencil and Goyo for writing
if &filetype == 'markdown'
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
endif

com! WordProcessor call WordProcessorMode()
