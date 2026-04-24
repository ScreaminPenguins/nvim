-- which-key.nvim — keymap popup hint UI
-- https://github.com/folke/which-key.nvim

require("which-key").setup({})

require("which-key").add({
	{ "<leader>b", group = "Buffers" },
	{ "<leader>d", group = "Debug" },
	{ "<leader>h", group = "Harpoon" },
	{ "<leader>s", group = "Search" },
	{ "<leader>t", group = "Toggle" },
	{ "<leader>w", group = "Windows" },
	{ "g", group = "Go to" },
})

vim.keymap.set("n", "<leader>?", function()
	require("which-key").show({ global = false })
end, { desc = "Buffer keymaps (which-key)" })
