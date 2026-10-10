return {
    {
	"mason-org/mason-lspconfig.nvim",
	-- OJO: no declarar `config = ...` aquí. Si se define, lazy.nvim pasa `opts`
	-- como segundo argumento a esa función y NO llama al `setup()` automático,
	-- así que `ensure_installed` y `automatic_enable` nunca se ejecutaban.
	opts = {
	    ensure_installed = { "lua_ls", "rust_analyzer", "jdtls", "phpactor", "angularls", "ts_ls" },
	    -- Los servidores se habilitan explícitamente en lua/config/lsp.lua, en
	    -- config-load. Con `automatic_enable` activated, mason-lspconfig también
	    -- llamaba a vim.lsp.enable("jdtls") y se arrancaba un segundo cliente
	    -- jdtls con el root del repo, duplicando el indexado.
	    automatic_enable = false,
	},
	dependencies = {
	    { "mason-org/mason.nvim", opts = {} },
	    "neovim/nvim-lspconfig",
	},
    }
}