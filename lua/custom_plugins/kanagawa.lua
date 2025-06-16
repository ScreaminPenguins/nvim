return {
  {
    "rebelot/kanagawa.nvim",
    name = "kanagawa",
    lazy = false,
    config = function()
      require("kanagawa")
      vim.cmd("colorscheme kanagawa")
    end,
  },
}
