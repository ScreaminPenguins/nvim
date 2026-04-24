-- =============================================================================
-- Load order is intentional — do not reorder without understanding constraints.
-- =============================================================================
-- Disable unused built-in plugins
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_tutor_mode_plugin = 1

-- Set Map leaders
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Core options
require("config.options")

-- Install/Load plugins
require("pack")

-- =============================================================================
-- Plugin configuration
-- Order matters — colorscheme loads first to avoid unstyled flash.
-- LSP-adjacent plugins (blink, lspconfig, mason, conform) load before config.lsp.
-- =============================================================================

-- Colorscheme
require("plugins.kanagawa")

-- UI
require("plugins.dashboard")
require("plugins.lualine")
require("plugins.bufferline")
require("plugins.which-key")
require("plugins.todo-comments")

-- Navigation
require("plugins.neotree")
require("plugins.fzf-lua")
require("plugins.harpoon")
require("plugins.marks")
require("plugins.vim-tmux-navigator")

-- Syntax & Treesitter
require("plugins.treesitter")
require("plugins.markview")

-- LSP stack
require("plugins.blink-cmp")
require("plugins.nvim-lspconfig")
require("plugins.mason")
require("plugins.conform")
require("plugins.lazydev")

-- Git
require("plugins.gitsigns")
require("plugins.lazygit")

-- Terminal & scratch
require("plugins.scratch")

-- AI
require("plugins.claude-code")

-- Language / domain-specific
require("plugins.venv-selector")
require("plugins.obsidian")
require("plugins.dbtpal")
require("plugins.lookml")
require("plugins.vim-helm")

-- =============================================================================
-- Core config (after plugins are set up)
-- =============================================================================

-- LSP global config: vim.lsp.config("*", ...) and LspAttach keymaps.
-- Must run after blink-cmp is set up so capabilities are available.
require("config.lsp")

-- Global keymaps not tied to any specific plugin.
require("config.keymaps")

-- Global autocommands.
require("config.autocmds")

-- bootstrap lazy.nvim, LazyVim and your plugins
-- require("config.lazy")
-- require("config.options")
-- require("config.lsp")
-- require("config.keymaps")
-- require("config.autocmds")
--
-- -- Diagnostics
-- vim.diagnostic.config({
-- 	virtual_text = {
-- 		prefix = "",
-- 	},
-- })
--
-- vim.opt.foldmethod = "expr"
-- vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
