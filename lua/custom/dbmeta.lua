-- =============================================================================
-- custom/dbmeta.lua
-- =============================================================================
-- DataGrip-style schema cache: introspect a connection's columns once, keep
-- them on disk, and fuzzy-search every cached column across all connections.
--
--   :DBIntrospect [alias]   fetch (or refresh) the column catalog of one
--                           connection. No argument: the current query
--                           buffer's connection, else pick one. A `databases`
--                           parent alias ("Billing: Dev") does each of its
--                           databases. Only ever runs when invoked: nothing is
--                           introspected automatically.
--   :DBColumns [query]      fzf over every cached column (<leader>Ds); matches
--                           column names only, ctrl-t toggles matching
--                           alias/table/type too
--       <CR>    new query buffer: SELECT * FROM <table> LIMIT 100
--       ctrl-y  yank the qualified table name
--       ctrl-r  open the DBUI drawer expanded down to that table
--   :DBTables [query]       same, one row per schema.table (<leader>DT);
--                           matches connection + schema.table, same keys
--       preview lists the table's columns and when the cache was taken
--   I (in the DBUI drawer)  on a table: centred float with its columns/types,
--                           from the cache, else one live query. On a
--                           connection: its info (custom.dbinfo). q closes.
--
-- Cache: stdpath("cache")/dbmeta/<alias>.tsv, one row per column
-- (schema, table, column, type, nullable), first line a header with the alias
-- and fetch time. Schema metadata only, never credentials, but it describes
-- prod databases, so the dir is 0700 and it lives outside the dotfiles repo.
--
-- Excluded schemas (`exclude_schemas`, file-level `exclude.schemas`; for
-- MySQL also `exclude_databases`) are left out of the cache.
--
-- Supported: postgres (pg_catalog; tables, views, matviews, foreign tables,
-- partition parents), mysql/mariadb (information_schema, all non-system
-- schemas), bigquery (INFORMATION_SCHEMA.COLUMNS for the entry's dataset, or
-- the whole project in `region` — default "us" — billed at BigQuery's 10 MB
-- minimum), sqlite. Queries use dadbod's own client argv, so auth behaves
-- exactly like running a query.
-- =============================================================================

local dbconn = require("custom.dbconn")

local M = {}

local DIR = vim.fn.stdpath("cache") .. "/dbmeta"
local MAX_JOBS = 4 -- concurrent introspections (a parent alias may have many dbs)
local TIMEOUT_MS = 180000
local BQ_MAX_ROWS = 2000000

local running = {} -- alias -> true while its job is in flight

-- -----------------------------------------------------------------------------
-- Catalog queries, one per connection type
-- -----------------------------------------------------------------------------

local PG_SQL = [[
SELECT n.nspname, c.relname, a.attname, format_type(a.atttypid, a.atttypmod),
       CASE WHEN a.attnotnull THEN 'NO' ELSE 'YES' END
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE a.attnum > 0 AND NOT a.attisdropped
  AND c.relkind IN ('r', 'p', 'v', 'm', 'f') AND NOT c.relispartition
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg\_toast%' AND n.nspname NOT LIKE 'pg\_temp%'
  AND has_schema_privilege(n.oid, 'USAGE'){filter}
ORDER BY 1, 2, a.attnum]]

local MYSQL_SQL = [[
SELECT table_schema, table_name, column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys'){filter}
ORDER BY table_schema, table_name, ordinal_position]]

local SQLITE_SQL = [[
SELECT 'main', m.name, p.name, p.type, CASE WHEN p."notnull" THEN 'NO' ELSE 'YES' END
FROM sqlite_master m JOIN pragma_table_info(m.name) p
WHERE m.type IN ('table', 'view') AND m.name NOT LIKE 'sqlite\_%' ESCAPE '\'{filter}
ORDER BY m.name, p.cid]]

local function kind_of(entry)
	local k = entry.type or (entry.url and entry.url:match("^([%w+.-]+):"))
	return ({ postgresql = "postgres", mariadb = "mysql" })[k] or k
end

-- Parse "a\tb\tc\td\te" lines into rows.
local function parse_tsv(out)
	local rows = {}
	for line in out:gmatch("[^\n]+") do
		local f = vim.split(line, "\t", { plain = true })
		if #f >= 5 then
			table.insert(rows, { f[1], f[2], f[3], f[4], f[5] })
		end
	end
	return rows
end

local function parse_bq(out)
	local ok, data = pcall(vim.json.decode, out)
	if not ok or type(data) ~= "table" then
		return nil, "unexpected bq output"
	end
	local rows = {}
	for _, r in ipairs(data) do
		table.insert(rows, { r.table_schema, r.table_name, r.column_name, r.data_type, r.is_nullable })
	end
	return rows
end

-- SQL string literals. Standard SQL doubles quotes; MySQL and BigQuery also
-- treat backslash as an escape.
local function lit(v)
	return "'" .. tostring(v):gsub("'", "''") .. "'"
end
local function lit_bs(v)
	return "'" .. tostring(v):gsub("[\\']", "\\%0") .. "'"
end

local function with_filter(sql, clause)
	return (sql:gsub("{filter}", function()
		return clause
	end))
end

--- { cmd = argv, parse = fn(stdout) -> rows|nil, err } for an entry, or nil, why.
--- `only` = { schema = ?, table = } restricts it to one table (schema "" or
--- nil: the connection's default schema).
local function command_for(entry, only)
	local kind = kind_of(entry)
	local has_schema = only and only.schema and only.schema ~= ""
	if kind == "postgres" then
		local clause = only
				and ((has_schema and ("\n  AND n.nspname = " .. lit(only.schema)) or "") .. "\n  AND c.relname = " .. lit(
					only.table
				))
			or ""
		return {
			cmd = vim.fn["db#adapter#postgresql#interactive"](
				dbconn.url(entry),
				{ "-X", "-q", "-A", "-t", "-F", "\t", "-c", with_filter(PG_SQL, clause) }
			),
			parse = parse_tsv,
		}
	elseif kind == "mysql" then
		local clause = only
				and ("\n  AND table_schema = " .. (has_schema and lit_bs(only.schema) or "DATABASE()") .. "\n  AND table_name = " .. lit_bs(
					only.table
				))
			or ""
		return {
			cmd = vim.list_extend(
				vim.fn["db#adapter#mysql#interactive"](dbconn.url(entry)),
				{ "-B", "-N", "-e", with_filter(MYSQL_SQL, clause) }
			),
			parse = parse_tsv,
		}
	elseif kind == "sqlite" then
		local clause = only and (" AND m.name = " .. lit(only.table)) or ""
		return {
			cmd = {
				"sqlite3",
				"-readonly",
				"-batch",
				"-noheader",
				"-separator",
				"\t",
				entry.path,
				with_filter(SQLITE_SQL, clause),
			},
			parse = parse_tsv,
		}
	elseif kind == "bigquery" then
		local dataset = has_schema and only.schema or entry.dataset
		local view = dataset and string.format("`%s.%s`", entry.project, dataset)
			or string.format("`%s`.`region-%s`", entry.project, entry.region or "us")
		local sql = "SELECT table_schema, table_name, column_name, data_type, is_nullable FROM "
			.. view
			.. ".INFORMATION_SCHEMA.COLUMNS"
			.. (only and (" WHERE table_name = " .. lit_bs(only.table)) or "")
			.. " ORDER BY table_schema, table_name, ordinal_position"
		-- dadbod's argv ends in the subcommand; global flags must precede it.
		local cmd = vim.fn["db#adapter#bigquery#filter"](dbconn.url(entry))
		table.remove(cmd) -- "query"
		vim.list_extend(cmd, {
			"--format=json",
			"--headless",
			"query",
			"--nouse_legacy_sql",
			"--max_rows=" .. BQ_MAX_ROWS,
			sql,
		})
		return { cmd = cmd, parse = parse_bq }
	end
	return nil, "introspection not supported for type " .. tostring(kind)
end

--- Rows minus those in excluded schemas (MySQL: a schema is a database, so
--- `exclude_databases` applies there too).
local function drop_excluded(entry, rows)
	local mysql = kind_of(entry) == "mysql"
	return vim.tbl_filter(function(r)
		return not (dbconn.excluded(entry, "schemas", r[1]) or (mysql and dbconn.excluded(entry, "databases", r[1])))
	end, rows)
end

--- Run command_for(entry, only) in the background; cb(rows) or cb(nil, err)
--- on the main loop.
local function run(entry, only, cb)
	local ok_spec, spec, why = pcall(command_for, entry, only)
	if not ok_spec or not spec then
		-- pcall gives (false, err) on error, (true, nil, why) on unsupported.
		return vim.schedule(function()
			cb(nil, ok_spec and why or tostring(spec))
		end)
	end
	vim.system(spec.cmd, { text = true, timeout = TIMEOUT_MS }, function(res)
		vim.schedule(function()
			if res.code ~= 0 or res.signal ~= 0 then
				local msg = vim.trim((res.stderr or ""):match("[^\n]*[^%s][^\n]*") or "")
				if res.signal ~= 0 and msg == "" then
					msg = "timed out"
				end
				return cb(nil, msg ~= "" and msg or ("exit " .. res.code))
			end
			cb(spec.parse(res.stdout or ""))
		end)
	end)
end

-- -----------------------------------------------------------------------------
-- Cache files
-- -----------------------------------------------------------------------------

local function cache_path(alias)
	local name = alias:gsub("[^%w%-_.]", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
	return DIR .. "/" .. name .. ".tsv"
end

local function clean(v)
	return (tostring(v == nil and "" or v):gsub("[\t\r\n]", " "))
end

local function write_cache(entry, rows)
	vim.fn.mkdir(DIR, "p", tonumber("700", 8))
	local lines = { table.concat({ "#dbmeta", "1", clean(entry.alias), clean(kind_of(entry)), os.time() }, "\t") }
	for _, r in ipairs(rows) do
		table.insert(lines, table.concat(vim.tbl_map(clean, r), "\t"))
	end
	local path = cache_path(entry.alias)
	local tmp = path .. ".tmp"
	vim.fn.writefile(lines, tmp)
	vim.uv.fs_chmod(tmp, tonumber("600", 8))
	vim.uv.fs_rename(tmp, path)
end

--- Header of one cache file: { alias, kind, fetched, path } or nil.
local function read_header(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local line = f:read("*l") or ""
	f:close()
	local tag, _, alias, kind, fetched = unpack(vim.split(line, "\t", { plain = true }))
	if tag ~= "#dbmeta" or not alias then
		return nil
	end
	return { alias = alias, kind = kind, fetched = tonumber(fetched), path = path }
end

local function cached_files()
	local out = {}
	for _, path in ipairs(vim.fn.glob(DIR .. "/*.tsv", true, true)) do
		local h = read_header(path)
		if h then
			table.insert(out, h)
		end
	end
	table.sort(out, function(a, b)
		return a.alias < b.alias
	end)
	return out
end

local function age(epoch)
	local s = os.time() - (epoch or 0)
	if s < 3600 then
		return math.floor(s / 60) .. "m"
	elseif s < 86400 then
		return math.floor(s / 3600) .. "h"
	end
	return math.floor(s / 86400) .. "d"
end

-- -----------------------------------------------------------------------------
-- :DBIntrospect
-- -----------------------------------------------------------------------------

--- Connections named by `name`: that alias, or every database of a parent.
local function resolve(name)
	-- A `databases = "*"` server alias: make sure its databases are listed
	-- first (the lookup normally only runs for the active group/filter).
	dbconn.ensure_discovered(name)
	-- A server alias means all its databases (dbconn.get would give just one).
	local children = vim.tbl_filter(function(e)
		return e.parent == name
	end, dbconn.entries())
	if #children > 0 then
		return children
	end
	local entry = dbconn.get(name)
	return entry and { entry } or {}
end

--- Introspect `list` in the background (MAX_JOBS at a time), then report once.
function M.introspect(list)
	local queue, ok, failed, columns = {}, {}, {}, 0
	for _, e in ipairs(list) do
		if running[e.alias] then
			vim.notify("dbmeta: " .. e.alias .. " is already being introspected", vim.log.levels.WARN)
		else
			table.insert(queue, e)
		end
	end
	local total, active = #queue, 0
	if total == 0 then
		return
	end
	vim.notify("dbmeta: introspecting " .. (total == 1 and queue[1].alias or (total .. " connections")) .. "…")

	local function finish()
		local msg = string.format(
			"dbmeta: cached %d column%s from %d connection%s",
			columns,
			columns == 1 and "" or "s",
			#ok,
			#ok == 1 and "" or "s"
		)
		if #ok == 0 then
			msg = "dbmeta: introspection failed"
		end
		if #failed > 0 then
			msg = msg .. (#ok == 0 and ":" or "\nfailed:") .. "\n  " .. table.concat(failed, "\n  ")
		end
		vim.notify(msg, #failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
	end

	local start_next
	local function done(entry, rows, err)
		running[entry.alias] = nil
		active = active - 1
		if rows then
			write_cache(entry, rows)
			columns = columns + #rows
			table.insert(ok, entry.alias)
		else
			table.insert(failed, entry.alias .. ": " .. err)
		end
		if #queue == 0 and active == 0 then
			finish()
		else
			start_next()
		end
	end

	start_next = function()
		while active < MAX_JOBS and #queue > 0 do
			local entry = table.remove(queue, 1)
			running[entry.alias] = true
			active = active + 1
			run(entry, nil, function(rows, err)
				done(entry, rows and drop_excluded(entry, rows), err)
			end)
		end
	end
	start_next()
end

--- :DBIntrospect [alias] — see the header for how the target is chosen.
function M.command(name)
	if name and name ~= "" then
		local list = resolve(name)
		if #list == 0 then
			vim.notify("dbmeta: unknown connection '" .. name .. "'", vim.log.levels.WARN)
			return
		end
		return M.introspect(list)
	end
	local current = vim.b.db_alias and dbconn.get(vim.b.db_alias)
	if current then
		return M.introspect({ current })
	end
	-- Pick one: every connection, plus "<parent> (all databases)" rows; a
	-- parent is resolved (and, for "*", looked up) only once it is picked.
	local choices, parents = {}, {}
	for _, e in ipairs(dbconn.entries()) do
		if e.parent and not parents[e.parent] then
			parents[e.parent] = true
			table.insert(choices, { label = e.parent .. "  (all databases)", parent = e.parent })
		end
		table.insert(choices, { label = e.alias, list = { e } })
	end
	if #choices == 0 then
		vim.notify("dbmeta: no connections (see lua/config/db_connections.lua)", vim.log.levels.WARN)
		return
	end
	vim.ui.select(choices, {
		prompt = "Introspect connection:",
		format_item = function(c)
			return c.label
		end,
	}, function(choice)
		if choice then
			M.introspect(choice.list or resolve(choice.parent))
		end
	end)
end

-- -----------------------------------------------------------------------------
-- :DBColumns / :DBTables pickers
-- -----------------------------------------------------------------------------

local function quote_ident(kind, name)
	if kind == "mysql" then
		return name:match("^[%w_$]+$") and name or ("`" .. name:gsub("`", "``") .. "`")
	end
	return name:match("^[%l_][%l%d_$]*$") and name or ('"' .. name:gsub('"', '""') .. '"')
end

--- How to write schema.table in a query on this connection.
local function qualified_table(entry, kind, schema, tbl)
	if kind == "bigquery" then
		return string.format("`%s.%s.%s`", entry and entry.project or "?", schema, tbl)
	elseif kind == "sqlite" then
		return quote_ident(kind, tbl)
	end
	return quote_ident(kind, schema) .. "." .. quote_ident(kind, tbl)
end

-- Picker lines: visible fields first, then three hidden fields used by the
-- preview and the actions, always last so both pickers share them:
--   columns: alias \t schema.table \t column \t type   \t path \t schema \t table
--   tables:  alias \t schema.table \t N cols           \t path \t schema \t table
-- Visible fields are space-padded into columns (the padding is trimmed on read).
local MAX_PAD = 48

local function pad(s, width)
	return s .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(s)))
end

-- Pad the first `n` fields of every row and join into tab-separated lines.
local function to_lines(rows, n)
	local w = {}
	for i = 1, n do
		w[i] = 0
		for _, row in ipairs(rows) do
			w[i] = math.min(MAX_PAD, math.max(w[i], vim.fn.strdisplaywidth(row[i])))
		end
	end
	local lines = {}
	for _, row in ipairs(rows) do
		for i = 1, n do
			row[i] = pad(row[i], w[i])
		end
		table.insert(lines, table.concat(row, "\t"))
	end
	return lines
end

--- Every cached column: cb(header, schema, table, column, type) per row.
local function each_cached(files, cb)
	for _, h in ipairs(files) do
		local first = true
		for line in io.lines(h.path) do
			if first then
				first = false
			else
				local s, t, c, ty = unpack(vim.split(line, "\t", { plain = true }))
				if c then
					cb(h, s, t, c, ty or "")
				end
			end
		end
	end
end

local function column_lines(files)
	local rows = {}
	each_cached(files, function(h, s, t, c, ty)
		table.insert(rows, { h.alias, s .. "." .. t, c, ty, h.path, s, t })
	end)
	return to_lines(rows, 3)
end

local function table_lines(files)
	local rows, index = {}, {}
	each_cached(files, function(h, s, t)
		local key = h.path .. "\0" .. s .. "\0" .. t
		if not index[key] then
			index[key] = { h.alias, s .. "." .. t, 0, h.path, s, t }
			table.insert(rows, index[key])
		end
		index[key][3] = index[key][3] + 1
	end)
	for _, row in ipairs(rows) do
		row[3] = row[3] .. (row[3] == 1 and " col" or " cols")
	end
	return to_lines(rows, 2)
end

local function parse_line(line)
	local f = vim.split(line, "\t", { plain = true })
	local n = #f
	return { alias = vim.trim(f[1]), path = f[n - 2], schema = f[n - 1], table = f[n] }
end

-- Shell preview: the selected table's columns, read back from its cache file.
local PREVIEW = [[S={-2} T={-1} awk -F'\t' '
NR == 1 { cmd = "date -r " $5 " \"+%Y-%m-%d %H:%M\""; cmd | getline when; close(cmd)
          print $3 "  ·  " ENVIRON["S"] "." ENVIRON["T"]; print "cached " when; print ""; next }
$1 == ENVIRON["S"] && $2 == ENVIRON["T"] { printf "%-36s %-28s %s\n", $3, $4, ($5 == "NO" ? "not null" : "") }
' {-3}]]

local function selected_target(selected)
	local sel = selected and selected[1]
	if not sel then
		return nil
	end
	local item = parse_line(sel)
	local entry = dbconn.get(item.alias)
	local h = read_header(item.path)
	local kind = (entry and kind_of(entry)) or (h and h.kind)
	return item, entry, kind
end

local function gone(item)
	vim.notify("dbmeta: '" .. item.alias .. "' is no longer in the connections file", vim.log.levels.WARN)
end

--- DBUI drawer items (plain data, one per drawer line).
local function drawer_items()
	local ok, items = pcall(vim.fn.eval, "db_ui#drawer#get().content")
	return ok and type(items) == "table" and items or {}
end

--- Open the drawer on `entry`, expand down to schema/table, cursor on it.
function M.reveal_table(entry, schema, tbl)
	require("custom.dbtab").reveal(entry) -- connection row, expanded, cursor on it
	if vim.bo.filetype ~= "dbui" then
		return
	end
	local current = drawer_items()[vim.fn.line(".")]
	local key = current and current.dbui_db_key_name
	if not key or key == "" then
		return
	end
	local function find(path)
		for i, item in ipairs(drawer_items()) do
			if item.dbui_db_key_name == key and item.type == path then
				return i, item
			end
		end
	end
	local function open(path)
		local lnum, item = find(path)
		if not lnum then
			return false
		end
		vim.api.nvim_win_set_cursor(0, { lnum, 0 })
		if item.expanded == 0 or item.expanded == false then
			vim.cmd([[execute "normal \<Plug>(DBUI_SelectLine)"]])
		end
		return true
	end
	local target
	if find("schemas") then
		target = open("schemas")
			and open("schemas->items->" .. schema)
			and find("schemas->items->" .. schema .. "->tables->items->" .. tbl)
	else
		target = open("tables") and find("tables->items->" .. tbl)
	end
	if not target then
		vim.notify(
			"dbmeta: " .. schema .. "." .. tbl .. " not in the drawer (excluded schema, or press R to refresh it)",
			vim.log.levels.WARN
		)
		return
	end
	vim.api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd("normal! zz")
end

-- Shared by both pickers.
local actions = {
	["default"] = function(selected)
		local item, entry, kind = selected_target(selected)
		if not item then
			return
		elseif not entry then
			return gone(item)
		end
		local tbl = qualified_table(entry, kind, item.schema, item.table)
		require("custom.dbtab").open_query(entry, false, { "SELECT *", "FROM " .. tbl, "LIMIT 100;" })
	end,
	["ctrl-y"] = function(selected)
		local item, entry, kind = selected_target(selected)
		if item then
			local tbl = qualified_table(entry, kind, item.schema, item.table)
			vim.fn.setreg('"', tbl)
			vim.fn.setreg("+", tbl)
			vim.notify("dbmeta: yanked " .. tbl)
		end
	end,
	["ctrl-r"] = function(selected)
		local item, entry = selected_target(selected)
		if entry then
			M.reveal_table(entry, item.schema, item.table)
		elseif item then
			gone(item)
		end
	end,
}

local function cache_header(files, what)
	local oldest = math.huge
	for _, h in ipairs(files) do
		oldest = math.min(oldest, h.fetched or 0)
	end
	return string.format(
		"%d connections cached, oldest %s ago · %s · <CR> select · ctrl-y yank table · ctrl-r show in drawer",
		#files,
		age(oldest),
		what
	)
end

local function cached_or_warn()
	local files = cached_files()
	if #files == 0 then
		vim.notify("dbmeta: nothing cached yet — run :DBIntrospect on a connection first", vim.log.levels.WARN)
		return nil
	end
	return files
end

--- Fuzzy-search every cached column. `query` pre-fills the prompt.
function M.columns(query)
	local files = cached_or_warn()
	if not files then
		return
	end
	require("fzf-lua").fzf_exec(column_lines(files), {
		prompt = "Columns> ",
		query = query,
		preview = PREVIEW,
		keymap = { fzf = { ["ctrl-t"] = "change-nth(1..4|3)" } },
		fzf_opts = {
			["--delimiter"] = "\t",
			["--with-nth"] = "1..4",
			-- Match column names only; ctrl-t flips to alias/table/type as well.
			["--nth"] = "3",
			["--tabstop"] = "2",
			["--header"] = cache_header(files, "matching column names (ctrl-t: all fields)"),
		},
		actions = actions,
	})
end

--- Fuzzy-search every cached schema.table (one row per table). Matches the
--- connection alias and schema.table; `query` pre-fills the prompt.
function M.tables(query)
	local files = cached_or_warn()
	if not files then
		return
	end
	require("fzf-lua").fzf_exec(table_lines(files), {
		prompt = "Tables> ",
		query = query,
		preview = PREVIEW,
		fzf_opts = {
			["--delimiter"] = "\t",
			["--with-nth"] = "1..3",
			["--nth"] = "1..2",
			["--tabstop"] = "2",
			["--header"] = cache_header(files, "matching connection + schema.table"),
		},
		actions = actions,
	})
end

-- -----------------------------------------------------------------------------
-- Drawer pop-up: `I` on a table row (or one of its helper rows) in DBUI
-- -----------------------------------------------------------------------------
-- Reads the item under the cursor through db_ui#drawer#get() (DBUI's public
-- accessor). Columns come from the :DBIntrospect cache when it has the table,
-- otherwise from a live catalog query for that one table.

-- { alias, schema, table, url, scheme } for the drawer line under the cursor.
local function drawer_table()
	local ok, item = pcall(vim.fn.eval, "db_ui#drawer#get().content[line('.') - 1]")
	if not ok or type(item) ~= "table" then
		return nil
	end
	local schema, tbl = item.schema, item.table -- helper rows ("Columns", "List", …)
	if not tbl and type(item.type) == "string" then -- the table row itself
		schema, tbl = item.type:match("^schemas%->items%->(.-)%->tables%->items%->(.+)$")
		if not tbl then
			tbl = item.type:match("^tables%->items%->(.+)$")
		end
	end
	if not tbl or item.dbui_db_key_name == "" then
		return nil
	end
	local key = vim.fn.string(item.dbui_db_key_name)
	local db = vim.fn.eval(
		"{ 'name': db_ui#drawer#get().dbui.dbs["
			.. key
			.. "].name, 'url': db_ui#drawer#get().dbui.dbs["
			.. key
			.. "].url }"
	)
	return { alias = db.name, url = db.url, schema = schema or "", table = tbl }
end

--- Cached rows for one table: rows, fetched-epoch; nil when not cached.
local function cached_table(alias, schema, tbl)
	local path = cache_path(alias)
	local h = read_header(path)
	if not h then
		return nil
	end
	local rows, first = {}, true
	for line in io.lines(path) do
		if first then
			first = false
		else
			local r = vim.split(line, "\t", { plain = true })
			if r[2] == tbl and (schema == "" or r[1] == schema) then
				table.insert(rows, r)
			end
		end
	end
	if #rows == 0 then
		return nil -- table newer than the cache: fall through to a live query
	end
	return rows, h.fetched
end

--- Centred pop-up: COLUMN / TYPE / NULL, one row per column (custom.dbpopup).
local function show_columns(t, rows, source)
	local cells = { { "COLUMN", "TYPE", "NULL" } }
	for _, r in ipairs(rows) do
		table.insert(cells, { r[3], r[4] or "", r[5] == "NO" and "not null" or "" })
	end
	local name = (t.schema ~= "" and (t.schema .. ".") or "") .. t.table
	require("custom.dbpopup").open({
		lines = require("custom.dbpopup").columns(cells),
		title = name,
		footer = t.alias .. " · " .. #rows .. " columns · " .. source,
		highlights = { { 0, "Title" } },
	})
end

--- { columns = n, fetched = epoch } for an alias's cache file, or nil.
function M.cache_status(alias)
	local path = cache_path(alias)
	local h = read_header(path)
	if not h then
		return nil
	end
	return { columns = #vim.fn.readfile(path) - 1, fetched = h.fetched, age = age(h.fetched) }
end

--- Float listing the columns of the table under the cursor in the DBUI drawer.
function M.drawer_columns()
	local t = drawer_table()
	if not t then
		-- On a connection row (or anything under it that isn't a table): info.
		local ok, alias = pcall(
			vim.fn.eval,
			"get(get(db_ui#drawer#get().dbui.dbs, db_ui#drawer#get().content[line('.') - 1].dbui_db_key_name, {}), 'name', '')"
		)
		if ok and alias ~= "" then
			return require("custom.dbinfo").show(alias)
		end
		vim.notify("dbmeta: put the cursor on a connection or a table in the drawer", vim.log.levels.WARN)
		return
	end
	local rows, fetched = cached_table(t.alias, t.schema, t.table)
	if rows then
		return show_columns(t, rows, "cached " .. age(fetched) .. " ago")
	end
	-- Not cached: one live catalog query for this table only.
	local entry = dbconn.get(t.alias) or { alias = t.alias, url = t.url }
	if not entry.type and entry.url then -- a connection DBUI knows but the file doesn't
		local kind = kind_of(entry)
		if kind == "sqlite" then
			entry.path = entry.url:gsub("^sqlite:", "")
		elseif kind == "bigquery" then
			entry.project = entry.url:match("^bigquery:([^:?/]+)")
		end
	end
	local win = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(win)
	run(entry, { schema = t.schema, table = t.table }, function(live, err)
		if not live then
			return vim.notify("dbmeta: " .. t.alias .. ": " .. tostring(err), vim.log.levels.WARN)
		elseif #live == 0 then
			return vim.notify("dbmeta: no columns visible for " .. t.table, vim.log.levels.WARN)
		end
		-- Only pop up if the cursor is still where it was asked from.
		if vim.api.nvim_get_current_win() == win and vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor) then
			show_columns(t, live, "live")
		end
	end)
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("dbmeta", { clear = true }),
	pattern = "dbui",
	callback = function(ev)
		-- K is DBUI's "previous sibling"; I (inspect) is free.
		vim.keymap.set("n", "I", M.drawer_columns, {
			buffer = ev.buf,
			desc = "Database: table columns / connection info",
		})
	end,
})

vim.api.nvim_create_user_command("DBIntrospect", function(opts)
	M.command(opts.args)
end, {
	nargs = "?",
	complete = function(lead)
		return dbconn.complete_alias(lead)
	end,
	desc = "Cache a DB connection's columns for :DBColumns (no argument: current buffer's)",
})

vim.api.nvim_create_user_command("DBColumns", function(opts)
	M.columns(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", desc = "Search cached DB columns across connections" })

vim.api.nvim_create_user_command("DBTables", function(opts)
	M.tables(opts.args ~= "" and opts.args or nil)
end, { nargs = "?", desc = "Search cached DB schemas/tables across connections" })

return M
