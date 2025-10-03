local set = vim.keymap.set

-- TODO: handle unsaved changes
set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- Windows
set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })
set("n", "<leader>|", "<C-W>v", { noremap = true, desc = "Split Window Right" })
set("n", "<leader>wd", "<C-W>c", { noremap = true, desc = "Close Window" })

-- Buffers
set("n", "<leader>bd", "<cmd>bd<cr>", { noremap = true, desc = "Close Buffer" })
set("n", "<leader>bb", "<cmd>bprevious<cr>", { noremap = true, desc = "Previous Buffer" })

-- Better search highlighting
set("n", "/", function()
	vim.api.nvim_feedkeys("/", "n", true)
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		pattern = "/",
		once = true,
		callback = function()
			vim.defer_fn(function()
				vim.cmd("nohlsearch")
			end, 50)
		end,
	})
end, { noremap = true, desc = "Search Forward" })

set("n", "n", function()
	vim.cmd("normal! n")
	vim.defer_fn(function()
		vim.cmd("nohlsearch")
	end, 1000)
end, { noremap = true, desc = "Next Match" })

-- Diagnostics
-- TODO: Make this better
vim.keymap.set("n", "E", function()
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
end, { silent = true, noremap = true })
