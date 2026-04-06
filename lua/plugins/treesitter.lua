return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").setup()

			require("nvim-treesitter").install({
				"bash",
				"c",
				"dockerfile",
				"helm",
				"json",
				"lua",
				"make",
				"markdown",
				"python",
				"query",
				"sql",
				"vim",
				"vimdoc",
				"yaml",
			})

			-- Enable highlighting and indent via Neovim core
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(ev)
					local ok = pcall(vim.treesitter.start, ev.buf)
					if ok then
						vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
		end,
	},
}
