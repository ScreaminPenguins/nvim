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

local items = {} -- parsed file entries, in file order (`databases` not yet expanded)
local entries = {} -- final connection entries, in file order
local by_alias = {} -- alias -> entry
local secrets = {} -- keychain account -> password (session cache)
local discovered = {} -- `databases = "*"` alias -> list of db names, or false (session cache)
local exclude = { databases = {}, schemas = {} } -- file-level `exclude = { ... }`
local loaded = false
local finalized = false
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

--- (Re)read the connections file. `databases` entries are expanded later, on
--- first use of M.entries()/M.get() (see finalize below).
function M.load()
	items, entries, by_alias = {}, {}, {}
	exclude = { databases = {}, schemas = {} }
	loaded, finalized = true, false
	local seen = {}
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
	for _, kind in ipairs({ "databases", "schemas" }) do
		exclude[kind] = vim.deepcopy((spec.exclude or {})[kind] or {})
	end
	for i, raw in ipairs(spec.connections or {}) do
		if type(raw.alias) ~= "string" or raw.alias == "" then
			vim.notify("dbconn: connection #" .. i .. " has no alias, skipped", vim.log.levels.WARN)
		elseif seen[raw.alias] then
			vim.notify("dbconn: duplicate alias '" .. raw.alias .. "', skipped", vim.log.levels.WARN)
		else
			seen[raw.alias] = true
			local d = defaults[raw.type] or {}
			local item = vim.tbl_extend("keep", raw, d)
			-- Exclusion lists add up (defaults[type] + entry) rather than replace.
			for _, key in ipairs({ "exclude_databases", "exclude_schemas" }) do
				if d[key] and raw[key] then
					item[key] = vim.list_extend(vim.deepcopy(d[key]), raw[key])
				end
			end
			table.insert(items, item)
		end
	end
	return items
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

-- -----------------------------------------------------------------------------
-- Several databases per server: `databases = { "a", "b" }` or `databases = "*"`
-- -----------------------------------------------------------------------------
-- One file entry becomes one connection per database, aliased
-- "<alias> / <database>", all sharing the entry's Keychain secret (account =
-- the entry's alias, or its `secret` string). "*" asks the server (postgres
-- only) for every database the user may connect to; that runs once per
-- session, when connections are first needed (opening the DB tab), with
-- `database` (default "postgres") as the database to connect to for the
-- lookup. If the lookup fails, `database` alone is used as the fallback.

local DISCOVER_SQL = "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate"
	.. " AND has_database_privilege(datname, 'CONNECT') ORDER BY 1"
local DISCOVER_TIMEOUT_MS = 10000

--- Run the "*" lookups for `templates` in parallel, caching names per alias.
local function discover(templates)
	local todo = {}
	for _, t in ipairs(templates) do
		if discovered[t.alias] == nil then
			if t.type == "postgres" or t.type == "postgresql" then
				table.insert(todo, t)
			else
				discovered[t.alias] = false
				vim.notify(
					"dbconn: " .. t.alias .. ': databases = "*" needs type postgres; list them instead',
					vim.log.levels.WARN
				)
			end
		end
	end
	if #todo == 0 then
		return
	end
	fetch_secrets(todo)
	local jobs = {}
	for _, t in ipairs(todo) do
		local acct = secret_account(t)
		local url = M.build_url(
			vim.tbl_extend("force", t, { database = t.database or "postgres" }),
			acct and secrets[acct] or nil
		)
		-- dadbod's own psql argv (-w: never prompt), so auth matches queries.
		local cmd = vim.fn["db#adapter#postgresql#interactive"](url, { "-X", "-q", "-A", "-t", "-c", DISCOVER_SQL })
		jobs[t.alias] = vim.system(cmd, { text = true })
	end
	for alias, job in pairs(jobs) do
		local res = job:wait(DISCOVER_TIMEOUT_MS)
		local names = {}
		for line in (res.stdout or ""):gmatch("[^\n]+") do
			table.insert(names, vim.trim(line))
		end
		if res.code == 0 and #names > 0 then
			discovered[alias] = names
		else
			discovered[alias] = false
			local why = res.code == 0 and "no databases returned" or vim.trim((res.stderr or ""):match("[^\n]*") or "")
			vim.notify(
				"dbconn: " .. alias .. ": database discovery failed (" .. (why ~= "" and why or "timed out") .. ")",
				vim.log.levels.WARN
			)
		end
	end
end

-- -----------------------------------------------------------------------------
-- Exclusions: `exclude = { databases = {...}, schemas = {...} }` at file level
-- (every connection), `exclude_databases` / `exclude_schemas` per entry or in
-- defaults[type]. Patterns are globs (`*`, `?`), whole-name, case-insensitive.
-- -----------------------------------------------------------------------------

local function glob_to_pattern(glob)
	local p = glob:lower():gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".")
	return "^" .. p .. "$"
end

--- Exclusion globs that apply to `entry` (may be nil: file-level only).
--- kind = "databases" | "schemas".
function M.exclusions(entry, kind)
	local list = vim.deepcopy(exclude[kind] or {})
	local own = entry and entry["exclude_" .. kind]
	if type(own) == "string" then
		own = { own }
	end
	return vim.list_extend(list, own or {})
end

--- Is `name` excluded for `entry`? kind = "databases" | "schemas".
function M.excluded(entry, kind, name)
	local lname = tostring(name):lower()
	for _, glob in ipairs(M.exclusions(entry, kind)) do
		if lname:match(glob_to_pattern(glob)) then
			return true
		end
	end
	return false
end

local function expand(item, names)
	local acct = secret_account(item)
	local out = {}
	for _, db in ipairs(names) do
		if M.excluded(item, "databases", db) then
			goto continue
		end
		local e = vim.deepcopy(item)
		e.databases = nil
		e.database = db
		e.alias = item.alias .. " / " .. db
		e.secret = acct -- every expansion shares the file entry's credential
		e.parent = item.alias
		table.insert(out, e)
		::continue::
	end
	return out
end

--- Build `entries` from `items`, expanding `databases`. Idempotent per load.
local function finalize()
	if finalized then
		return
	end
	finalized = true
	discover(vim.tbl_filter(function(i)
		return i.databases == "*"
	end, items))
	entries, by_alias = {}, {}
	local function add(e)
		if by_alias[e.alias] then
			vim.notify("dbconn: duplicate alias '" .. e.alias .. "', skipped", vim.log.levels.WARN)
		else
			table.insert(entries, e)
			by_alias[e.alias] = e
		end
	end
	for _, item in ipairs(items) do
		local names = item.databases
		if names == nil or names == false then -- false: opt out of a defaults[type] value
			add(item)
		else
			if names == "*" then
				names = discovered[item.alias] or (item.database and { item.database } or {})
			end
			if type(names) ~= "table" then
				vim.notify("dbconn: " .. item.alias .. ': databases must be a list or "*"', vim.log.levels.WARN)
			else
				for _, e in ipairs(expand(item, names)) do
					add(e)
				end
			end
		end
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
-- With an active group, the DBUI drawer and <leader>Dn picker show only that
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
-- Case-insensitive plain substring match against alias, type, groups, team
-- and Cloud SQL project/instance.
-- Combines with the active group (both must match).

local active_filter = nil

local function matches_filter(entry)
	if not active_filter then
		return true
	end
	local needle = active_filter:lower()
	local hay = { entry.alias, entry.type or "", entry.team or "" }
	vim.list_extend(hay, groups_of(entry))
	if type(entry.cloudsql) == "table" then
		vim.list_extend(hay, { entry.cloudsql.project or "", entry.cloudsql.instance or "" })
	end
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

--- g:db_ui_hide_schemas for the drawer. DBUI only has a global list (matched
--- by name in every connection), so this is the union of the file-level
--- schema exclusions and those of every entry shown.
function M.drawer_hidden_schemas(list)
	local seen, out = {}, {}
	local globs = M.exclusions(nil, "schemas")
	for _, e in ipairs(list) do
		vim.list_extend(globs, e.exclude_schemas and M.exclusions(e, "schemas") or {})
	end
	for _, glob in ipairs(globs) do
		if not seen[glob:lower()] then
			seen[glob:lower()] = true
			table.insert(out, "\\c" .. vim.fn.glob2regpat(glob))
		end
	end
	return out
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
	vim.g.db_ui_hide_schemas = M.drawer_hidden_schemas(visible)
	applied = true
end

function M.entries()
	if not loaded then
		M.load()
	end
	finalize()
	return entries
end

function M.get(alias)
	return M.entries() and by_alias[alias]
end

-- File aliases (= Keychain accounts) plus expanded ones already known. Never
-- triggers discovery, so <Tab> stays instant.
local function complete_alias(lead)
	if not loaded then
		M.load()
	end
	local seen, out = {}, {}
	for _, list in ipairs({ items, finalized and entries or {} }) do
		for _, e in ipairs(list) do
			if not seen[e.alias] and vim.startswith(e.alias, lead) then
				seen[e.alias] = true
				table.insert(out, e.alias)
			end
		end
	end
	return out
end
M.complete_alias = complete_alias

--- Store a password in the Keychain for an alias (or shared secret account).
function M.set_secret(alias)
	-- File entries first: M.get() could trigger "*" discovery, which would run
	-- (and fail) before this secret exists.
	if not loaded then
		M.load()
	end
	local entry
	for _, item in ipairs(items) do
		if item.alias == alias then
			entry = item
		end
	end
	entry = entry or (finalized and by_alias[alias])
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
	discovered = {} -- re-ask servers, picks up new databases
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
