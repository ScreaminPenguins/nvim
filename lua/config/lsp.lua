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

-- Overrides that cannot live in lsp/<server>.lua.
--
-- vim.pack appends plugins after the config dir on runtimepath, and
-- vim.lsp.config merges lsp/<server>.lua files in runtimepath order, so
-- nvim-lspconfig's copy wins on any key our own file also sets. Keys lspconfig
-- does not define (e.g. the yamlls schema map) still work from lsp/. Explicit
-- vim.lsp.config(name, ...) calls are merged last, so they win outright.
--
-- intelephense: root_markers is order-sensitive (vim.fs.root treats the list as
-- priority tiers). lspconfig ships { ".git", "composer.json" }, which roots a
-- PHP project at the enclosing git repo rather than at its composer.json.
vim.lsp.config("intelephense", {
	root_markers = { "composer.json", ".git" },
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
		-- grr, not gr: Neovim 0.11+ ships grn/gra/gri/grr as defaults, making gr a
		-- prefix. A bare gr mapping stalls for timeoutlen on every press.
		vim.keymap.set("n", "grr", "<cmd>FzfLua lsp_references<cr>", {buffer = buf, desc = "Go To: References" })
		vim.keymap.set("n", "<leader>rs", "<cmd>lua vim.lsp.buf.rename()<cr>", {buffer = buf, desc = "LSP: Rename Symbol" })
	end,
})

-- Enable LSP servers.
-- Per-server configuration lives in lsp/<server>.lua — Neovim 0.12 reads
-- these natively and merges them with the "*" capabilities above.
-- Moved here from plugins/nvim-lspconfig.lua (the dir = stdpath hack).
vim.lsp.enable({
  "bqls",        -- BigQuery SQL
  "bashls",                 -- Shell
  "buf_ls",       -- Protobuf
  "docker_language_server", -- Docker (mason pkg: docker-language-server)
  "gopls",        -- Go
  "helm_ls",      -- Helm
  "intelephense", -- PHP
  "jdtls",        -- Java (aspirational — config incomplete)
  "jsonls",       -- JSON
  "lua_ls",       -- Lua
  "ruff",         -- Python linter/formatter
  "taplo",        -- TOML
  "ty",           -- Python type checker
  "yamlls",       -- YAML
})
