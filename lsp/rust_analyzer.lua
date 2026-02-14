local mason_packages = vim.fn.stdpath("data") .. "/mason/packages"
local rust_bin = mason_packages .. "/rust-analyzer/rust-analyzer-x86_64-unknown-linux-gnu"

local capabilities = {}
local status_ok, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
if status_ok then
    capabilities = cmp_nvim_lsp.default_capabilities()
end

return {
    cmd = { rust_bin },
    capabilities = capabilities,
    filetypes = { "rust" },
    root_markers = { "Cargo.toml", ".git" },
    settings = {
        ["rust-analyzer"] = { -- Asegúrate de usar el nombre correcto del setting
            imports = {
                granularity = { group = "module" },
                prefix = "self",
            },
            cargo = {
                buildScripts = { enable = true },
            },
            procMacro = { enable = true },
        }
    }
}
