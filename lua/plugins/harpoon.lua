-- harpoon — quick file marks and navigation
-- https://github.com/ThePrimeagen/harpoon (branch: harpoon2)

local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>th", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Toggle: Harpoon menu" })
vim.keymap.set("n", "<leader>hh", function() harpoon:list():add() end,      { desc = "Harpoon: add file" })
vim.keymap.set("n", "<leader>h1", function() harpoon:list():select(1) end,  { desc = "Harpoon: file 1" })
vim.keymap.set("n", "<leader>h2", function() harpoon:list():select(2) end,  { desc = "Harpoon: file 2" })
vim.keymap.set("n", "<leader>h3", function() harpoon:list():select(3) end,  { desc = "Harpoon: file 3" })
vim.keymap.set("n", "<leader>h4", function() harpoon:list():select(4) end,  { desc = "Harpoon: file 4" })
