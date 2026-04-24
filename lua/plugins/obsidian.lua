-- obsidian.nvim — Markdown note-taking integrated with Obsidian vaults
-- https://github.com/epwalsh/obsidian.nvim
--
-- Loaded lazily on the first markdown buffer (load = false in pack.lua).
-- Workspace detection is automatic — commands activate only when the current
-- file lives inside a configured workspace path

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("obsidian-load", { clear = true }),
	pattern = "markdown",
	once = true,
	callback = function()
		vim.cmd.packadd("obsidian.nvim")

		require("obsidian").setup({
			legacy_commands = false,
			templates = {
				folder = "Templates",
				date_format = "%Y-%m-%d, %a",
				time_format = "HH:mm",
				substitutions = {
					date = function(_, suffix)
						local client = require("obsidian").get_client()
						local format = suffix or client.opts.templates.date_format
						return require("obsidian.util").format_date(os.time(), format)
					end,
					time = function(_, suffix)
						local client = require("obsidian").get_client()
						local format = suffix or client.opts.templates.time_format
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
		})

		require("which-key").add({
			{ "<leader>n", group = "Notes" },
		})

		vim.keymap.set("n", "<leader>nd", "<cmd>ObsidianToday<cr>", { desc = "Notes: daily note" })
		vim.keymap.set("n", "<leader>nft", "<cmd>ObsidianNewFromTemplate<cr>", { desc = "Notes: new from template" })
	end,
})
