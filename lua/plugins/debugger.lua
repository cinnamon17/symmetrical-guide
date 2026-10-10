return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require('dap')
            local dapui = require('dapui')

            dapui.setup()

            dap.adapters.php = {
                type = 'executable',
                command = 'node',
                args = { vim.fn.stdpath("data") .. "/mason/packages/php-debug-adapter/extension/out/phpDebug.js" }
	    }
	    dap.adapters.lldb = {
		type = "executable",
		command = vim.fn.stdpath("data") .. "/mason/packages/codelldb/codelldb",
		name = "lldb",
	    }

	    dap.configurations.php = {
		{
		    type = 'php',
		    request = 'launch',
		    name = 'Listen for Xdebug',
		}
	    }

	    -- Antes el binario se adivinaba con root_dir:match("([^/]+)$"), lo que
	    -- fallaba con workspaces de Cargo (el root no es el nombre del crate) y
	    -- exigía un `cargo build` manual previo. Ahora se usa el campo `cargo`
	    -- de dap (nativo de nvim-dap) y un preLaunchTask que compila.
	    dap.configurations.rust = {
		{
		    name = "Rust: Debug (cargo run)",
		    type = "lldb",
		    request = "launch",
		    cargo = {
			metadata = { kind = "debug" },
			build_args = {},
			target = function()
			    local root = vim.fs.root(0, { "Cargo.toml", ".git" })
			    if not root then
				return nil
			    end
			    -- Nombre del crate desde el manifiesto, no desde el dirname.
			    local manifest = root .. "/Cargo.toml"
			    local lines = vim.fn.readfile(manifest)
			    for _, line in ipairs(lines) do
				local name = line:match('^%s*name%s*=%s*"([^"]+)"')
				if name then
				    return name
				end
			    end
			    return nil
			end,
		    },
		    cwd = "${workspaceFolder}",
		    stopOnEntry = false,
		    preLaunchTask = {
			name = "cargo build",
			program = "cargo",
			args = { "build" },
			cwd = "${workspaceFolder}",
		    },
		},
		{
		    name = "Rust: Debug last test",
		    type = "lldb",
		    request = "launch",
		    program = "${workspaceFolder}/target/debug/deps/",
		    cwd = "${workspaceFolder}",
		    stopOnEntry = false,
		},
	    }

	    --- ¿Es un proyecto Spring Boot? Se busca el plugin de Spring Boot, que es
	    --- lo que define las tareas `bootRun` (Gradle) / `spring-boot:run` (Maven).
	    local function spring_boot_task(root)
		if not root then
		    return nil
		end
		local has_spring = vim.fn.glob(root .. "/**/spring-boot-starter-*.jar", false, true)
		local pom = vim.fn.filereadable(root .. "/pom.xml") == 1
		local gradle = vim.fn.filereadable(root .. "/build.gradle") == 1
		    or vim.fn.filereadable(root .. "/build.gradle.kts") == 1
		if #has_spring == 0 and not pom and not gradle then
		    return nil
		end
		-- Wrapper primero: es la versión del proyecto, no la global.
		if gradle then
		    if vim.fn.executable(root .. "/gradlew") == 1 then
			return { name = "bootRun (gradlew)", program = root .. "/gradlew", args = { "bootRun" } }
		    end
		    if vim.fn.executable("gradle") == 1 then
			return { name = "bootRun (gradle)", program = "gradle", args = { "bootRun" } }
		    end
		end
		if pom then
		    if vim.fn.executable(root .. "/mvnw") == 1 then
			return { name = "spring-boot:run (mvnw)", program = root .. "/mvnw",
				 args = { "spring-boot:run" } }
		    end
		    if vim.fn.executable("mvn") == 1 then
			return { name = "spring-boot:run (mvn)", program = "mvn", args = { "spring-boot:run" } }
		    end
		end
		return nil
	    end

	    --- Launch de una app Spring Boot: levanta el server y se le attacha.
	    local function spring_boot_launch(port)
		local root = vim.fs.root(0, { "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
		local task = spring_boot_task(root)
		if not task then
		    vim.notify("No parece un proyecto Spring Boot (sin pom.xml/build.gradle ni spring-boot-starter)",
			vim.log.levels.WARN)
		    return
		end
		vim.notify(("Lanzando %s… (attach en %d)"):format(task.name, port), vim.log.levels.INFO)
		dap.run({
		    type = 'java',
		    request = 'attach',
		    name = "Spring Boot (attach)",
		    hostName = "127.0.0.1",
		    port = port,
		    timeout = 30000,
		    preLaunchTask = {
			name = task.name,
			program = task.program,
			args = task.args,
			cwd = root,
		    },
		})
	    end

	    -- Solo attach. Las configs de `launch` las genera jdtls con
	    -- setup_dap_main_class_configs() cuando detecta los main classes del
	    -- proyecto, así que no hace falta definirlas a mano ni preguntar por
	    -- mainClass/projectName.
	    dap.configurations.java = {
		{
		    type = 'java',
		    request = 'attach',
		    name = "Attach java",
		    hostName = "127.0.0.1",
		    port = 5005,
		    timeout = 30000,
		},
	    }

	    --- Attach a un puerto concreto, por si el 5005 está ocupado.
	    local function java_attach()
		local default = (dap.configurations.java[1] or {}).port or 5005
		local port = vim.fn.input("Puerto de attach: ", tostring(default))
		port = tonumber(port)
		if not port then
		    vim.notify("Puerto no válido", vim.log.levels.ERROR)
		    return
		end
		dap.run({
		    type = 'java',
		    request = 'attach',
		    name = ("Attach java (puerto %d)"):format(port),
		    hostName = "127.0.0.1",
		    port = port,
		    timeout = 30000,
		})
	    end

	    vim.keymap.set('n', '<F5>', function() dap.continue() end)
	    vim.keymap.set('n', '<leader>dj', function() java_attach() end,
		{ desc = "Debug java: attach a un puerto" })
	    vim.keymap.set('n', '<leader>ds', function() spring_boot_launch(5005) end,
		{ desc = "Debug: lanzar Spring Boot y attach" })
	    vim.keymap.set('n', '<F10>', function() dap.step_over() end)
	    vim.keymap.set('n', '<F11>', function() dap.step_into() end)
	    vim.keymap.set('n', '<leader>b', function() dap.toggle_breakpoint() end)
	    vim.keymap.set('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end)

	    dap.listeners.before.attach.dapui_config = function()
		dapui.open()
	    end
	    dap.listeners.before.launch.dapui_config = function()
		dapui.open()
	    end
	    dap.listeners.before.event_terminated.dapui_config = function()
		dapui.close()
	    end
	    dap.listeners.before.event_exited.dapui_config = function()
		dapui.close()
	    end
	end
    },
}
