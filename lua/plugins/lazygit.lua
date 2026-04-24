-- lazygit.nvim — LazyGit TUI integration
-- https://github.com/kdheepak/lazygit.nvim
--
-- No setup() call — configuration is done via vim.g globals if needed.
-- plenary.nvim dependency removed — only required when
-- lazygit_floating_window_use_plenary = 1, which is not set.

vim.keymap.set("n", "<leader>lg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
