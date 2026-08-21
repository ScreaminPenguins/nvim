return {
	cmd = { "ruff", "server" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
	-- The native ruff server reads its editor config from initializationOptions.settings.
	-- configurationPreference defaults to "editorFirst", so these win over a project's
	-- pyproject.toml / ruff.toml without having to edit each project.
	--
	-- I001 ("Import block is unsorted or un-formatted") is an isort rule, and
	-- `ruff format` does not sort imports — only `ruff check --fix` does. So conform's
	-- ruff_format can never clear it and the diagnostic just sits there. Ignoring it
	-- here silences it in the editor only; `ruff check` on the CLI and in CI still
	-- reports it, so a project that enforces import order keeps enforcing it.
	init_options = {
		settings = {
			lint = {
				ignore = { "I001" },
			},
		},
	},
}
