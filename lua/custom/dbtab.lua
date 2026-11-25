-- =============================================================================
-- custom/dbtab.lua
-- =============================================================================
-- A dedicated tab for vim-dadbod work, plus a results layout that gives each
-- query buffer its own results pane along the bottom of that tab.
--
-- Why the results hook exists: dadbod opens results with :pedit, and a tab can
-- only have one preview window, so results from two query buffers overwrite
-- each other. On `User <out>/DBExecutePre` (fired after :pedit, while the query
-- buffer is still current) we either swap the result into that query buffer's
-- existing pane, or demote the fresh preview window to a normal window and slot
-- it into the bottom row. Demoting is what makes the next :pedit open a new
-- pane instead of reusing this one.
--
-- dadbod also refuses to start a query while the tab's "last preview buffer"
-- still has a job running; clearing t:db_last_preview_buffer in the same hook
-- lets different query buffers run concurrently.
-- =============================================================================

local dbconn = require("custom.dbconn")

local M = {}

local RESULTS_HEIGHT = 0.35 -- fraction of the editor height
local results = {} -- query bufnr -> result winid (DB tab only)
local query_count = {} -- alias -> running counter for buffer names

local function find_dbtab()
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		if vim.t[tab].dbtab then
			return tab
		end
	end
end

local function in_dbtab()
	return vim.t.dbtab == true
end

--- Switch to the DB tab, creating it (and loading connections) if needed.
function M.open()
	local tab = find_dbtab()
	if tab then
		vim.api.nvim_set_current_tabpage(tab)
		return
	end
	dbconn.apply()
	vim.cmd("tabnew")
	vim.t.dbtab = true
	vim.cmd("DBUI")
end

--- In the DB tab, toggle the DBUI drawer; elsewhere, jump to the DB tab.
function M.toggle()
	if in_dbtab() then
		vim.cmd("DBUIToggle")
	else
		M.open()
	end
end

local function is_result_win(win)
	for _, w in pairs(results) do
		if w == win then
			return true
		end
	end
	return false
end

local function live_result_wins()
	local wins = {}
	for buf, win in pairs(results) do
		if
			vim.api.nvim_win_is_valid(win)
			and vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage()
		then
			table.insert(wins, win)
		else
			results[buf] = nil
		end
	end
	-- Left-to-right screen order, so "last" is the rightmost pane.
	table.sort(wins, function(a, b)
		return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
	end)
	return wins
end

local function equalize(wins)
	if #wins == 0 then
		return
	end
	local height = math.floor(vim.o.lines * RESULTS_HEIGHT)
	local width = math.floor(vim.o.columns / #wins)
	for _, w in ipairs(wins) do
		vim.wo[w].winfixheight = false
		vim.api.nvim_win_set_height(w, height)
		vim.wo[w].winfixheight = true
		if #wins > 1 then
			vim.api.nvim_win_set_width(w, width)
		end
	end
end

local function place_result(ev)
	if not in_dbtab() then
		return
	end
	local out_path = ev.match:gsub("/DBExecutePre$", "")
	local out_buf = vim.fn.bufnr(out_path)
	local src_buf = vim.api.nvim_get_current_buf()
	vim.t.db_last_preview_buffer = nil

	if out_buf == -1 or vim.bo[src_buf].filetype == "dbout" then
		return
	end
	local new_win
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_win_get_buf(w) == out_buf and vim.wo[w].previewwindow then
			new_win = w
			break
		end
	end
	if not new_win then
		return
	end

	local existing = results[src_buf]
	if existing and vim.api.nvim_win_is_valid(existing) and existing ~= new_win then
		-- Re-run: show the new result in this query's pane, drop the preview.
		vim.api.nvim_win_set_buf(existing, out_buf)
		vim.api.nvim_win_close(new_win, true)
		equalize(live_result_wins()) -- closing the preview gave its rows away
		return
	end

	vim.wo[new_win].previewwindow = false
	local others = live_result_wins()
	if #others > 0 then
		-- Keep panes in the same left-to-right order as their query windows:
		-- go left of the first pane whose query sits further right, else last.
		local src_col = vim.api.nvim_win_get_position(0)[2]
		local target, rightbelow = others[#others], true
		for _, w in ipairs(others) do
			for buf, rw in pairs(results) do
				local qwin = rw == w and vim.fn.bufwinid(buf) or -1
				if qwin ~= -1 and vim.api.nvim_win_get_position(qwin)[2] > src_col then
					target, rightbelow = w, false
					break
				end
			end
			if not rightbelow then
				break
			end
		end
		vim.fn.win_splitmove(new_win, target, { vertical = true, rightbelow = rightbelow })
	else
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("wincmd J")
		end)
	end
	results[src_buf] = new_win
	equalize(live_result_wins())
end

--- The window to put a new query buffer in: current one if it's a plain
--- editing window, otherwise the first non-drawer, non-result window.
local function main_win()
	local function eligible(w)
		local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
		return ft ~= "dbui" and ft ~= "dbout" and not is_result_win(w) and not vim.wo[w].previewwindow
	end
	local cur = vim.api.nvim_get_current_win()
	if eligible(cur) then
		return cur
	end
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if eligible(w) then
			return w
		end
	end
end

local function open_query(entry, split)
	M.open()
	dbconn.apply()
	local win = main_win()
	if win then
		vim.api.nvim_set_current_win(win)
		if split then
			vim.cmd("rightbelow vsplit")
		end
	else
		vim.cmd("botright vnew")
	end

	query_count[entry.alias] = (query_count[entry.alias] or 0) + 1
	local buf = vim.api.nvim_create_buf(true, false)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_name(buf, string.format("db://%s/%d", entry.alias, query_count[entry.alias]))
	vim.api.nvim_win_set_buf(0, buf)
	vim.bo[buf].filetype = entry.type == "redis" and "redis" or "sql"
	vim.b[buf].db = dbconn.url(entry)
	vim.b[buf].db_alias = entry.alias
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- " .. entry.alias, "" })
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
end

--- Keys for <leader>DS: DBUI's executor in drawer-opened buffers (it handles
--- bind parameters and query info), plain :DB in buffers that only carry b:db.
--- Global rather than buffer-local so the keys never fall through to `D`
--- (delete to end of line) in a buffer that lacks the mapping.
function M.run_keys(visual)
	if vim.b.dbui_db_key_name then
		return "<Plug>(DBUI_ExecuteQuery)"
	elseif vim.b.db or vim.w.db or vim.t.db or vim.g.db then
		return visual and ":DB<cr>" or "<cmd>%DB<cr>"
	end
	vim.schedule(function()
		vim.notify("No database connection for this buffer (open one with <leader>Dq)", vim.log.levels.WARN)
	end)
	return visual and "<Esc>" or ""
end

--- Pick a connection by alias and open a new query buffer for it.
--- opts.split = true opens it in a vertical split beside the current query.
function M.new_query(opts)
	opts = opts or {}
	-- Respects the active group (<leader>Dg / :DBGroup), same as the drawer.
	local entries = dbconn.visible_entries()
	local group = dbconn.active_group()
	if vim.tbl_isempty(entries) then
		vim.notify(
			"dbtab: no connections"
				.. (group and (" in group '" .. group .. "'") or "")
				.. " (see lua/config/db_connections.lua)",
			vim.log.levels.WARN
		)
		return
	end
	vim.ui.select(entries, {
		prompt = "Query connection" .. (group and (" [" .. group .. "]") or "") .. ":",
		format_item = function(e)
			local where = e.type == "bigquery" and (e.project .. (e.dataset and (":" .. e.dataset) or ""))
				or e.url and "url"
				or e.path
				or ((e.host or "localhost") .. (e.database ~= nil and ("/" .. tostring(e.database)) or ""))
			local groups = type(e.group) == "table" and table.concat(e.group, ",") or (e.group or "")
			-- Group is part of the text, so fuzzy-typing a group name filters too.
			return string.format("%-28s %-14s %-9s %s", e.alias, groups, e.type or "url", where)
		end,
	}, function(choice)
		if choice then
			open_query(choice, opts.split)
		end
	end)
end

local group = vim.api.nvim_create_augroup("dbtab", { clear = true })

vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "*/DBExecutePre",
	callback = place_result,
})

vim.api.nvim_create_autocmd("WinClosed", {
	group = group,
	callback = function(ev)
		local closed = tonumber(ev.match)
		for buf, w in pairs(results) do
			if w == closed then
				results[buf] = nil
			end
		end
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = group,
	callback = function(ev)
		results[ev.buf] = nil
	end,
})

return M
