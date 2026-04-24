-- neo-tree.nvim — file explorer sidebar
-- https://github.com/nvim-neo-tree/neo-tree.nvim
--
-- Pinned to v3.x branch (version = "v3.x" in pack.lua).

require("neo-tree").setup({
	filesystem = {
		filtered_items = {
			hide_dotfiles = false,
			hide_gitignored = false,
			hide_by_name = {},
		},
	},
})

vim.keymap.set("n", "<leader>te", "<cmd>Neotree toggle<cr>", { desc = "Toggle: Neotree" })
