-- uv.nvim — uv package manager integration
-- https://github.com/benomahony/uv.nvim
--
-- Loaded lazily on the first Python buffer (load = false in pack.lua).

vim.api.nvim_create_autocmd("FileType", {
  group   = vim.api.nvim_create_augroup("uv-load", { clear = true }),
  pattern = "python",
  once    = true,
  callback = function()
    vim.cmd.packadd("uv.nvim")

    require("uv").setup({ picker_integration = true })

    require("which-key").add({
      { "<leader>u", group = "uv" },
    })

    vim.keymap.set("n", "<leader>ui", "<cmd>UVInit<cr>", { desc = "uv: init project" })
    vim.keymap.set("n", "<leader>ua", function()
      vim.ui.input({ prompt = "Package name: " }, function(input)
        if input and input ~= "" then
          require("uv").run_command("uv add " .. input)
        end
      end)
    end, { desc = "uv: add dependency" })
    vim.keymap.set("n", "<leader>ur", "<cmd>UVRunFile<cr>", { desc = "uv: run file" })
  end,
})
