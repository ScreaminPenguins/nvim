return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    opts = {},
    keys = {
      {
        "<leader><Space>",
        function()
          vim.cmd("FzfLua files")
        end,
        mode = "n",
        desc = "FZF: Files",
      },
      {
        "<leader>/",
        function()
          vim.cmd("FzfLua live_grep")
        end,
        mode = "n",
        desc = "FZF: Grep Project",
      },
      {
        "<leader>sb",
        function()
          vim.cmd("FzfLua lgrep_curbuf")
        end,
        mode = "n",
        desc = "FZF: Grep Current Buffer",
      },
      {
        "<leader>sd",
        function()
          vim.cmd("FzfLua diagnostics_document")
        end,
        mode = "n",
        desc = "FZF: Document Diagnostics",
      },
      {
        "<leader>sm",
        function()
          vim.cmd("FzfLua marks")
        end,
        mode = "n",
        desc = "FZF: Marks",
      },
      {
        "<leader>ss",
        function()
          vim.cmd("FzfLua lsp_document_symbols")
        end,
        mode = "n",
        desc = "FZF: Document Symbols",
      },
    },
  },
}
