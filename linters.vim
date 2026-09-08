"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                           Linters—Neomake and ALE                           "
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if g:vim_minimal == 0
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
    "" ALE for vanilla vim (replaces syntastic — archived upstream; see PLUGINS.md)
    function! LinterStatus() abort
      let l:counts = ale#statusline#Count(bufnr(''))
      let l:all_errors = l:counts.error + l:counts.style_error
      let l:all_non_errors = l:counts.total - l:all_errors
      return l:counts.total == 0 ? 'OK' : printf('%dW %dE', l:all_non_errors, l:all_errors)
    endfunction
    set statusline+=%#warningmsg#
    set statusline+=%{LinterStatus()}
    set statusline+=%*

    let g:ale_lint_on_text_changed = 'never'
    let g:ale_lint_on_enter        = 0
    let g:ale_lint_on_save         = 1

    " Quiet the same noisy pylint codes the old syntastic config suppressed.
    " NOTE: verify the exact option name against `:help ale-python-pylint` —
    " ALE's per-linter `_options` convention is consistent but this one wasn't
    " directly confirmed in the top-level doc.
    let g:ale_python_pylint_options = '--disable=C0301,C0168,C0901,W0612,W0611,E221,E501,E116,bad-whitespace,invalid-name'

    " flake8 folds pep8+pyflakes+mccabe into one linter — the modern
    " equivalent of syntastic's old pep8/py3kwarn/pyflakes3k combo
    let g:ale_python_short_checkers = ['flake8']
    let g:ale_python_long_checkers  = ['flake8', 'pylint']
    let g:ale_python_checker        = 'short'
    let g:ale_linters = {'python': g:ale_python_short_checkers}

    " Toggle between the light (flake8) and heavy (flake8+pylint) checker sets
    function! TogglePyCheckers()
      if g:ale_python_checker ==# 'short'
        let g:ale_linters['python'] = g:ale_python_long_checkers
        let g:ale_python_checker = 'long'
      else
        let g:ale_linters['python'] = g:ale_python_short_checkers
        let g:ale_python_checker = 'short'
      endif
      ALELint
    endfunction

    " Focus this buffer on pylint alone. ALE has no per-linter ad-hoc run the
    " way `:SyntasticCheck pylint` did — closest equivalent is a buffer-local
    " linter list, which is what this does.
    function! FocusPylint()
      let b:ale_linters = ['pylint']
      ALELint
    endfunction

    function! ResetCheckers()
      unlet! b:ale_linters
      let g:ale_linters['python'] = g:ale_python_short_checkers
      let g:ale_python_checker = 'short'
      ALEResetBuffer
      ALELint
    endfunction

    nmap <silent> <LocalLeader>pl :ALELint<cr>
    nmap <silent> <LocalLeader>pk :call FocusPylint()<cr>
    nmap <silent> <LocalLeader>pu :call ResetCheckers()<cr>
    nmap <silent> <LocalLeader>pt :call TogglePyCheckers()<cr>
  endif
endif
