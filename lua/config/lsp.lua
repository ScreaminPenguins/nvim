local set = vim.keymap.set

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "Lsp Actions",
  callback = function()
    set("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", { desc = "LSP: Hover" })
    set("n", "gd", "<cmd>FzfLua lsp_definitions<cr>", { desc = "Go To: Definition" })
    set("n", "gD", "<cmd>FzfLua lsp_declarations<cr>", { desc = "Go To: Declaration" })
    set("n", "gi", "<cmd>FzfLua lsp_implementations<cr>", { desc = "Go To: Implementation" })
    set("n", "gt", "<cmd>FzfLua lsp_typedefs<cr>", { desc = "Go To: Type Definition" })
    set("n", "gr", "<cmd>FzfLua lsp_references<cr>", { desc = "Go To: References" })
  end,
})

local capabilities = require("blink.cmp").get_lsp_capabilities()
vim.lsp.config("*", {
  capabilities = capabilities,
})
