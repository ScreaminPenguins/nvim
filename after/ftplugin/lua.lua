local set = vim.opt_local
local keymap = vim.keymap

set.expandtab = true
set.shiftwidth = 2
set.tabstop = 2

keymap.set("n", "<space><space>x", "<cmd>source %<cr>",   { buffer = true, desc = "Source file" })
keymap.set("n", "<space>x",        ":.lua<cr>",           { buffer = true, desc = "Execute line" })
keymap.set("v", "<space>x",        ":<C-u>'<,'>lua<cr>",  { buffer = true, desc = "Execute selection" })
