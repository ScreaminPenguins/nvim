return {
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*", -- recommended, use latest release instead of latest commit
		cond = vim.fn.getcwd() == vim.fn.expand("/Users/ash_gent/Documents/McWork"),
		-- ft = "markdown",
		---@module 'obsidian'
		---@type obsidian.config
		opts = {
			legacy_commands = false,
			templates = {
				folder = "Templates",
				date_format = "%Y-%m-%d, %a",
				time_format = "HH:mm",
				substitutions = {
					date = function(_, suffix)
						local format = suffix or Obsidian.opts.templates.date_format
						return require("obsidian.util").format_date(os.time(), format)
					end,
					time = function(_, suffix)
						local format = suffix or Obsidian.opts.templates.time_format
						return require("obsidian.util").format_date(os.time(), format)
					end,
					title = function(ctx)
						return ctx.partial_note and ctx.partial_note:display_name()
					end,
					id = function(ctx)
						return ctx.partial_note and ctx.partial_note.id
					end,
					path = function(ctx)
						return ctx.partial_note and tostring(ctx.partial_note.path)
					end,
					yesterday = function()
						return os.date("%Y-%m-%d", os.time() - 86400)
					end,
					tomorrow = function()
						return os.date("%Y-%m-%d", os.time() + 86400)
					end,
				},
			},
			daily_notes = {
				folder = "DailyNotes",
				template = "/Users/ash_gent/Documents/McWork/Templates/daily_note_template.md",
			},
			workspaces = {
				{
					name = "work",
					path = "/Users/ash_gent/Documents/McWork",
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
