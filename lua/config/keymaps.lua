--Window Navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window"})
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window"})
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window"})
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window"})


vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })
