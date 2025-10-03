-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.options")
require("config.lsp")
require("config.keymaps")
require("config.autocmds")

-- Diagnostics
vim.diagnostic.config({
	virtual_text = {
		prefix = "",
  }
})
