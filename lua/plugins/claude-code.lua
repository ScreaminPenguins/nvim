-- claude-code.nvim — Claude Code integration
-- https://github.com/greggh/claude-code.nvim

require("claude-code").setup({
	window = {
		position = "float",
	},
})

-- Register <leader>c group label in which-key
require("which-key").add({ "<leader>c", group = "Claude" })

vim.keymap.set("n", "<leader>cc", "<cmd>ClaudeCode<cr>", { desc = "Claude Code" })
vim.keymap.set("n", "<leader>cC", "<cmd>ClaudeCodeContinue<cr>", { desc = "Claude Code Continue" })

-- Exit terminal mode and close the float with <C-d>
vim.keymap.set("t", "<C-d>", "<C-\\><C-n><cmd>ClaudeCode<cr>", { desc = "Hide Claude Code" })
