vim.pack.add({ 'https://github.com/folke/tokyonight.nvim' }, { confirm = false })

-- Same palette as Ghostty's tokyonight / tokyonight-day; transparent so Ghostty's opacity shows
require('tokyonight').setup({
  style = 'night',
  light_style = 'day',
  transparent = true,
  styles = { sidebars = 'transparent', floats = 'transparent' },
})
vim.cmd.colorscheme('tokyonight')
