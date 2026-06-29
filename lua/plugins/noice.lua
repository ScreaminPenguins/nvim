-- noice - notifications/messages/cmdline windows
-- https://github.com/folke/noice.nvim

-- nvim-notify is noice's notification backend. Configure it first so noice
-- picks up these settings when it routes notifications through the notify view.
require("notify").setup({
	stages = "fade_in_slide_out",
	timeout = 3000,
	render = "wrapped-compact",
	max_width = 80,
	merge_duplicates = true, -- plugin default; set explicitly to satisfy lua_ls (its type annotation marks this field non-optional)
})
vim.notify = require("notify")

require("noice").setup({
	lsp = {
		-- override markdown rendering so hover/signature docs use Treesitter.
		-- (no cmp.entry override — this config uses blink.cmp, not nvim-cmp)
		override = {
			["vim.lsp.util.convert_input_to_markdown_lines"] = true,
			["vim.lsp.util.stylize_markdown"] = true,
		},
	},
	-- send :!cmd shell output to a scrollable split instead of the brief
	-- bottom-right mini view (noice doesn't route shell_* kinds by default).
	routes = {
		{
			view = "split",
			filter = { event = "msg_show", kind = { "shell_out", "shell_err", "shell_ret" } },
		},
	},
	-- center the cmdline popup (and its completion menu) on screen.
	-- overrides the top-anchored positions set by the command_palette preset.
	-- rows are percentages of the editor height — tune to taste.
	cmdline = { view = "cmdline_popup" },
	views = {
		cmdline_popup = {
			position = {
				row = "50%",
				col = "50%",
			},
			size = {
				min_width = 60,
				width = "auto",
				height = "auto",
			},
		},
	},
	-- presets for easier configuration
	presets = {
		bottom_search = true, -- use a classic bottom cmdline for search
		command_palette = true, -- position the cmdline and popupmenu together
		long_message_to_split = true, -- long messages will be sent to a split
		inc_rename = false, -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = false, -- add a border to hover docs and signature help
	},
})
