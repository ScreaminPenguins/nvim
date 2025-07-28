vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      schemas = {
        ["https://sweet-serve.sweetwater.com/api/schemas/helm/main"] = "values.yaml",
      },
    },
  },
})
