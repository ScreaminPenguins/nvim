return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
	{
		dir = vim.fn.stdpath("config"),
		config = function()
			vim.lsp.enable("basedpyright") -- has rename capabilities
			vim.lsp.enable("bashls")
			vim.lsp.enable("docker-language-server")
			vim.lsp.enable("gopls")
			vim.lsp.enable("helmls")
			vim.lsp.enable("lua_ls")
			vim.lsp.enable("ruff")
			vim.lsp.enable("ty")
			vim.lsp.enable("json-lsp")
			vim.lsp.enable("yaml-language-server")

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("lsp", { clear = true }),
				callback = function(args)
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = args.buf,
						callback = function()
							require("conform").format({ bufnr = args.buf })
						end,
					})
				end,
			})
		end,
	},
}
