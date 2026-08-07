-- =============================================================================
-- custom/qf.lua
-- =============================================================================
-- Asynchronous :make replacement that populates the quickfix list.
-- Usage: require("custom.qf").make()      -- run 'makeprg'
--        require("custom.qf").make("-q")  -- run 'makeprg' with extra arguments
--        require("custom.qf").toggle()    -- show / hide the quickfix window
--
-- :make is synchronous: it blocks Neovim until the command exits. That is
-- tolerable for a fast linter and painful for a test suite, so this runs the
-- same 'makeprg' through vim.system and parses the output with 'errorformat'
-- once it finishes.
--
-- Quickfix is worth the trouble because it holds *locations*, not text. LSP
-- diagnostics only cover buffers that are open; a project-wide lint or test run
-- reports files you have never opened, and those become ]q-navigable here.
-- =============================================================================

local M = {}

local handle = nil
local run_id = 0

-- 'makeprg' and 'errorformat' are global-local. The per-filetype values set in
-- after/ftplugin/*.lua are buffer-local, and vim.o would read straight past
-- them to the global value; nvim_get_option_value returns the effective one.
local function option(name)
	return vim.api.nvim_get_option_value(name, {})
end

local function qf_win()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "quickfix" then
			return win
		end
	end
end

-- Build the command the way Vim's :make does: arguments replace $* when the
-- placeholder is present, and are appended when it is not. Matching that means
-- a 'makeprg' written for :make behaves identically here.
local function build(prg, args)
	if prg:find("$*", 1, true) then
		return (prg:gsub("%$%*", args))
	end
	if args ~= "" then
		return prg .. " " .. args
	end
	return prg
end

local function fill(title, efm, output, code)
	-- setqflist parses with 'errorformat' itself. Reimplementing that parsing
	-- would be both harder and less correct than handing it the raw lines.
	vim.fn.setqflist({}, " ", {
		title = title,
		lines = vim.split(output, "\n", { trimempty = true }),
		efm = efm,
	})

	-- Lines matching no pattern are still added, as entries with valid = 0 and no
	-- location. They are noise you would have to ]q past, so count only the
	-- findings that can actually be jumped to and decide from that.
	local valid = 0
	for _, item in ipairs(vim.fn.getqflist()) do
		if item.valid == 1 then
			valid = valid + 1
		end
	end

	if valid > 0 then
		vim.cmd.copen()
		vim.notify(("%s → %d item%s"):format(title, valid, valid == 1 and "" or "s"), vim.log.levels.WARN)
		return
	end

	-- Nothing navigable: clear whatever unmatched noise landed in the list rather
	-- than leaving a window full of text you cannot jump from.
	vim.fn.setqflist({}, "r")
	vim.cmd.cclose()

	if code == 0 then
		vim.notify(title .. " → clean")
	else
		-- The trap this avoids: a command that failed but whose output does not
		-- match 'errorformat' produces an empty list, which looks exactly like
		-- success. Say so instead, because the fix is the errorformat, not the code.
		vim.notify(("%s → exit %d, but nothing matched 'errorformat'"):format(title, code), vim.log.levels.ERROR)
	end
end

function M.make(args)
	args = type(args) == "string" and vim.trim(args) or ""

	local prg = option("makeprg")
	if prg == "" then
		vim.notify("'makeprg' is empty for this buffer", vim.log.levels.ERROR)
		return
	end

	local cmd = build(prg, args)
	local ok, expanded = pcall(vim.fn.expandcmd, cmd)
	cmd = ok and expanded or cmd

	-- Capture the errorformat now: the callback runs later, by which time the
	-- current buffer may be the quickfix window or another filetype entirely.
	local efm = option("errorformat")

	-- A second run while one is in flight is almost always "I fixed it, try
	-- again", so supersede rather than refuse or let two writes race the list.
	if handle then
		handle:kill("sigterm")
	end

	run_id = run_id + 1
	local id = run_id

	vim.notify("Running " .. cmd)

	-- Through the shell so pipes and quoting in 'makeprg' behave as :make would.
	-- Splitting on spaces would break `pytest -k "foo bar"`.
	handle = vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }, { text = true }, function(out)
		vim.schedule(function()
			if id ~= run_id then
				return -- superseded by a newer run
			end
			handle = nil
			fill(cmd, efm, (out.stdout or "") .. (out.stderr or ""), out.code)
		end)
	end)
end

function M.toggle()
	local win = qf_win()
	if win then
		vim.api.nvim_win_close(win, false)
	else
		vim.cmd.copen()
	end
end

return M
