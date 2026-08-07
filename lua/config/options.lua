-- =============================================================================
-- config/vim.options.lua
-- =============================================================================

-- UI
vim.opt.number         = true    -- show line number in gutter
vim.opt.relativenumber = true    -- show line numbers relative to cursor line
vim.opt.cmdheight      = 0       -- hide command line when not in use
vim.opt.wrap           = false   -- disable autowrap
vim.opt.splitbelow     = true    -- horizontal splits open below
vim.opt.splitright     = true    -- vertical splits open to the right

-- Split dividers: use heavy box-drawing chars so the line between windows
-- is easy to see (color is set via WinSeparator in the kanagawa config).
vim.opt.fillchars = {
  vert      = "┃",
  horiz     = "━",
  horizup   = "┻",
  horizdown = "┳",
  vertleft  = "┫",
  vertright = "┣",
  verthoriz = "╋",
}


-- Editing
vim.opt.expandtab  = true        -- spaces instead of tabs
vim.opt.shiftwidth = 4           -- number of spaces used to make 1 level of (auto)indentation: `<<, >>`
vim.opt.tabstop    = 4           -- number of spaces used to make a `tab`
vim.opt.confirm    = true        -- prompt instead of error when closing unsaved buffer


-- Clipboard
vim.opt.clipboard = "unnamedplus" -- sync with system clipboard


-- Whitespace visibility (toggled with <leader>ts)
vim.opt.list = false
vim.opt.listchars = {
  tab        = "» ",
  trail      = "·",
  space      = "·",
  multispace = "---+",
}


-- Folding (treesitter-based)
-- foldlevel = 99 keeps all folds open by default.
-- foldlevelstart = 99 ensures new buffers also open with all folds open.
vim.opt.foldmethod    = "expr"
vim.opt.foldexpr      = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel     = 99
vim.opt.foldlevelstart = 99


-- Grep (ripgrep)
-- :grep fills the quickfix list, which the fzf-lua pickers do not. That is the
-- point: once matches are in quickfix, :cdo runs an edit over every one of them
-- (`:cdo s/old/new/g | update`), so a rename is scoped to exactly the lines
-- that matched. A picker finds one result; quickfix operates on all of them.
-- The default grepformat has no %c, so the column from --vimgrep needs adding.
vim.opt.grepprg = "rg --vimgrep --smart-case"
vim.opt.grepformat = "%f:%l:%c:%m"


-- Diagnostics
vim.diagnostic.config({
  virtual_text = {
		prefix = "",
},
})
