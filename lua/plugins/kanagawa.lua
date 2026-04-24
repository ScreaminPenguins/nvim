-- kanagawa.nvim — colorscheme
-- https://github.com/rebelot/kanagawa.nvim
--
-- Full option reference:
-- https://github.com/rebelot/kanagawa.nvim#configuration
require("kanagawa").setup({
  commentStyle = { italic = false },
  keywordStyle = { italic = false },
})

vim.cmd("colorscheme kanagawa")
