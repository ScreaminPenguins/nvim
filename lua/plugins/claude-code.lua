return {
	"greggh/claude-code.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim", -- Required for git operations
	},
	lazy = true,
	opts = {
		window = {
			position = "float",
		},
	},
	config = function(_, opts)
		require("claude-code").setup(opts)
		local wk = require("which-key")
		wk.add({ "<leader>c", group = "[C]laude" })

		-- local set = vim.keymap.set
		-- local claude_term = nil
		--
		-- -- local toggle_claude = function()
		-- --   if not claude_term then
		-- --     claude_term = 1
		-- --     vim.cmd("ClaudeCode")
		-- --   else
		-- --     claude_term = nil
		-- --     vim.cmd("ClaudeCode")
		-- -- end
		--
		-- set("n", "<leader>cc", function()
		-- 	if not claude_term then
		-- 		claude_term = 1
		-- 		vim.cmd("ClaudeCode")
		-- 	else
		-- 		claude_term = nil
		-- 		vim.cmd("ClaudeCode")
		-- 	end
		-- end)

		vim.keymap.set("n", "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Claude Code" })
		vim.keymap.set("n", "<leader>cC", "<cmd>ClaudeCodeContinue<cr>", { desc = "Claude Code Continue" })
		vim.keymap.set("t", "<C-d>", "<C-\\><C-n><cmd>ClaudeCode<cr>", { desc = "Hide Claude Code float" })
	end,
	keys = {},
}
