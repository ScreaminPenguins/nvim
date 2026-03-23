local lkml_keywords = "(view|measure|dimension|dimension_group|filter|parameter|explore|join|set)"

local function lkml_symbols()
	require("fzf-lua").grep({
		search = lkml_keywords .. [[\s*:\s*\w+]],
		no_esc = true,
		rg_opts = "--glob '*.lkml'",
	})
end

local function lkml_goto_def()
	local word = vim.fn.expand("<cword>")
	require("fzf-lua").grep({
		search = lkml_keywords .. [[\s*:\s*]] .. word .. [[\b]],
		no_esc = true,
		rg_opts = "--glob '*.lkml'",
	})
end

local function lkml_hover()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end

	local pattern = lkml_keywords .. [[\s*:\s*]] .. word .. [[\b]]
	local cwd = vim.fn.getcwd()

	local results = vim.fn.systemlist({ "rg", "--no-heading", "-n", "--glob", "*.lkml", "-e", pattern, cwd })
	if #results == 0 then
		vim.notify("No LookML definition found for: " .. word, vim.log.levels.INFO)
		return
	end

	-- results are "filepath:linenum:content" — use the first match
	local filepath, lnum_str = results[1]:match("^(.-):(%d+):")
	if not filepath then
		return
	end

	local lnum = tonumber(lnum_str)
	local file_lines = vim.fn.readfile(filepath)
	if not file_lines or #file_lines == 0 then
		return
	end

	-- extract the full block by tracking brace depth
	local content = {}
	local depth = 0
	for i = lnum, math.min(lnum + 40, #file_lines) do
		local line = file_lines[i]
		table.insert(content, line)
		for ch in line:gmatch(".") do
			if ch == "{" then
				depth = depth + 1
			elseif ch == "}" then
				depth = depth - 1
			end
		end
		if depth <= 0 and i > lnum then
			break
		end
	end

	-- prepend source location as a header
	local short_path = filepath:gsub(vim.pesc(cwd) .. "/", "")
	table.insert(content, 1, "")
	table.insert(content, 1, short_path .. ":" .. lnum_str)

	vim.lsp.util.open_floating_preview(content, "lookml", {
		border = "rounded",
		max_width = 100,
		max_height = 30,
	})
end

-- Dashboard files (.dashboard.lookml) are YAML, not LookML.
-- Symbols: top-level dashboard names and element names.
-- gd: resolve explore/field references back into .lkml files.
local function dashboard_symbols()
	require("fzf-lua").grep({
		search = [[(^\s*-\s+dashboard:|^\s+name:)\s+\S+]],
		no_esc = true,
		rg_opts = "--glob '*.dashboard.lookml'",
	})
end

local function dashboard_goto_def()
	local word = vim.fn.expand("<cword>")
	require("fzf-lua").grep({
		search = lkml_keywords .. [[\s*:\s*]] .. word .. [[\b]],
		no_esc = true,
		rg_opts = "--glob '*.lkml'",
	})
end

return {
	{
		"thalesmello/lkml.vim",
		init = function()
			-- lkml.vim handles *.lkml detection, but be explicit as a guard
			vim.filetype.add({ extension = { lkml = "lookml" } })

			-- Dashboard files need explicit detection; set a distinct filetype
			-- so we can attach keymaps without polluting all yaml buffers.
			vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
				pattern = "*.dashboard.lookml",
				callback = function(ev)
					vim.bo[ev.buf].filetype = "lookml_dashboard"
				end,
			})
		end,
		config = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "lookml",
				callback = function(ev)
					local buf = ev.buf
					vim.keymap.set("n", "<leader>ss", lkml_symbols, { buffer = buf, desc = "LookML symbols" })
					vim.keymap.set("n", "gd", lkml_goto_def, { buffer = buf, desc = "LookML go to definition" })
					vim.keymap.set("n", "K", lkml_hover, { buffer = buf, desc = "LookML hover definition" })
				end,
			})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "lookml_dashboard",
				callback = function(ev)
					local buf = ev.buf
					-- Use YAML treesitter parser for syntax highlighting
					vim.treesitter.start(buf, "yaml")
					vim.keymap.set("n", "<leader>ss", dashboard_symbols, { buffer = buf, desc = "Dashboard symbols" })
					vim.keymap.set("n", "gd", dashboard_goto_def, { buffer = buf, desc = "Dashboard go to definition" })
					vim.keymap.set("n", "K", lkml_hover, { buffer = buf, desc = "LookML hover definition" })
				end,
			})
		end,
	},
}
