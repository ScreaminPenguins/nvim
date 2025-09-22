return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    opts = {
      winopts = {},
    },
    keys = {
      {
        "<leader>sf",
        "<cmd>FzfLua files<cr>",
        mode = "n",
        desc = "Files",
      },
      {
        "<leader>/",
        "<cmd>FzfLua live_grep<cr>",
        mode = "n",
        desc = "Grep Project",
      },
      {
        "<leader>sb",
        "<cmd>FzfLua buffers<cr>",
        mode = "n",
        desc = "Buffers",
      },
      {
        "<leader>sB",
        "<cmd>FzfLua grep_curbuff<cr>",
        mode = "n",
        desc = "Grep Current Buffer",
      },
      {
        "<leader>sd",
        "<cmd>FzfLua diagnostics_document<cr>",
        mode = "n",
        desc = "Document Diagnostics",
      },
      {
        "<leader>sm",
        "<cmd>FzfLua marks<cr>",
        mode = "n",
        desc = "Marks",
      },
      {
        "<leader>ss",
        "<cmd>FzfLua lsp_document_symbols<cr>",
        mode = "n",
        desc = "Document Symbols",
      },
      {
        "<leader>sw",
        "<cmd>FzfLua grep_cword<cr>",
        mode = "n",
        desc = "Grep for current word",
      },
      {
        "<leader>sW",
        "<cmd>FzfLua grep_cWORD<cr>",
        mode = "n",
        desc = "Grep for current WORD",
      },
    },
  },
}
