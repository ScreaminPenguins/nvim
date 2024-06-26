return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  init = function()
    vim.g.lualine_laststatus = vim.o.laststatus
    if vim.fn.argc(-1) > 0 then
      -- set an empty statusline till lualine loads
      vim.o.statusline = " "
    else
      -- hide the statusline on the starter page
      vim.o.statusline = 0
    end
  end,
  opts = function()
    -- Do I need this?
    local lualine_require = require("lualine_require")
    lualine_require.require = require

    local icons = LazyVim.config.icons

    vim.o.laststatus = vim.g.lualine_laststatus

    local opts = {
      options = {
        theme = "auto",
        globalstatus = vim.o.laststatus == 3, -- Dafuq
        disabled_filetypes = { statusline = {} },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },

        lualine_c = {
          LazyVim.lualine.root_dir(),
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
          { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
          { LazyVim.lualine.pretty_path() },
        },
        lualine_x = {
          -- stylua: ignore
          {
            function() return require("noice").api.status.command.get() end,
            cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
            color = function() return LazyVim.ui.fg("Statement") end,
          },
          -- stylua: ignore
          {
            function() return require("noice").api.status.mode.get() end,
            cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
            color = function() return LazyVim.ui.fg("Constant") end,
          },
          -- stylua: ignore
          {
            function() return "  " .. require("dap").status() end,
            cond = function() return package.loaded["dap"] and require("dap").status() ~= "" end,
            color = function() return LazyVim.ui.fg("Debug") end,
          },
          -- stylua: ignore
          {
            require("lazy.status").updates,
            cond = require("lazy.status").has_updates,
            color = function() return LazyVim.ui.fg("Special") end,
          },
          {
            "diff",
            symbols = {
              added = icons.git.added,
              modified = icons.git.modified,
              removed = icons.git.removed,
            },
            source = function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns then
                return {
                  added = gitsigns.added,
                  modified = gitsigns.changed,
                  removed = gitsigns.removed,
                }
              end
            end,
          },
        },
        lualine_y = {
          { "progress", separator = " ", padding = { left = 1, right = 0 } },
          { "location", padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          { "datetime", style = "%Y-%m-%d %H:%M:%S (%Z)" },
          -- function()
          --   return " " .. os.date("%R")
          -- end,
        },
      },
    }
    extensions = { "neo-tree", "lazy" }
    return opts
  end,
  -- dependencies = { "nvim-tree/nvim-web-devicons" },
  -- config = function()
  --   require("lualine").setup({
  --     options = {
  --       icons_enabled = true,
  --       theme = "auto",
  --       component_separators = { left = "", right = "" },
  --       section_separators = { left = "", right = "" },
  --       disabled_filetypes = {
  --         statusline = {},
  --         winbar = {},
  --       },
  --       ignore_focus = {},
  --       always_divide_middle = true,
  --       globalstatus = false,
  --       refresh = {
  --         statusline = 1000,
  --         tabline = 1000,
  --         winbar = 1000,
  --       },
  --     },
  --     sections = {
  --       lualine_a = { "mode" },
  --       lualine_b = { "branch", "diff", "diagnostics" },
  --       lualine_c = { "filename" },
  --       -- lualine_w = { "encoding", "fileformat", "filetype" },
  --       lualine_x = { "progress" },
  --       lualine_y = { "location" },
  --       lualine_z = { { "datetime", style = "%Y-%m-%d %H:%M:%S (%Z)" } },
  --     },
  --     inactive_sections = {
  --       lualine_a = {},
  --       lualine_b = {},
  --       lualine_c = { "filename" },
  --       lualine_x = { "location" },
  --       lualine_y = {},
  --       lualine_z = {},
  --     },
  --     tabline = {},
  --     winbar = {},
  --     inactive_winbar = {},
  --     extensions = {},
  --   })
  -- end,
}
