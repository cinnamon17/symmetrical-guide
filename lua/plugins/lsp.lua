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
	    -- 1. FUNCIÓN DE AUTO-DETECCIÓN (Para portabilidad total)
	    local function find_java_path(version)
		local jvm_path = "/usr/lib/jvm/"
		local handle = vim.loop.fs_scandir(jvm_path)
		if not handle then return nil end

		while true do
		    local name, type = vim.loop.fs_scandir_next(handle)
		    if not name then break end

		    -- FILTROS CRUCIALES: 
		    -- 1. Que contenga la versión (8, 11, 21)
		    -- 2. Que NO empiece por punto (ignora .jinfo y archivos ocultos)
		    -- 3. Que sea un directorio o un enlace simbólico
		    if name:find("temurin%-" .. version) 
			and not name:match("^%.") 
			and (type == "directory" or type == "link") then
			return jvm_path .. name
		    end
		end
		return nil
	    end

	    -- Obtenemos las rutas dinámicamente
	    local path_21 = find_java_path("21")
	    local path_11 = find_java_path("11")
	    local path_8  = find_java_path("8")

	    -- Validación de seguridad: si no encuentra el 21, avisamos
	    if not path_21 then
		vim.notify("JDTLS: No se encontró el JDK de Java 21 en /usr/lib/jvm/", vim.log.levels.ERROR)
		return
	    end

	    vim.keymap.set('n', '<A-o>', function()
		require('jdtls').organize_imports()
	    end, { desc = 'Organize Java imports' })

	    vim.keymap.set('n', 'crv', function()
		require('jdtls').extract_variable()
	    end, { desc = 'Extract variable' })

	    vim.keymap.set('v', 'crv', function()
		require('jdtls').extract_variable({visual = true})
	    end, { desc = 'Extract variable (visual)' })

	    vim.keymap.set('n', 'crc', function()
		require('jdtls').extract_constant()
	    end, { desc = 'Extract constant' })

	    vim.keymap.set('v', 'crc', function()
		require('jdtls').extract_constant({visual = true})
	    end, { desc = 'Extract constant (visual)' })

	    vim.keymap.set('v', 'crm', function()
		require('jdtls').extract_method({visual = true})
	    end, { desc = 'Extract method' })

	    local root_dir = vim.fs.dirname(vim.fs.find({'gradlew', '.git', 'mvnw', 'build.gradle', 'pom.xml', 'settings.gradle'}, { upward = true })[1])
	    local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
	    local workspace_dir = vim.fn.stdpath('data') .. '/workspace/' .. project_name
	    local is_libgdx = vim.fn.findfile('core/build.gradle', root_dir..';') ~= ''

	    local jdtls_bin = vim.env.MASON .. '/bin/jdtls'

	    local config = {
		-- AQUÍ ESTÁ EL TRUCO: Forzamos al script de Mason a usar Java 21 para el SERVIDOR
		-- Esto evita tener que editar el archivo .py de Mason
		cmd = {
		    jdtls_bin,
		    "--java-executable", path_21 .. "/bin/java"
		},
		root_dir = root_dir,
		settings = {
		    java = {
			configuration = {
			    -- JDTLS usará estos para COMPILAR según el proyecto
			    runtimes = {
				{ name = "JavaSE-1.8", path = path_8 },
				{ name = "JavaSE-11",  path = path_11 },
				{ name = "JavaSE-21",  path = path_21, default = true },
			    },
			    updateBuildConfiguration = "automatic",
			    annotationProcessing = {
				enabled = true,
				fileOutput = {
				    enabled = true,
				    directory = "${project_dir}/build/generated/sources/annotationProcessor/java/main"
				}
			    }
			},
			completion = {
			    favoriteStaticMembers = {
				"org.springframework.*",
				"org.junit.*",
				"org.mockito.Mockito.*",
				is_libgdx and "com.badlogic.gdx.*" or nil,
			    },
			    importOrder = is_libgdx and { "com.badlogic", "java", "javax", "" } or nil
			}
		    }
		},
		init_options = {
		    extendedClientCapabilities = {
			progressReportProvider = true,
			classFileContentsSupport = true,
			advancedOrganizeImportsSupport = is_libgdx or nil
		    },
		    bundles = {
			vim.fn.glob("/usr/local/src/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-0.53.2.jar", true)
		    },
		    workspace = workspace_dir,
		    jvm_args = is_libgdx and {
			"-Xms1g", "-Xmx4g",
			"--add-opens", "java.base/java.util=ALL-UNNAMED"
		    } or nil
		},
		capabilities = require('cmp_nvim_lsp').default_capabilities()
	    }

		require('jdtls').start_or_attach(config)
	    -- Your existing nvim-cmp setup (unchanged)
	    vim.api.nvim_create_autocmd('FileType', {
		pattern = 'java',
		callback = function()
		    local cmp = require('cmp')
		    cmp.setup.buffer({
			completion = {
			    completeopt = 'menu,menuone,noinsert,noselect'
			},
			sources = cmp.config.sources({
			    { name = 'nvim_lsp' },
			    { name = 'buffer' },
			    { name = 'path' }
			})
		    })
		end
	    })

	    -- Proper shutdown on exit
	    vim.api.nvim_create_autocmd('VimLeave', {
		callback = function()
		    if vim.fn.has('unix') == 1 then
			os.execute("killall -9 java 2>/dev/null")
		    end
		end,
	    })
	end
    },

    -- PHP
    {
	'phpactor/phpactor',
	ft = 'php',
	build = 'composer install',  -- Added build step
	dependencies = {  -- Added completion dependencies
	    'hrsh7th/nvim-cmp',
	    'hrsh7th/cmp-nvim-lsp',
	    'neovim/nvim-lspconfig',
	},
	config = function()
	    -- Your existing PHP Actor configuration
	    require("lspconfig").phpactor.setup {
		cmd = { "phpactor", "language-server" },
		filetypes = { "php" },
		root_dir = function(fname)
		    local root_files = {
			'composer.json',
			'.git',
			'.phpactor.json',
			'phpactor.yml',
			'symfony.lock'
		    }
		    return require('lspconfig.util').root_pattern(unpack(root_files))(fname) or
		    vim.fn.expand('%:p:h')
		end,
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
	    -- Optional: PHP-specific keymaps
	    vim.api.nvim_create_autocmd('FileType', {
		pattern = 'php',
		callback = function()
		    vim.keymap.set('n', '<leader>pc', '<cmd>PhpactorContextMenu<CR>', { buffer = true, desc = 'PHP Context Menu' })
		    vim.keymap.set('n', '<leader>pi', '<cmd>PhpactorImportClass<CR>', { buffer = true, desc = 'Import Class' })
		end
	    })
	end
    },
}
