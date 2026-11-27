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
-- Finding connections: <leader>Dg filters the drawer/picker to one group,
-- <leader>D/ (:DBFilter) by text in alias/type/group; <leader>Dj fuzzy-picks
-- any connection and opens the drawer expanded on it.
--
-- Schema search (DataGrip-style): <leader>Di / :DBIntrospect [alias] caches a
-- connection's columns on disk; <leader>Ds / :DBColumns fuzzy-searches every
-- cached column across connections, <leader>DT / :DBTables every schema.table;
-- `I` on a table in the drawer pops up its columns and types.
--
-- Metadata: <leader>Dm / :DBInfo (or `I` on a connection in the drawer) shows
-- an entry's team, Cloud SQL project/instance, links and notes; <leader>Do /
-- :DBOpen opens one of its links.
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
-- Drawer order: A→Z by alias ("file" = connections-file order). Read by
-- custom/dbconn.lua when it builds vim.g.dbs.
vim.g.dbconn_drawer_sort = "alias"

set("n", "<leader>Du", dbtab.toggle, { desc = "Database: toggle DB tab / drawer" })
set("n", "<leader>Dn", dbtab.new_query, { desc = "Database: new query (pick alias)" })
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
-- CSV export re-runs the query in the client's CSV mode (lua/custom/dbexport.lua).
require("custom.dbexport")
-- Per-window winbar naming each query/results pane's connection; production
-- connections get a red bar (lua/custom/dbwinbar.lua).
require("custom.dbwinbar")
set("n", "<leader>De", "<cmd>DBExport<cr>", { desc = "Database: export buffer as CSV" })
set("x", "<leader>De", ":DBExport<cr>", { desc = "Database: export selection as CSV" })
set("n", "<leader>DR", "<cmd>DBReload<cr>", { desc = "Database: reload connections" })
set("n", "<leader>Dg", function()
	require("custom.dbconn").pick_group()
end, { desc = "Database: filter by group" })
-- Text filter over alias/type/group (:DBFilter); combines with the group.
set("n", "<leader>D/", function()
	require("custom.dbconn").prompt_filter()
end, { desc = "Database: filter connections by text" })
set("n", "<leader>Dj", dbtab.pick_reveal, { desc = "Database: jump to connection in drawer" })
-- Schema cache + cross-connection column search (lua/custom/dbmeta.lua).
-- :DBIntrospect only ever runs when invoked, one connection (or one server's
-- databases) at a time.
require("custom.dbmeta")
set("n", "<leader>Di", "<cmd>DBIntrospect<cr>", { desc = "Database: introspect connection (cache columns)" })
set("n", "<leader>Ds", "<cmd>DBColumns<cr>", { desc = "Database: search cached columns" })
set("n", "<leader>DT", "<cmd>DBTables<cr>", { desc = "Database: search cached schemas/tables" })
-- Connection metadata (team, Cloud SQL, links, notes) — lua/custom/dbinfo.lua.
require("custom.dbinfo")
set("n", "<leader>Dm", "<cmd>DBInfo<cr>", { desc = "Database: connection info" })
set("n", "<leader>Do", "<cmd>DBOpen<cr>", { desc = "Database: open connection link" })
set("n", "<leader>DI", function()
	require("custom.dbinfo").info_current()
end, { desc = "Database: info for this buffer's connection" })
set("n", "<leader>Df", "<cmd>DBUIFindBuffer<cr>", { desc = "Database: find buffer" })
set("n", "<leader>Da", "<cmd>DBUIAddConnection<cr>", { desc = "Database: add connection" })
set("n", "<leader>Dr", "<cmd>DBUIRenameBuffer<cr>", { desc = "Database: rename buffer" })
