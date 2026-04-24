local opt = vim.opt

opt.clipboard = "unnamedplus"
opt.cmdheight = 0
opt.confirm = true
opt.expandtab = true
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldmethod = "expr"
opt.list = false
opt.listchars = {
	tab = "» ",
	trail = "·",
	space = "·",
	multispace = "---+",
}
opt.number = true
opt.relativenumber = true
opt.shiftwidth = 4
opt.splitbelow = true
opt.tabstop = 4
opt.wrap = false

vim.diagnostic.config({
	virtual_text = {
		prefix = "",
	},
})
