return {

    "renerocksai/telekasten.nvim",

    dependencies = {
	"nvim-telescope/telescope.nvim"
    },
    config = function ()
	local home = vim.fn.expand("~/.local/notas")
	require('telekasten').setup({
	    home = home,
	    templates = home .. "/templates"
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
	    pattern = home .. "/*.md",
	    callback = function()
		local source = home .. "/" -- Importante el slash para copiar contenido
		local target = "cinnamon17@server:/home/cinnamon17/notas/"

		vim.fn.jobstart({ "rsync", "-avz", "--delete", source, target }, {
		    on_exit = function(_, exit_code)
			if exit_code == 0 then
			    vim.notify("Notas sincronizadas", vim.log.levels.INFO, { title = "Telekasten" })
			else
			    vim.notify("Error en rsync: " .. exit_code, vim.log.levels.ERROR)
			end
		    end,
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
