-- fzf-lua — fuzzy finder UI for files, grep, LSP, and more
-- https://github.com/ibhagwan/fzf-lua

require("fzf-lua").setup({
	winopts = {
		preview = {
			layout = "vertical",
			vertical = "down:80%",
			winopts = {
				cursorcolumn = false,
				cursorline = true,
				cursorlineopt = "both",
				foldenable = false,
				foldmethod = "manual",
				list = false,
				number = true,
				relativenumber = false,
				scrolloff = -1,
				signcolumn = "no",
				winblend = 0,
			},
		},
	},
	files = {
		cwd_prompt = false,
	},
	lsp = {
		symbols = {
			symbol_style = 1,
		},
	},
})

local fzf = require("fzf-lua")

vim.keymap.set("n", "<leader>sf", function()
	fzf.files({ prompt = "Files> " })
end, { desc = "Search: files" })
vim.keymap.set(
	"n",
	"<leader>/",
	"<cmd>FzfLua live_grep winopts.preview.layout=vertical winopts.preview.vertical=down:80%<cr>",
	{ desc = "Search: grep project" }
)
vim.keymap.set("n", "<leader>sb", "<cmd>FzfLua buffers<cr>", { desc = "Search: buffers" })
vim.keymap.set("n", "<leader>sB", "<cmd>FzfLua grep_curbuf<cr>", { desc = "Search: grep current buffer" })
vim.keymap.set("n", "<leader>sd", "<cmd>FzfLua diagnostics_document<cr>", { desc = "Search: document diagnostics" })
vim.keymap.set("n", "<leader>sm", "<cmd>FzfLua marks<cr>", { desc = "Search: marks" })
vim.keymap.set("n", "<leader>ss", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", { desc = "Search: workspace symbols" })
vim.keymap.set("n", "<leader>sw", "<cmd>FzfLua grep_cword<cr>", { desc = "Search: word under cursor" })
vim.keymap.set("n", "<leader>sW", "<cmd>FzfLua grep_cWORD<cr>", { desc = "Search: WORD under cursor" })
vim.keymap.set("n", "<leader>sk", "<cmd>FzfLua keymaps<cr>", { desc = "Search: keymaps" })
