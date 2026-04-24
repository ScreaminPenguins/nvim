return {
	cmd = { "yaml-language-server", "--stdio" },
	filetypes = { "yaml" },
	settings = {
		yaml = {
			schemas = {
				["https://sweet-serve.sweetwater.com/api/schemas/helm/main"] = "**helm/values*.yaml",
			},
		},
	},
}
