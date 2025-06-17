return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensured_installed = {
          "c",
          "lua",
          "markdown",
          "python",
          "query",
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
