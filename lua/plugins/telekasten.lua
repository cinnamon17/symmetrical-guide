return {

    "renerocksai/telekasten.nvim",

    dependencies = {
	"nvim-telescope/telescope.nvim"
    },
    config = function ()
	require('telekasten').setup({
	    home = vim.fn.expand("~/.local/notas"),
	    templates = vim.fn.expand("~/.local/notas/templates")
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
	    pattern = vim.fn.expand("~/.local/notas/*.md"),
	    callback = function()
		local source = vim.fn.expand("~/.local/notas/")
		local target = "cinnamon17@server:/home/cinnamon17/notas/"

		vim.fn.jobstart({
		    "rsync", "-avz", "--delete", source, target
		}, {
		    on_exit = function(job_id, exit_code, event)
			if exit_code ~= 0 then
			    print("Error en la sincronización con rsync")
			end
		    end
		})
	    end,
	})

	vim.keymap.set("n", "<leader>z", "<cmd>Telekasten panel<CR>")
	vim.keymap.set("n", "<leader>zf", "<cmd>Telekasten find_notes<CR>")
	vim.keymap.set("n", "<leader>zg", "<cmd>Telekasten search_notes<CR>")
	vim.keymap.set("n", "<leader>zd", "<cmd>Telekasten goto_today<CR>")
	vim.keymap.set("n", "<leader>zz", "<cmd>Telekasten follow_link<CR>")
	vim.keymap.set("n", "<leader>zn", "<cmd>Telekasten new_note<CR>")
	vim.keymap.set("n", "<leader>zt", "<cmd>Telekasten new_templated_note<CR>")
	vim.keymap.set("n", "<leader>zb", "<cmd>Telekasten show_backlinks<CR>")
	vim.keymap.set("n", "<leader>zI", "<cmd>Telekasten insert_img_link<CR>")

	vim.keymap.set("i", "[[", "<cmd>Telekasten insert_link<CR>")

    end
}
