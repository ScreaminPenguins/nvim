vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highligh on text yank",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd({ "FileType", "BufReadPost", "BufNewFile" }, {
  callback = function()
    vim.defer_fn(function()
      if require("nvim-treesitter.parsers").has_parser() then
        vim.opt.foldmethod = "expr"
        vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
      else
        vim.opt.foldmethod = "syntax"
      end
    end, 50)
  end
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  group = vim.api.nvim_create_augroup("json_conceal", { clear = true }),
  pattern = { "json" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end
})
