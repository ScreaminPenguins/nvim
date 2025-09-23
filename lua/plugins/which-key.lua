return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    config = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>b", group = "[B]uffers" },
        { "<leader>s", group = "[S]earch" },
        { "<leader>t", group = "[T]ools" },
        { "<leader>w", group = "[W]indows" },
        { "g", group = "+Go To" },
        -- nested groupings
        { "<leader>tc", group = "[C]laude" },
        { "<leader>tu", group = "[U]V" },
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
        "<leader>tl",
        "<cmd>Lazy<cr>",
        desc = "Lazy: UI",
      },
    },
  },
}
