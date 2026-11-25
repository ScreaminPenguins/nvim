-- Workaround for vim-dadbod-ui shadowing the runtime SQL ftplugin.
-- $VIMRUNTIME/ftplugin/mysql.vim does `runtime ftplugin/sql.vim`, which sources
-- only the FIRST match on 'runtimepath' — vim-dadbod-ui's ftplugin/sql.vim (it
-- just adds <leader>W/E/S maps). The real SQL ftplugin never runs, so mysql
-- buffers get no 'commentstring' (gcc: "Option 'commentstring' is empty"),
-- 'comments', matchit words, etc. Source it explicitly when that happened;
-- b:did_ftplugin is unset exactly in that case, so this is a no-op otherwise.
if vim.b.did_ftplugin == nil then
	vim.cmd.source(vim.env.VIMRUNTIME .. "/ftplugin/sql.vim")
end

-- MySQL buffers share the SQL buffer options (indent, folding).
vim.cmd.runtime("after/ftplugin/sql.lua")
