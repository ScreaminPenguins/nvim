-- nvim-treesitter — parser management and tree-sitter integration
-- https://github.com/nvim-treesitter/nvim-treesitter
--
-- After plugin updates, run :TSUpdate to sync parsers.

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

-- Enable tree-sitter highlighting and indent for every buffer that has a parser.
-- pcall absorbs the error when no parser exists for the filetype.
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
	callback = function(ev)
		local ok = pcall(vim.treesitter.start, ev.buf)
		if ok then
			vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})
