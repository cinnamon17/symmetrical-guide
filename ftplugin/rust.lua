vim.lsp.enable('rust_analyzer')

vim.keymap.set('n', '<leader>rr', '<cmd>Cargo run<CR>', { buffer = true })
