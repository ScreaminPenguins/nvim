return {
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("harpoon"):setup()
		end,
		keys = {
			{
				"<leader>th",
				function()
					local hp = require("harpoon")
					hp.ui:toggle_quick_menu(hp:list())
				end,
				desc = "Toggle Harpoon UI",
			},
			{
				"<leader>hh",
				function()
					require("harpoon"):list():add()
				end,
				desc = "Harpoon file",
			},
			{
				"<leader>h1",
				function()
					require("harpoon"):list():select(1)
				end,
				desc = "Fetch file: 1",
			},
			{
				"<leader>h2",
				function()
					require("harpoon"):list():select(2)
				end,
				desc = "Fetch file: 2",
			},
			{
				"<leader>h3",
				function()
					require("harpoon"):list():select(3)
				end,
				desc = "Fetch file: 3",
			},
			{
				"<leader>h4",
				function()
					require("harpoon"):list():select(4)
				end,
				desc = "Fetch file: 4",
			},
		},
	},
}
