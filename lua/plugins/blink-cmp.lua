-- blink.cmp — completion engine
-- https://github.com/saghen/blink.cmp

require("blink.cmp").setup({
  keymap = { preset = "super-tab" },

  -- auto_show defaults to true — explicitly disabled here
  completion = {
    documentation = { auto_show = false },
  },

  sources = {
    per_filetype = {
      lua = { inherit_defaults = true, "lazydev" },
      -- vim-dadbod-completion: table/column completion in DB buffers.
      sql = { inherit_defaults = true, "dadbod" },
      mysql = { inherit_defaults = true, "dadbod" },
      plsql = { inherit_defaults = true, "dadbod" },
    },
    providers = {
      lazydev = {
        name = "LazyDev",
        module = "lazydev.integrations.blink",
        score_offset = 100, -- float lazydev items above LSP items in lua buffers
      },
      dadbod = {
        name = "Dadbod",
        module = "vim_dadbod_completion.blink",
      },
    },
  },

  fuzzy = { implementation = "prefer_rust" },
})
