vim.pack.add({
  'https://github.com/neovim/nvim-lspconfig',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/mason-org/mason-lspconfig.nvim',
}, { confirm = false })

require('mason').setup()
-- Installed by Mason, enabled automatically
require('mason-lspconfig').setup({
  ensure_installed = { 'vtsls', 'html', 'cssls', 'jsonls', 'lua_ls', 'jdtls', 'expert' },
  automatic_enable = true,
})

-- Already on the system (rustup, go install, gleam, pnpm)
vim.lsp.enable({ 'gopls', 'rust_analyzer', 'gleam', 'oxlint', 'oxfmt' })
