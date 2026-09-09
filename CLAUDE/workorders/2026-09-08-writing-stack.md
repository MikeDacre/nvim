# Work order — prose / writing stack (FINAL)

Date: 2026-09-08 · Raised in: claude.ai Project chat · Execute in: Claude Code
Branch: cut `feat/writing-stack` from `dev`
Status: design verified end-to-end against a full clone; see "Verified" below.

## Goal

Dual-editor writing mode: distraction-free editing, sidebar document switching,
spellcheck + autocorrect with toggles, and Obsidian support that activates **if
and only if** the file is inside a vault. Every change must work in plain Vim 9
and Neovim 0.12.

## Decisions (user, 2026-09-08)

- `lervag/wiki.vim` replaces `obsidian.nvim` outright — it is dual-editor.
  It needs Vim 9.1+ / nvim 0.10+; remote Debian boxes on Vim 9.0 simply do not
  get it, which is fine because those machines are for code, not prose.
- Only vault is `~/Ansetl`, on **rincewind only**. It must NOT be hardcoded in
  this public repo: detection is by `.obsidian/` marker, `$OBSIDIAN_VAULT` is
  the per-machine fallback, set in rincewind's zshrc outside this repo.
- `vimwiki` is removed. It holds no data and its only observable effect is a
  bug (see Bug 1).
- Zen mode is `goyo.vim` + `limelight.vim`; the Neovim-only pair goes.
- Sidebar needs no new plugin: NERDTree, fzf.vim and tagbar are already here.

## Bugs found while designing this — all reproduced, all fixed below

Every one of these was hit in testing, not reasoned about. Six of the eight
would have shipped silently.

1. **vimwiki hijacks every markdown buffer.** With no `g:vimwiki_list`,
   `g:vimwiki_ext2syntax` still defaults to mapping `.md`/`.mkdn`/`.markdown`
   to markdown, and `g:vimwiki_global_ext` defaults to 1, so
   `vimwiki#u#ft_set()` (`autoload/vimwiki/u.vim:245`) sets
   `filetype=vimwiki` on any markdown file anywhere on disk. Consequence:
   every `FileType markdown` autocmd in the config is starved, and
   `preservim/vim-markdown` — declared `{'for': 'markdown'}` — has never
   loaded at all. Removing vimwiki fixes it; `g:vimwiki_global_ext = 0` is the
   equivalent fix if it is ever reinstated.

2. **`:WikiEnable` is defined without `-bar`.** `autocmd BufRead *.md if
   ... | WikiEnable | endif` raises **E488: Trailing characters** — the
   command eats `| endif`. It must be called from inside a function body.

3. **`if exists(':Limelight') | Limelight | endif` raises E171.** Same class,
   different cause: vim-plug's lazy-load stub for an `'on'` command is created
   without `-bar` even though limelight's real command has it. Reproduced in
   both editors. Any user command invoked between bars in this config is
   suspect — write it multi-line.

4. **`g:wiki_root` cannot hold a Funcref.** It is a lowercase variable name, so
   `let g:wiki_root = function('s:WikiRoot')` raises **E704: Funcref variable
   name must start with a capital**. wiki.vim resolves it with
   `exists('*' . name)`, so the root function must be **global** and passed by
   name as a string.

5. **`g:wiki_global_load = 0` does not scope wiki.vim to vaults.** Its gate is
   `wiki#get_root_local() ==# wiki#get_root_global()`, and `get_root_local()`
   searches for `index.md` **relative to cwd**, not to the file. Two failures
   fall out of that:
   - inside a vault with no `index.md`, wiki.vim never activates at all;
   - outside a vault, if `MikevimWikiRoot()` returns `''` then
     `get_root_global()` resolves to the **cwd**, so any markdown file opened
     while cwd holds an `index.md` activates wiki.vim. A Hugo page bundle is
     exactly that shape, and Hugo support is on the roadmap. Reproduced: with
     cwd `content/post/bundle/`, `doc.md` came up with `b:wiki` set.

   Fix: activate from our own autocmd, and have the root function return an
   **empty sentinel directory** rather than `''` when outside a vault, so
   wiki.vim's own gate can never match by accident. Verified: activates only
   in the vault, from any cwd, in both editors.

6. **`g:wiki_filetypes = []` is not a valid way to silence wiki.vim's own
   autocmd.** It works for gating, but `g:wiki_filetypes[0]` is indexed in
   `link.vim:254`, `graph/builder.vim:36`, `toc.vim:369` and
   `journal.vim:303` — an empty list means E684 on link creation, TOC and
   journal. Rejected; do not reach for it.

7. **`scripts/check.local.sh`'s plugged-parity parser mis-parses a non-nvim
   `if`.** It recognises `if has('nvim')`, `if !has('nvim')` and
   `if g:vim_minimal`, and anything else falls through — but the matching
   `endif` still pops the stack, so the enclosing guard is dropped early. With
   the wiki.vim version guard the current output is accidentally still correct,
   but it is fragile, and on a Vim 9.0 machine it reports a false
   `vim missing: wiki.vim`. Fix in Phase 5.

8. **`vim-pencil` pollutes `v:errmsg` with E216.** It runs
   `sil! au! pencil_autoformat * <buffer>` (`autoload/pencil.vim:175`) against
   a group it never creates when `g:pencil#autoformat = 0`. `silent!` hides the
   message but not `v:errmsg`, so `check.local.sh` will report
   **E216: No such group or event: pencil_autoformat** as a WARN. Cosmetic and
   pre-existing. Document it; do not "fix" it by flipping autoformat.

## Verified

Method: shallow clones in `/tmp/wtest`, then a full `git clone` of this repo to
`/tmp/nvimtest` with a `plugged/` symlink farm (the 51 existing plugins minus
the six being dropped, plus the four new ones), the real `init.vim` and
`plugins.vim` patched to the end state, and both editors run against it.

- **Both editors load the end-state config clean**: `vim -es -N -u init.vim`
  and `nvim --headless -u init.vim` both exit 0 with empty `v:errmsg` and no
  `E<n>:` on stderr.
- **Gating matrix**, identical in Vim 9.1 and nvim 0.12.5:

  | file | cwd | `b:wiki` |
  |---|---|---|
  | `vault/sub/note.md` | outside the vault | 1 |
  | `vault/sub/note.md` | inside the vault | 1 |
  | `outside/plain.md` | plain dir | 0 |
  | `hugo/content/post/bundle/index.md` | the bundle dir | 0 |

- **Filetype**: `ft=markdown` on every markdown buffer once vimwiki is gone.
- **Prose init**: `&l:spell=1`, `&l:wrap=1`, 322 buffer-local abbreviations.
- **Autocorrect toggle** round-trips 322 -> 0 -> 322 in both editors.
- **Goyo**: `:Goyo` / `:Goyo!` clean, tabs 2 -> 1, `laststatus` restored (1 in
  Vim, 2 in nvim), no errors after the Bug 3 fix.
- **NERDTree + Goyo**: `:NERDTree`, `:Goyo`, `:Goyo!` -> windows 2 -> 5 -> 2,
  one tab, editor alive, no error. The two `BufEnter ... :quit` NERDTree
  autocmds (`init.vim:331,334`) do not misfire.
- **Mapping inventory** in a vault markdown buffer: wiki.vim's `\k*` set,
  vim-markdown's header motions and gitgutter's `\h*` coexist with no clash.
  wiki.vim does claim `<CR>` and `<Tab>` in normal mode, but only in vault
  buffers.
- **Spell dictionary needs no change**: `~/.vim` and `~/.config/nvim` are both
  symlinks to `~/nvim`, so the repo's `spell/en.utf-8.add` is on the
  runtimepath for both editors and its words test clean under
  `spelllang=en_us` even with `spellfile` empty.
- **Licences**, read from the LICENSE bodies: goyo, limelight, wiki.vim,
  vim-pencil, vim-litecorrect all MIT (GitHub reports NOASSERTION on the
  preservim ones because of the file's preamble).
- **Maintenance**, GitHub API 2026-09-08: `epwalsh/obsidian.nvim` last release
  v3.9.0 (2024-07-11), 196 open issues; `obsidian-nvim/obsidian.nvim` v3.16.7
  (2026-09-01), 50 open. wiki.vim last commit 2026-08-29; goyo 2025-12-21;
  limelight 2026-03-09.
- **vimwiki holds nothing**: no `~/vimwiki`, no `*.wiki` within five levels of
  `$HOME`, no `g:vimwiki_list`, no mapping, no cache. Checked on baboona only —
  see Residual risks.

## Phase 1 — correct PLUGINS.md (commit on its own)

The 2026-09-07 audit recorded `epwalsh/obsidian.nvim` as "verified, still
active". It is not; use the table above. In the same edit note that `reedes/*`
now 301-redirects to `preservim/*` — vim-plug follows it, so nothing was
broken, but the declaration was stale.

`fix(docs): correct obsidian.nvim maintenance status in PLUGINS.md`

## Phase 2 — plugins.vim

Replace the "Markdown writing" block (lines 65-75):

```vim
  " Prose / writing — all dual-editor (2026-09-08 audit)
  Plug 'preservim/vim-pencil'
  Plug 'preservim/vim-litecorrect'
  Plug 'junegunn/goyo.vim', { 'on': 'Goyo' }
  Plug 'junegunn/limelight.vim', { 'on': 'Limelight' }
  Plug 'preservim/vim-markdown', { 'for': 'markdown' }  " plasticboy transferred here
  if has('nvim-0.10') || has('patch-9.1.0')
    Plug 'lervag/wiki.vim'
  endif
  Plug 'MikeDacre/vim-checkbox'
```

Remove: `ravibrock/spellwarn.nvim` (clears the standing P1),
`epwalsh/obsidian.nvim`, `vimoutliner/vimoutliner`, `vimwiki/vimwiki`, and
`folke/twilight.nvim` + `folke/zen-mode.nvim` (lines ~97-98).

The `if has('nvim')` block at lines 69-72 becomes empty — delete the whole
block, do not leave a bare `if`/`endif`.

Drop the now-false comment at `lua/plugin_config.lua:10-11` ("obsidian.nvim
owns markdown link handling now") — wiki.vim does.

`refactor(plugins): dual-editor prose stack; drop nvim-only writing plugins`

## Phase 3 — init.vim

Replace the "Pencil and markdown" stanza (`init.vim:255-258`, inside the
existing `if g:vim_minimal == 0` block — it must stay inside it) with the
block below. This is the tested text; do not paraphrase it.

```vim
  " ---- Prose / writing -------------------------------------------------
  let g:pencil#autoformat = 0
  let g:pencil#wrapModeDefault = 'soft'
  let g:vim_markdown_frontmatter = 1
  let g:vim_markdown_toc_autofit = 1

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
  " Do NOT write `if ... | Limelight | endif`: vim-plug's lazy-load stub for an
  " 'on' command is defined without -bar, so the trailing `| endif` is eaten
  " and you get E171. Same trap as :WikiEnable above.
  function! s:GoyoEnter() abort
    if exists(':Limelight')
      Limelight
    endif
    setlocal spell
  endfunction
  function! s:GoyoLeave() abort
    if exists(':Limelight')
      Limelight!
    endif
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

Note on `iabclear <buffer>`: it clears **all** buffer-local abbreviations, not
only litecorrect's. Nothing else in this config sets any, so it is safe today —
if that changes, the toggle needs to be narrowed.

`feat(prose): zen mode, autocorrect toggle, vault-scoped wiki.vim`

## Phase 4 — dead code and stray files

- `functions.vim:218-241`: delete the commented-out `WordProcessorMode()` block
  and its `com! WordProcessor` line. Phase 3 supersedes it.
- `.obsidian.vim` in the repo root is an **Obsidian app** vim-mode keymap file,
  not editor config, and nothing sources it. Move it to `priv/` or delete —
  **ask first**, it is a user-authored file.

`chore: remove superseded WordProcessorMode stub`

## Phase 5 — fix the plugged-parity parser (Bug 7)

In `scripts/check.local.sh`, the parser currently ends its conditional handling
with:

```python
    if line.startswith('if g:vim_minimal'):
        cond_stack.append(None); continue
```

Generalise it so any unrecognised `if` still balances its `endif`:

```python
    if re.match(r'^if\b', line):
        cond_stack.append(None); continue
```

Keep it **after** the two `has('nvim')` cases so those still classify. Confirm
the output is unchanged on this machine (55 plugins, no missing) before and
after.

Also extend the comment above that block: a version-guarded `Plug` (the
wiki.vim case) is attributed to both editors, so on a Vim 9.0 machine this
check emits a false `vim missing: wiki.vim`. That is expected, not a fault.

`fix(check): balance non-nvim conditionals in the plugged-parity parser`

## Phase 6 — documentation

- `README.md`: add `<leader>z` (zen), `<leader>ss` (spell toggle), `<leader>sa`
  (autocorrect toggle) and the `<leader>k*` wiki.vim prefix (`\kw` index, `\kk`
  journal) to the mapping tables. State that wiki.vim loads only on Vim 9.1+ /
  nvim 0.10+ and activates only inside a `.obsidian/` vault, and that
  `$OBSIDIAN_VAULT` is the per-machine fallback. Then `make doc` — never
  hand-edit `doc/mikevim.txt` or `doc/tags`.
- `PLUGINS.md`: update the audit table for every add and removal; record the
  pencil E216 WARN (Bug 8); mark the `spellwarn.nvim` P1 resolved.
- `CLAUDE/project.json`: add the pencil E216 WARN as a hazard so it is not
  re-investigated.
- `ROADMAP.md`: "Collapse the note stack (vimwiki / vimoutliner / riv /
  obsidian.nvim)" is fully closed by this work order — propose moving it to
  Done, don't reword it.
- `python3 scripts/todo.py` for follow-ups. Never hand-edit TODO.txt.

## Acceptance tests

Headless, both editors:

1. `bash scripts/check.sh` — passes. Expect one new WARN (E216, Bug 8), plus
   the pre-existing `fd`/`rg` WARNs on machines without them.
2. `vim -c 'q'` and `nvim -c 'q'` — clean start.
3. `VIM_MINIMAL=true vim -c 'q'` — still clean; none of this is in the minimal
   path.
4. Open a plain `.md` outside any vault: `:echo &ft` is `markdown`, not
   `vimwiki`. **This gates every prose autocmd — check it first.**
5. Reproduce the Bug 5 trap: `mkdir -p /tmp/t && touch /tmp/t/index.md
   /tmp/t/doc.md`, `cd /tmp/t`, open `doc.md`, `:echo exists('b:wiki')` is 0.
6. Open a `.md` inside a vault from a cwd outside it:
   `:echo exists('b:wiki')` is 1, `&l:spell` is 1, `&l:wrap` is 1.
7. `:Goyo` then `:Goyo!` — no errors, `laststatus` restored.
8. `\sa` twice — abbreviation count drops to zero and comes back.
9. `\kw` opens the wiki index inside a vault.

Interactive, in MacVim and in a real terminal — headless cannot confirm these:

10. `\z` dims the surrounding paragraphs (limelight needs syntax and conceal in
    a real screen; `exists('#limelight')` read 0 under `vim -es`, which is
    probably a headless artifact but has not been confirmed).
11. `:NERDTreeToggle` still opens on the left, and Goyo -> pick a file ->
    Goyo behaves sanely. Goyo tears down other windows by design, so a sidebar
    and zen mode are mutually exclusive; that is expected.

Then `:PlugInstall` from **both** editors, and ask the user before
`:PlugClean` — it is a gated command, and running it from the wrong editor has
deleted the other editor's plugins here before (2026-09-07).

## Residual risks

- **vimwiki data on rincewind was not checked.** Run
  `find ~ -maxdepth 5 -name '*.wiki'` there before `:PlugClean`. If files turn
  up they still open as plain text, and wiki.vim reads them if `'wiki'` is
  added to `g:wiki_filetypes`.
- **`~/Ansetl` was never opened.** Vault detection was tested against a
  synthetic `.obsidian/` directory, not the real vault. Test 6 on rincewind is
  the real proof.
- **`g:mikevim_wiki_none` creates `~/.cache/mikevim/no-wiki` on first markdown
  open outside a vault.** Deliberate, idempotent, and the only filesystem side
  effect this work order introduces.
- **`<leader>kw` outside a vault** opens an index inside the sentinel
  directory rather than doing nothing. Harmless but odd; on rincewind
  `$OBSIDIAN_VAULT` makes it open the real vault index instead.

## Out of scope

Per-project prose behaviour — Hugo content directories, vaults, multi-chapter
manuscripts — driven by root detection is a separate, larger design. Do not
start it here. `MikevimWikiRoot()` is the marker-search seed it will build on,
and Bug 5 is the evidence that the detection has to be per-file, not per-cwd.
