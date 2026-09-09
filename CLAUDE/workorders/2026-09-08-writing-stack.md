# Work order — prose / writing stack

Date: 2026-09-08 · Raised in: claude.ai Project chat · Execute in: Claude Code
Branch: cut `feat/writing-stack` from `dev` (`bash scripts/feature.sh new writing-stack`)

## Goal

A dual-editor writing mode: distraction-free "zen" editing, a left sidebar for
switching documents, spellcheck + autocorrect with toggles, and Obsidian vault
support that activates **if and only if** the file is inside a vault.

## Decisions (user, 2026-09-08)

- `lervag/wiki.vim` replaces `obsidian.nvim` outright. Markdown writing happens
  in MacVim/Neovim; wiki.vim requires Vim 9.1+ / nvim 0.10+ and that is fine —
  remote Debian boxes on Vim 9.0 are for code, not prose.
- Only vault: `~/Ansetl`, on **rincewind only**. Do not hardcode it in this
  public repo — detection is by `.obsidian/` marker, with `$OBSIDIAN_VAULT` as
  the per-machine fallback (set in rincewind's zshrc, outside this repo).
- Zen mode is `goyo.vim` + `limelight.vim`; the Neovim-only pair goes.

## Already verified — do not redo

All of the following was run on baboona against Vim 9.1 and nvim 0.12.5 with
isolated `-u` rc files and shallow clones in `/tmp/wtest`:

- `WikiRoot()` returns the vault root for a file inside a vault and `''`
  outside, in both editors, with cwd deliberately elsewhere.
- `g:wiki_global_load = 0` **alone is not enough**. wiki.vim's own gate enables
  a buffer only when `wiki#get_root_local() ==# wiki#get_root_global()`, and
  `get_root_local()` searches for an `index.md` **relative to cwd**, not to the
  file. In an Obsidian vault with no `index.md` it never matches. The explicit
  `s:VaultEnable()` autocmd below is the working mechanism — it was tested and
  gives `b:wiki` set inside the vault, unset outside, no errors, both editors.
- `WikiEnable` has no `-bar`, so `if ... | WikiEnable | endif` raises E488.
  It must be called from inside a function body. (Tested; this is why the
  autocmd calls `s:VaultEnable()` rather than inlining the condition.)
- wiki.vim's default `g:wiki_mappings_prefix` is `<leader>w`, which collides
  with the existing `<Leader>ww` -> `ToggleWrap()` (`functions.vim:216`).
  wiki.vim silently skips mappings that already exist, so WikiIndex would just
  never bind. Prefix moved to `<leader>k` (verified free against every
  `<leader>` mapping in the repo). `<leader>z`, `<leader>ss`, `<leader>sa`
  verified free too.
- `vim-litecorrect` installs 322 buffer-local insert abbreviations, identical
  in both editors. The `iabclear <buffer>` / `litecorrect#init()` toggle was
  tested: 322 -> 0 -> 322.
- `Goyo` / `Goyo!` run clean in both editors and restore `laststatus`
  correctly (1 in Vim, 2 in nvim).
- Licences confirmed by reading the LICENSE bodies: goyo, limelight, wiki.vim
  = MIT; vim-pencil, vim-litecorrect, vim-lexical = MIT (GitHub reports
  NOASSERTION because the file is named `License` with a preamble).
- **vimwiki currently hijacks every `.md` buffer.** With no `g:vimwiki_list`,
  vimwiki's `g:vimwiki_ext2syntax` still defaults to mapping `.md` -> markdown,
  so `vimwiki#u#ft_set()` (autoload/vimwiki/u.vim:245) sets `filetype=vimwiki`
  on any markdown file, anywhere. Reproduced against the live config in both
  editors. `let g:vimwiki_global_ext = 0` restores `filetype=markdown`;
  verified in both editors. See Phase 2a — this is a required fix, not an
  option.
- Spellfile needs no change: `~/.vim` and `~/.config/nvim` are both symlinks to
  `~/nvim`, so `zg` already writes to the repo's `spell/en.utf-8.add` in both
  editors.

## Known benign noise

`vim-pencil` runs `sil! au! pencil_autoformat * <buffer>` (autoload/pencil.vim
:175) against a group it never created when `g:pencil#autoformat = 0`. `silent!`
suppresses display but not `v:errmsg`, so **E216: No such group or event:
pencil_autoformat** will show up in `check.sh` as a WARN from now on. It is
cosmetic and pre-existing (the config has set `g:pencil#autoformat = 0` since
before this work order). Record it in `PLUGINS.md` as a known WARN; do not
"fix" it by changing the autoformat setting.

## Phase 1 — correct the PLUGINS.md obsidian.nvim row (commit on its own)

The 2026-09-07 audit recorded `epwalsh/obsidian.nvim` as "verified, still
active". GitHub API, 2026-09-08:

| repo | last commit | latest release | open issues |
|---|---|---|---|
| `epwalsh/obsidian.nvim` | 2026-04-12 | v3.9.0 (2024-07-11) | 196 |
| `obsidian-nvim/obsidian.nvim` | 2026-09-06 | v3.16.7 (2026-09-01) | 50 |

Correct that row. Also note in the same edit that `reedes/*` now 301-redirects
to `preservim/*` — vim-plug follows the redirect, so nothing was broken, but
the declaration was stale.

`fix(docs): correct obsidian.nvim maintenance status in PLUGINS.md`

## Phase 2 — plugins.vim

Replace the "Markdown writing" block (currently lines 62-75):

```vim
  " Prose / writing — all dual-editor (2026-09-08 audit)
  Plug 'preservim/vim-pencil'                        " was reedes/*, now a 301
  Plug 'preservim/vim-litecorrect'                   " insert-mode autocorrect
  Plug 'junegunn/goyo.vim',      { 'on': 'Goyo' }
  Plug 'junegunn/limelight.vim', { 'on': 'Limelight' }
  Plug 'preservim/vim-markdown', { 'for': 'markdown' }
  " wiki.vim needs Vim 9.1+ / nvim 0.10+. Older remote Vim simply doesn't get
  " it — those machines are for code, not prose (user decision 2026-09-08).
  if has('nvim-0.10') || has('patch-9.1.0')
    Plug 'lervag/wiki.vim'
  endif
  Plug 'MikeDacre/vim-checkbox'
  Plug 'vimwiki/vimwiki'
```

Removals in this phase:
- `ravibrock/spellwarn.nvim` — clears the standing P1 (unguarded Lua into Vim 9)
- `epwalsh/obsidian.nvim` — superseded by wiki.vim
- `vimoutliner/vimoutliner` — overlap, unmaintained since 2023
- `folke/twilight.nvim` and `folke/zen-mode.nvim` (lines ~97-98) — duplicated by
  goyo/limelight, nvim-only

The `if has('nvim')` block at lines 69-72 becomes empty — delete it entirely,
don't leave a bare `if`/`endif`.

Also drop the now-false comment in `lua/plugin_config.lua:10-11`
("obsidian.nvim owns markdown link handling now") — wiki.vim does.

`refactor(plugins): dual-editor prose stack; drop nvim-only writing plugins`

## Phase 2a — stop vimwiki claiming every markdown buffer (REQUIRED)

In `init.vim`, before anything markdown-related:

```vim
  " vimwiki's ext2syntax maps .md -> markdown by default, which makes it set
  " filetype=vimwiki on EVERY markdown buffer, anywhere on disk. That starves
  " every `FileType markdown` autocmd in this config. Scope it to its own
  " wiki paths.
  let g:vimwiki_global_ext = 0
```

Without this, the `augroup mikevim_prose` autocmd in Phase 3 never fires,
because `FileType markdown` never happens: no pencil, no litecorrect, no spell.
`vim-markdown` (declared `{'for': 'markdown'}`) never loads either. wiki.vim is
unaffected — its trigger is `BufRead *.md`, a file pattern, not a filetype.

`fix(markdown): scope vimwiki to its own paths (g:vimwiki_global_ext)`

## Phase 3 — init.vim

Inside the existing `if g:vim_minimal == 0` block, replace the four-line
"Pencil and markdown" stanza (lines ~255-258) with:

```vim
  " ---- Prose / writing -------------------------------------------------
  let g:pencil#autoformat = 0
  let g:pencil#wrapModeDefault = 'soft'
  let g:vim_markdown_frontmatter = 1
  let g:vim_markdown_toc_autofit = 1

  " Obsidian: wiki.vim activates if and only if the file sits under a
  " directory containing .obsidian/. $OBSIDIAN_VAULT is the per-machine
  " fallback so the index mapping works from anywhere on that machine.
  function! WikiRoot() abort
    let l:marker = finddir('.obsidian', expand('%:p:h') . ';')
    if !empty(l:marker)
      return fnamemodify(l:marker, ':p:h:h')
    endif
    return (!empty($OBSIDIAN_VAULT) && isdirectory($OBSIDIAN_VAULT))
          \ ? $OBSIDIAN_VAULT : ''
  endfunction

  let g:wiki_root            = 'WikiRoot'
  let g:wiki_global_load     = 0
  let g:wiki_filetypes       = ['md']
  let g:wiki_mappings_prefix = '<leader>k'   " <leader>w is ToggleWrap

  " WikiEnable has no -bar, so it cannot be inlined in an `if ... | ... |`
  function! s:VaultEnable() abort
    if exists(':WikiEnable') && !empty(WikiRoot())
      WikiEnable
    endif
  endfunction

  function! s:ProseInit() abort
    call pencil#init({'wrap': 'soft'})
    call litecorrect#init()
    let b:mikevim_autocorrect = 1
    setlocal spell spelllang=en_us
  endfunction

  function! s:AutocorrectToggle() abort
    if get(b:, 'mikevim_autocorrect', 0)
      iabclear <buffer>
      let b:mikevim_autocorrect = 0
    else
      call litecorrect#init()
      let b:mikevim_autocorrect = 1
    endif
    echo 'autocorrect ' . (b:mikevim_autocorrect ? 'on' : 'off')
  endfunction
  command! AutocorrectToggle call s:AutocorrectToggle()

  augroup mikevim_prose
    autocmd!
    autocmd FileType markdown,rst,text,mail call s:ProseInit()
    autocmd BufRead,BufNewFile *.md call s:VaultEnable()
  augroup END

  " Zen mode — goyo drives limelight
  let g:goyo_width = 90
  let g:limelight_conceal_ctermfg = 'gray'
  let g:limelight_conceal_guifg   = '#777777'
  function! s:GoyoEnter() abort
    if exists(':Limelight') | Limelight | endif
    setlocal spell
  endfunction
  function! s:GoyoLeave() abort
    if exists(':Limelight') | Limelight! | endif
  endfunction
  augroup mikevim_goyo
    autocmd!
    autocmd User GoyoEnter nested call s:GoyoEnter()
    autocmd User GoyoLeave nested call s:GoyoLeave()
  augroup END

  nnoremap <leader>z  :Goyo<CR>
  nnoremap <leader>ss :setlocal spell!<CR>:setlocal spell?<CR>
  nnoremap <leader>sa :AutocorrectToggle<CR>
```

`feat(prose): zen mode, autocorrect toggle, vault-scoped wiki.vim`

## Phase 4 — dead code and stray files

- `functions.vim:218-241`: delete the commented-out `WordProcessorMode()` block
  and its `com! WordProcessor` line. Phase 3 supersedes it entirely.
- `.obsidian.vim` in the repo root is an **Obsidian app** vim-mode keymap file,
  not part of the editor config, and it is not sourced by anything. It does not
  belong on the runtimepath. Move it to `priv/` or delete it — **ask before
  deleting**, it is a user-authored file.

`chore: remove superseded WordProcessorMode stub`

## Phase 5 — documentation

- `README.md`: add the new mappings to the mapping tables — `<leader>z` (zen),
  `<leader>ss` (spell toggle), `<leader>sa` (autocorrect toggle), `<leader>k*`
  (wiki.vim prefix; `<leader>kw` index, `<leader>kk` journal). Note that
  wiki.vim only loads on Vim 9.1+/nvim 0.10+ and only activates inside a vault.
  Then `make doc` — never hand-edit `doc/mikevim.txt` or `doc/tags`.
- `PLUGINS.md`: update the audit table for every add/remove above; record the
  E216 pencil WARN; mark the P1 `spellwarn.nvim` line resolved.
- `CLAUDE/project.json`: nothing to change unless a hazard is added — consider
  adding the pencil E216 WARN as a hazard so it is not re-investigated.
- `ROADMAP.md`: "Collapse the note stack (vimwiki / vimoutliner / riv /
  obsidian.nvim)" is now mostly done — propose moving it to Done, don't reword.
- `python3 scripts/todo.py` for any follow-ups. Do not hand-edit TODO.txt.

## Open decision — do not act without asking

`vimwiki` is kept, with Phase 2a scoping it to its own wiki paths. Removing it
entirely remains the bigger consolidation win and would close the ROADMAP note-
stack item outright, but it is a behaviour change the user has not approved.
Note that Phase 2a is required either way: if vimwiki stays, it needs the
scoping; if it goes, the hijack goes with it.

## Acceptance tests

Run these before `session.sh end`:

1. `bash scripts/check.sh` — passes. Expect one new WARN (E216, above).
2. `vim -c 'q'` and `nvim -c 'q'` — clean start, no errors.
3. In each editor, open a plain `.md` file **outside** any wiki:
   `:echo &ft` is `markdown`, not `vimwiki`. This is the Phase 2a regression
   test and it gates every prose autocmd.
4. In each editor, open a `.md` file **inside** a vault: `:echo exists('b:wiki')`
   is 1, `:echo &l:spell` is 1, `:echo &l:wrap` is 1.
5. Same, **outside** a vault: `:echo exists('b:wiki')` is 0.
6. `:Goyo` then `:Goyo!` — no errors, `laststatus` restored.
7. `\sa` twice — abbreviation count drops to zero and comes back.
8. `\kw` opens the wiki index inside a vault.
9. `VIM_MINIMAL=true vim -c 'q'` — still clean (none of this is in the minimal
   path).
