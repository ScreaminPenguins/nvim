-- lualine.nvim — statusline
-- https://github.com/nvim-lualine/lualine.nvim

require("lualine").setup({
  options = {
    globalstatus = true, -- single statusline shared across all splits
  },
  sections = {
    lualine_c = { { "filename", path = 1 } }, -- relative path instead of filename only
    lualine_x = { "searchcount", "encoding", "fileformat", "filetype" },
    lualine_y = { "lsp_status", "progress" }, -- lsp_status: shows active server + progress spinner
  },
})
