-- Quickfix and location list windows.
--
-- Neovim ships a runtime ftplugin/qf.vim, but it defines no mappings, so q has
-- to be added here. This is the "override a keymap for one filetype" case: q
-- normally starts a macro recording, which is useless in a list you only ever
-- read and dismiss.

local set = vim.opt_local

set.wrap = false -- one entry per line; wrapped paths are hard to scan
set.number = false
set.relativenumber = false
set.signcolumn = "no"

-- <C-w>c rather than :cclose, so this also closes a *location* list window —
-- :cclose only knows about the quickfix list and would leave a loclist open.
vim.keymap.set("n", "q", "<C-w>c", { buffer = true, desc = "Close quickfix" })
