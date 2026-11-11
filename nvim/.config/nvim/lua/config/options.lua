vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local o = vim.opt
o.number = true
o.relativenumber = true
o.signcolumn = 'yes'
o.cursorline = true
o.scrolloff = 8
o.wrap = false

o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true

o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true

o.clipboard = 'unnamedplus'
o.undofile = true
o.swapfile = false
o.updatetime = 250
o.termguicolors = true
o.winborder = 'rounded'
o.completeopt = { 'menu', 'menuone', 'noselect' }

vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { source = 'if_many' },
})
