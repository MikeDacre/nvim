"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                        Linters—Neomake and Syntastic                        "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if g:vim_minimal == 0 && g:vim_mini == 'false'
  if has('nvim')
    "" Neomake for NeoVim

    " Python
    let g:neomake_python_pylint_maker = {
      \ 'args': [
      \ '-d', 'C0301, C168, C901, W0612, W0611, E221, E501, E116, bad-whitespace, invalid-name',
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
    let g:neomake_python_enabled_makers = ['python', 'pylint', 'pyflakes']

    " Toggle More Intense Neomake Checkers
    let g:pyneo_lint_on=0
    fun ToggleNeomake()
      if g:pyneo_lint_on
        let g:neomake_python_enabled_makers = ['python', 'pylint', 'pyflakes']
        let g:pyneo_lint_on=0
      else
        let g:neomake_python_enabled_makers = ['python', 'pyflakes', 'pep8', 'pylint', 'vulture']
        let g:pyneo_lint_on=1
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
    call neomake#configure#automake('rnw', 250)
  else
    "" Syntastic for vanilla vim
    set statusline+=%#warningmsg#
    set statusline+=%{SyntasticStatuslineFlag()}
    set statusline+=%*

    let g:syntastic_always_populate_loc_list = 1
    let g:syntastic_auto_loc_list            = 1
    let g:syntastic_check_on_open            = 0
    let g:syntastic_check_on_wq              = 0
    let g:syntastic_aggregate_errors         = 1

    if findfile('/usr/bin/pyflakes-python2')
      let pyflakes_python2 = 'pyflakes-python2'
    else
      let pyflakes_python2 = 'pyflakes'
    endif

    let g:syntastic_python3_checkers         = ['python', 'pep8', 'py3kwarn', 'pyflakes3k', 'pylint']
    let g:syntastic_python2_checkers         = ['python', 'pep8', 'py3kwarn', pyflakes_python2, 'pylint']
    let g:syntastic_python3_small_checkers   = ['python', 'pep8', 'py3kwarn', 'pyflakes3k']
    let g:syntastic_python2_small_checkers   = ['python', 'pep8', 'py3kwarn', pyflakes_python2]

    let g:syntastic_quiet_messages = {
        \ 'regex': ['bad-whitespace', 'W0612', 'C901', 'W0611', 'E221', 'E501', 'E116']
        \ }
    let g:syntastic_python_pep8_quiet_messages = {'regex': 'E2[27]1'}
    let g:syntastic_python_pylint_quiet_messages = {'regex': ['too-few-public-methods', 'too-many-statements', 'too-many-nested-blocks', 'superfluous-parens', 'bad-whitespace', 'too-many-instance-attributes', 'invalid-name', 'too-many-arguments', 'too-many-locals', 'too-many-branches', 'too-many-statements']}
    let g:syntastic_python_pyflakes_quiet_messages = {'regex': ['']}

    let g:syntastic_mode_map = { "mode": "passive" }

    if has( 'python3' )
      let g:python_version = 3
      let g:syntastic_python_python_exec     = 'python3'
      let g:syntastic_python_checkers        = g:syntastic_python3_small_checkers
      let g:syntastic_python_checker         = 'long'
    else
      let g:python_version = 2
      let g:syntastic_python_checkers        = g:syntastic_python2_small_checkers
      let g:syntastic_python_checker         = 'long'
    endif

    fun TogglePyCheckers()
      if g:syntastic_python_checker == 'long'
        if g:python_version == 2
          let g:syntastic_python_checkers    = g:syntastic_python2_small_checkers
        elseif g:python_mode == 3
          let g:syntastic_python_checkers    = g:syntastic_python3_small_checkers
        endif
        let g:syntastic_python_checker = 'short'
      elseif g:syntastic_python_checker == 'short'
        if g:python_version == 2
          let g:syntastic_python_checkers    = g:syntastic_python2_checkers
        elseif g:python_mode == 3
          let g:syntastic_python_checkers    = g:syntastic_python3_checkers
        endif
        let g:syntastic_python_checker = 'long'
      endif
    endfun

    fun ResetCheckers()
      SyntasticReset
      sign unplace *
      let g:pymode_lint_checkers = ['mccabe', 'pep257']
    endfun


    nmap <silent> <LocalLeader>pl :SyntasticCheck<cr>
    nmap <silent> <LocalLeader>pk :SyntasticCheck pylint<cr>
    nmap <silent> <LocalLeader>pu :call ResetCheckers()<cr>
    nmap <silent> <LocalLeader>pt :call TogglePyCheckers()<cr>
  endif
endif
