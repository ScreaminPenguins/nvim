return {
	{
		'nvim-telescope/telescope.nvim',
		tag = '0.1.8',
		dependencies = {
			'nvim-lua/plenary.nvim',
			{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
		},
		require("telescope").setup({
		}),
		config = function()
			vim.keymap.set("n", "<leader>fd", require("telescope.builtin").find_files)
			vim.keymap.set("n", "<leader>en", function()
				require("telescope.builtin").find_files({
					cwd = vim.fn.stdpath("config")
				})
			end)
		end
	},
}
