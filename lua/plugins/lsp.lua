return {
    -- Java
    {
	"mfussenegger/nvim-jdtls",
	ft = "java",
	dependencies = {
	    "hrsh7th/nvim-cmp",
	    "hrsh7th/cmp-nvim-lsp",
	    "hrsh7th/cmp-path",
	    "hrsh7th/cmp-buffer",
	    "mfussenegger/nvim-dap"
	},
	config = function()
	    vim.api.nvim_create_autocmd('VimLeave', {
		callback = function()
		    if vim.fn.has('unix') == 1 then
			os.execute("killall -9 java 2>/dev/null")
		    end
		end,
	    })
	end
    },

}
