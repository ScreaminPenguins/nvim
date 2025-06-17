return {
  {
    "someone-stole-my-name/yaml-companion.nvim",
    name = "yaml-companion",
    dependencies = {
      { "neovim/nvim-lspconfig" },
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope.nvim" },
    },
    config = function()
      require("telescope").load_extension("yaml_schema")
      require("yaml-companion").setup({
        lspconfig = {
          settings = {
            yaml = {
              schemaStore = {
                url = "https://sweet-serve.sweetwater.com/api/schemas/helm/main",
              },
              schemaDownload = { enable = true },
            },
          },
        },
        schemas = {
          -- {
          --   name = "Sweetwater",
          --   uri = "https://sweet-serve.sweetwater.com/api/schemas/helm/main",
          -- },
        },
      })
    end,
  },
}
