-- mason.nvim — LSP server, formatter, and tool installer
-- https://github.com/mason-org/mason.nvim

local ensure_installed = {
  -- Language servers
  "ty",                    -- Python (replacing basedpyright)
  "bash-language-server",  -- Shell
  "buf",                   -- Protobuf (lspconfig server name: buf_ls)
  "docker-language-server", -- Docker
  "gopls",                 -- GoLang
  "helm-ls",               -- Helm
  "intelephense",          -- PHP
  "jdtls",                 -- Java
  "lua-language-server",    -- Lua
  "yaml-language-server",   -- YAML

  -- Linters / formatters
  "ruff",    -- Python
  "stylua",  -- Lua
  "prettier", -- Misc

  -- Debuggers
  "debugpy", -- Python
}

require("mason").setup()

local mr = require("mason-registry")

-- When a package finishes installing mid-session, re-trigger FileType so LSP
-- handlers re-evaluate the current buffer and attach the new server.
-- Replaces the lazy.nvim internal previously used here.
mr:on("package:install:success", function()
  vim.defer_fn(function()
    vim.api.nvim_exec_autocmds("FileType", {
      buf = vim.api.nvim_get_current_buf(),
    })
  end, 100)
end)

-- Install any missing tools on startup
mr.refresh(function()
  for _, tool in ipairs(ensure_installed) do
    local p = mr.get_package(tool)
    if not p:is_installed() then
      p:install()
    end
  end
end)

vim.keymap.set("n", "<leader>tM", "<cmd>Mason<cr>", { desc = "Toggle: Mason" })
