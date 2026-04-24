---@diagnostic disable: missing-fields
-- venv-selector.nvim — Python virtual environment picker
-- https://github.com/linux-cultist/venv-selector.nvim

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("venv-selector-load", { clear = true }),
	pattern = "python",
	once = true,
	callback = function()
		vim.cmd.packadd("venv-selector.nvim")

		require("venv-selector").setup({
			options = {
				notify_user_on_venv_activation = true,
			},
			search = {},
			hooks = {
				require("venv-selector.hooks").dynamic_python_lsp_hook,
			},
		})

		vim.keymap.set("n", "<leader>vs", "<cmd>VenvSelect<cr>", { desc = "Select Python Venv" })
	end,
})
