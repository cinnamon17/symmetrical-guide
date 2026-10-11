-- Configuración de los language servers.
--
-- Nota: aquí se usa `vim.lsp.config()` a propósito y NO un directorio `lsp/`
-- en la raíz de la config. Neovim 0.11 resuelve `vim.lsp.config[nombre]` fusionando
-- (`tbl_deep_extend`) todos los `lsp/<nombre>.lua` que encuentra en el runtimepath,
-- en orden, y el último gana. Como `nvim-lspconfig` va después de la config del
-- usuario en el rtp, sus valores pisaban los nuestros. Las llamadas explícitas a
-- `vim.lsp.config()` se aplican al final y sí tienen prioridad real.

local uv = vim.uv or vim.loop

local M = {}

local servers = {}

--- Capacidades de nvim-cmp para que los servidores ofrezcan snippets y documentación.
local function cmp_capabilities()
	local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
	if ok then
		return cmp_nvim_lsp.default_capabilities()
	end
	return {}
end

--- Resuelve un marcador walkeando hacia arriba desde el archivo del buffer.
--- A diferencia de `vim.fs.find` pelado, parte del path del buffer y no del cwd.
local function root_from(bufnr, markers)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return nil
	end
	return vim.fs.root(name, markers)
end

--- ¿Estamos dentro de un proyecto Angular?
local function is_angular_project(root)
	if not root then
		return false
	end
	return uv.fs_stat(root .. "/angular.json") ~= nil
		or uv.fs_stat(root .. "/.angular") ~= nil
		or uv.fs_stat(root .. "/project.json") ~= nil
end

--- Dónde se cachean las versiones de @angular/language-service.
local function cache_root()
	return vim.fn.stdpath("data") .. "/angular"
end

--- Major de `@angular/core` declarado en el package.json del proyecto.
---
--- No es una heurística: es el número que el propio proyecto declara. ngserver no
--- valida que language-service case con core (solo exige `>= 15.0`), así que
--- elegir el major correcto es cosa nuestra.
local function detect_angular_core_version(root)
	local pkg = root and (uv.fs_stat(root .. "/package.json") and root .. "/package.json" or nil)
	if not pkg then
		return nil
	end
	local fd = io.open(pkg, "r")
	if not fd then
		return nil
	end
	local content = fd:read("*a")
	fd:close()
	local ok, json = pcall(vim.json.decode, content)
	if not ok or type(json) ~= "table" then
		return nil
	end
	local deps = vim.tbl_extend("force", json.dependencies or {}, json.devDependencies or {})
	local raw = deps["@angular/core"]
	if type(raw) ~= "string" then
		return nil
	end
	local major = raw:match("^%^?(%d+)") or raw:match("^(%d+)")
	return {
		major = major,
		-- Versión concreta sin el prefijo de rango, para --angularCoreVersion.
		full = raw:gsub("^[%^~><= ]+", ""),
	}
end

local function detect_angular_version(root)
	local v = detect_angular_core_version(root)
	return v and v.major or nil
end

-- Datos calculados en `root_dir` y leídos en `cmd`. El closure de `root_dir`
-- solo recibe el bufnr, no la config, así que no hay forma de devolverlos por
-- el return; se pasan por esta tabla, indexada por root ya resuelto.
local angular_cache_by_root = {}
-- Roots ya avisados, para no repetir el notify en cada buffer.
local angular_warned = {}

--- ¿La caché de este major está COMPLETA?
---
--- No basta con que exista `@angular/language-service`: una caché instalada con
--- una versión anterior de esta config puede tener solo ese paquete y fallar en
--- silencio. Se exige además TypeScript, que es lo que ngserver no encuentra sin
--- él (ngserver exige `typescript >= 5.0` en sus probe locations).
local function cached_language_service(major)
	local dir = cache_root() .. "/ng-" .. major .. "/node_modules"
	if uv.fs_stat(dir .. "/@angular/language-service") and uv.fs_stat(dir .. "/typescript") then
		return dir
	end
	return nil
end

--- Paquetes que necesita `@angular/language-service` para funcionar.
---
--- OJO: `@angular/language-service` NO declara ninguna dependencia ni peerDependency
--- en su package.json (es autónomo), pero en la práctica necesita el ecosystem de
--- Angular y TypeScript para resolver templates. Instalar solo el paquete deja una
--- caché con un único directorio `@angular/`, y ngserver arranca con
--- `initialized=true` pero responde `null` a TODO: ni completions, ni hover, ni
--- diagnósticos. Es un cliente mudo, que es peor que un fallo visible.
local function language_service_packages(major)
	return {
		"@angular/language-service@" .. major,
		"@angular/compiler@" .. major,
		"@angular/compiler-cli@" .. major,
		"@angular/core@" .. major,
		"typescript@~5.9.0",
	}
end

--- Instala @angular/language-service del major correspondiente en la caché.
---
--- Usa `npm install --prefix`, que escribe en el directorio de caché y NO toca el
--- proyecto: no aparece un `node_modules` en el repo del usuario. Bloquea (~1s en
--- frío, instantáneo si ya está en la cache de npm) porque el arranque del
--- cliente depende de que exista.
local function install_language_service(major)
	local prefix = cache_root() .. "/ng-" .. major
	uv.fs_mkdir(prefix, 493) -- 0755

	local cmd = { "npm", "install", "--prefix", prefix }
	vim.list_extend(cmd, language_service_packages(major))
	vim.list_extend(cmd, { "--silent", "--no-fund", "--no-audit" })

	local result = vim
		.system(cmd, { text = true }, function(out)
			vim.schedule(function()
				local dir = cache_root() .. "/ng-" .. major .. "/node_modules"
				if uv.fs_stat(dir .. "/@angular/language-service") then
					vim.notify(
						("angular: language-service@%s instalado en %s"):format(major, dir),
						vim.log.levels.INFO
					)
				else
					vim.notify(
						("angular: no se pudo instalar @angular/language-service@%s. Se usará ts_ls.\n%s"):format(
							major,
							out.err ~= "" and out.err or out.stdout
						),
						vim.log.levels.WARN
					)
				end
			end)
		end)
		:wait()
	if not cached_language_service(major) then
		return nil
	end
	return result
end

--- Asegura que exista language-service para el proyecto y devuelve su node_modules.
local function ensure_language_service(root)
	local major = detect_angular_version(root)
	if not major then
		return nil, "no se pudo determinar la versión de @angular/core"
	end
	local cached = cached_language_service(major)
	if cached then
		return cached
	end
	local ok = install_language_service(major)
	if not ok then
		return nil, ("falló la instalación de @angular/language-service@%s"):format(major)
	end
	return cached_language_service(major)
end

--- Rutas donde ngserver busca `typescript` y `@angular/*`.
---
--- ngserver no usa el `typescript` que trae empaquetado: exige que se le
--- indiquen directorios de sondeo y falla con
--- "Failed to resolve 'typescript/lib/tsserverlibrary'" si la lista llega vacía.
--- Siempre incluimos el `node_modules` del propio binario de mason como red de
--- seguridad, y delante el del proyecto para que mande la versión del usuario.
local function probe_locations(root, ng_dir)
	-- `node_modules` del proyecto: es donde están las versiones que el usuario
	-- eligió (y donde debe vivir @angular/language-service).
	local ts_dirs = {}
	if root then
		table.insert(ts_dirs, root .. "/node_modules")
	end

	-- Red de seguridad: el typescript que trae el propio ngserver de mason.
	-- Sin esto, un proyecto sin `npm install` deja a ngserver sin resolución y
	-- muere con "Failed to resolve 'typescript/lib/tsserverlibrary'".
	--
	-- Ojo con el path. `exepath("ngserver")` da
	--   mason/packages/angular-language-server/node_modules/.bin/ngserver
	-- pero ese binario es un symlink, y `fs_realpath` lo sigue hasta
	--   .../node_modules/@angular/language-server/bin/ngserver
	-- De ahí a `node_modules` (donde está typescript) hay que subir TRES niveles,
	-- no dos. Con dos se llegaba a `@angular`, que no contiene typescript, y el
	-- fallback quedaba silenciosamente inútil.
	local exe = vim.fn.exepath("ngserver")
	local resolved = exe ~= "" and (uv.fs_realpath(exe) or exe) or nil
	if resolved then
		local bundled = vim.fs.normalize(vim.fs.dirname(resolved) .. "/../../..")
		if uv.fs_stat(bundled .. "/typescript") then
			table.insert(ts_dirs, bundled)
		end
	end

	-- Para `@angular/language-service`: primero el proyecto, luego la caché del
	-- major detectado, luego mason. El paquete NO viene en mason, así que sin la
	-- caché ngserver arranca pero responde NADA a completion/hover/definition.
	local ng_dirs = {}
	if root then
		table.insert(ng_dirs, root .. "/node_modules")
	end
	if ng_dir then
		table.insert(ng_dirs, ng_dir)
	end
	if resolved then
		local bundled = vim.fs.normalize(vim.fs.dirname(resolved) .. "/../../..")
		if uv.fs_stat(bundled) then
			table.insert(ng_dirs, bundled)
		end
	end

	return table.concat(ts_dirs, ","), table.concat(ng_dirs, ",")
end

-- Lua ---------------------------------------------------------------------

function servers.lua_ls()
	vim.lsp.config("lua_ls", {
		capabilities = cmp_capabilities(),
		root_markers = {
			".luarc.json",
			".luarc.jsonc",
			"stylua.toml",
			".stylua.toml",
			".git",
			"init.lua",
		},
		settings = {
			Lua = {
				runtime = { version = "LuaJIT" },
				workspace = {
					library = vim.api.nvim_get_runtime_file("", true),
					maxPreload = 2000,
					preloadFileSize = 1000,
				},
				telemetry = { enable = false },
			},
		},
	})
end

-- Rust --------------------------------------------------------------------

function servers.rust_analyzer()
	vim.lsp.config("rust_analyzer", {
		capabilities = cmp_capabilities(),
		settings = {
			["rust-analyzer"] = {
				imports = {
					granularity = "Module",
					group = "self",
				},
				cargo = {
					buildScripts = { enable = true },
				},
				procMacro = { enable = true },
				check = {
					command = "clippy",
					allFeatures = true,
				},
			},
		},
	})
end

-- PHP ---------------------------------------------------------------------

function servers.phpactor()
	vim.lsp.config("phpactor", {
		capabilities = cmp_capabilities(),
		init_options = {
			["symfony.enabled"] = true,
			["language_server_phpstan.enabled"] = false,
			["language_server_psalm.enabled"] = false,
		},
		-- phpactor lee claves planas con notación de punto; el bloque anidado
		-- `settings.phpactor.*` que había aquí nunca llega al servidor.
		settings = {
			["symfony.enabled"] = true,
			["completion.insertUseDeclaration"] = true,
			["language_server_phpstan.enabled"] = false,
			["language_server_psalm.enabled"] = false,
		},
	})
end

-- Angular / TypeScript ----------------------------------------------------

function servers.angularls()
	vim.lsp.config("angularls", {
		capabilities = cmp_capabilities(),
		filetypes = {
			"typescript",
			"typescript.tsx",
			"typescriptreact",
			"javascript",
			"javascriptreact",
			"html",
			"htmlangular",
		},
		-- Neovim detecta las plantillas Angular como filetype `htmlangular`
		-- (runtime/lua/vim/filetype/detect.lua, M.html: basta un `@if`, `@for`,
		-- `ngIf`... en el contenido). El LSP manda el filetype literal como
		-- `languageId`, y ngserver SOLO trata un documento como plantilla Angular
		-- si `languageId === "html"` (index.js, Session.onDidOpenTextDocument).
		-- Con `htmlangular` el .html no queda asociado a ningún proyecto
		-- configurado y ngserver no publica diagnósticos, hover ni completion en
		-- plantillas externas.
		-- Verificado en el proyecto real sin tocar disco: sin este mapeo, 0
		-- diagnósticos en .html; con él:
		--   [ngtsc] Property 'propiedadQueNoExisteXYZ' does not exist on type 'Saludo'.
		get_language_id = function(_, ft)
			return ft == "htmlangular" and "html" or ft
		end,
		-- `cmd` como función en vez de `before_init`: ngserver lee las probe
		-- locations de `argv` (`parseStringArray(argv...)`), no de
		-- `initializationOptions`, así que tienen que ir como argumentos de CLI.
		-- La función se evalúa al arrancar el cliente, cuando ya se conoce el
		-- root_dir definitivo.
		cmd = function(dispatchers, config)
			local cached = angular_cache_by_root[config.root_dir] or {}
			local ts_probes, ng_probes = probe_locations(config.root_dir, cached.cache)
			local cmd = { "ngserver", "--stdio", "--tsProbeLocations", ts_probes, "--ngProbeLocations", ng_probes }
			if cached.core_version then
				vim.list_extend(cmd, { "--angularCoreVersion", cached.core_version })
			end
			return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
		end,
		-- Solo se activa dentro de proyectos Angular. Para el resto de TypeScript
		-- entra ts_ls, evitando dos servidores compitiendo por el mismo buffer.
		--
		-- Aquí se resuelve también @angular/language-service: sin él ngserver
		-- arranca "bien" (initialized=true) pero responde NADA a completion,
		-- hover y definition, que es peor que un fallo visible. Si no se puede
		-- conseguir, no se llama a on_dir() y entra ts_ls en su lugar.
		root_dir = function(bufnr, on_dir)
			local root = root_from(bufnr, { "angular.json", "project.json", ".angular" })
			if not is_angular_project(root) then
				return
			end

			local ng_dir, err = ensure_language_service(root)
			if not ng_dir then
				local seen = angular_warned[root]
				if not seen then
					angular_warned[root] = true
					-- Ojo: vim.notify NO interpola %s. Hay que pasar la tabla
					-- como segundo argumento de string.format.
					vim.notify(
						string.format(
							"angular: %s.\nSe usará ts_ls (sin soporte de templates Angular).\n"
								.. "Para arreglarlo: npm install --save-dev @angular/language-service",
							err
						),
						vim.log.levels.WARN
					)
				end
				-- Sin on_dir() -> este cliente no arranca; ts_ls toma el relevo.
				return
			end

			-- Guardamos el dato para que `cmd` lo use sin volver a detectarlo.
			local core = detect_angular_core_version(root)
			angular_cache_by_root[root] = {
				cache = ng_dir,
				core_version = core and core.full or nil,
			}
			on_dir(root)
		end,
	})
end

function servers.ts_ls()
	vim.lsp.config("ts_ls", {
		capabilities = cmp_capabilities(),
		filetypes = {
			"typescript",
			"typescript.tsx",
			"typescriptreact",
			"javascript",
			"javascriptreact",
		},
		-- Corre SIEMPRE, también en proyectos Angular. angularls es "angularOnly"
		-- (ngserver hardcodea `pluginConfig.angularOnly = true`, index.js): en
		-- .ts NO reporta errores TS, ni completions, ni hover (devuelve nil),
		-- solo cosas de plantilla. Si ts_ls cede el paso, un .ts de un proyecto
		-- Angular se queda sin diagnóstico TS y sin completions.
		-- Medido 2026-10-11 sobre el proyecto real (sin tocar disco):
		--   error TS en app.ts   -> angularls: diag 0 | con ts_ls: diag 2 [typescript]
		--   completion en this.  -> angularls: nil  | ts_ls: 13 items
		-- No hay solapamiento: angularls no responde a TS, así que los dos
		-- conviven sin duplicar items.
		root_dir = function(bufnr, on_dir)
			local root = root_from(bufnr, {
				"tsconfig.json",
				"jsconfig.json",
				"package.json",
				".git",
			})
			if root then
				on_dir(root)
			end
		end,
	})
end

--- Habilita todos los servidores. Se invoca durante la carga de la config, antes
--- de que Neovim lea el archivo de la línea de órdenes.
---
--- Importante: `vim.lsp.enable()` registra un autocmd `FileType` y solo hace
--- "catch-up" con `doautoall` si `vim.v.vim_did_enter == 1`. Si se llama desde un
--- ftplugin, el `FileType` del buffer de arranque ya ocurrió con `did_enter == 0`,
--- así que el autocmd se crea demasiado tarde y ese primer buffer nunca recibe
--- cliente LSP. Llamarlo aquí, en config-load, evita ese hueco.
function M.setup()
	servers.lua_ls()
	servers.rust_analyzer()
	servers.phpactor()
	servers.angularls()
	servers.ts_ls()

	vim.lsp.enable({
		"lua_ls",
		"rust_analyzer",
		"phpactor",
		"angularls",
		"ts_ls",
	})

	-- catch-up defensivo para cualquier buffer ya abierto (p. ej. session restores)
	vim.api.nvim_create_autocmd("VimEnter", {
		group = vim.api.nvim_create_augroup("lsp.enable", { clear = true }),
		desc = "Arranca los LSP en buffers ya cargados antes de VimEnter",
		callback = function()
			vim.cmd.doautoall("nvim.lsp.enable", "FileType")
		end,
	})
end

return M