vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  settings = {
    Lua = {
      completion = { enable = true },
    },
  },
})

vim.lsp.enable("lua_ls")
