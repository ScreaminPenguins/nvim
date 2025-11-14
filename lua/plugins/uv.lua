return {
	{
		"benomahony/uv.nvim",
		opts = {
			picker_integration = true,
		},
		lazy = true,
		ft = { "python" },
		config = function(_, opts)
			require("uv").setup(opts)

			local wk = require("which-key")
			wk.add({
				{ "<leader>u", group = "[U]v" },
			})
			vim.keymap.set("n", "<leader>ui", "<cmd>UVInit<cr>", { desc = "UV init" })
			vim.keymap.set(
				"n",
				"<leader>ua",
				"<cmd>lua vim.ui.input({prompt = 'Enter package name: '}, function(input) if input and input ~= '' then require('uv').run_command('uv add ' .. input) end end)<CR>",
				{ desc = "UV add dependency" }
			)
			vim.keymap.set("n", "<leader>ur", "UVRunFile", { desc = "UV run file" })
		end,
		keys = {},
	},
}
