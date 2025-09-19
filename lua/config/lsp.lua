local add_desc = function(opts, descr)
	return vim.tbl_extend("force", opts, { desc = descr })
end

local set = vim.keymap.set

vim.api.nvim_create_autocmd("LspAttach", {
	desc = "Lsp Actions",
	callback = function(event)
		local opts = { buffer = event.buf }

		set("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", add_desc(opts, "LSP: Hover"))
		set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", add_desc(opts, "Go To: Definition"))
		set("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", add_desc(opts, "Go To: Declaration"))
		set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", add_desc(opts, "Go To: Implementation"))
		set("n", "gt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", add_desc(opts, "Go To: Type Definition"))
		set("n", "gr", "<cmd>lua vim.lsp.buf.references()<cr>", add_desc(opts, "Go To: References"))
	end
})


local capabilities = require("blink.cmp").get_lsp_capabilities()
vim.lsp.config("*", {
	capabilities = capabilities
})
