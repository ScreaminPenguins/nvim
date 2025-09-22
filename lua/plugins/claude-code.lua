return {
  "greggh/claude-code.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for git operations
  },
  lazy = false,
  config = function()
    require("claude-code").setup({
      keymaps = {
        toggle = {
          variants = {},
        },
      },
    })
    vim.keymap.del({ "n" }, "<leader>cC")
    local wk = require("which-key")
    wk.add({ "<leader>tc", group = "[C]laude" })
  end,
  keys = {
    { "<leader>tcc", "<cmd>ClaudeCode<cr>", mode = "n", desc = "Claude Code" },
    { "<leader>tcC", "<cmd>ClaudeCodeContinue<cr>", mode = "n", desc = "Claude Code Continue" },
    { "<leader>tcV", "<cmd>ClaudeCodeVerbose<cr>", mode = "n", desc = "Claude Code Verbose" },
  },
}
