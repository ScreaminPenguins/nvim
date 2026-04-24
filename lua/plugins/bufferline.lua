-- bufferline.nvim — tab-style buffer list in the tabline
-- https://github.com/akinsho/bufferline.nvim

require("bufferline").setup({
	options = {
		custom_filter = function(buf_nbr)
			local bt = vim.bo[buf_nbr].buftype
			local ft = vim.bo[buf_nbr].filetype
			return bt ~= "terminal" and ft ~= "dashboard"
		end,
		offsets = {
			{
				filetype = "neo-tree",
				text = "Neo-tree",
				highlight = "Directory",
				text_align = "left",
			},
		},
	},
})

vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
