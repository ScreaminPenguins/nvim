-- =============================================================================
-- custom/dbpopup.lua
-- =============================================================================
-- Centred, focused, read-only float shared by the dadbod helpers (table
-- columns in custom.dbmeta, connection info in custom.dbinfo). Sized to its
-- content (capped to the editor), no wrapping; q / <Esc> or leaving it closes.
-- =============================================================================

local M = {}

local NS = vim.api.nvim_create_namespace("dbpopup")
local win -- the open pop-up, if any

function M.close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	win = nil
end

--- Align rows of cells into lines: every column but the last is padded to
--- its widest cell plus `gap` spaces.
function M.columns(rows, gap)
	gap = gap or 3
	local w = {}
	for _, r in ipairs(rows) do
		for i = 1, #r - 1 do
			w[i] = math.max(w[i] or 0, vim.fn.strdisplaywidth(r[i]))
		end
	end
	local lines = {}
	for _, r in ipairs(rows) do
		local parts = {}
		for i, cell in ipairs(r) do
			table.insert(parts, i < #r and (cell .. string.rep(" ", w[i] - vim.fn.strdisplaywidth(cell) + gap)) or cell)
		end
		table.insert(lines, " " .. (table.concat(parts):gsub("%s+$", "")) .. " ")
	end
	return lines
end

--- Open the pop-up.
--- opts.lines      list of strings
--- opts.title      top border text
--- opts.footer     bottom border text (right-aligned)
--- opts.highlights list of { line (0-based), group[, col_start, col_end] }
--- opts.keys       { lhs = { fn, desc } } extra buffer-local normal maps
--- Returns the buffer and window.
function M.open(opts)
	M.close()
	local lines = opts.lines
	local title = " " .. (opts.title or "") .. " "
	local footer = opts.footer and (" " .. opts.footer .. " ") or nil
	local width = math.max(vim.fn.strdisplaywidth(title), footer and vim.fn.strdisplaywidth(footer) or 0) + 4
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(width, vim.o.columns - 6)
	local height = math.max(1, math.min(#lines, math.floor(vim.o.lines * 0.8)))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	for _, h in ipairs(opts.highlights or {}) do
		local line, group, s, e = unpack(h)
		if s then
			vim.api.nvim_buf_set_extmark(buf, NS, line, s, { end_col = e, hl_group = group })
		else
			vim.api.nvim_buf_set_extmark(buf, NS, line, 0, { end_row = line + 1, hl_group = group, hl_eol = true })
		end
	end
	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
		footer = footer,
		footer_pos = footer and "right" or nil,
	})
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = true
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, M.close, { buffer = buf, nowait = true, desc = "Close pop-up" })
	end
	for lhs, map in pairs(opts.keys or {}) do
		vim.keymap.set("n", lhs, map[1], { buffer = buf, nowait = true, desc = map[2] })
	end
	-- Scheduled: closing a window from inside WinLeave is not allowed.
	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = buf,
		once = true,
		callback = function()
			vim.schedule(M.close)
		end,
	})
	return buf, win
end

return M
