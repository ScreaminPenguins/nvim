-- vim-dadbod — database interface for Neovim
-- https://github.com/tpope/vim-dadbod
-- https://github.com/kristijanhusak/vim-dadbod-ui
-- https://github.com/kristijanhusak/vim-dadbod-completion
--
-- Loaded eagerly (small vimscript plugins) so :DBUI is always available.
-- Completion is wired into blink.cmp for sql/mysql/plsql buffers —
-- see plugins/blink-cmp.lua.
--
-- Connections: defined by alias in lua/config/db_connections.lua (gitignored;
-- template in db_connections.example.lua). Passwords live in the macOS
-- Keychain (service "nvim-dadbod", account = alias) — set one with
-- :DBSecretSet <alias>, re-read the file with :DBReload. Implementation:
-- lua/custom/dbconn.lua. vim.g.dbs is populated lazily the first time the DB
-- tab opens, so ~100 Keychain lookups never touch startup.
--
-- Layout: <leader>Du jumps to a dedicated DB tab (created once per session).
-- Each query buffer gets its own results pane along the bottom; two queries
-- run side by side give two result panes side by side. Implementation:
-- lua/custom/dbtab.lua.
--
-- BigQuery uses the `bq` CLI; auth is gcloud's, not dadbod's — run
-- `gcloud auth application-default login` if queries fail with an auth error.

local set = vim.keymap.set
local dbtab = require("custom.dbtab")

-- dadbod-ui settings — must be set before :DBUI runs.
vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1
vim.g.db_ui_win_position = "left"
vim.g.db_ui_winwidth = 40
-- Persist saved queries and connections under the standard data dir.
vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
-- Don't auto-execute on save; run queries explicitly (<leader>S in a DBUI
-- buffer, or <leader>DS in any query buffer).
vim.g.db_ui_execute_on_save = 0

set("n", "<leader>Du", dbtab.toggle, { desc = "Database: toggle DB tab / drawer" })
set("n", "<leader>Dq", dbtab.new_query, { desc = "Database: new query (pick alias)" })
set("n", "<leader>Dv", function()
	dbtab.new_query({ split = true })
end, { desc = "Database: new query in vsplit" })
-- Left on the cmdline so <Tab> completes aliases.
set("n", "<leader>Dk", ":DBSecretSet ", { desc = "Database: set Keychain secret" })
set("n", "<leader>DS", function()
	return dbtab.run_keys(false)
end, { expr = true, remap = true, desc = "Database: run buffer" })
set("x", "<leader>DS", function()
	return dbtab.run_keys(true)
end, { expr = true, remap = true, desc = "Database: run selection" })
set("n", "<leader>DR", "<cmd>DBReload<cr>", { desc = "Database: reload connections" })
set("n", "<leader>Dg", function()
	require("custom.dbconn").pick_group()
end, { desc = "Database: filter by group" })
set("n", "<leader>Df", "<cmd>DBUIFindBuffer<cr>", { desc = "Database: find buffer" })
set("n", "<leader>Da", "<cmd>DBUIAddConnection<cr>", { desc = "Database: add connection" })
set("n", "<leader>Dr", "<cmd>DBUIRenameBuffer<cr>", { desc = "Database: rename buffer" })
