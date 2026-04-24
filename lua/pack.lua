-- =============================================================================
-- pack.lua
-- =============================================================================
-- Ordering rules:
--   1. Shared dependencies first (plenary, web-devicons, nui)
--   2. Plugins that others depend on before those that depend on them
--   3. Within a group, order doesn't matter
--
-- On first install: plugins are cloned but not sourced — a restart is required.
-- On subsequent starts: all plugins are loaded normally via :packadd.
--
-- To update all plugins:
--   :lua vim.pack.update()
-- To restore to lockfile state:
--   :lua vim.pack.update(nil, { target = 'lockfile' })
-- =============================================================================

vim.pack.add({

	-- ---------------------------------------------------------------------------
	-- Shared dependencies
	-- Listed first — multiple plugins below depend on these.
	-- ---------------------------------------------------------------------------
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/MunifTanjim/nui.nvim",

	-- ---------------------------------------------------------------------------
	-- Colorscheme
	-- ---------------------------------------------------------------------------
	"https://github.com/rebelot/kanagawa.nvim",

	-- ---------------------------------------------------------------------------
	-- UI
	-- ---------------------------------------------------------------------------
	"https://github.com/nvimdev/dashboard-nvim",
	"https://github.com/nvim-lualine/lualine.nvim",
	"https://github.com/akinsho/bufferline.nvim",
	"https://github.com/folke/which-key.nvim",
	"https://github.com/folke/todo-comments.nvim",

	-- ---------------------------------------------------------------------------
	-- Navigation & Search
	-- ---------------------------------------------------------------------------
	{ src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = "v3.x" },
	"https://github.com/ibhagwan/fzf-lua",
	"https://github.com/chentoast/marks.nvim",
	"https://github.com/christoomey/vim-tmux-navigator",
	{ src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },

	-- ---------------------------------------------------------------------------
	-- Syntax & Treesitter
	-- NOTE: Treesitter parsers must be updated manually after plugin updates.
	--       Run :TSUpdate to sync parsers.
	--       See plugins/treesitter.lua for parser configuration.
	-- ---------------------------------------------------------------------------
	"https://github.com/nvim-treesitter/nvim-treesitter",
	{ src = "https://github.com/OXY2DEV/markview.nvim", load = false },

	-- ---------------------------------------------------------------------------
	-- LSP stack
	-- Order: blink.cmp before lspconfig — config/lsp.lua calls
	--        blink.cmp.get_lsp_capabilities() which must be available.
	-- ---------------------------------------------------------------------------
	"https://github.com/rafamadriz/friendly-snippets", -- snippets source for blink
	{ src = "https://github.com/saghen/blink.cmp", version = "v1" },
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/stevearc/conform.nvim",
	"https://github.com/folke/lazydev.nvim",

	-- ---------------------------------------------------------------------------
	-- Git
	-- ---------------------------------------------------------------------------
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/kdheepak/lazygit.nvim",

	-- ---------------------------------------------------------------------------
	-- AI
	-- ---------------------------------------------------------------------------
	"https://github.com/greggh/claude-code.nvim",

	-- ---------------------------------------------------------------------------
	-- Language & domain-specific
	-- ---------------------------------------------------------------------------
	{ src = "https://github.com/linux-cultist/venv-selector.nvim", load = false },
	{ src = "https://github.com/epwalsh/obsidian.nvim", load = false },

	{ src = "https://github.com/PedramNavid/dbtpal", load = false },
	{ src = "https://github.com/towolf/vim-helm", load = false },

	-- ---------------------------------------------------------------------------
	-- Debugger (DAP)
	-- TODO: confirm URLs when working through mason.lua
	-- ---------------------------------------------------------------------------
	-- "https://github.com/mfussenegger/nvim-dap",
	-- "https://github.com/rcarriga/nvim-dap-ui",
	-- "https://github.com/nvim-neotest/nvim-nio",
	-- "https://github.com/mfussenegger/nvim-dap-python",
	-- "https://github.com/theHamsta/nvim-dap-virtual-text",
	-- "https://github.com/jay-babu/mason-nvim-dap.nvim",

	-- ---------------------------------------------------------------------------
	-- Lua development
	-- ---------------------------------------------------------------------------
	-- NOTE: lazydev is in the LSP stack section above.
	-- No entry for mason-lspconfig — removed, was unused.
})
