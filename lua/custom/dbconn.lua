-- =============================================================================
-- custom/dbconn.lua
-- =============================================================================
-- Database connections for vim-dadbod, keyed by alias.
--
-- Connection details live in lua/config/db_connections.lua (gitignored; see
-- db_connections.example.lua for the schema). Passwords never touch that file:
-- they live in the macOS Keychain as generic passwords with
--   service = "nvim-dadbod", account = <alias>   (or the alias named by `secret`)
--
-- Secrets are fetched lazily — the first time the DB tab opens — with every
-- `security` lookup run in parallel, then cached in this module for the session.
-- They are never written to vim.g, disk, or :messages, but note that dadbod
-- builds CLI argv from the URL (psql/mysql/redis-cli), so a password is visible
-- to `ps` while a query runs. :DBSecretSet has the same brief exposure.
-- =============================================================================

local M = {}

local SERVICE = "nvim-dadbod"
local CONFIG_PATH = vim.fn.stdpath("config") .. "/lua/config/db_connections.lua"

local SCHEMES = {
	postgres = "postgresql",
	postgresql = "postgresql",
	mysql = "mysql",
	mariadb = "mariadb",
	redis = "redis",
	rediss = "rediss",
	sqlserver = "sqlserver",
	clickhouse = "clickhouse",
	snowflake = "snowflake",
	sqlite = "sqlite",
	duckdb = "duckdb",
}

local entries = {} -- list of normalised connection entries, in file order
local by_alias = {} -- alias -> entry
local secrets = {} -- keychain account -> password (session cache)
local loaded = false
local applied = false

-- RFC 3986 percent-encoding for userinfo components.
local function encode(str)
	return (tostring(str):gsub("[^%w%-%._~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function secret_account(entry)
	if entry.secret == true then
		return entry.alias
	elseif type(entry.secret) == "string" then
		return entry.secret
	end
end

local function query_string(params)
	if not params or vim.tbl_isempty(params) then
		return ""
	end
	local parts = {}
	for k, v in pairs(params) do
		table.insert(parts, encode(k) .. "=" .. encode(v))
	end
	table.sort(parts)
	return "?" .. table.concat(parts, "&")
end

--- Build a dadbod URL for an entry, embedding `password` when given.
function M.build_url(entry, password)
	if entry.url then
		if not password then
			return entry.url
		end
		-- Splice ":password" in after the user in scheme://user@host...
		local url, n = entry.url:gsub("^([%w+.-]+://[^:/@]*)@", "%1:" .. encode(password):gsub("%%", "%%%%") .. "@", 1)
		if n == 0 then
			vim.notify("dbconn: " .. entry.alias .. ": cannot splice password into url (no user@)", vim.log.levels.WARN)
		end
		return url
	end

	local t = entry.type
	if t == "bigquery" then
		return "bigquery:"
			.. entry.project
			.. (entry.dataset and (":" .. entry.dataset) or "")
			.. query_string(entry.params)
	end

	local scheme = SCHEMES[t]
	if not scheme then
		error("dbconn: " .. entry.alias .. ": unknown type '" .. tostring(t) .. "' (use `url =` instead)")
	end
	if t == "sqlite" or t == "duckdb" then
		return scheme .. ":" .. entry.path
	end

	local userinfo = ""
	if entry.user or password then
		userinfo = (entry.user and encode(entry.user) or "") .. (password and (":" .. encode(password)) or "") .. "@"
	end
	local host = (entry.host or "localhost") .. (entry.port and (":" .. entry.port) or "")
	local db = entry.database ~= nil and ("/" .. tostring(entry.database)) or ""
	return scheme .. "://" .. userinfo .. host .. db .. query_string(entry.params)
end

--- (Re)read the connections file. Returns the entry list.
function M.load()
	entries, by_alias = {}, {}
	loaded = true
	if vim.fn.filereadable(CONFIG_PATH) == 0 then
		vim.notify(
			"dbconn: no connections file at " .. CONFIG_PATH .. " (copy db_connections.example.lua)",
			vim.log.levels.WARN
		)
		return entries
	end
	local ok, spec = pcall(dofile, CONFIG_PATH)
	if not ok or type(spec) ~= "table" then
		vim.notify("dbconn: failed to load " .. CONFIG_PATH .. ": " .. tostring(spec), vim.log.levels.ERROR)
		return entries
	end
	local defaults = spec.defaults or {}
	for i, raw in ipairs(spec.connections or {}) do
		if type(raw.alias) ~= "string" or raw.alias == "" then
			vim.notify("dbconn: connection #" .. i .. " has no alias, skipped", vim.log.levels.WARN)
		elseif by_alias[raw.alias] then
			vim.notify("dbconn: duplicate alias '" .. raw.alias .. "', skipped", vim.log.levels.WARN)
		else
			local entry = vim.tbl_extend("keep", raw, defaults[raw.type] or {})
			table.insert(entries, entry)
			by_alias[entry.alias] = entry
		end
	end
	return entries
end

--- Fetch missing secrets for `list` from the Keychain, in parallel.
local function fetch_secrets(list)
	local jobs = {}
	for _, entry in ipairs(list) do
		local acct = secret_account(entry)
		if acct and secrets[acct] == nil and not jobs[acct] then
			jobs[acct] = vim.system(
				{ "security", "find-generic-password", "-s", SERVICE, "-a", acct, "-w" },
				{ text = true }
			)
		end
	end
	local missing = {}
	for acct, job in pairs(jobs) do
		local res = job:wait(5000)
		if res.code == 0 then
			secrets[acct] = (res.stdout or ""):gsub("\n$", "")
		else
			secrets[acct] = false -- remember the miss so we don't re-query every apply
			table.insert(missing, acct)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		vim.notify(
			"dbconn: no Keychain secret for: " .. table.concat(missing, ", ") .. "\nSet with :DBSecretSet <alias>",
			vim.log.levels.WARN
		)
	end
end

--- Resolved URL for one entry. Fetches its secret on demand, so a connection
--- outside the active group still works from the picker.
function M.url(entry)
	local acct = secret_account(entry)
	if acct and secrets[acct] == nil then
		fetch_secrets({ entry })
	end
	local pw = acct and secrets[acct] or nil
	return M.build_url(entry, pw or nil)
end

-- -----------------------------------------------------------------------------
-- Groups
-- -----------------------------------------------------------------------------
-- `group = "datahub"` (or a list, `group = { "datahub", "prod" }`) on an entry.
-- With an active group, the DBUI drawer and <leader>Dq picker show only that
-- group's connections; nil shows everything. Ungrouped entries appear only
-- under "all".

local active_group = nil

local function groups_of(entry)
	local g = entry.group
	if g == nil then
		return {}
	end
	return type(g) == "table" and g or { g }
end

local function in_active_group(entry)
	return active_group == nil or vim.tbl_contains(groups_of(entry), active_group)
end

-- -----------------------------------------------------------------------------
-- Text filter (:DBFilter / <leader>D/)
-- -----------------------------------------------------------------------------
-- Case-insensitive plain substring match against alias, type and groups.
-- Combines with the active group (both must match).

local active_filter = nil

local function matches_filter(entry)
	if not active_filter then
		return true
	end
	local needle = active_filter:lower()
	local hay = { entry.alias, entry.type or "" }
	vim.list_extend(hay, groups_of(entry))
	for _, s in ipairs(hay) do
		if tostring(s):lower():find(needle, 1, true) then
			return true
		end
	end
	return false
end

--- Entries visible under the active group and filter, in file order.
function M.visible_entries()
	return vim.tbl_filter(function(e)
		return in_active_group(e) and matches_filter(e)
	end, M.entries())
end

function M.active_filter()
	return active_filter
end

--- "group datahub, filter 'prod'" / "all" — for prompts and messages.
function M.view_label()
	local parts = {}
	if active_group then
		table.insert(parts, "group " .. active_group)
	end
	if active_filter then
		table.insert(parts, "filter '" .. active_filter .. "'")
	end
	return #parts > 0 and table.concat(parts, ", ") or nil
end

--- Every group name used in the file, sorted.
function M.groups()
	local seen = {}
	for _, entry in ipairs(M.entries()) do
		for _, g in ipairs(groups_of(entry)) do
			seen[g] = true
		end
	end
	local list = vim.tbl_keys(seen)
	table.sort(list)
	return list
end

function M.active_group()
	return active_group
end

--- Populate vim.g.dbs for DBUI. Idempotent unless `force`.
function M.apply(force)
	if applied and not force then
		return
	end
	if not loaded or force then
		M.load()
	end
	local visible = M.visible_entries()
	fetch_secrets(visible) -- only what the drawer will show
	local dbs = {}
	for _, entry in ipairs(visible) do
		local ok, url = pcall(M.url, entry)
		if ok then
			table.insert(dbs, { name = entry.alias, url = url })
		else
			vim.notify(url, vim.log.levels.ERROR)
		end
	end
	vim.g.dbs = dbs
	applied = true
end

function M.entries()
	if not loaded then
		M.load()
	end
	return entries
end

function M.get(alias)
	if not loaded then
		M.load()
	end
	return by_alias[alias]
end

local function complete_alias(lead)
	return vim.tbl_filter(
		function(a)
			return vim.startswith(a, lead)
		end,
		vim.tbl_map(function(e)
			return e.alias
		end, M.entries())
	)
end

--- Store a password in the Keychain for an alias (or shared secret account).
function M.set_secret(alias)
	local entry = M.get(alias)
	local acct = entry and secret_account(entry) or alias
	local pw = vim.fn.inputsecret("Password for " .. acct .. ": ")
	if pw == "" then
		vim.notify("dbconn: empty password, nothing stored", vim.log.levels.WARN)
		return
	end
	local res = vim.system({ "security", "add-generic-password", "-U", "-s", SERVICE, "-a", acct, "-w", pw }):wait()
	if res.code ~= 0 then
		vim.notify("dbconn: security add-generic-password failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
		return
	end
	secrets[acct] = pw
	vim.notify("dbconn: stored secret for " .. acct .. " (run :DBReload to refresh DBUI)")
end

--- Rebuild vim.g.dbs and make DBUI pick it up. DBUI only reads g:dbs when it
--- builds its instance, so reset it; an open drawer is closed first and
--- reopened after, otherwise it keeps rendering the old instance's list.
local function refresh_drawer()
	M.apply(true)
	if vim.fn.exists("*db_ui#reset_state") == 0 then
		return -- DBUI not loaded yet; it will read vim.g.dbs when it starts
	end
	local drawer_open = false
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "dbui" then
			drawer_open = true
		end
	end
	if drawer_open then
		vim.cmd("DBUIClose")
	end
	vim.fn["db_ui#reset_state"]()
	if drawer_open then
		vim.cmd("DBUI")
	end
end

--- Re-read the file, re-fetch secrets that were missing, refresh DBUI.
function M.reload()
	for acct, v in pairs(secrets) do
		if v == false then
			secrets[acct] = nil
		end
	end
	refresh_drawer()
	vim.notify("dbconn: loaded " .. #entries .. " connections (" .. #vim.g.dbs .. " shown)")
end

--- Show only `name`'s connections in the drawer and picker; nil/"" shows all.
function M.set_group(name)
	if name == "" then
		name = nil
	end
	if name and not vim.tbl_contains(M.groups(), name) then
		vim.notify("dbconn: unknown group '" .. name .. "'", vim.log.levels.WARN)
		return
	end
	active_group = name
	refresh_drawer()
	vim.notify("dbconn: " .. (M.view_label() or "all") .. ": " .. #vim.g.dbs .. " connections")
end

--- Show only connections whose alias/type/group contains `text`; nil/"" clears.
function M.set_filter(text)
	text = text and vim.trim(text) or ""
	active_filter = text ~= "" and text or nil
	refresh_drawer()
	local level = #vim.g.dbs == 0 and vim.log.levels.WARN or vim.log.levels.INFO
	vim.notify("dbconn: " .. (M.view_label() or "all") .. ": " .. #vim.g.dbs .. " connections", level)
end

--- Prompt for the filter text, pre-filled with the current one.
function M.prompt_filter()
	vim.ui.input({ prompt = "DB filter (empty clears): ", default = active_filter or "" }, function(text)
		if text ~= nil then -- nil = cancelled
			M.set_filter(text)
		end
	end)
end

--- Drop both the group and the filter (show every connection).
function M.clear_view()
	active_group, active_filter = nil, nil
	refresh_drawer()
end

--- Pick a group with vim.ui.select (first item shows everything).
function M.pick_group()
	local items = vim.list_extend({ "(all)" }, M.groups())
	vim.ui.select(items, {
		prompt = "DB group (current: " .. (active_group or "all") .. "):",
	}, function(choice)
		if choice then
			M.set_group(choice ~= "(all)" and choice or nil)
		end
	end)
end

vim.api.nvim_create_user_command("DBSecretSet", function(opts)
	M.set_secret(opts.args)
end, { nargs = 1, complete = complete_alias, desc = "Store a DB password in the macOS Keychain" })

vim.api.nvim_create_user_command("DBGroup", function(opts)
	M.set_group(opts.args)
end, {
	nargs = "?",
	complete = function(lead)
		return vim.tbl_filter(function(g)
			return vim.startswith(g, lead)
		end, M.groups())
	end,
	desc = "Show one group of DB connections (no argument: all)",
})

vim.api.nvim_create_user_command("DBFilter", function(opts)
	M.set_filter(opts.args)
end, { nargs = "?", desc = "Show DB connections matching text (no argument: clear)" })

vim.api.nvim_create_user_command("DBReload", function()
	M.reload()
end, { desc = "Reload DB connections file and secrets" })

return M
