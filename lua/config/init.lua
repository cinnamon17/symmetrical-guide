local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
	vim.api.nvim_echo({
	    { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
	    { out, "WarningMsg" },
	    { "\nPress any key to exit..." },
	}, true, {})
	vim.fn.getchar()
	os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)
vim.opt.number = true
vim.opt.relativenumber = true
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.o.clipboard = "unnamedplus";
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.cmdheight = 2
vim.opt.completeopt = { "menu", "menuone", "noselect" }

vim.diagnostic.config({
    virtual_text = true,      -- Show inline virtual text
    signs = true,            -- Show signs in the sign column
    underline = true,        -- Underline errors
    update_in_insert = false,-- Don't update while typing
    severity_sort = true,    -- Sort diagnostics by severity
    float = true
})

vim.keymap.set('n', '[d', vim.diagnostic.get_prev, { desc = "Go to previous diagnostic" })
vim.keymap.set('n', ']d', vim.diagnostic.get_next, { desc = "Go to next diagnostic" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror message" })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- Función para bloquear la tecla si no hay un número previo
local function jump_only(key, message)
    if vim.v.count > 0 then
	return key
    else
	vim.notify(message, vim.log.levels.INFO)
	return "<Ignore>"
    end
end

-- Mapeos inteligentes: permiten 10j pero bloquean j solo.
vim.keymap.set('n', 'h', function() return jump_only('h', "Usa b, B, F, T") end, { expr = true, silent = true })
vim.keymap.set('n', 'j', function() return jump_only('j', "Usa Ctrl+d, }, /, *") end, { expr = true, silent = true })
vim.keymap.set('n', 'k', function() return jump_only('k', "Usa Ctrl+u, {, ?, #") end, { expr = true, silent = true })
vim.keymap.set('n', 'l', function() return jump_only('l', "Usa w, W, f, t") end, { expr = true, silent = true })

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
	local clients = vim.lsp.get_clients()
	for _, client in ipairs(clients) do
	    client.stop(500)
	end
    end,
    desc = "Matar procesos LSP huérfanos al salir de Neovim",
})

require("lazy").setup({
    spec = {
	{ import = "plugins" },
    },
    install = { colorscheme = { "catppuccin" } },
    checker = { enabled = false},
})

-- Debe ir DESPUÉS de lazy.setup(): los servidores ya están declarados por los
-- specs, así que aquí solo se resuelven configs y se habilitan. Necesita estar
-- en config-load (y no en un ftplugin) para que el buffer de arranque también
-- levante su LSP.
require("config.lsp").setup()
