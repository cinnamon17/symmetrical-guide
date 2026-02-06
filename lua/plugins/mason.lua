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
	    vim.lsp.config('*' ,{})
	end
    }
}
