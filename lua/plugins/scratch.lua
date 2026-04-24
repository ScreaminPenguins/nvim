-- scratch — custom per-filetype scratch buffers
-- Implementation: lua/custom/scratch.lua
-- Keymaps registered by setup():
--   <leader>tn — toggle scratch buffer for current filetype
--   <leader>tl — list / open saved scratch buffers (fzf picker)
--   <leader>tx — delete scratch buffer(s) (fzf picker)
--
-- Scratch files are persisted to:
--   vim.fn.stdpath("data") .. "/scratches/"

require("custom.scratch").setup({
	use_fzf = true,
	keys = {
		toggle = "<leader>tn",
		list   = "<leader>tl",
		delete = "<leader>tx",
	},
})
