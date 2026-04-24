-- lkml.vim + custom LookML tooling
-- https://github.com/thalesmello/lkml.vim
--
-- lkml.vim registers the `lookml` filetype for *.lkml files automatically.
-- Custom keymaps (symbols, go-to-definition, hover) are layered on top via
-- FileType autocmds. fzf-lua + ripgrep power all navigation — no LSP needed.
--
-- Dashboard files (*.dashboard.lookml) are YAML, not LookML, so they get
-- a distinct filetype with separate symbol/goto handling.

local lkml_keywords = "(view|measure|dimension|dimension_group|filter|parameter|explore|join|set)"

local function lkml_symbols()
  require("fzf-lua").grep({
    search  = lkml_keywords .. [[\s*:\s*\w+]],
    no_esc  = true,
    rg_opts = "--glob '*.lkml'",
  })
end

local function lkml_goto_def()
  local word = vim.fn.expand("<cword>")
  require("fzf-lua").grep({
    search  = lkml_keywords .. [[\s*:\s*]] .. word .. [[\b]],
    no_esc  = true,
    rg_opts = "--glob '*.lkml'",
  })
end

local function lkml_hover()
  local word = vim.fn.expand("<cword>")
  if word == "" then return end

  local pattern = lkml_keywords .. [[\s*:\s*]] .. word .. [[\b]]
  local cwd     = vim.fn.getcwd()
  local results = vim.fn.systemlist({ "rg", "--no-heading", "-n", "--glob", "*.lkml", "-e", pattern, cwd })

  if #results == 0 then
    vim.notify("No LookML definition found for: " .. word, vim.log.levels.INFO)
    return
  end

  local filepath, lnum_str = results[1]:match("^(.-):(%d+):")
  if not filepath then return end

  local lnum       = tonumber(lnum_str)
  local file_lines = vim.fn.readfile(filepath)
  if not file_lines or #file_lines == 0 then return end

  -- Extract the full block by tracking brace depth
  local content = {}
  local depth   = 0
  for i = lnum, math.min(lnum + 40, #file_lines) do
    local line = file_lines[i]
    table.insert(content, line)
    for ch in line:gmatch(".") do
      if ch == "{" then depth = depth + 1
      elseif ch == "}" then depth = depth - 1
      end
    end
    if depth <= 0 and i > lnum then break end
  end

  local short_path = filepath:gsub(vim.pesc(cwd) .. "/", "")
  table.insert(content, 1, "")
  table.insert(content, 1, short_path .. ":" .. lnum_str)

  vim.lsp.util.open_floating_preview(content, "lookml", {
    border    = "rounded",
    max_width  = 100,
    max_height = 30,
  })
end

local function dashboard_symbols()
  require("fzf-lua").grep({
    search  = [[(^\s*-\s+dashboard:|^\s+name:)\s+\S+]],
    no_esc  = true,
    rg_opts = "--glob '*.dashboard.lookml'",
  })
end

local function dashboard_goto_def()
  local word = vim.fn.expand("<cword>")
  require("fzf-lua").grep({
    search  = lkml_keywords .. [[\s*:\s*]] .. word .. [[\b]],
    no_esc  = true,
    rg_opts = "--glob '*.lkml'",
  })
end

-- Detect *.dashboard.lookml as a distinct filetype (always-on — no plugin needed).
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group   = vim.api.nvim_create_augroup("lookml-dashboard-ft", { clear = true }),
  pattern = "*.dashboard.lookml",
  callback = function(ev)
    vim.bo[ev.buf].filetype = "lookml_dashboard"
  end,
})

-- Load lkml.vim on the first lookml buffer, then attach keymaps.
vim.api.nvim_create_autocmd("FileType", {
  group   = vim.api.nvim_create_augroup("lkml-load", { clear = true }),
  pattern = "lookml",
  once    = true,
  callback = function()
    vim.cmd.packadd("lkml.vim")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group   = vim.api.nvim_create_augroup("lookml-keymaps", { clear = true }),
  pattern = "lookml",
  callback = function(ev)
    local buf = ev.buf
    vim.keymap.set("n", "<leader>ss", lkml_symbols,   { buffer = buf, desc = "LookML: symbols" })
    vim.keymap.set("n", "gd",         lkml_goto_def,  { buffer = buf, desc = "LookML: go to definition" })
    vim.keymap.set("n", "K",          lkml_hover,     { buffer = buf, desc = "LookML: hover definition" })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group   = vim.api.nvim_create_augroup("lookml-dashboard-keymaps", { clear = true }),
  pattern = "lookml_dashboard",
  callback = function(ev)
    local buf = ev.buf
    vim.treesitter.start(buf, "yaml")
    vim.keymap.set("n", "<leader>ss", dashboard_symbols,  { buffer = buf, desc = "Dashboard: symbols" })
    vim.keymap.set("n", "gd",         dashboard_goto_def, { buffer = buf, desc = "Dashboard: go to definition" })
    vim.keymap.set("n", "K",          lkml_hover,         { buffer = buf, desc = "LookML: hover definition" })
  end,
})
