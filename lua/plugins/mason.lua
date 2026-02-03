return {
    {
	"mason-org/mason-lspconfig.nvim",
	opts = {
	    ensure_installed = { "lua_ls", "rust_analyzer", "jdtls", "phpactor", "angularls", "ts_ls" },
	},
	dependencies = {
	    { "mason-org/mason.nvim", opts = {} },
	    "neovim/nvim-lspconfig",
	},
	config = function()
	    local lspconfig = require("lspconfig")
	    lspconfig.jdtls.setup = function() end
	    lspconfig.lua_ls.setup({})
	    lspconfig.rust_analyzer.setup({})
	    lspconfig.phpactor.setup({})
	    lspconfig.angularls.setup({})
	    lspconfig.ts_ls.setup({})
	end
    }
}
