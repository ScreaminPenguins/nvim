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

-- Toggle the tab bar's visibility by flipping `showtabline`. bufferline renders
-- into the tabline, so hiding the tabline hides the tabs without unloading the
-- plugin or dropping the cycle keymaps below.
vim.keymap.set("n", "<leader>tB", function()
	vim.o.showtabline = vim.o.showtabline == 0 and 2 or 0
end, { desc = "Toggle: buffer tabs" })

-- Cycle buffers. When the bar is visible, use bufferline's ordered cycle so the
-- motion matches the on-screen order. When it's hidden, Neovim stops evaluating
-- the tabline expression, so bufferline's internal list goes stale and would
-- skip buffers opened while hidden — fall back to native :bnext/:bprevious,
-- which always sees every listed buffer (order is invisible when hidden anyway).
vim.keymap.set("n", "<S-h>", function()
	vim.cmd(vim.o.showtabline == 0 and "bprevious" or "BufferLineCyclePrev")
end, { desc = "Prev buffer" })
vim.keymap.set("n", "<S-l>", function()
	vim.cmd(vim.o.showtabline == 0 and "bnext" or "BufferLineCycleNext")
end, { desc = "Next buffer" })
