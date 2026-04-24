-- =============================================================================
-- config/keymaps.lua
-- =============================================================================
-- Global keymaps not tied to a specific plugin.
-- Plugin-specific keymaps live in their respective plugins/*.lua files.
-- LSP keymaps (gd, gr, K, <leader>rs, etc.) live in config/lsp.lua.
-- =============================================================================

local set = vim.keymap.set

-- Quit
set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- -----------------------------------------------------------------------------
-- Windows
-- -----------------------------------------------------------------------------
set("n", "<leader>wv", "<C-W>v", { desc = "Split Right" })
set("n", "<leader>ws", "<cmd>split<cr>", { desc = "Split Below" })
set("n", "<leader>wd", "<C-W>c", { desc = "Close Window" })
set("n", "<leader>wo", "<C-W>o", { desc = "Close Other Windows" })

set("n", "<leader>wm", function()
  local win = vim.api.nvim_get_current_win()
  local win_width = vim.api.nvim_win_get_width(win)
  if win_width >= vim.o.columns - 10 then
    vim.cmd("wincmd =") -- already maximised — restore equal splits
  else
    vim.cmd("wincmd |") -- maximise width
    vim.cmd("wincmd _") -- maximise height
  end
end, { desc = "Toggle Maximize Window" })

-- -----------------------------------------------------------------------------
-- Buffers
-- -----------------------------------------------------------------------------
-- Smart buffer close: prompts to save if modified, then switches to an
-- alternate/previous buffer rather than closing the window.
set("n", "<leader>bd", function()
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo.modified then
    local choice = vim.fn.confirm(("Save changes to %q?"):format(vim.fn.bufname()), "&Yes\n&No\n&Cancel")
    if choice == 0 or choice == 3 then
      return
    end -- Esc or Cancel
    if choice == 1 then
      vim.cmd.write()
    end -- Yes
  end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(win, function()
      if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
        return
      end

      local alt = vim.fn.bufnr("#")
      if alt ~= buf and vim.fn.buflisted(alt) == 1 then
        vim.api.nvim_win_set_buf(win, alt)
        return
      end

      local ok = pcall(vim.cmd, "bprevious")
      if ok and buf ~= vim.api.nvim_win_get_buf(win) then
        return
      end

      vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
    end)
  end

  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.cmd, "bdelete! " .. buf)
  end
end, { desc = "Close Buffer" })

set("n", "<leader>bb", "<cmd>b#<cr>", { desc = "Previous Buffer" })

-- -----------------------------------------------------------------------------
-- Diagnostics
-- -----------------------------------------------------------------------------
vim.keymap.set("n", "<leader>td", function()
  local vt = vim.diagnostic.config().virtual_text
  if vt then
    vim.diagnostic.config({ virtual_text = false })
  else
    vim.diagnostic.config({
      virtual_text = {
        prefix = "",
      },
    })
  end
end, { desc = "Toggle: diagnostics" })

-- -----------------------------------------------------------------------------
-- UI toggles
-- -----------------------------------------------------------------------------
set("n", "<leader>ts", ":set list!<cr>", { desc = "Toggle: listchars" })

-- -----------------------------------------------------------------------------
-- Tmux sessionizer
-- Opens the sessionizer script in a floating terminal window.
-- -----------------------------------------------------------------------------
set("n", "<C-f>", function()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  vim.fn.jobstart(os.getenv("HOME") .. "/.local/scripts/tmux-sessionizer", {
    term = true,
    on_exit = function()
      vim.api.nvim_win_close(win, true)
    end,
  })
  vim.cmd("startinsert")
end, { desc = "Tmux Sessionizer" })

-- -----------------------------------------------------------------------------
-- Floating terminal (state and logic in custom/terminal.lua)
-- -----------------------------------------------------------------------------
local terminal = require("custom.terminal")

set("n", "<leader>tt", terminal.toggle, { desc = "Toggle Terminal" })
set("t", "<C-T>", terminal.close, { desc = "Close Terminal" })

-- -----------------------------------------------------------------------------
-- Git
-- -----------------------------------------------------------------------------

-- Open the current repo's remote URL in the browser.
-- Handles both SSH (git@github.com:user/repo.git) and HTTPS remote formats.
set("n", "<leader>go", function()
  local remote = vim.fn.system("git remote get-url origin 2>/dev/null"):gsub("\n", "")
  if remote == "" then
    vim.notify("No git remote found", vim.log.levels.WARN)
    return
  end
  local url = remote:gsub("^git@([^:]+):", "https://%1/"):gsub("%.git$", "")
  vim.fn.jobstart({ "open", url }, { detach = true })
  vim.notify("Opening: " .. url, vim.log.levels.INFO)
end, { desc = "Open Git Remote in Browser" })
