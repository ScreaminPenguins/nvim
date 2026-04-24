-- =============================================================================
-- config/lsp.lua
-- =============================================================================
-- Global LSP setup: capabilities, buffer-local keymaps, and server enablement.
--
-- Load order requirement: must run after plugins/blink-cmp is set up,
-- since get_lsp_capabilities() requires blink.cmp to be on the runtimepath.
-- =============================================================================
vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(),
})

-- Buffer-local LSP keymaps — registered once per buffer when a server attaches.
-- Using buffer = args.buf ensures these only exist in buffers with an active
-- LSP server, and don't pollute global keymap space.
vim.api.nvim_create_autocmd("LspAttach", {
	desc = "Lsp Keymaps",
	group = vim.api.nvim_create_augroup("lsp-keymaps", { clear = true }),
	callback = function(args)
    local buf = args.buf
		vim.keymap.set("n", "K", '<cmd>lua vim.lsp.buf.hover({ border = "rounded" })<cr>', {buffer = buf, desc = "LSP: Hover" })
		vim.keymap.set("n", "gd", "<cmd>FzfLua lsp_definitions<cr>", {buffer = buf, desc = "Go To: Definition" })
		vim.keymap.set("n", "gD", "<cmd>FzfLua lsp_declarations<cr>", {buffer = buf, desc = "Go To: Declaration" })
		vim.keymap.set("n", "gi", "<cmd>FzfLua lsp_implementations<cr>", {buffer = buf, desc = "Go To: Implementation" })
		vim.keymap.set("n", "gt", "<cmd>FzfLua lsp_typedefs<cr>", {buffer = buf, desc = "Go To: Type Definition" })
		vim.keymap.set("n", "gr", "<cmd>FzfLua lsp_references<cr>", {buffer = buf, desc = "Go To: References" })
	end,
})

-- Enable LSP servers.
-- Per-server configuration lives in lsp/<server>.lua — Neovim 0.12 reads
-- these natively and merges them with the "*" capabilities above.
-- Moved here from plugins/nvim-lspconfig.lua (the dir = stdpath hack).
vim.lsp.enable({
  "bashls",                 -- Shell
  "buf_ls",       -- Protobuf
  "dockerls",     -- Docker
  "gopls",        -- Go
  "helm_ls",      -- Helm
  "intelephense", -- PHP
  "jdtls",        -- Java (aspirational — config incomplete)
  "jsonls",       -- JSON
  "lua_ls",       -- Lua
  "ruff",         -- Python linter/formatter
  "ty",           -- Python type checker
  "yamlls",       -- YAML
})
