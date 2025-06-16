-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Highlight on text yank
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highligh on text yank",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
