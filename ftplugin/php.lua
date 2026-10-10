-- phpactor ya se habilita en config/lsp.lua durante la carga de la config.

vim.keymap.set('n', '<leader>pc', '<cmd>PhpactorContextMenu<CR>', { buffer = true, desc = 'PHP Context Menu' })
vim.keymap.set('n', '<leader>pi', '<cmd>PhpactorImportClass<CR>', { buffer = true, desc = 'Import Class' })
vim.keymap.set('n', '<leader>pn', '<cmd>PhpactorGotoClass<CR>', { buffer = true, desc = 'Goto Class' })
vim.keymap.set('n', '<leader>pr', '<cmd>PhpactorReferences<CR>', { buffer = true, desc = 'PHP References' })