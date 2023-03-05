function RunCommand(cmd)
  -- Save current buffer and window
  local cur_bufnr = vim.fn.bufnr("%")
  local cur_winid = vim.fn.win_getid()

  -- Kill any existing terminal
  for _, buf in ipairs(vim.fn.getbufinfo()) do
    if buf.variables.terminal_job_id then
      vim.cmd("silent! bdelete! " .. buf.bufnr)
    end
  end

  -- Open new terminal in vertical split
  vim.cmd("vsplit | terminal " .. cmd)

  -- Restore current buffer and window
  vim.fn.win_gotoid(cur_winid)
  vim.cmd("buffer " .. cur_bufnr)
end

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.go',
  callback = function()
    vim.lsp.buf.code_action({ context = { only = { 'source.organizeImports' } }, apply = true })
  end
})

vim.cmd "noremap <C-s> :update<CR>"

