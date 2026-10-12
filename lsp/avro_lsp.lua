return {
	cmd = { "avro-lsp" },
	filetypes = { "avsc" },
	-- avro-lsp resolves cross-file type references from the workspace root, so
	-- `avro-schemas` is checked before `.git`: a schema dir inside a larger repo
	-- should root there rather than at the repo top.
	root_markers = { "avro-schemas", ".git" },
}
