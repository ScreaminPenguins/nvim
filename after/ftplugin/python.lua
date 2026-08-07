local set = vim.opt_local

set.expandtab = true
set.shiftwidth = 4
set.tabstop = 4

-- :Make / <leader>m run ruff over the project and put each finding in the
-- quickfix list. --output-format=concise emits one `file:line:col: CODE message`
-- per line, which is what the errorformat below parses. ruff is installed by
-- Mason, which prepends its bin directory to Neovim's PATH, so no path needed.
--
-- $* is where :Make's arguments land, so `:Make --fix` works.
-- %-G%.%# discards every line that is not a finding. Without it ruff's trailing
-- "Found 3 errors." and "[*] 2 fixable ..." summary lines land in the quickfix
-- list as entries with no location, which you then have to ]q past.
set.makeprg = "ruff check --output-format=concise $*"
set.errorformat = "%f:%l:%c: %m,%-G%.%#"
