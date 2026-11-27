-- =============================================================================
-- custom/dbinfo.lua
-- =============================================================================
-- Connection metadata from lua/config/db_connections.lua, shown in a centred
-- pop-up, plus opening an entry's web links.
--
--   :DBInfo [alias]   <leader>Dm, or `I` on a connection row in the drawer
--   <leader>DI        the current query buffer's (or results pane's) connection
--   :DBOpen [alias]   <leader>Do — pick one of the entry's links, open it
--   No alias: the current query buffer's connection, else the drawer's
--   connection under the cursor, else a picker.
--
-- The pop-up has a "connection" pane (type, host, database, user, secret,
-- excludes, cache) above a "metadata" pane (team, groups, env, Cloud SQL,
-- info, links, notes); it starts in metadata. o opens the link on the cursor
-- line (else picks one), y yanks the value on the cursor line, <Tab> switches
-- pane, q / <Esc> closes.
--
-- Metadata fields (all optional, any connection type; see the example file):
--   team     = "data-platform"
--   cloudsql = { project = "…", instance = "…", region = "us-central1" }
--   links    = { console = "https://…", runbook = "https://…" }
--              (or one string, or a list of strings)
--   notes    = "free text"
--   info     = { slack = "#data-platform", oncall = "…" }   any extra rows
-- Derived links: Cloud SQL console (cloudsql.project + instance) and the
-- BigQuery console (bigquery entries). Never shows passwords: only the name
-- of the Keychain account.
-- =============================================================================

local dbconn = require("custom.dbconn")

local M = {}

--- { { name, url }, … } — the entry's own links, then derived ones.
function M.links(entry)
	local out, seen = {}, {}
	local function add(name, url)
		if type(url) == "string" and url ~= "" and not seen[url] then
			seen[url] = true
			table.insert(out, { name, url })
		end
	end
	local links = entry.links
	if type(links) == "string" then
		add("web", links)
	elseif type(links) == "table" then
		for i, url in ipairs(links) do
			add("link " .. i, url)
		end
		local names = vim.tbl_filter(function(k)
			return type(k) == "string"
		end, vim.tbl_keys(links))
		table.sort(names)
		for _, name in ipairs(names) do
			add(name, links[name])
		end
	end
	local sql = entry.cloudsql
	if type(sql) == "table" and sql.project and sql.instance then
		add(
			"Cloud SQL console",
			string.format(
				"https://console.cloud.google.com/sql/instances/%s/overview?project=%s",
				sql.instance,
				sql.project
			)
		)
	end
	if entry.type == "bigquery" and entry.project then
		add("BigQuery console", "https://console.cloud.google.com/bigquery?project=" .. entry.project)
	end
	return out
end

local function pad(s, w)
	return s .. string.rep(" ", w - vim.fn.strdisplaywidth(s))
end

local function list(v)
	if v == nil then
		return nil
	end
	return type(v) == "table" and table.concat(v, ", ") or tostring(v)
end

--- Label/value rows describing an entry (no secrets), in two sections:
--- connection (how to reach it) and metadata (who owns it, links, notes).
local function rows(entry)
	local conn, meta = {}, {}
	local function adder(list)
		return function(label, value)
			if value ~= nil and value ~= "" then
				table.insert(list, { label, tostring(value) })
			end
		end
	end
	local add, addm = adder(conn), adder(meta)

	-- Connection
	local kind = entry.type or (entry.url and entry.url:match("^([%w+.-]+):")) or "?"
	add("Type", kind)
	if entry.url then
		add("URL", entry.url) -- as written in the file: the password is never in it
	elseif kind == "bigquery" then
		add("Project", entry.project)
		add("Dataset", entry.dataset)
		add("Region", entry.region)
	elseif entry.path then
		add("Path", entry.path)
	else
		add("Host", (entry.host or "localhost") .. (entry.port and (":" .. entry.port) or ""))
		add("Database", entry.database)
		add("User", entry.user)
	end
	if entry.pending then
		add("Databases", 'all ("*"), not listed yet: :DBDiscover or pick its group')
	elseif entry.parent then
		add("Server entry", entry.parent)
	end
	local acct = entry.secret == true and entry.alias or (type(entry.secret) == "string" and entry.secret) or nil
	add("Secret", acct and ('Keychain "nvim-dadbod" / "' .. acct .. '"'))
	local excl_db = list(entry.exclude_databases)
	local excl_schema = list(entry.exclude_schemas)
	add("Excludes", excl_db and (pad("databases", 12) .. excl_db))
	add(excl_db and "" or "Excludes", excl_schema and (pad("schemas", 12) .. excl_schema))
	local ok, dbmeta = pcall(require, "custom.dbmeta")
	local cache = ok and dbmeta.cache_status(entry.alias)
	add(
		"Cache",
		cache and (cache.columns .. " columns, cached " .. cache.age .. " ago") or "not cached (:DBIntrospect)"
	)

	-- Metadata
	addm("Team", entry.team)
	addm("Groups", list(entry.group))
	addm("Env", entry.env)
	local sql = entry.cloudsql
	if type(sql) == "table" then
		local sub = {}
		for _, k in ipairs({ "project", "instance", "region" }) do
			if sql[k] then
				table.insert(sub, { k, sql[k] })
			end
		end
		if sql.project and sql.region and sql.instance then
			table.insert(sub, { "connection", sql.project .. ":" .. sql.region .. ":" .. sql.instance })
		end
		for i, kv in ipairs(sub) do
			addm(i == 1 and "Cloud SQL" or "", pad(kv[1], 12) .. kv[2])
		end
	end
	if type(entry.info) == "table" then
		local keys = vim.tbl_keys(entry.info)
		table.sort(keys, function(x, y)
			return tostring(x) < tostring(y)
		end)
		for _, k in ipairs(keys) do
			addm(tostring(k), list(entry.info[k]))
		end
	end
	local links, lw = M.links(entry), 0
	for _, link in ipairs(links) do
		lw = math.max(lw, vim.fn.strdisplaywidth(link[1]))
	end
	for i, link in ipairs(links) do
		addm(i == 1 and "Links" or "", pad(link[1], lw + 2) .. link[2])
	end
	if entry.notes then
		for i, line in ipairs(vim.split(tostring(entry.notes), "\n", { plain = true })) do
			addm(i == 1 and "Notes" or "", line)
		end
	end
	return conn, meta
end

local function open_url(url)
	local _, err = vim.ui.open(url)
	if err then
		vim.notify("dbinfo: " .. err, vim.log.levels.ERROR)
	end
end

--- Pick one of the entry's links (or open it if there is just one).
function M.open_link(entry)
	local links = M.links(entry)
	if #links == 0 then
		vim.notify("dbinfo: " .. entry.alias .. " has no links (add `links = { … }`)", vim.log.levels.WARN)
	elseif #links == 1 then
		open_url(links[1][2])
	else
		vim.ui.select(links, {
			prompt = entry.alias .. " links:",
			format_item = function(l)
				return l[1] .. "  " .. l[2]
			end,
		}, function(choice)
			if choice then
				open_url(choice[2])
			end
		end)
	end
end

--- Info pop-up for an alias or entry: a "connection" pane above a
--- "metadata" pane (custom.dbpopup stack; <Tab> switches between them).
function M.show(target)
	local entry = type(target) == "table" and target or dbconn.get(target)
	if not entry then
		vim.notify("dbinfo: '" .. tostring(target) .. "' is not in the connections file", vim.log.levels.WARN)
		return
	end
	local conn, meta = rows(entry)
	if #meta == 0 then
		meta = { { "", "no metadata (team, cloudsql, links, notes, info — see db_connections.example.lua)" } }
	end
	-- One label width across both panes so their values line up.
	local lw = 0
	for _, list in ipairs({ conn, meta }) do
		for _, row in ipairs(list) do
			lw = math.max(lw, vim.fn.strdisplaywidth(row[1]))
		end
	end
	local function pane(list, title)
		local lines, hl = {}, {}
		for i, row in ipairs(list) do
			table.insert(lines, " " .. pad(row[1], lw + 2) .. row[2] .. " ")
			if row[1] ~= "" then
				table.insert(hl, { i - 1, "Title", 1, 1 + #row[1] })
			end
		end
		return { lines = lines, title = title, highlights = hl }
	end
	local sections = { conn, meta }
	local function value(i, lnum)
		local row = sections[i][lnum]
		return row and row[2] or ""
	end
	require("custom.dbpopup").open_stack({
		panes = { pane(conn, entry.alias .. " · connection"), pane(meta, "metadata") },
		footer = "o open link · y yank value · <Tab> switch pane · q close",
		focus = 2, -- links live in metadata
		keys = {
			o = {
				function(i, lnum)
					local url = value(i, lnum):match("https?://%S+")
					if url then
						open_url(url)
					else
						M.open_link(entry)
					end
				end,
				"Open link",
			},
			y = {
				function(i, lnum)
					local v = value(i, lnum)
					-- Links rows are "name  url": yank just the url.
					v = v:match("https?://%S+") or v
					vim.fn.setreg('"', v)
					vim.fn.setreg("+", v)
					vim.notify("dbinfo: yanked " .. v)
				end,
				"Yank value",
			},
		},
	})
end

--- The connection of a query buffer: <leader>Dn buffers carry b:db_alias,
--- drawer-opened ones b:dbui_db_key_name (DBUI's "<name>_<source>" key).
local function buffer_entry(buf)
	local alias = vim.b[buf].db_alias
	if alias then
		return dbconn.get(alias)
	end
	local key = vim.b[buf].dbui_db_key_name
	if type(key) == "string" and key ~= "" then
		local ok, name =
			pcall(vim.fn.eval, "get(get(db_ui#drawer#get().dbui.dbs, " .. vim.fn.string(key) .. ", {}), 'name', '')")
		return ok and name ~= "" and dbconn.get(name) or nil
	end
end

--- The connection meant by "no argument": current buffer, drawer row, or nil.
local function current_entry()
	local from_buffer = buffer_entry(0)
	if from_buffer then
		return from_buffer
	end
	if vim.bo.filetype == "dbout" then -- a results pane: its query buffer
		local src = require("custom.dbtab").result_source(vim.api.nvim_get_current_win())
		return src and buffer_entry(src) or nil
	end
	if vim.bo.filetype == "dbui" then
		local ok, alias = pcall(
			vim.fn.eval,
			"get(get(db_ui#drawer#get().dbui.dbs, db_ui#drawer#get().content[line('.') - 1].dbui_db_key_name, {}), 'name', '')"
		)
		if ok and alias ~= "" then
			return dbconn.get(alias)
		end
	end
end

local function with_entry(name, prompt, fn)
	if name and name ~= "" then
		local entry = dbconn.get(name)
		if not entry then
			return vim.notify("dbinfo: unknown connection '" .. name .. "'", vim.log.levels.WARN)
		end
		return fn(entry)
	end
	local entry = current_entry()
	if entry then
		return fn(entry)
	end
	vim.ui.select(dbconn.entries(), {
		prompt = prompt,
		format_item = function(e)
			return string.format("%-32s %-16s %s", e.alias, e.team or "", e.type or "url")
		end,
	}, function(choice)
		if choice then
			fn(choice)
		end
	end)
end

--- Info pop-up for the current query buffer's (or results pane's)
--- connection only; no picker.
function M.info_current()
	local entry = current_entry()
	if not entry then
		vim.notify("dbinfo: this buffer has no connection (open a query with <leader>Dn)", vim.log.levels.WARN)
		return
	end
	M.show(entry)
end

function M.info(name)
	with_entry(name, "Connection info:", M.show)
end

function M.open(name)
	with_entry(name, "Open links for:", M.open_link)
end

vim.api.nvim_create_user_command("DBInfo", function(opts)
	M.info(opts.args)
end, {
	nargs = "?",
	complete = function(lead)
		return dbconn.complete_alias(lead)
	end,
	desc = "Show a DB connection's metadata (no argument: current buffer's)",
})

vim.api.nvim_create_user_command("DBOpen", function(opts)
	M.open(opts.args)
end, {
	nargs = "?",
	complete = function(lead)
		return dbconn.complete_alias(lead)
	end,
	desc = "Open one of a DB connection's links (no argument: current buffer's)",
})

return M
