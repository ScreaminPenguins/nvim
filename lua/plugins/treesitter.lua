return {
  {
    "nvim-treesitter/nvim-treesitter",

    build = ":TSUpdate",
    branch = "master", -- TODO: This will be moved to the rewrite branch `main`- requires work
    opts = {
      auto_install = true,
      ensure_installed = {
        "bash",
        "c",
        "dockerfile",
        "helm",
        "json",
        "lua",
        "make",
        "markdown",
        "python",
        "query",
        "sql",
        "vim",
        "vimdoc",
        "yaml",
      },
      fold = { enable = true },
      highlight = { enable = true },
      ignore_install = {},
      indent = { enable = true },
      sync_install = false,
    },
    lazy = vim.fn.argc(-1) == 0,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
