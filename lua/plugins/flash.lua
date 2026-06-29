-- flash
-- https://github.com/folke/flash.nvim

local flash = require("flash")
flash.setup({
	modes = { char = { jump_labels = true }, search = { enabled = true } },
})

vim.keymap.set({ "n", "x", "o" }, "s", flash.jump, { desc = "Flash" })
vim.keymap.set({ "n", "x", "o" }, "S", flash.treesitter, { desc = "Flash Treesitter" })
vim.keymap.set("c", "<c-s>", flash.toggle, { desc = "Flash: toggle search" })
