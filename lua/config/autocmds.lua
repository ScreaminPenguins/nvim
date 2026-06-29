-- =============================================================================
-- config/autocmds.lua
-- =============================================================================

-- Briefly highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight on yank",
  group = vim.api.nvim_create_augroup("yank-highlight", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})


-- Disable concealing in JSON buffers (keeps quotes and braces visible)
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("json-conceal", { clear = true }),
  pattern = "json",
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})


-- Format on save via conform.nvim.
-- conform handles filetype matching internally via formatters_by_ft —
-- no need to gate this on LspAttach. If no formatter is configured for
-- the filetype, conform is a no-op.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("auto-format", { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "sql" then
      require("conform").format({ bufnr = args.buf })
    end
  end,
})
