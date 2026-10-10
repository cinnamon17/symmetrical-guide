return {
    {
	"hrsh7th/nvim-cmp",
	-- `lazy = false`: cmp debe estar en el runtimepath durante la carga de la
	-- config, porque lua/config/lsp.lua pide `cmp_nvim_lsp.default_capabilities()`
	-- al construir las capacidades de cada servidor. Con carga diferida el
	-- require fallaba y los servidores se levantaban sin snippet support.
	lazy = false,
	dependencies = {
	    "hrsh7th/cmp-nvim-lsp",
	    "hrsh7th/cmp-path",
	    "hrsh7th/cmp-buffer",
	},
	-- `config` en vez de `opts`: lazy resuelve los valores de `opts` al importar
	-- el spec, cuando el módulo `cmp` todavía no está en el runtimepath.
	-- Además `cmp.mapping` no es un submódulo: es un campo que `require("cmp")`
	-- define en su init.lua, así que hay que acceder vía el módulo principal.
	config = function()
	    local cmp = require("cmp")
	    local mapping = cmp.mapping
	    cmp.setup({
		completion = {
		    completeopt = "menu,menuone,noinsert,noselect",
		},
		mapping = {
		    ["<C-n>"] = mapping.select_next_item(),
		    ["<C-p>"] = mapping.select_prev_item(),
		    ["<C-y>"] = mapping.confirm({ select = true }),
		    ["<C-Space>"] = mapping.complete(),
		},
		sources = {
		    { name = "nvim_lsp" },
		    { name = "buffer" },
		    { name = "path" },
		},
	    })
	end,
    }
}