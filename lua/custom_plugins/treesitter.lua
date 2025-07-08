return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local configs = require("nvim-treesitter.configs")
      configs.setup({
        ensured_installed = {
          "c",
          "lua",
          "markdown",
          "python",
          "query",
          "sql",
          "vim",
          "vimdoc",
        },
        auto_install = true,
        highlight = {
          enable = true,
        },
      })
    end,
  },
}
