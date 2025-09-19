-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.autocmds")
require("config.options")
require("config.lsp")

-- Diagnostics
vim.diagnostic.config({
	virtual_text = {
		prefix = "●",
	},
})
