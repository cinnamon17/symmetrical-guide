return {
    "tpope/vim-fugitive",
    config = function()
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "Git status" })
        vim.keymap.set("n", "<leader>gp", function() vim.cmd("Git push") end, { desc = "Git push" })
        vim.keymap.set("n", "<leader>gb", function() vim.cmd("Git blame") end, { desc = "Git blame" })
        vim.keymap.set("n", "<leader>gd", vim.cmd.Gvdiffsplit, { desc = "Git diff split" })
        vim.keymap.set("n", "<leader>gl", function() vim.cmd("Git log") end, { desc = "Git log" })
        vim.keymap.set("n", "<leader>gw", function() vim.cmd("Gwrite") end, { desc = "Git stage file (Gwrite)" })
        vim.keymap.set("n", "<leader>gr", function() vim.cmd("Gread") end, { desc = "Git checkout file (Gread)" })
    end,
}
