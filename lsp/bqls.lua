-- bqls: BigQuery SQL. Attaches to `sql` buffers EXCEPT dadbod query buffers
-- bound to a non-BigQuery connection (b:db = postgresql://..., etc.), where
-- BigQuery diagnostics would be wrong. Plain .sql files (no b:db, e.g. dbt
-- models) still get bqls. b:db must be set before the filetype is — DBUI does
-- this, and so does custom/dbtab.lua.
return {
	cmd = { "bqls" },
	filetypes = { "sql" },
	root_dir = function(bufnr, on_dir)
		-- Decide on the next tick, not now: DBUI opens a saved query with :edit
		-- (FileType sql fires here, before b:db exists) and only then sets b:db
		-- and filetype=mysql. Checking immediately would approve bqls and its
		-- deferred start would attach to a MySQL buffer.
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "sql" then
				return
			end
			local db = vim.b[bufnr].db
			if type(db) == "string" and not db:match("^bigquery:") then
				return -- not calling on_dir() skips this buffer
			end
			on_dir(vim.fs.root(bufnr, { ".git" }))
		end)
	end,
	settings = {
		-- project_id defaults to `gcloud config get project` if omitted
	},
}
