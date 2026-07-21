-- vim-dadbod — database interface for Neovim
-- https://github.com/tpope/vim-dadbod
-- https://github.com/kristijanhusak/vim-dadbod-ui
-- https://github.com/kristijanhusak/vim-dadbod-completion
--
-- Loaded eagerly (small vimscript plugins) so :DBUI is always available.
-- Completion is wired into blink.cmp for sql/mysql/plsql buffers —
-- see plugins/blink-cmp.lua.
--
-- BigQuery support ships with vim-dadbod core via its `bigquery` adapter,
-- which shells out to the `bq` CLI (Google Cloud SDK). Auth is handled by
-- gcloud, not dadbod — run `gcloud auth application-default login` if queries
-- fail with an auth error. URL forms:
--   bigquery:PROJECT
--   bigquery:PROJECT:DATASET
--   bigquery://PROJECT/DATASET?location=US   (query params become bq flags)
--
-- Connections: the Sweetwater warehouse projects are pre-registered below in
-- vim.g.dbs so they appear in the :DBUI drawer. Add more interactively with
-- <leader>Da (:DBUIAddConnection). Ad-hoc queries: :DB <url> <query>.

-- Named connections shown in the DBUI drawer. Projects mirror the gcloud
-- configurations (dev / prod / sandbox warehouses).
vim.g.dbs = {
	{ name = "bq-dev", url = "bigquery:dev-enterprise-wareh-6c24fdfb" },
	{ name = "bq-prod", url = "bigquery:prod-enterprise-ware-c8219262" },
	{ name = "bq-sandbox", url = "bigquery:sandbox-thunderdome" },
}

-- dadbod-ui settings — must be set before :DBUI runs.
vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_show_database_icon = 1
vim.g.db_ui_win_position = "left"
vim.g.db_ui_winwidth = 40
-- Persist saved queries and connections under the standard data dir.
vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
-- Don't auto-execute on save; run queries explicitly (<leader>S in a DBUI
-- buffer, or <Plug>(DBUI_ExecuteQuery)).
vim.g.db_ui_execute_on_save = 0

vim.keymap.set("n", "<leader>Du", "<cmd>DBUIToggle<cr>", { desc = "Database: toggle UI" })
vim.keymap.set("n", "<leader>Df", "<cmd>DBUIFindBuffer<cr>", { desc = "Database: find buffer" })
vim.keymap.set("n", "<leader>Da", "<cmd>DBUIAddConnection<cr>", { desc = "Database: add connection" })
vim.keymap.set("n", "<leader>Dr", "<cmd>DBUIRenameBuffer<cr>", { desc = "Database: rename buffer" })

-- New query buffer bound directly to a connection via b:db, bypassing the DBUI
-- drawer. The drawer's schema tree re-runs INFORMATION_SCHEMA.SCHEMATA on every
-- expand (dadbod-ui has no schema cache); binding b:db and running with :DB
-- never touches the drawer, so that query is never issued. Completion isn't
-- triggered either — vim-dadbod-completion ships no bigquery scheme.
local function new_query_buffer()
  local dbs = vim.g.dbs or {}
  if vim.tbl_isempty(dbs) then
    vim.notify("dadbod: no connections in vim.g.dbs", vim.log.levels.WARN)
    return
  end
  vim.ui.select(dbs, {
    prompt = "Query connection:",
    format_item = function(item) return item.name .. "  (" .. item.url .. ")" end,
  }, function(choice)
    if not choice then return end
    vim.cmd("botright new")
    vim.bo.filetype = "sql"
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.b.db = choice.url
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "-- " .. choice.name .. " (" .. choice.url .. ")", "" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    -- Run the whole buffer (normal) or the visual selection against b:db.
    vim.keymap.set("n", "<leader>DS", "<cmd>%DB<cr>", { buffer = true, desc = "Database: run buffer" })
    vim.keymap.set("x", "<leader>DS", ":DB<cr>", { buffer = true, desc = "Database: run selection" })
  end)
end

vim.keymap.set("n", "<leader>Dq", new_query_buffer, { desc = "Database: new query buffer (no drawer)" })
