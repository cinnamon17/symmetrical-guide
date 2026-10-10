-- lua_ls ya se habilita en config/lsp.lua durante la carga de la config.
-- El mapa <leader>lf usa require pcall porque lua_ls es un objetivo natural
-- para escribir la propia config.
vim.keymap.set('n', '<leader>lf', function()
	local path = vim.api.nvim_buf_get_name(0)
	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.lsp.buf.format({ async = true })
end, { buffer = true, desc = 'Format buffer' })