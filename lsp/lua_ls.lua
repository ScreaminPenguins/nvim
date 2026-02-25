return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", ".git" },
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
				pathStrict = false,
			},
			workspace = {
				checkThirdParty = false,
				ignoreDir = {},
			},
			telemetry = {
				enable = false,
			},
		},
	},
}
