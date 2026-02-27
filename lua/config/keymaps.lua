local set = vim.keymap.set

set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- Windows
set("n", "<leader>|", "<C-W>v", { noremap = true, desc = "Split Window Right" })
set("n", "<leader>-", "<CMD>:split<CR>", { noremap = true, desc = "Split Window Below" })
set("n", "<leader>wd", "<C-W>c", { noremap = true, desc = "Close Window" })

-- Buffers
-- set("n", "<leader>bd", "<cmd>bd<cr>", { noremap = true, desc = "Close Buffer" })
set("n", "<leader>bd", function(buf)
	buf = buf or 0
	buf = buf == 0 and vim.api.nvim_get_current_buf() or buf

	if vim.bo.modified then
		local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname()), "&Yes\n&No\n&Cancel")
		if choice == 0 or choice == 3 then -- 0 for <Esc>/<C-c> and 3 for Cancel
			return
		end
		if choice == 1 then -- Yes
			vim.cmd.write()
		end
	end

	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.api.nvim_win_call(win, function()
			if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
				return
			end
			-- Try using alternate buffer
			local alt = vim.fn.bufnr("#")
			if alt ~= buf and vim.fn.buflisted(alt) == 1 then
				vim.api.nvim_win_set_buf(win, alt)
				return
			end

			-- Try using previous buffer
			local has_previous = pcall(vim.cmd, "bprevious")
			if has_previous and buf ~= vim.api.nvim_win_get_buf(win) then
				return
			end

			-- Create new listed buffer
			local new_buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_win_set_buf(win, new_buf)
		end)
	end
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.cmd, "bdelete! " .. buf)
	end
end, { noremap = true, desc = "Close Buffer" })
set("n", "<leader>bb", "<cmd>b#<cr>", { noremap = true, desc = "Previous Buffer" })

-- Rename symbol
set("n", "<leader>rs", vim.lsp.buf.rename, { desc = "LSP Rename" })

-- Diagnostics
-- TODO: Make this better
vim.keymap.set("n", "<leader>td", function()
	local vt = vim.diagnostic.config().virtual_text
	if vt then
		vim.diagnostic.config({ virtual_text = false })
	else
		vim.diagnostic.config({
			virtual_text = {
				prefix = "",
			},
		})
	end
end, { silent = true, noremap = true, desc = "Toggle diagnostic" })

-- Toggle listchars
vim.keymap.set("n", "<leader>ts", ":set list!<CR>", { desc = "Toggle listchars" })

-- Tmux sessionizer
set("n", "<C-f>", function()
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	})
	vim.fn.jobstart(os.getenv("HOME") .. "/.local/scripts/tmux-sessionizer", {
		term = true,
		on_exit = function()
			vim.api.nvim_win_close(win, true)
		end,
	})
	vim.cmd("startinsert")
end, { desc = "Tmux Sessionizer" })
