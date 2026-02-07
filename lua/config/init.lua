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

-- Deshabilitar hjkl en modo normal
vim.keymap.set('n', 'h', '<Nop>', { noremap = true })
vim.keymap.set('n', 'j', '<Nop>', { noremap = true })
vim.keymap.set('n', 'k', '<Nop>', { noremap = true })
vim.keymap.set('n', 'l', '<Nop>', { noremap = true })

-- Opcional: Mostrar mensaje recordatorio
vim.keymap.set('n', 'h', function()
  print("❌ Usa b, B, F, T en su lugar")
end, { noremap = true })

vim.keymap.set('n', 'j', function()
  print("❌ Usa Ctrl+d, }, /, * en su lugar")
end, { noremap = true })

vim.keymap.set('n', 'k', function()
  print("❌ Usa Ctrl+u, {, ?, # en su lugar")
end, { noremap = true })

vim.keymap.set('n', 'l', function()
  print("❌ Usa w, W, f, t en su lugar")
end, { noremap = true })
require("lazy").setup({
    spec = {
	{ import = "plugins" },
    },
    install = { colorscheme = { "catppuccin" } },
    checker = { enabled = false},
})
