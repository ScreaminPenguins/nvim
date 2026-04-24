-- lazydev.nvim — Lua development environment for Neovim config/plugin work
-- https://github.com/folke/lazydev.nvim

require("lazydev").setup({
  library = {
    -- Load luvit (vim.uv) types when "vim.uv" appears in the file
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  },
})
