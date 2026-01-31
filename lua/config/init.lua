-- Bootstrap lazy.nvim
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

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.python3_host_prog = vim.fn.expand("~/.local/share/nvim/python_env/bin/python3")
vim.g.loaded_julia_provider = 0

if jit.os == "Windows" then
    vim.g.python3_host_prog = vim.fn.expand('~/.pyenv/pyenv-win/versions/3.11.6/python')
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.o.number = true
vim.o.clipboard = "unnamedplus";
vim.opt.shiftwidth = 4
vim.opt.cmdheight = 2

-- Configure diagnostics display
vim.diagnostic.config({
  virtual_text = true,      -- Show inline virtual text
  signs = true,            -- Show signs in the sign column
  underline = true,        -- Underline errors
  update_in_insert = false,-- Don't update while typing
  severity_sort = true,    -- Sort diagnostics by severity
  float = true
  })

-- Navigate diagnostics
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror message" })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- Setup lazy.nvim
require("lazy").setup({
    spec = {
	-- import your plugins
	{ import = "plugins" },
    },
    -- Configure any other settings here. See the documentation for more details.
    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { "catppuccin" } },
    -- automatically check for plugin updates
    checker = { enabled = false},
})
