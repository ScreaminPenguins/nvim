return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*", -- recommended, use latest release instead of latest commit
		ft = "markdown",
		---@module 'obsidian'
		---@type obsidian.config
		opts = {
			legacy_commands = false,
			templates = {
				folder = "Templates",
				date_format = "%Y-%m-%d, %a",
			},
			daily_notes = {
				folder = "DailyNotes",
			},
			workspaces = {
				{
					name = "work",
					path = "~/Repositories/work/McWorkVault/McWork/",
				},
			},
		},
		config = function(_, opts)
			require("obsidian").setup(opts)

			local wk = require("which-key")
			wk.add({
				{ "<leader>n", group = "[N]otes" },
			})

			-- Register keymaps after plugin loads
			vim.keymap.set("n", "<leader>nd", "<cmd>ObsidianToday<cr>", { desc = "New daily note" })
			vim.keymap.set("n", "<leader>nft", "<cmd>ObsidianNewFromTemplate<cr>", { desc = "New note from template" })
		end,
	},
}
