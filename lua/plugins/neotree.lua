return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons", -- optional, but recommended
		},
		lazy = false, -- neo-tree will lazily load itself
		config = function(_, opts)
			require("neo-tree").setup(opts)

			vim.keymap.set("n", "<leader>te", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neotree" })
		end,
		---@module 'neo-tree'
		---@type neotree.Config
		opts = {
			filesystem = {
				filtered_items = {
					hide_dotfiles = false,
					hide_gitignored = false,
					hide_by_name = {},
				},
			},
		},
		keys = {},
	},
}
