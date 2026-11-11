local map = vim.keymap.set

map('n', '<Esc>', '<cmd>nohlsearch<cr>')
map('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
map('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
map('n', '<leader>e', '<cmd>Explore<cr>', { desc = 'File explorer (netrw)' })

-- Move between splits
map('n', '<C-h>', '<C-w>h')
map('n', '<C-j>', '<C-w>j')
map('n', '<C-k>', '<C-w>k')
map('n', '<C-l>', '<C-w>l')

-- Keep selection when indenting
map('v', '<', '<gv')
map('v', '>', '>gv')

map('n', '<leader>d', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
map('n', '<leader>pu', function() vim.pack.update() end, { desc = 'Update plugins' })
