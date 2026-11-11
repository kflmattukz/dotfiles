-- Table of contents. Order matters: options (leader) before plugins and keymaps.
require('config.options')
require('config.keymaps')
require('config.autocmds')

require('plugins.colorscheme')
require('plugins.treesitter')
require('plugins.lsp')
require('plugins.completion')
require('plugins.picker')
