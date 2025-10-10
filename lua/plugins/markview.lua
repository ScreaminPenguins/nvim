return {
	"OXY2DEV/markview.nvim",
	lazy = false,

	priority = 49,
	ft = { "markdown" },
	keys = {
		{ "<leader>vt", "<cmd>Markview toggle<cr>", mode = "n", desc = "Toggle Markview" },
	},

	-- For blink.cmp's completion
	-- source
	dependencies = {
		"saghen/blink.cmp",
	},
}
