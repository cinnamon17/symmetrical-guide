-- Los servidores (angularls / ts_ls) ya se habilitan globalmente en
-- config/lsp.lua durante la carga de la config; aquí solo van los keymaps.

vim.keymap.set('n', '<leader>fi', vim.lsp.buf.format, { buffer = true, desc = 'Format file' })
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = true, desc = 'Code action' })
vim.keymap.set('v', '<leader>ca', function()
	vim.lsp.buf.code_action({
		range = true,
		context = { sources = { 'nui', 'nvim_lsp', 'null-ls', 'toggletype' } },
	})
end, { buffer = true, desc = 'Code action (visual)' })