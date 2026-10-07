" Obsidian-style note creation from templates.
"
" Templates are {TemplateName}.md files in g:mikevim_notes_template_dir, using
" Obsidian Templater syntax: {{date:YYYYMMDDHHmm}} and {{cursor}}. Each
" template on disk at source-time gets its own :Note{TemplateName} command —
" add a template, get a command, no vim config change needed. Run
" :NotesRescan after dropping in a new template without restarting.
"
" :Note{TemplateName} {title...} creates, writes and opens
" {slug}-{YYYYMMDDHHmm}.md in g:mikevim_notes_dir (cwd if unset), with:
"   id/created   the YYYYMMDDHHmm timestamp, for indexing
"   title        the given title, smart-title-cased
"   updated      left to the BufWritePre hook below, which keeps it current
"                on every save of any markdown file with a frontmatter
"                `updated:` key — not just notes created here.

if !exists('g:mikevim_notes_template_dir')
  let g:mikevim_notes_template_dir = expand('~/Ansetl/z99_Assets/Templates/Notes')
endif
if !exists('g:mikevim_notes_dir')
  let g:mikevim_notes_dir = ''  " empty = cwd at creation time
endif

" Small words Title Case lowercases unless they open or close the title —
" https://titlecaseconverter.com/rules/ is the common reference for this list.
let s:titlecase_small = split('a an and as at but by en for from if in into '
      \ . 'nor of on onto or per so than the to v v. via vs vs.', ' ')

function! s:TitleCaseWord(word, is_edge) abort
  if !a:is_edge && index(s:titlecase_small, tolower(a:word)) >= 0
    return tolower(a:word)
  endif
  return toupper(a:word[0]) . a:word[1:]
endfunction

function! s:TitleCase(title) abort
  let l:words = split(a:title)
  if empty(l:words)
    return ''
  endif
  let l:last = len(l:words) - 1
  for l:i in range(len(l:words))
    let l:words[l:i] = s:TitleCaseWord(l:words[l:i], l:i == 0 || l:i == l:last)
  endfor
  return join(l:words, ' ')
endfunction

function! s:Slug(title) abort
  let l:slug = substitute(tolower(a:title), '[^a-z0-9]\+', '_', 'g')
  return substitute(l:slug, '^_\+\|_\+$', '', 'g')
endfunction

" Returns [line, col] (0-indexed) of the first {{cursor}} marker, or [-1, -1].
function! s:FindCursorMark(lines) abort
  for l:i in range(len(a:lines))
    let l:col = stridx(a:lines[l:i], '{{cursor}}')
    if l:col >= 0
      return [l:i, l:col]
    endif
  endfor
  return [-1, -1]
endfunction

function! MikevimNoteCreate(template, title) abort
  let l:title = substitute(a:title, '^\s*\|\s*$', '', 'g')
  if empty(l:title)
    echoerr 'Note' . a:template . ': a title is required'
    return
  endif

  let l:template_path = g:mikevim_notes_template_dir . '/' . a:template . '.md'
  if !filereadable(l:template_path)
    echoerr 'Note' . a:template . ': template not found: ' . l:template_path
    return
  endif

  let l:id = strftime('%Y%m%d%H%M')
  let l:cased_title = s:TitleCase(l:title)
  let l:slug = s:Slug(l:title)

  let l:lines = readfile(l:template_path)
  let l:lines = map(l:lines, {_, line -> substitute(line, '{{date:YYYYMMDDHHmm}}', l:id, 'g')})
  let l:lines = map(l:lines, {_, line -> line =~# '^title:' ? 'title: "' . l:cased_title . '"' : line})

  let [l:cursor_line, l:cursor_col] = s:FindCursorMark(l:lines)
  let l:lines = map(l:lines, {_, line -> substitute(line, '{{cursor}}', '', 'g')})

  let l:dir = empty(g:mikevim_notes_dir) ? getcwd() : g:mikevim_notes_dir
  let l:path = l:dir . '/' . l:slug . '-' . l:id . '.md'
  if filereadable(l:path)
    echoerr 'Note' . a:template . ': ' . l:path . ' already exists'
    return
  endif

  if writefile(l:lines, l:path) != 0
    echoerr 'Note' . a:template . ': could not write ' . l:path
    return
  endif

  execute 'edit ' . fnameescape(l:path)
  if l:cursor_line >= 0
    call cursor(l:cursor_line + 1, l:cursor_col + 1)
  endif
endfunction

" A template filename with spaces, dots or other characters :command can't
" use in a name would break the execute() below; it's skipped with a warning
" instead of erroring the whole sourcing pass — one bad template file must
" not break every machine's next pull the way a syntax error in init.vim
" would (see CLAUDE.md hazards).
function! s:DefineNoteCommands() abort
  if !isdirectory(g:mikevim_notes_template_dir)
    return
  endif
  for l:file in glob(g:mikevim_notes_template_dir . '/*.md', 0, 1)
    let l:name = fnamemodify(l:file, ':t:r')
    if l:name !~# '^[A-Za-z][A-Za-z0-9]*$'
      echohl WarningMsg
      echom 'notes.vim: skipping template with unusable command name: ' . l:name
      echohl None
      continue
    endif
    execute 'command! -nargs=+ Note' . l:name . " call MikevimNoteCreate('" . l:name . "', <q-args>)"
  endfor
endfunction

command! NotesRescan call s:DefineNoteCommands()
call s:DefineNoteCommands()

" Keeps `updated:` current on every save of any markdown file that has one,
" not just notes created above — mirrors Obsidian Templater's on-save update.
function! s:UpdateFrontmatterTimestamp() abort
  if line('$') < 2 || getline(1) !=# '---'
    return
  endif
  let l:close = -1
  for l:i in range(2, min([line('$'), 40]))
    if getline(l:i) ==# '---'
      let l:close = l:i
      break
    endif
  endfor
  if l:close < 0
    return
  endif
  for l:i in range(2, l:close - 1)
    if getline(l:i) =~# '^updated:'
      call setline(l:i, 'updated: ' . strftime('%Y%m%d%H%M'))
      return
    endif
  endfor
endfunction

augroup mikevim_notes
  autocmd!
  autocmd BufWritePre *.md call s:UpdateFrontmatterTimestamp()
augroup END
