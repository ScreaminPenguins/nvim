return {
	filetypes = { "yaml" },
	settings = {
		yaml = {
			schemas = {
				["https://sweet-serve.sweetwater.com/api/schemas/helm/main"] = "**helm/values*.yaml",
			},
		},
	},
}
