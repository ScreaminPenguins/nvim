-- =============================================================================
-- custom/dbpopup.lua
-- =============================================================================
-- Centred, focused, read-only floats shared by the dadbod helpers: one pane
-- (table columns in custom.dbmeta) or a vertical stack of panes (connection
-- info in custom.dbinfo). Sized to the content (capped to the editor), no
-- wrapping; q / <Esc>, or leaving all panes, closes; <Tab> cycles panes.
-- =============================================================================

local M = {}

local NS = vim.api.nvim_create_namespace("dbpopup")
local wins = {} -- the open pop-up's panes

function M.close()
	for _, w in ipairs(wins) do
		if vim.api.nvim_win_is_valid(w) then
			vim.api.nvim_win_close(w, true)
		end
	end
	wins = {}
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

local function highlight(buf, list)
	for _, h in ipairs(list or {}) do
		local line, group, s, e = unpack(h)
		if s then
			vim.api.nvim_buf_set_extmark(buf, NS, line, s, { end_col = e, hl_group = group })
		else
			vim.api.nvim_buf_set_extmark(buf, NS, line, 0, { end_row = line + 1, hl_group = group, hl_eol = true })
		end
	end
end

--- Open a vertical stack of panes, sharing one width, centred as a group.
--- opts.panes  list of { lines, title, highlights, footer? }
---             highlights: { line (0-based), group[, col_start, col_end] }
--- opts.footer bottom border text of the last pane (right-aligned)
--- opts.focus  index of the pane to start in (default 1)
--- opts.keys   { lhs = { fn(pane_index, lnum), desc } } maps in every pane
--- Returns the list of { buf, win }.
function M.open_stack(opts)
	M.close()
	local panes = opts.panes
	local width = 0
	for i, p in ipairs(panes) do
		local footer = p.footer or (i == #panes and opts.footer) or nil
		width = math.max(width, vim.fn.strdisplaywidth(" " .. (p.title or "") .. " ") + 4)
		if footer then
			width = math.max(width, vim.fn.strdisplaywidth(" " .. footer .. " ") + 4)
		end
		for _, l in ipairs(p.lines) do
			width = math.max(width, vim.fn.strdisplaywidth(l))
		end
	end
	width = math.min(width, vim.o.columns - 6)

	-- Heights: each pane's line count; if the stack (plus 2 border rows per
	-- pane) is too tall, take rows from the tallest pane until it fits.
	local heights = vim.tbl_map(function(p)
		return math.max(1, #p.lines)
	end, panes)
	local budget = math.floor(vim.o.lines * 0.85) - 2 * #panes
	local function total()
		local t = 0
		for _, h in ipairs(heights) do
			t = t + h
		end
		return t
	end
	while total() > budget do
		local tallest = 1
		for i, h in ipairs(heights) do
			if h > heights[tallest] then
				tallest = i
			end
		end
		if heights[tallest] <= 1 then
			break
		end
		heights[tallest] = heights[tallest] - 1
	end

	local row = math.max(0, math.floor((vim.o.lines - total() - 2 * #panes) / 2) - 1)
	local col = math.floor((vim.o.columns - width) / 2)
	local out = {}
	for i, p in ipairs(panes) do
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, #p.lines > 0 and p.lines or { "" })
		vim.bo[buf].modifiable = false
		vim.bo[buf].bufhidden = "wipe"
		highlight(buf, p.highlights)
		local footer = p.footer or (i == #panes and opts.footer) or nil
		local win = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			row = row,
			col = col,
			width = width,
			height = heights[i],
			style = "minimal",
			border = "rounded",
			title = " " .. (p.title or "") .. " ",
			title_pos = "center",
			footer = footer and (" " .. footer .. " ") or nil,
			footer_pos = footer and "right" or nil,
		})
		vim.wo[win].wrap = false
		vim.wo[win].cursorline = true
		row = row + heights[i] + 2
		table.insert(wins, win)
		table.insert(out, { buf = buf, win = win })
	end

	for i, pane in ipairs(out) do
		local buf = pane.buf
		for _, key in ipairs({ "q", "<Esc>" }) do
			vim.keymap.set("n", key, M.close, { buffer = buf, nowait = true, desc = "Close pop-up" })
		end
		vim.keymap.set("n", "<Tab>", function()
			vim.api.nvim_set_current_win(out[i % #out + 1].win)
		end, { buffer = buf, nowait = true, desc = "Next pane" })
		vim.keymap.set("n", "<S-Tab>", function()
			vim.api.nvim_set_current_win(out[(i - 2) % #out + 1].win)
		end, { buffer = buf, nowait = true, desc = "Previous pane" })
		for lhs, map in pairs(opts.keys or {}) do
			vim.keymap.set("n", lhs, function()
				map[1](i, vim.fn.line("."))
			end, { buffer = buf, nowait = true, desc = map[2] })
		end
		-- Moving between panes is fine; leaving all of them closes the stack.
		vim.api.nvim_create_autocmd("WinLeave", {
			buffer = buf,
			callback = function()
				vim.schedule(function()
					if #wins > 0 and not vim.tbl_contains(wins, vim.api.nvim_get_current_win()) then
						M.close()
					end
				end)
			end,
		})
	end
	vim.api.nvim_set_current_win(out[opts.focus or 1].win)
	return out
end

--- Open a single-pane pop-up.
--- opts.lines      list of strings
--- opts.title      top border text
--- opts.footer     bottom border text (right-aligned)
--- opts.highlights list of { line (0-based), group[, col_start, col_end] }
--- opts.keys       { lhs = { fn, desc } } extra buffer-local normal maps
--- Returns the buffer and window.
function M.open(opts)
	local keys = {}
	for lhs, map in pairs(opts.keys or {}) do
		keys[lhs] = {
			function()
				map[1]()
			end,
			map[2],
		}
	end
	local out = M.open_stack({
		panes = { { lines = opts.lines, title = opts.title, highlights = opts.highlights } },
		footer = opts.footer,
		keys = keys,
	})
	return out[1].buf, out[1].win
end

return M
