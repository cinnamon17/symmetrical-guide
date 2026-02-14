local lspconfig = require("lspconfig")
local root_patterns = { ".git", "angular.json", "tsconfig.ts"}
local root_dir = vim.fs.dirname(vim.fs.find(root_patterns, { upward = true })[1])
local ts_lib = root_dir .. "/node_modules/typescript/lib"
local ng_lib = root_dir .. "/node_modules/@angular/language-service"

return {
    cmd = {
	"ngserver",
	"--stdio",
	"--tsProbeLocations", ts_lib,
	"--ngProbeLocations", ng_lib
    },
    root_dir = lspconfig.util.root_pattern("angular.json", "project.json", "tsconfig.json"),
},
