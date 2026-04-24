return {
	{
		"ibhagwan/fzf-lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false,
		config = function()
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
		end,
		keys = {
			{
				"<leader>sf",
				"<cmd>lua FzfLua.files({prompt='Files❯ '})<cr>",
				mode = "n",
				desc = "Files",
			},
			{
				"<leader>/",
				"<cmd>FzfLua live_grep winopts.preview.layout=vertical winopts.preview.vertical=down:80%<cr>",
				mode = "n",
				desc = "Grep Project",
			},
			{
				"<leader>sb",
				"<cmd>FzfLua buffers<cr>",
				mode = "n",
				desc = "Buffers",
			},
			{
				"<leader>sB",
				"<cmd>FzfLua grep_curbuf<cr>",
				mode = "n",
				desc = "Grep Current Buffer",
			},
			{
				"<leader>sd",
				"<cmd>FzfLua diagnostics_document<cr>",
				mode = "n",
				desc = "Document Diagnostics",
			},
			{
				"<leader>sm",
				"<cmd>FzfLua marks<cr>",
				mode = "n",
				desc = "Marks",
			},
			{
				"<leader>ss",
				"<cmd>FzfLua lsp_live_workspace_symbols<cr>",
				mode = "n",
				desc = "Document Symbols",
			},
			{
				"<leader>sw",
				"<cmd>FzfLua grep_cword<cr>",
				mode = "n",
				desc = "Grep for current word",
			},
			{
				"<leader>sW",
				"<cmd>FzfLua grep_cWORD<cr>",
				mode = "n",
				desc = "Grep for current WORD",
			},
			{
				"<leader>sk",
				"<cmd>FzfLua keymaps<cr>",
				mode = "n",
				desc = "Keymaps",
			},
		},
	},
}
