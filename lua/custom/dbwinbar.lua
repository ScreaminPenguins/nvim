-- =============================================================================
-- custom/dbwinbar.lua
-- =============================================================================
-- Per-window winbar naming the connection of each dadbod query buffer and
-- results pane, so side-by-side queries are unambiguous (the statusline is
-- global and only shows the focused window).
--
--   󰆼 DataHub: Dev · mysql · datahub, dev
--   PROD  DataHub: Prod · mysql · datahub, prod          (whole bar red)
--   ↳ results · DataHub: Dev
--
-- Covers <leader>Dq buffers (b:db_alias) and DBUI drawer buffers
-- (b:dbui_db_key_name = "<name>_<source>"); type/groups come from the
-- connections file via custom.dbconn.
--
-- Production: `env = "prod"` on the entry decides; otherwise a whole word
-- "prod"/"production" in the alias or a group ("DataHub: Prod" yes,
-- "product-db" no). `env = "dev"` (anything not prod) opts an entry out.
--
-- The winbar option is set only on windows showing a DB buffer and cleared
-- when such a window switches to something else — a non-empty 'winbar' takes
-- a screen line even if the expression renders empty.
-- =============================================================================

local dbconn = require("custom.dbconn")
local dbtab = require("custom.dbtab")

local M = {}

local EXPR = "%{%v:lua.require'custom.dbwinbar'.render()%}"

local function set_highlights()
	local err = vim.api.nvim_get_hl(0, { name = "DiagnosticError", link = false })
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	vim.api.nvim_set_hl(0, "DbWinbarProd", { fg = normal.bg or 0x1f1f28, bg = "#ff9e3b" or 0xe82424, bold = true })
	vim.api.nvim_set_hl(0, "DbWinbar", { default = true, link = "WinBar" })
	vim.api.nvim_set_hl(0, "DbWinbarDim", { default = true, link = "Comment" })
end

local function connection_name(buf)
	local alias = vim.b[buf].db_alias
	if alias then
		return alias
	end
	local key = vim.b[buf].dbui_db_key_name
	if type(key) == "string" and key ~= "" then
		return (key:gsub("_[^_]+$", "")) -- strip DBUI's "_<source>" suffix
	end
end

local function is_prod(entry, name)
	if entry and entry.env then
		return tostring(entry.env):lower():match("^prod") ~= nil
	end
	local hay = { name or "" }
	if entry and entry.group then
		vim.list_extend(hay, type(entry.group) == "table" and entry.group or { entry.group })
	end
	for _, s in ipairs(hay) do
		local l = tostring(s):lower()
		if l:match("%f[%a]prod%f[%A]") or l:match("%f[%a]production%f[%A]") then
			return true
		end
	end
	return false
end

-- { name, kind, groups, prod } for a query buffer, or nil.
local function describe(buf)
	local name = connection_name(buf)
	if not name then
		local db = vim.b[buf].db
		if type(db) ~= "string" then
			return nil
		end
		name = db:gsub("://[^@/]*@", "://") -- never show credentials
	end
	local entry = dbconn.get(name)
	local kind = entry and (entry.type or (entry.url and entry.url:match("^([%w+.-]+):")))
	if not kind and type(vim.b[buf].db) == "string" then
		kind = vim.b[buf].db:match("^([%w+.-]+):")
	end
	local groups = entry and entry.group
	if type(groups) == "table" then
		groups = table.concat(groups, ", ")
	end
	return { name = name, kind = kind, groups = groups, prod = is_prod(entry, name) }
end

local function esc(s)
	return (tostring(s):gsub("%%", "%%%%"))
end

local function is_db_window(win)
	local buf = vim.api.nvim_win_get_buf(win)
	if vim.bo[buf].filetype == "dbout" then
		return true
	end
	return describe(buf) ~= nil and vim.bo[buf].filetype ~= "dbui"
end

function M.render()
	-- Set by Neovim while drawing a winbar; the current window covers callers
	-- like nvim_eval_statusline({ winid }) that evaluate in that window.
	local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
	if not win or not vim.api.nvim_win_is_valid(win) then
		return ""
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local prefix = "󰆼 "
	local info
	if vim.bo[buf].filetype == "dbout" then
		local src = dbtab.result_source(win)
		info = src and describe(src)
		prefix = "↳ results · "
		if not info then
			return "%#DbWinbarDim# ↳ results"
		end
	else
		info = describe(buf)
		if not info then
			return ""
		end
	end
	local parts = { esc(info.name) }
	if info.kind then
		table.insert(parts, esc(info.kind))
	end
	if info.groups and info.groups ~= "" then
		table.insert(parts, esc(info.groups))
	end
	local text = table.concat(parts, " · ")
	if info.prod then
		-- %= pads to the full width, so the whole bar is red.
		return "%#DbWinbarProd# PROD  " .. prefix .. text .. "%="
	end
	return "%#DbWinbar# " .. prefix .. text
end

local function refresh(win)
	if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
		return -- skip floats
	end
	if is_db_window(win) then
		if vim.wo[win].winbar ~= EXPR then
			vim.wo[win].winbar = EXPR
		end
	elseif vim.wo[win].winbar == EXPR then
		vim.wo[win].winbar = "" -- inherited by a split, or buffer switched away
	end
end

local function refresh_tab()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		refresh(win)
	end
end

set_highlights()

local group = vim.api.nvim_create_augroup("dbwinbar", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })
-- Scheduled: DBUI sets b:db / b:dbui_db_key_name / filetype after the buffer
-- enters its window, and dbtab moves results panes inside DBExecutePre.
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "WinNew", "TabEnter" }, {
	group = group,
	callback = function()
		vim.schedule(refresh_tab)
	end,
})
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "*/DBExecutePre",
	callback = function()
		vim.schedule(refresh_tab)
	end,
})

return M
