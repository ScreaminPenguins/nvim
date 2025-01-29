return {
  {
    "epwalsh/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    lazy = true,
    ft = "markdown", -- use ft OR event
    -- event = {
    --   "BufReadPre /Users/ash_gent/Documents/Obsidian Vault/*.md",
    --   "BufNewFile /Users/ash_gent/Documents/Obsidian Vault/*.md",
    -- },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "Strixhaven",
          path = "/Users/ash_gent/Documents/Obsidian Vault/Strixhaven",
        },
      },
    },
  },
}
