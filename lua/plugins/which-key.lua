return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    config = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>l", group = "[L]azy" },
      })
    end,
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
      {
        "<leader>lu",
        function()
          vim.cmd("Lazy")
        end,
        desc = "Lazy: UI",
      },
    },
  },
}
