-- =============================================================================
-- custom/terminal.lua
-- =============================================================================
-- Floating terminal toggle.
-- Usage: require("custom.terminal").toggle()
-- =============================================================================

local M = {}

local term_buf = nil
local term_win = nil

function M.toggle()
  -- If the window is open, close it (buffer is preserved for next open)
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, false)
    term_win = nil
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  -- Reuse existing buffer if still valid, otherwise create a new one
  if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then
    term_buf = vim.api.nvim_create_buf(false, true)
  end

  term_win = vim.api.nvim_open_win(term_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  -- Start the terminal process if this buffer hasn't been used as one yet
  if vim.bo[term_buf].buftype ~= "terminal" then
    vim.cmd("terminal")
    term_buf = vim.api.nvim_get_current_buf()
  end

  vim.cmd("startinsert")
end

function M.close()
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, false)
    term_win = nil
  end
end

return M
