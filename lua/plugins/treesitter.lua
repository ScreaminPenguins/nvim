return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      auto_install = true,
      ensure_installed = {
        "c",
        "json",
        "lua",
        "markdown",
        "python",
        "query",
        "sql",
        "yaml",
        "vim",
        "vimdoc",
      },
      fold = { enable = true },
      highlight = { enable = true },
      ignore_install = {},
      indent = { enable = true },
      sync_install = false
    },
    lazy = vim.fn.argc(-1) == 0,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
