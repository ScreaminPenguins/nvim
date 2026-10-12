-- avro-lsp — language server for Apache Avro schema files
-- https://github.com/matthias-Q/avro-lsp
--
-- Only the `avsc` filetype is registered here. The rest of the wiring lives
-- where the conventions put it: server config in lsp/avro_lsp.lua, enablement
-- in config/lsp.lua, buffer options in after/ftplugin/avsc.lua.
--
-- Neovim has no built-in *.avsc detection, and vim.lsp.enable matches on
-- filetype, so without this the server would never attach. The name has to be
-- `avsc` (not `json`) to keep avro-lsp off every other JSON file in a project.
--
-- avro-lsp is not in the mason registry, so plugins/mason.lua cannot install or
-- update it — the binary at /usr/local/bin/avro-lsp is managed by hand.
vim.filetype.add({
	extension = {
		avsc = "avsc",
	},
})
