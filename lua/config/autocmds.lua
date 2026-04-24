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


-- Show command line while recording a macro, hide it again when done.
-- Works alongside cmdheight = 0 in options.lua.
vim.api.nvim_create_autocmd("RecordingEnter", {
  group = vim.api.nvim_create_augroup("macro-cmdheight", { clear = true }),
  callback = function()
    vim.opt.cmdheight = 1
  end,
})
vim.api.nvim_create_autocmd("RecordingLeave", {
  group = vim.api.nvim_create_augroup("macro-cmdheight", { clear = false }),
  callback = function()
    vim.opt.cmdheight = 0
  end,
})


-- Format on save via conform.nvim.
-- conform handles filetype matching internally via formatters_by_ft —
-- no need to gate this on LspAttach. If no formatter is configured for
-- the filetype, conform is a no-op.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("auto-format", { clear = true }),
  callback = function(args)
    require("conform").format({ bufnr = args.buf })
  end,
})
