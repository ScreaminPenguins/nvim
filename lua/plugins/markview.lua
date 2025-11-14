return {
	"OXY2DEV/markview.nvim",
	lazy = false,

	priority = 49,
	ft = { "markdown" },
	config = function(_, opts)
		require("markview").setup({ opts })

		vim.keymap.set("n", "<leader>tm", "<cmd>Markview toggle<cr>", { desc = "Toggle Markview" })
	end,
	keys = {},

	-- For blink.cmp's completion
	-- source
	dependencies = {
		"saghen/blink.cmp",
	},
}
