 local root_dir = function(fname)
    local root_files = {
        'composer.json',
        '.git',
        '.phpactor.json',
        'phpactor.yml',
        'symfony.lock'
    }
    
    local root = vim.fs.dirname(vim.fs.find(root_files, { 
        upward = true, 
        path = fname 
    })[1])
    
    return root or vim.fs.dirname(fname)
end

return {
    cmd = { "phpactor", "language-server" },
    filetypes = { "php" },
    root_dir = root_dir,
    init_options = {
	["symfony.enabled"] = true,
	["symfony.xml_path"] = "var/cache/dev/App_KernelDevDebugContainer.xml",
	["language_server_phpstan.enabled"] = false,
	["language_server_psalm.enabled"] = false,
    },
    settings = {
	phpactor = {
	    symfony = {
		enabled = true,
	    },
	    completion = {
		enabled = true,
		insertUseDeclaration = true,
	    }
	}
    }
}
