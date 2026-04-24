-- markview.nvim — rendered markdown preview inside Neovim buffers
-- https://github.com/OXY2DEV/markview.nvim

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("markview-load", { clear = true }),
	pattern = "markdown",
	once = true,
	callback = function()
		vim.cmd.packadd("markview.nvim")
		require("markview").setup({})
		vim.keymap.set("n", "<leader>tm", "<cmd>Markview toggle<cr>", { desc = "Toggle: Markview" })
	end,
})
