-- lualine.nvim — statusline
-- https://github.com/nvim-lualine/lualine.nvim

-- kanagawa palette for statusline accents. Safe to call here: init.lua loads
-- the kanagawa colorscheme before this file, so the theme can be inferred.
local palette = require("kanagawa.colors").setup().palette

require("lualine").setup({
  options = {
    globalstatus = true, -- single statusline shared across all splits
  },
  sections = {
    lualine_c = { { "filename", path = 1 } }, -- relative path instead of filename only
    lualine_x = {
      {
        -- macro recording indicator ("recording @q"). noice skips the default
        -- msg_showmode message, so surface it here instead. Deferred to render
        -- time so it works regardless of noice/lualine setup order.
        function()
          return require("noice").api.statusline.mode.get()
        end,
        cond = function()
          return package.loaded["noice"] and require("noice").api.statusline.mode.has()
        end,
        color = { fg = palette.roninYellow },
      },
      "searchcount",
      "encoding",
      "fileformat",
      "filetype",
    },
    lualine_y = { "lsp_status", "progress" }, -- lsp_status: shows active server + progress spinner
  },
})
