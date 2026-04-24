local M = {}

local scratch_dir = vim.fn.stdpath("data") .. "/scratches"

-- state[ft] = { buf = <bufnr>, win = <winid> | nil }
local state = {}

local config = {
	use_fzf = false,
}

local ext_map = {
	lua = "lua",
	python = "py",
	javascript = "js",
	typescript = "ts",
	typescriptreact = "tsx",
	javascriptreact = "jsx",
	markdown = "md",
	rust = "rs",
	go = "go",
	sh = "sh",
	bash = "sh",
	zsh = "zsh",
	sql = "sql",
	json = "json",
	yaml = "yaml",
	toml = "toml",
	html = "html",
	css = "css",
	c = "c",
	cpp = "cpp",
}

local function get_ft()
	local ft = vim.bo.filetype
	if ft == nil or ft == "" then
		return "markdown"
	end
	return ft
end

local function scratch_path(ft)
	local ext = ext_map[ft] or ft
	return scratch_dir .. "/scratch." .. ext
end

-- Derive filetype from a scratch filename (e.g. "scratch.py" -> "python")
local function ft_from_name(name)
	local ext = name:match("%.(%w+)$") or "txt"
	for k, v in pairs(ext_map) do
		if v == ext then
			return k
		end
	end
	return ext
end

local function open_float(buf, ft)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	return vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " scratch [" .. ft .. "] ",
		title_pos = "center",
	})
end

local function load_scratch_buf(ft)
	local path = scratch_path(ft)
	vim.fn.mkdir(scratch_dir, "p")

	local buf = vim.fn.bufadd(path)
	if not vim.api.nvim_buf_is_loaded(buf) then
		vim.fn.bufload(buf)
	end
	vim.bo[buf].buflisted = false
	vim.bo[buf].bufhidden = "hide"
	if vim.bo[buf].filetype == "" then
		vim.bo[buf].filetype = ft
	end

	-- auto-save on leave — named group prevents duplicates on retoggle
	local group = vim.api.nvim_create_augroup("ScratchAutoSave_" .. ft, { clear = true })
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		group = group,
		callback = function()
			if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
				vim.api.nvim_buf_call(buf, function()
					vim.cmd("silent! write")
				end)
			end
		end,
	})

	return buf
end

local function get_scratch_names()
	local files = vim.fn.glob(scratch_dir .. "/*", false, true)
	if #files == 0 then
		return {}
	end
	return vim.tbl_map(function(f)
		return vim.fn.fnamemodify(f, ":t")
	end, files)
end

local function open_by_name(name)
	local ft = ft_from_name(name)
	local path = scratch_dir .. "/" .. name
	local s = state[ft]

	local buf
	if s and s.buf and vim.api.nvim_buf_is_valid(s.buf) then
		buf = s.buf
	else
		buf = vim.fn.bufadd(path)
		if not vim.api.nvim_buf_is_loaded(buf) then
			vim.fn.bufload(buf)
		end
		vim.bo[buf].buflisted = false
		vim.bo[buf].bufhidden = "hide"
		state[ft] = { buf = buf, win = nil }
		s = state[ft]
	end

	if s.win and vim.api.nvim_win_is_valid(s.win) then
		vim.api.nvim_win_close(s.win, false)
	end

	local win = open_float(buf, ft)
	state[ft].win = win
end

local function delete_by_name(name)
	local ft = ft_from_name(name)
	local s = state[ft]

	if s then
		if s.win and vim.api.nvim_win_is_valid(s.win) then
			vim.api.nvim_win_close(s.win, true)
		end
		if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
			vim.api.nvim_buf_delete(s.buf, { force = true })
		end
		state[ft] = nil
	end

	vim.fn.delete(scratch_dir .. "/" .. name)
	vim.notify("Deleted " .. name, vim.log.levels.INFO)
end

function M.toggle()
	local ft = get_ft()
	local s = state[ft]

	if s and s.win and vim.api.nvim_win_is_valid(s.win) then
		vim.api.nvim_win_close(s.win, false)
		s.win = nil
		return
	end

	local buf
	if s and s.buf and vim.api.nvim_buf_is_valid(s.buf) then
		buf = s.buf
	else
		buf = load_scratch_buf(ft)
		state[ft] = { buf = buf, win = nil }
	end

	local win = open_float(buf, ft)
	state[ft].win = win
end

function M.list()
	local names = get_scratch_names()
	if #names == 0 then
		vim.notify("No scratch buffers", vim.log.levels.INFO)
		return
	end

	if config.use_fzf then
		require("fzf-lua").fzf_exec(names, {
			prompt = "Scratch> ",
			fzf_opts = { ["--multi"] = true },
			actions = {
				["default"] = function(selected)
					if selected and selected[1] then
						open_by_name(selected[1])
					end
				end,
				["ctrl-d"] = function(selected)
					for _, name in ipairs(selected or {}) do
						delete_by_name(name)
					end
				end,
			},
		})
	else
		vim.ui.select(names, { prompt = "Open scratch buffer" }, function(choice)
			if choice then
				open_by_name(choice)
			end
		end)
	end
end

function M.delete()
	local names = get_scratch_names()
	if #names == 0 then
		vim.notify("No scratch buffers", vim.log.levels.INFO)
		return
	end

	if config.use_fzf then
		require("fzf-lua").fzf_exec(names, {
			prompt = "Delete scratch> ",
			fzf_opts = { ["--multi"] = true },
			actions = {
				["default"] = function(selected)
					for _, name in ipairs(selected or {}) do
						delete_by_name(name)
					end
				end,
			},
		})
	else
		vim.ui.select(names, { prompt = "Delete scratch buffer" }, function(choice)
			if choice then
				delete_by_name(choice)
			end
		end)
	end
end

function M.setup(opts)
	opts = opts or {}
	config.use_fzf = opts.use_fzf or false

	local keys = vim.tbl_deep_extend("force", {
		toggle = "<leader>tn",
		list = "<leader>ln",
		delete = "<leader>nd",
	}, opts.keys or {})

	vim.keymap.set("n", keys.toggle, M.toggle, { desc = "Scratch: toggle" })
	vim.keymap.set("n", keys.list, M.list, { desc = "Scratch: list" })
	vim.keymap.set("n", keys.delete, M.delete, { desc = "Scratch: delete" })

	vim.api.nvim_create_autocmd("WinClosed", {
		group = vim.api.nvim_create_augroup("ScratchWinClosed", { clear = true }),
		callback = function(ev)
			local closed = tonumber(ev.match)
			for _, s in pairs(state) do
				if s.win == closed then
					s.win = nil
				end
			end
		end,
	})
end

return M
