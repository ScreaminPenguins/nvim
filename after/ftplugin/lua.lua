local set = vim.opt_local
local keymap = vim.keymap

set.expandtab = true
set.shiftwidth = 2
set.tabstop = 2

keymap.set("n", "<space><space>x", "<cmd>source %<CR>")
keymap.set("n", "<space>x", ":.lua<CR>")
keymap.set("v", "<space>x", ":.lua<CR>")
