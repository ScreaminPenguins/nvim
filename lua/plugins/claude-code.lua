return {
	"greggh/claude-code.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim", -- Required for git operations
	},
	lazy = true,
	opts = {},
	config = function(_, opts)
		require("claude-code").setup(opts)

		local wk = require("which-key")
		wk.add({ "<leader>c", group = "[C]laude" })

		vim.keymap.set("n", "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Claude Code" })
		vim.keymap.set("n", "<leader>cC", "<cmd>ClaudeCodeContinue<cr>", { desc = "Claude Code Continue" })
	end,
	keys = {},
}
