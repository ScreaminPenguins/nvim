-- nvim-dap — Debug Adapter Protocol client
-- https://github.com/mfussenegger/nvim-dap
-- https://github.com/rcarriga/nvim-dap-ui
-- https://github.com/mfussenegger/nvim-dap-python
-- https://github.com/theHamsta/nvim-dap-virtual-text
-- https://github.com/jay-babu/mason-nvim-dap.nvim
--
-- Separated from mason.lua — DAP is a distinct concern from tool installation.
-- mason-nvim-dap bridges Mason-installed debuggers into nvim-dap adapters.

local dap    = require("dap")
local dapui  = require("dapui")

-- DAP UI — opens/closes automatically on session start/end
dapui.setup()

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

-- Virtual text — show variable values inline while debugging
require("nvim-dap-virtual-text").setup()

-- Python — use uv as the python provider
require("dap-python").setup("uv")

-- Bridge Mason-installed debuggers into nvim-dap adapters
require("mason-nvim-dap").setup()

-- Keymaps
local set = vim.keymap.set

set("n", "<leader>db", function() dap.toggle_breakpoint() end,                          { desc = "Toggle Breakpoint" })
set("n", "<leader>dB", function() dap.set_breakpoint(vim.fn.input("Condition: ")) end,  { desc = "Breakpoint Condition" })
set("n", "<leader>dc", function() dap.continue() end,                                   { desc = "Run / Continue" })
set("n", "<leader>dC", function() dap.run_to_cursor() end,                              { desc = "Run to Cursor" })
set("n", "<leader>di", function() dap.step_into() end,                                  { desc = "Step Into" })
set("n", "<leader>do", function() dap.step_out() end,                                   { desc = "Step Out" })
set("n", "<leader>dO", function() dap.step_over() end,                                  { desc = "Step Over" })
set("n", "<leader>dl", function() dap.run_last() end,                                   { desc = "Run Last" })
set("n", "<leader>dt", function() dap.terminate() end,                                  { desc = "Terminate" })
set("n", "<leader>dr", function() dap.repl.toggle() end,                                { desc = "Toggle REPL" })
set("n", "<leader>dg", function() dap.goto_() end,                                      { desc = "Go to Line (No Execute)" })
set("n", "<leader>dj", function() dap.down() end,                                       { desc = "Down" })
set("n", "<leader>dk", function() dap.up() end,                                         { desc = "Up" })
set("n", "<leader>dP", function() dap.pause() end,                                      { desc = "Pause" })
set("n", "<leader>ds", function() dap.session() end,                                    { desc = "Session" })
set("n", "<leader>dw", function() require("dap.ui.widgets").hover() end,                { desc = "Widgets" })
set("n", "<leader>du", function() dapui.toggle() end,                                   { desc = "DAP UI" })
set({ "n", "v" }, "<leader>de", function() dapui.eval() end,                            { desc = "Eval" })
