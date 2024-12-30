return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		cmd = "Neotree",
		keys = {
			{
				"<leader>fe", function()
				require("neo-tree.command").execute({
					toggle = true,
					dir = vim.uv.cwd()
				})
			end
			}
		},
		opts = {
			filesystem = {
				filtered_items = {
					visible = true,
					show_hidden_count = true,
					hide_dotfiles = false,
					hide_gitignored = false,
					hide_by_name = {},
					never_show = {},
				},
			},
		},
	}
}
