return {
    {
	"nvim-telescope/telescope.nvim",
	dependencies = {
	    "nvim-lua/plenary.nvim",
	    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }
	},
	config = function()
	    require("telescope").setup({
		defaults = {
		    mappings = {
			i = {
			    ["<C-j>"] = require("telescope.actions").move_selection_next,
			    ["<C-k>"] = require("telescope.actions").move_selection_previous,
			}
		    },
		    layout_strategy = "horizontal",
		    layout_config = {
			width = 0.95,
		    }
		}
	    })

	    local function search_config()
		require("telescope.builtin").find_files({
		    prompt_title = "< Configuración de Neovim >",
		    cwd = vim.fn.stdpath("config"),
		    follow = true,
		})
	    end

	    local builtin = require('telescope.builtin')
	    vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
            vim.keymap.set('n', '<leader>fF', builtin.git_files, { desc = 'Telescope git files' })
	    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
	    vim.keymap.set('n', '<leader>fs', builtin.grep_string , { desc = 'Telescope find string' })
	    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
	    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
	    vim.keymap.set('n', '<leader>fd', builtin.lsp_definitions, { desc = 'Goto Definition (Telescope)' })
	    vim.keymap.set('n', '<leader>fr', builtin.lsp_references, { desc = 'Telescope LSP references' })
	    vim.keymap.set('n', '<leader>fx', builtin.diagnostics, { desc = 'Telescope diagnostics' })
	    vim.keymap.set("n", "<leader>fc", search_config, { desc = "[F]ind [C]onfig files" })
	    vim.keymap.set("n", "<leader>fi", builtin.lsp_implementations, { desc = "Telescope LSP implementations" })
	    vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "Telescope list keymaps" })
	    vim.keymap.set("n", "<leader>fq", builtin.quickfix, { desc = "Telescope quickfix" })
	    vim.keymap.set("n", "<leader>fj", builtin.jumplist, { desc = "Telescope jumplist" })
            vim.keymap.set('n', '<leader>fS', builtin.lsp_document_symbols, { desc = 'Telescope document symbols' })
	end
    }
}
