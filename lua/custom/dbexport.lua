-- =============================================================================
-- custom/dbexport.lua
-- =============================================================================
-- :DBExport [file] — re-run the current query buffer (or a line range /
-- visual selection) against its connection (b:db) in the client's CSV mode,
-- and write the result to a file. Works in DBUI drawer buffers and
-- <leader>Dq buffers alike.
--
-- Dadbod's own adapters build the base command, so connection handling
-- (host, user, Keychain password in the URL, bq project/params) is identical
-- to a normal :DB run; only the output-format flags are added:
--   postgres          psql -X -q --csv -v ON_ERROR_STOP=1
--   mysql / mariadb   mysql --batch (TSV), converted to CSV here
--   bigquery          bq --format=csv --quiet query --max_rows=N
--   sqlite / duckdb   -csv [-header]
--
-- The query runs a SECOND time. BigQuery re-runs are billed, and a statement
-- that isn't a read (SELECT/WITH/…) repeats its side effects, so both ask for
-- confirmation first. MySQL NULLs export as empty fields (as psql --csv does);
-- a literal string 'NULL' is indistinguishable from NULL in MySQL batch output.
-- =============================================================================

local M = {}

M.bigquery_max_rows = 100000
M.default_dir = vim.fn.expand("~/Downloads")
M.progress_interval_ms = 15000 -- "still running" notification cadence

local READ_KEYWORDS = {
	select = true,
	with = true,
	show = true,
	explain = true,
	describe = true,
	desc = true,
	values = true,
	table = true,
	pragma = true,
}

-- CSV field quoting per RFC 4180.
local function csv_field(s)
	if s:find('[,"\r\n]') then
		return '"' .. s:gsub('"', '""') .. '"'
	end
	return s
end

-- mysql --batch: tab-separated, with \t \n \\ \0 escaped and NULL as "NULL".
local MYSQL_UNESCAPE = { t = "\t", n = "\n", ["\\"] = "\\", ["0"] = "\0", r = "\r" }

local function mysql_tsv_to_csv(tsv)
	local out = {}
	for line in vim.gsplit(tsv:gsub("\n$", ""), "\n", { plain = true }) do
		local fields = {}
		for field in vim.gsplit(line, "\t", { plain = true }) do
			if field == "NULL" then
				field = ""
			else
				field = field:gsub("\\(.)", function(c)
					return MYSQL_UNESCAPE[c] or ("\\" .. c)
				end)
			end
			table.insert(fields, csv_field(field))
		end
		table.insert(out, table.concat(fields, ","))
	end
	return table.concat(out, "\n") .. "\n"
end

M._mysql_tsv_to_csv = mysql_tsv_to_csv -- exposed for testing

--- argv for running `url` in CSV mode, plus a post-processing function.
--- Returns nil, err for unsupported schemes.
local function csv_command(url)
	local scheme = url:match("^([%w+.-]+):")
	local adapter = function(fn, ...)
		return vim.fn["db#adapter#" .. scheme .. "#" .. fn](url, ...)
	end
	if scheme == "postgresql" or scheme == "postgres" then
		scheme = "postgresql"
		return adapter("interactive", { "-X", "-q", "--csv", "-v", "ON_ERROR_STOP=1" })
	elseif scheme == "mysql" or scheme == "mariadb" then
		return vim.list_extend(adapter("interactive"), { "--batch" }), mysql_tsv_to_csv
	elseif scheme == "bigquery" then
		local cmd = adapter("filter") -- [bq, --project_id=…, params…, "query"]
		local sub = table.remove(cmd)
		vim.list_extend(cmd, { "--format=csv", "--quiet", sub, "--max_rows=" .. M.bigquery_max_rows })
		return cmd
	elseif scheme == "sqlite" then
		return vim.list_extend(adapter("command"), { "-csv", "-header" })
	elseif scheme == "duckdb" then
		return vim.list_extend(adapter("command"), { "-csv" })
	end
	return nil, "CSV export not supported for '" .. tostring(scheme) .. "' connections"
end

-- Readable name for the output file: picker alias, else DBUI connection name.
local function connection_name()
	local name = vim.b.db_alias
	if not name and vim.b.dbui_db_key_name then
		name = vim.b.dbui_db_key_name:gsub("_[^_]+$", "") -- strip "_g:dbs" / "_file" source
	end
	return ((name or "query"):gsub("[^%w%-_]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

local function needs_confirm(scheme, query)
	local reasons = {}
	if scheme == "bigquery" then
		table.insert(reasons, "BigQuery re-runs are billed")
	end
	-- Check EVERY statement, so `SET …; DELETE …` still asks. Comments are
	-- stripped first; splitting on ';' is naive (a ';' inside a string makes an
	-- extra fragment), which can only cause an unneeded prompt, never a missed one
	-- for a statement that starts a line.
	local stripped = query:gsub("/%*.-%*/", " "):gsub("%-%-[^\n]*", " ")
	local writes = {}
	for stmt in vim.gsplit(stripped, ";", { plain = true }) do
		local words = vim.split(vim.trim(stmt:gsub("^[%s(]+", "")):lower(), "%s+")
		local first = words[1] or ""
		local session_set = first == "set" and words[2] ~= "global" and words[2] ~= "persist"
		if first ~= "" and first:match("^[%a_]+$") and not READ_KEYWORDS[first] and not session_set then
			writes[first:upper()] = true
		end
	end
	if not vim.tbl_isempty(writes) then
		local kinds = vim.tbl_keys(writes)
		table.sort(kinds)
		table.insert(reasons, "contains " .. table.concat(kinds, ", ") .. " (side effects will repeat)")
	end
	return reasons
end

local function run(url, query, path, scheme)
	local cmd, convert_or_err = csv_command(url)
	if not cmd then
		vim.notify("dbexport: " .. convert_or_err, vim.log.levels.ERROR)
		return
	end
	local input = vim.fn["db#adapter#call"](url, "massage", { query }, query)
	vim.notify("dbexport: running " .. scheme .. " query → " .. path)
	local started = vim.uv.now()
	local elapsed = function()
		return math.floor((vim.uv.now() - started) / 1000)
	end
	-- Heartbeat so a long export is visibly alive (and visible in :messages).
	local timer = vim.uv.new_timer()
	timer:start(
		M.progress_interval_ms,
		M.progress_interval_ms,
		vim.schedule_wrap(function()
			vim.notify(string.format("dbexport: still running (%ds) → %s", elapsed(), path))
		end)
	)
	vim.system(cmd, { stdin = input, text = true }, function(res)
		vim.schedule(function()
			timer:stop()
			timer:close()
			if res.code ~= 0 then
				vim.notify(
					string.format(
						"dbexport: query failed after %ds (exit %d)\n%s",
						elapsed(),
						res.code,
						vim.trim(res.stderr or "")
					),
					vim.log.levels.ERROR
				)
				return
			end
			local data = res.stdout or ""
			if type(convert_or_err) == "function" then
				data = convert_or_err(data)
			end
			vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
			local f, err = io.open(path, "wb")
			if not f then
				vim.notify("dbexport: cannot write " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
				return
			end
			f:write(data)
			f:close()
			local _, lines = data:gsub("\n", "")
			local note = ""
			if scheme == "bigquery" and lines - 1 >= M.bigquery_max_rows then
				note = " — hit the " .. M.bigquery_max_rows .. "-row cap, output is truncated"
			end
			vim.notify(string.format("dbexport: done in %ds — wrote %s (%d lines)%s", elapsed(), path, lines, note))
		end)
	end)
end

--- opts: { line1, line2, range (0 = whole buffer), file }
function M.export(opts)
	opts = opts or {}
	local db = vim.b.db
	if type(db) ~= "string" or db == "" then
		vim.notify("dbexport: no connection for this buffer (open one with <leader>Dq)", vim.log.levels.WARN)
		return
	end
	local url = vim.fn["db#resolve"](db)
	local scheme = url:match("^([%w+.-]+):") or "?"

	local lines = (opts.range or 0) > 0 and vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
		or vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local query = vim.trim(table.concat(lines, "\n"))
	if query == "" then
		vim.notify("dbexport: nothing to run", vim.log.levels.WARN)
		return
	end

	local reasons = needs_confirm(scheme, query)
	if #reasons > 0 then
		local ok = vim.fn.confirm("Re-run query for CSV export?\n- " .. table.concat(reasons, "\n- "), "&Yes\n&No", 2)
		if ok ~= 1 then
			vim.notify("dbexport: cancelled", vim.log.levels.WARN)
			return
		end
	end

	if opts.file and opts.file ~= "" then
		run(url, query, vim.fn.expand(opts.file), scheme)
		return
	end
	local default = string.format("%s/%s-%s.csv", M.default_dir, connection_name(), os.date("%Y%m%d-%H%M%S"))
	vim.ui.input({ prompt = "Export CSV to: ", default = default, completion = "file" }, function(path)
		if path and path ~= "" then
			run(url, query, vim.fn.expand(path), scheme)
		else
			vim.notify("dbexport: cancelled (no file name)", vim.log.levels.WARN)
		end
	end)
end

vim.api.nvim_create_user_command("DBExport", function(o)
	M.export({ line1 = o.line1, line2 = o.line2, range = o.range, file = o.args })
end, { nargs = "?", range = true, complete = "file", desc = "Re-run query and export results as CSV" })

return M
