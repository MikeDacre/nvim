-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

-- nvim-tree.lua dropped in the 2026-09-07 plugin audit: nerdtree (init.vim)
-- is now the single dual file-tree answer for both editors.
-- nvim-mdlink dropped the same audit pass: wiki.vim (plugins.vim) owns
-- markdown link handling now, in both editors.

-- nvim-treesitter only joins the runtimepath once :PlugInstall has run for
-- nvim, so these requires must be guarded. Unguarded (as they were) a machine
-- without the plugin — a fresh clone before :PlugInstall, a git worktree,
-- which has no plugged/ at all — throws
--   E5108: module 'nvim-treesitter.install' not found
-- on every startup, and the error aborts the rest of this file. Absence is
-- not an error worth shouting about at startup; check.local.sh already
-- reports plugged/ drift as a WARN, which is where it belongs.
local ok_install, ts_install = pcall(require, "nvim-treesitter.install")
local ok_configs, ts_configs = pcall(require, "nvim-treesitter.configs")

if ok_install and ok_configs then
  -- prefer_git must be set before .setup{} below: ensure_installed installs
  -- run synchronously inside setup(), using whatever prefer_git is at that
  -- exact moment. Setting it after setup() (as this used to) means the
  -- first run always takes the curl+tar download path instead of git
  -- clone, and — if stdpath('data') ever points somewhere unexpected —
  -- leaves tree-sitter-*.tar.gz sitting wherever that curl ran.
  ts_install.prefer_git = true

  ts_configs.setup {
    -- A list of parser names, or "all" (the listed parsers MUST always be installed)
    -- "latex" excluded: this frozen nvim-treesitter fork marks it as needing
    -- generation from the grammar definition, which needs the tree-sitter CLI
    -- (not installed) — errors on every startup otherwise.
    ensure_installed = {"bash", "c", "cmake", "comment", "cpp", "css", "csv", "diff", "dockerfile", "editorconfig", "func", "git_config", "git_rebase", "gitattributes", "gitcommit", "gitignore", "go", "gpg", "html", "javascript", "jsdoc", "json", "json5", "llvm", "lua", "luadoc", "make", "markdown", "markdown_inline", "nginx", "objc", "objdump", "passwd", "perl", "php", "printf", "python", "query", "readline", "regex", "ruby", "sql", "ssh_config", "tmux", "todotxt", "typescript", "vim", "vimdoc", "xml", "yaml"},

    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,

    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,

    -- List of parsers to ignore installing (or "all")
    -- ignore_install = { "javascript" },

    ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
    -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

    highlight = {
      enable = true,

      -- Exactly one `disable` key. This table used to carry two — upstream's
      -- README example `disable = { "c", "rust" }` followed by the large-file
      -- function — and Lua keeps only the LAST value for a repeated key, so the
      -- c/rust list was dead code that never disabled anything. Dropped rather
      -- than honoured: "c" is deliberately in ensure_installed above (and "rust"
      -- is not), so disabling it was upstream boilerplate, not intent.
      -- NOTE: if a language is ever added here it is the parser name, not the
      -- filetype — "latex", not "tex".
      --
      -- Skip treesitter highlighting on large files; it is slow there and the
      -- regex syntax fallback is good enough.
      disable = function(lang, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        -- vim.loop is the deprecated alias; vim.uv is the name since 0.10.
        local uv = vim.uv or vim.loop
        local ok, stats = pcall(uv.fs_stat, vim.api.nvim_buf_get_name(buf))
        return (ok and stats and stats.size > max_filesize) or false
      end,

      -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
      -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
      -- Using this option may slow down your editor, and you may see some duplicate highlights.
      -- Instead of true it can also be a list of languages
      additional_vim_regex_highlighting = false,
    },
  }
end
