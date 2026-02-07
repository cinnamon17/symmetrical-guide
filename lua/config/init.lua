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
vim.g.loaded_julia_provider = 0
vim.opt.number = true
vim.opt.relativenumber = true
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.o.number = true
vim.o.clipboard = "unnamedplus";
vim.opt.shiftwidth = 4
vim.opt.cmdheight = 2
vim.g.python3_host_prog = vim.fn.expand("~/.venv/bin/python")

vim.diagnostic.config({
    virtual_text = true,      -- Show inline virtual text
    signs = true,            -- Show signs in the sign column
    underline = true,        -- Underline errors
    update_in_insert = false,-- Don't update while typing
    severity_sort = true,    -- Sort diagnostics by severity
    float = true
})

vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror message" })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- Función para bloquear la tecla si no hay un número previo
local function jump_only(key, message)
  if vim.v.count > 0 then
    return key
  else
    print(message)
    return "<Ignore>"
  end
end

-- Mapeos inteligentes: permiten 10j pero bloquean j solo.
vim.keymap.set('n', 'h', function() return jump_only('h', "Usa b, B, F, T") end, { expr = true, silent = true })
vim.keymap.set('n', 'j', function() return jump_only('j', "Usa Ctrl+d, }, /, *") end, { expr = true, silent = true })
vim.keymap.set('n', 'k', function() return jump_only('k', "Usa Ctrl+u, {, ?, #") end, { expr = true, silent = true })
vim.keymap.set('n', 'l', function() return jump_only('l', "❌ Usa w, W, f, t") end, { expr = true, silent = true })

require("lazy").setup({
    spec = {
	{ import = "plugins" },
    },
    install = { colorscheme = { "catppuccin" } },
    checker = { enabled = false},
})
