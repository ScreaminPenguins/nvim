return {
  {
    "benomahony/uv.nvim",
    opts = {
      picker_integration = true,
    },
    lazy = true,
    ft = { "python" },
    keys = {
      {
        "<leader>tui",
        "<cmd>UVInit<cr>",
        { desc = "UV Init" },
      },
      {
        "<leader>tua",
        "<cmd>lua vim.ui.input({prompt = 'Enter package name: '}, function(input) if input and input ~= '' then require('uv').run_command('uv add ' .. input) end end)<CR>",
        { desc = "UV Add Package" },
      },
    },
  },
}
