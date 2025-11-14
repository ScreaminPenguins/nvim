return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"ibhagwan/fzf-lua",
	},
	lazy = true,
	ft = { "python" }, -- Load when opening Python files
	config = function(_, opts)
		require("venv-selector").setup(opts)

		vim.keymap.set("n", "<leader>vs", "<cmd>VenvSelect<cr>", { desc = "Venv Select" })
	end,
	keys = {},
	opts = { -- this can be an empty lua table - just showing below for clarity.
		search = {}, -- if you add your own searches, they go here.
		options = {}, -- if you add plugin options, they go here.
	},
}
