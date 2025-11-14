return {
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {},
		config = function()
			local wk = require("which-key")
			wk.add({
				{ "<leader>b", group = "[B]uffers" },
				{ "<leader>d", group = "[D]ebug" },
				{ "<leader>h", group = "[H]arpoon" },
				{ "<leader>l", group = "[L]oad Plugin" },
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>t", group = "[T]oggle" },
				{ "<leader>w", group = "[W]indows" },
				{ "g", group = "+Go To" },
			})
		end,
		keys = {
			{
				"<leader>lc",
				"<cmd>lua require('claude-code')<cr>",
				desc = "Load Claude",
			},
			{
				"<leader>?",
				function()
					require("which-key").show({ global = false })
				end,
				desc = "Buffer Local Keymaps (which-key)",
			},
			{
				"<leader>tl",
				"<cmd>Lazy<cr>",
				desc = "Toggle: Lazy UI",
			},
		},
	},
}
