vim.pack.add({ 'https://github.com/nvim-mini/mini.pick' }, { confirm = false })

local pick = require('mini.pick')
pick.setup()
vim.ui.select = pick.ui_select

local map = vim.keymap.set
map('n', '<leader>f', pick.builtin.files, { desc = 'Find files' })
map('n', '<leader>/', pick.builtin.grep_live, { desc = 'Live grep' })
map('n', '<leader>b', pick.builtin.buffers, { desc = 'Buffers' })
map('n', '<leader>h', pick.builtin.help, { desc = 'Help' })
map('n', '<leader>r', pick.builtin.resume, { desc = 'Resume last picker' })
