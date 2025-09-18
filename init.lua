-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Highlight on text yank
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highligh on text yank",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Opts
local opt = vim.opt
opt.clipboard = "unnamedplus"
opt.relativenumber = true
opt.shiftwidth = 4

-- Diagnostics
vim.diagnostic.config({
	virtual_text = {
		prefix = "●",
	},
})


-- Keymaps
local keymap = vim.keymap

keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- Windows
keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })
keymap.set("n", "<leader>|", "<C-W>v", { noremap = true, desc = "Split Window Right" })
keymap.set("n", "<leader>wd", "<C-W>c", { noremap = true, desc = "Close Window" })

-- Buffers
keymap.set("n", "<leader>bd", "<cmd>bd<cr>", { noremap = true, desc = "Close Buffer" })


keymap.set(
	"n",
	"/",
	function()
		vim.api.nvim_feedkeys("/", "n", true)
		vim.api.nvim_create_autocmd("CmdlineLeave", {
			pattern = "/",
			once = true,
			callback = function()
				vim.defer_fn(function() vim.cmd("nohlsearch") end, 50)
			end
		})
	end,
	{ noremap = true, desc = "Search Forward" }
)

keymap.set(
	"n", "n",
	function()
		vim.cmd("normal! n")
		vim.defer_fn(function()
			vim.cmd("nohlsearch")
		end, 1000)
	end,
	{ noremap = true, desc = "Next Match" }
)
