-- rust_analyzer ya se habilita en config/lsp.lua durante la carga de la config,
-- así que el buffer de arranque también lo levanta.

vim.keymap.set('n', '<leader>rr', '<cmd>Cargo run<CR>', { buffer = true, desc = 'Cargo run' })
vim.keymap.set('n', '<leader>rb', '<cmd>Cargo build<CR>', { buffer = true, desc = 'Cargo build' })
vim.keymap.set('n', '<leader>rt', '<cmd>Cargo test<CR>', { buffer = true, desc = 'Cargo test' })
vim.keymap.set('n', '<leader>rc', '<cmd>Cargo check<CR>', { buffer = true, desc = 'Cargo check' })

vim.keymap.set('n', '<leader>rm', function()
	vim.cmd.Rename()
end, { buffer = true, desc = 'Rename symbol' })