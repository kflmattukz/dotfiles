-- Merged on top of nvim-lspconfig's lua_ls config
return {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      diagnostics = { globals = { 'vim' } },
    },
  },
}
