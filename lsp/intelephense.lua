return {
	cmd = { "intelephense", "--stdio" },
	filetypes = { "php" },
	-- root_markers is set in config/lsp.lua — nvim-lspconfig overrides this file
	-- on any key it also defines, so setting it here has no effect.
	settings = {},
}
