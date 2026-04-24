-- conform.nvim — code formatter
-- https://github.com/stevearc/conform.nvim

require("conform").setup({
  default_format_opts = {
    lsp_format = "fallback",
  },
  formatters_by_ft = {
    json = { "prettier" },
    lua = { "stylua" }, -- was "sylua" (typo)
    markdown = { "prettier" },
    python = { "ruff_format" },
    yaml = { "prettier" },
  },
})
