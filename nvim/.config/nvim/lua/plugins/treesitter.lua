-- Recompile parsers after the plugin updates
vim.api.nvim_create_autocmd('PackChanged', {
  callback = function(ev)
    if ev.data.spec.name == 'nvim-treesitter' and ev.data.kind ~= 'delete' then
      if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
      vim.cmd('TSUpdate')
    end
  end,
})

vim.pack.add({ { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' } }, { confirm = false })

local parsers = {
  'bash', 'css', 'elixir', 'gleam', 'go', 'gomod', 'heex', 'html', 'java', 'javascript',
  'json', 'lua', 'markdown', 'markdown_inline', 'rust', 'toml', 'tsx', 'typescript', 'yaml',
}
require('nvim-treesitter').install(parsers)

vim.api.nvim_create_autocmd('FileType', {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
