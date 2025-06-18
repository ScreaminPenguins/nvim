vim.lsp.config("ruff", {
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
  settings = {},
})
vim.lsp.enable("ruff")
