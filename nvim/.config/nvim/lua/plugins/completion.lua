vim.pack.add({ { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('1.*') } }, { confirm = false })

require('blink.cmp').setup({
  keymap = { preset = 'default' }, -- C-y accept, C-n/C-p move, C-space open, C-e close
  completion = { documentation = { auto_show = true } },
  signature = { enabled = true },
})

-- Tell every server what blink supports
vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
