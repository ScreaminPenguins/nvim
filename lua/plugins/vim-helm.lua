-- vim-helm — syntax highlighting for Helm chart templates
-- https://github.com/towolf/vim-helm
--
-- Loaded lazily (load = false in pack.lua). Conditions for loading:
--   1. File path contains helm/*values*.yaml, OR
--   2. Chart.yaml exists in the current working directory (chart root)
--
-- After packadd, filetype detection is re-run so vim-helm's own autocmds
-- can set the correct filetype on the current buffer.

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	group = vim.api.nvim_create_augroup("vim-helm-load", { clear = true }),
	callback = function(args)
		local fname = vim.api.nvim_buf_get_name(args.buf)
		local is_helm_values = fname:match("[/\\]helm[/\\].*values.*%.yaml$") ~= nil
		local has_chart = vim.fn.filereadable(vim.fn.getcwd() .. "/Chart.yaml") == 1

		if not (is_helm_values or has_chart) then
			return
		end

		vim.cmd.packadd("vim-helm")
		vim.cmd("filetype detect")
		-- Plugin is now loaded and self-managing — remove this autocmd
		vim.api.nvim_del_augroup_by_name("vim-helm-load")
	end,
})
