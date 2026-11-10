" ---- Prose / writing -------------------------------------------------
let g:pencil#autoformat = 0
let g:pencil#wrapModeDefault = 'soft'
let g:vim_markdown_frontmatter = 1
" vim-markdown re-applies its own foldexpr on every InsertLeave/CursorHold;
" MikevimMdFoldexpr (below) wraps it instead.
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_toc_autofit = 1
let g:marked_app = "/Applications/Marked.app"

" Obsidian: wiki.vim activates iff the file sits under a .obsidian/ vault.
" g:wiki_root is lowercase so it CANNOT hold a Funcref (E704) — wiki.vim
" resolves it with exists('*'.name), so this function must be global.
" Outside a vault it returns an empty sentinel directory, never '': '' makes
" wiki.vim resolve the global root to the cwd, and its own gate then fires
" for any markdown file opened while cwd holds an index.md (a Hugo page
" bundle, for instance).
let g:mikevim_wiki_none = expand('~/.cache/mikevim/no-wiki')
function! MikevimWikiRoot() abort
  let l:marker = finddir('.obsidian', expand('%:p:h') . ';')
  if !empty(l:marker)
    return fnamemodify(l:marker, ':p:h:h')
  endif
  if !empty($OBSIDIAN_VAULT) && isdirectory($OBSIDIAN_VAULT)
    return $OBSIDIAN_VAULT
  endif
  if !isdirectory(g:mikevim_wiki_none)
    call mkdir(g:mikevim_wiki_none, 'p')
  endif
  return g:mikevim_wiki_none
endfunction

let g:wiki_root            = 'MikevimWikiRoot'
let g:wiki_global_load     = 0
let g:wiki_filetypes       = ['md']
let g:wiki_mappings_prefix = '<leader>k'   " <leader>w is ToggleWrap

" :WikiEnable has no -bar, so it cannot be inlined between | bars (E488).
function! s:VaultEnable() abort
  if exists(':WikiEnable') && !empty(finddir('.obsidian', expand('%:p:h') . ';'))
    WikiEnable
  endif
endfunction

" Vault detection is invisible otherwise — this is the "am I in a vault?"
" check for when \k mappings seem to do nothing.
function! s:WikiVaultStatus() abort
  let l:marker = finddir('.obsidian', expand('%:p:h') . ';')
  if !empty(l:marker)
    echo 'Obsidian vault: ' . fnamemodify(l:marker, ':p:h:h') . ' (.obsidian/ marker found)'
  elseif !empty($OBSIDIAN_VAULT) && isdirectory($OBSIDIAN_VAULT)
    echo 'Obsidian vault: ' . $OBSIDIAN_VAULT . ' ($OBSIDIAN_VAULT fallback)'
  else
    echo 'No Obsidian vault detected for this buffer — wiki.vim mappings are inactive'
  endif
endfunction
command! WikiVaultStatus call s:WikiVaultStatus()

function! s:ProseInit() abort
  " Markdown soft-wraps by default; other prose types stay unwrapped.
  call pencil#init({'wrap': &filetype ==# 'markdown' ? 'soft' : 'off'})
  call litecorrect#init()
  let b:mikevim_autocorrect = 1
  setlocal spell spelllang=en_us
endfunction

" ---- Write/Spell/AutoCorrect — independent toggles. SpellOn/Off never
" touches b:mikevim_autocorrect and vice versa, so either can run alone.
function! s:WriteOn() abort
  call pencil#init({'wrap': 'soft'})
  echo 'write mode on'
endfunction
function! s:WriteOff() abort
  call pencil#init({'wrap': 'off'})
  echo 'write mode off'
endfunction
command! WriteOn  call s:WriteOn()
command! WriteOff call s:WriteOff()
command! Write    WriteOn

" Full markdown render in a pane: glow(1) in a :terminal split. Vim 9's
" :terminal takes the same split modifiers as Neovim's, so one command
" works on both editors. Static render, not live-synced — rerun to refresh.
function! s:MdPreview() abort
  if !executable('glow')
    echohl WarningMsg
    echomsg '[mikevim] glow not found — brew install glow (see scripts/install.sh heavy)'
    echohl None
    return
  endif
  " List form: no shell quoting, so paths with spaces stay one argument
  " (Vim's :terminal does not understand shellescape()'s single quotes).
  " glow/compact.json is glamour's dark style minus the document margins
  " and heading padding. Open the pane first and word-wrap glow at its
  " real width: -w 0 makes the terminal itself break lines mid-word.
  let l:file = expand('%:p')
  vertical botright new
  let l:cmd = ['glow', '-s', g:vimdir_path . '/glow/compact.json',
        \ '-w', string(max([20, winwidth(0) - 5])), l:file]
  if has('nvim')
    call termopen(l:cmd)
  else
    call term_start(l:cmd, {'curwin': 1})
  endif
endfunction
command! MdPreview call s:MdPreview()

function! s:SpellOn() abort
  setlocal spell spelllang=en_us
  echo 'spell check on'
endfunction
function! s:SpellOff() abort
  setlocal nospell
  echo 'spell check off'
endfunction
command! SpellOn  call s:SpellOn()
command! SpellOff call s:SpellOff()
command! Spell    SpellOn

function! s:AutoCorrectOn() abort
  call litecorrect#init()
  let b:mikevim_autocorrect = 1
  echo 'autocorrect on'
endfunction
function! s:AutoCorrectOff() abort
  iabclear <buffer>
  let b:mikevim_autocorrect = 0
  echo 'autocorrect off'
endfunction
function! s:AutoCorrectToggle() abort
  if get(b:, 'mikevim_autocorrect', 0)
    call s:AutoCorrectOff()
  else
    call s:AutoCorrectOn()
  endif
endfunction
command! AutoCorrectOn     call s:AutoCorrectOn()
command! AutoCorrectOff    call s:AutoCorrectOff()
command! AutoCorrect       AutoCorrectOn
command! AutoCorrectToggle call s:AutoCorrectToggle()

" ---- Write-mode statusbar indicators ---------------------------------
" Global (not s:) so vim-airline's autoload parts and lualine's Lua
" components (vim.fn.*) can both call them: one definition of write-mode
" state instead of one per statusline plugin. "In write mode" reuses
" pencil's own b:pencil_wrap_mode rather than re-deriving it from
" filetype, so it tracks :WriteOn/:WriteOff exactly.
function! MikevimWriteModeActive() abort
  return exists('b:pencil_wrap_mode') && b:pencil_wrap_mode !=# 0
endfunction

" Font Awesome glyphs from the Nerd Font patched into guifont (DejaVu Sans
" Mono Nerd Font Mono) — book/pencil/check/xmark/save, codepoints verified
" against that font's own cmap (glyph names fa-book/fa-pencil/fa-check/
" fa-xmark/fa-save) before wiring these in, and rendered to a PNG and
" inspected, since a headless session can't otherwise confirm a PUA
" codepoint resolves to the intended shape.
function! MikevimSpellGlyph() abort
  return "" . (&spell ? "" : "")
endfunction

function! MikevimAutoCorrectGlyph() abort
  return "" . (get(b:, 'mikevim_autocorrect', 0) ? "" : "")
endfunction

" Replaces vim-airline's own section_a "SPELL" text (see the
" airline#parts#define_function('spell', ...) override below) — one
" compact cluster for both spell and autocorrect instead of a lone word.
function! MikevimSpellAutoCorrectStatus() abort
  if !MikevimWriteModeActive()
    return ''
  endif
  return MikevimSpellGlyph() . '/' . MikevimAutoCorrectGlyph()
endfunction

function! s:RelativeTime(epoch) abort
  let l:delta = localtime() - a:epoch
  if l:delta < 60
    return 'now'
  elseif l:delta < 3600
    return printf('%dm', l:delta / 60)
  elseif l:delta < 86400
    return printf('%dh', l:delta / 3600)
  else
    return printf('%dd', l:delta / 86400)
  endif
endfunction

function! MikevimLastSaveStatus() abort
  if !MikevimWriteModeActive()
    return ''
  endif
  if !exists('b:mikevim_last_save')
    return "" . 'unsaved'
  endif
  return "" . s:RelativeTime(b:mikevim_last_save) . (&modified ? '*' : '')
endfunction

function! MikevimWriteStatusline() abort
  if !MikevimWriteModeActive()
    return ''
  endif
  return join([MikevimSpellAutoCorrectStatus(), MikevimLastSaveStatus()], ' ')
endfunction

" Last line of a leading `---` frontmatter block, 0 if there is none.
function! s:FrontmatterEnd() abort
  if getline(1) !=# '---'
    return 0
  endif
  for l:i in range(2, min([line('$'), 200]))
    if getline(l:i) ==# '---'
      return l:i
    endif
  endfor
  return 0
endfunction

" vim-markdown's foldexpr plus one extra fold covering the frontmatter. The
" plugin's function is still called for every line: it tracks fenced-block
" and frontmatter state across consecutive lnums.
function! MikevimMdFoldexpr(lnum) abort
  let l:r = Foldexpr_markdown(a:lnum)
  let l:end = s:FrontmatterEnd()
  if l:end == 0 || a:lnum > l:end + 1
    return l:r
  elseif a:lnum <= l:end
    return a:lnum == 1 ? '>1' : a:lnum == l:end ? '<1' : '1'
  endif
  " First line after the block must not inherit the frontmatter's level.
  return (l:r ==# '=' || l:r ==# '-1') ? 0 : l:r
endfunction

function! s:MarkdownFoldInit() abort
  if exists('*Foldexpr_markdown')
    setlocal foldmethod=expr foldexpr=MikevimMdFoldexpr(v:lnum)
  endif
  setlocal foldenable foldlevel=99
endfunction

" Close the frontmatter fold once per buffer, on first display.
function! s:FoldFrontmatter() abort
  if &filetype !=# 'markdown' || get(b:, 'mikevim_fm_folded', 0)
    return
  endif
  let b:mikevim_fm_folded = 1
  if s:FrontmatterEnd() > 0
    silent! 1foldclose
  endif
endfunction

augroup mikevim_prose
  autocmd!
  autocmd FileType markdown,rst,text,mail call s:ProseInit()
  autocmd BufRead,BufNewFile *.md call s:VaultEnable()
  autocmd BufWritePost * let b:mikevim_last_save = localtime()
  autocmd FileType markdown nnoremap <buffer> <leader>mp :MdPreview<CR>
  " Heading folds stay open (foldlevel=99); only the YAML frontmatter starts
  " closed. zi toggles folding, zM/zc fold on demand.
  autocmd FileType markdown call s:MarkdownFoldInit()
  autocmd BufWinEnter *.md,*.markdown call s:FoldFrontmatter()
augroup END
