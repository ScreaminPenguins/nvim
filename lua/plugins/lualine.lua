-- https://github.com/nvim-lualine/lualine.nvim
return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        icons_enabled = true,
        theme = "palenight",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        globalstatus = false,
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 2 }, "encoding", "filesize" },
        lualine_x = { { "filetype", icon_only = false } },
        lualine_y = { "location", "progress" },
        lualine_z = {
          { "datetime", style = "%Y-%m-%d %H:%M:%S (%Z)" },
        },
      },
    },
  },
}
