-- dbtpal — dbt runner and test integration
-- https://github.com/PedramNavid/dbtpal
--
-- Loaded lazily on sql/yaml buffers (load = false in pack.lua).
-- No cwd guard needed — dbtpal auto-detects dbt_project.yml by walking up
-- the directory tree from the current file. Commands warn if no project found.

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("dbtpal-load", { clear = true }),
	pattern = { "sql", "yaml" },
	once = true,
	callback = function()
		vim.cmd.packadd("dbtpal")

		require("dbtpal").setup({
			path_to_dbt = "dbt",
			path_to_dbt_project = "/Users/ash_gent/Repositories/work/other_teams/dbt_projects",
			path_to_dbt_profiles_dir = vim.fn.expand("~/.dbt"),
			include_profiles_dir = true,
			include_project_dir = true,
			include_log_level = true,
			extended_path_search = true,
			protect_compiled_files = true,
			pre_cmd_args = {},
			post_cmd_args = {},
		})

		vim.keymap.set("n", "<leader>drf", "<cmd>DbtRun<cr>", { desc = "dbt: run model" })
		vim.keymap.set("n", "<leader>dra", "<cmd>DbtRunAll<cr>", { desc = "dbt: run all" })
		vim.keymap.set("n", "<leader>dtf", "<cmd>DbtTest<cr>", { desc = "dbt: test model" })
	end,
})
