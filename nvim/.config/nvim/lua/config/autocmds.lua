local group = vim.api.nvim_create_augroup('user', { clear = true })

vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  callback = function() vim.hl.on_yank() end,
})

-- LSP keymaps (0.12 defaults kept: grn rename, gra action, grr refs, K hover, [d ]d)
vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(ev)
    local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc }) end
    map('gd', vim.lsp.buf.definition, 'Go to definition')
    map('gr', vim.lsp.buf.references, 'References')
    map('<leader>th', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
    end, 'Toggle inlay hints')
  end,
})

-- Format on save; oxfmt wins when the project uses it
vim.api.nvim_create_autocmd('BufWritePre', {
  group = group,
  callback = function(ev)
    local clients = vim.lsp.get_clients({ bufnr = ev.buf, method = 'textDocument/formatting' })
    if #clients == 0 then return end
    local has_oxfmt = vim.iter(clients):any(function(c) return c.name == 'oxfmt' end)
    vim.lsp.buf.format({ bufnr = ev.buf, timeout_ms = 2000, name = has_oxfmt and 'oxfmt' or nil })
  end,
})
