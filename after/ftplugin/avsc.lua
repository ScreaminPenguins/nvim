-- *.avsc is JSON with an Avro schema inside it. The `avsc` filetype exists only
-- so avro-lsp can attach (see lua/plugins/avro.lua), so borrow JSON's
-- indentation and treesitter parser for highlighting, folding and indenting.
local set = vim.opt_local

set.expandtab = true
set.shiftwidth = 2
set.tabstop = 2

-- Matches after/ftplugin/json.lua: keep quotes and braces visible.
set.conceallevel = 0

vim.treesitter.start(0, "json")
