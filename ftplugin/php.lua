vim.lsp.enable('phpactor')

vim.keymap.set('n', '<leader>pc', '<cmd>PhpactorContextMenu<CR>', { buffer = true, desc = 'PHP Context Menu' })
vim.keymap.set('n', '<leader>pi', '<cmd>PhpactorImportClass<CR>', { buffer = true, desc = 'Import Class' })
