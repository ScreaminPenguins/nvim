-- kanagawa.nvim — colorscheme
-- https://github.com/rebelot/kanagawa.nvim
--
-- Full option reference:
-- https://github.com/rebelot/kanagawa.nvim#configuration
require("kanagawa").setup({
  commentStyle = { italic = false },
  keywordStyle = { italic = false },
  -- Make the divider line between window splits high-contrast and easy to see.
  overrides = function(colors)
    return {
      WinSeparator = { fg = colors.palette.oniViolet, bold = true },
    }
  end,
})

vim.cmd("colorscheme kanagawa")
