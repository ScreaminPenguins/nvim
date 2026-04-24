-- gitsigns.nvim — git signs and hunk actions
-- https://github.com/lewis6991/gitsigns.nvim
require("gitsigns").setup({
	attach_to_untracked = true,

	current_line_blame = false, -- toggle with <leader>tb
	current_line_blame_opts = {
		delay = 500,
		virt_text_pos = "eol",
	},

	on_attach = function(bufnr)
		local gs = require("gitsigns")
		local set = vim.keymap.set

		-- Hunk navigation — falls back to native diff navigation when in diff mode
		set("n", "]c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				gs.nav_hunk("next")
			end
		end, { buffer = bufnr, desc = "Next Hunk" })

		set("n", "[c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				gs.nav_hunk("prev")
			end
		end, { buffer = bufnr, desc = "Prev Hunk" })

		-- Stage / reset
		set("n", "<leader>hs", gs.stage_hunk, { buffer = bufnr, desc = "Stage Hunk" })
		set("n", "<leader>hr", gs.reset_hunk, { buffer = bufnr, desc = "Reset Hunk" })
		set("v", "<leader>hs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { buffer = bufnr, desc = "Stage Selected Lines" })
		set("v", "<leader>hr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { buffer = bufnr, desc = "Reset Selected Lines" })
		set("n", "<leader>hS", gs.stage_buffer, { buffer = bufnr, desc = "Stage Buffer" })
		set("n", "<leader>hR", gs.reset_buffer, { buffer = bufnr, desc = "Reset Buffer" })
		set("n", "<leader>hu", gs.undo_stage_hunk, { buffer = bufnr, desc = "Unstage Hunk" })

		-- Preview / blame
		set("n", "<leader>hp", gs.preview_hunk, { buffer = bufnr, desc = "Preview Hunk" })
		set("n", "<leader>hb", function()
			gs.blame_line({ full = true })
		end, { buffer = bufnr, desc = "Blame Line" })
		set("n", "<leader>tb", gs.toggle_current_line_blame, { buffer = bufnr, desc = "Toggle Line Blame" })

		-- Diff
		set("n", "<leader>hd", gs.diffthis, { buffer = bufnr, desc = "Diff Index" })
		set("n", "<leader>hD", function()
			gs.diffthis("~")
		end, { buffer = bufnr, desc = "Diff Last Commit" })

		-- Text object — select inner hunk in operator/visual mode
		set({ "o", "x" }, "ih", gs.select_hunk, { buffer = bufnr, desc = "Select Hunk" })
	end,
})
