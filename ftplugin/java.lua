-- Configuración de jdtls.
--
-- Se usa `jdtls.start_or_attach()` (no `vim.lsp.enable`) porque nvim-jdtls
-- necesita resolver el root del proyecto antes de arrancar el cliente.

local mason = vim.env.MASON or (vim.fn.stdpath("data") .. "/mason")

--- Directorios donde se buscan JDKs. Se recorren TODOS y se lee la versión real
--- de cada uno; no se busca por nombre de carpeta.
---
--- No se usa JAVA_HOME a propósito: si apunta a un JDK 8 (o a un JRE), jdtls no
--- arranca, porque necesita 17+ para el launcher. Elegir el JDK más alto que
--- cumpla el mínimo es lo que garantiza que funcione.
local JDK_DIRS = {
    "/usr/lib/jvm",
    "/usr/java",
    "/opt/java",
    "/opt/jdk",
    vim.fn.expand("~/.sdkman/candidates/java"),
    vim.fn.expand("~/.asdf/installs/java"),
    vim.fn.expand("~/.jabba/jdk"),
    vim.fn.expand("~/.sdkman/candidates/jdk"),
}

--- Versión numérica de un JDK, leyendo `bin/java -version`.
--- Devuelve major, minor o nil.
local function jdk_version(path)
    local java = path .. "/bin/java"
    if vim.fn.executable(java) == 0 then
        return nil
    end
    -- `java -version` escribe en stderr.
    local out = vim.fn.system({ java, "-version" })
    if vim.v.shell_error ~= 0 then
        return nil
    end
    -- openjdk version "21.0.12.1" 2026-08-18 LTS
    -- openjdk version "1.8.0_504"
    local major, minor = out:match('version%s+"(%d+)%.(%d+)')
    if not major then
        major = out:match('version%s+"(%d+)"')
        minor = "0"
    end
    if not major then
        return nil
    end
    return tonumber(major), tonumber(minor)
end

--- Todos los JDKs encontrados, como { {path=, major=, minor=} }.
local function detect_jdks()
    local found = {}
    local seen = {}
    for _, base in ipairs(JDK_DIRS) do
        if vim.fn.isdirectory(base) == 1 then
            local entries = vim.fn.glob(base .. "/*", false, true)
            for _, path in ipairs(entries) do
                if vim.fn.isdirectory(path) == 1 and not seen[path] then
                    local major, minor = jdk_version(path)
                    if major then
                        seen[path] = true
                        table.insert(found, { path = path, major = major, minor = minor })
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.major ~= b.major then
            return a.major > b.major
        end
        return a.minor > b.minor
    end)
    return found
end

local jdks = detect_jdks()

-- jdtls exige 17+ para el launcher. En la práctica se pide 21.
local MIN_LAUNCH = 17
local launch_jdk = vim.iter(jdks):find(function(j)
    return j.major >= MIN_LAUNCH
end)

if not launch_jdk then
    local found = #jdks > 0 and ("solo se encontraron: " .. table.concat(vim.tbl_map(function(j)
        return ("%s (Java %d)"):format(j.path, j.major)
    end, jdks), ", ")) or "no se encontró ningún JDK"
    vim.notify(
        ("JDTLS: se necesita un JDK %d+ para lanzar el servidor, y %s.\nBusqué en: %s"):format(
            MIN_LAUNCH,
            found,
            table.concat(JDK_DIRS, ", ")
        ),
        vim.log.levels.ERROR
    )
    return
end

--- Runtimes que se pasan a jdtls. Solo los que existen de verdad: mandar un
--- `path = nil` (como pasaba con el JDK 11, que no está instalado) hace que jdtls
--- reciba una config con un runtime vacío.
local function build_runtimes()
    local runtimes = {}
    for _, j in ipairs(jdks) do
        -- Solo tiene sentido exponer un ERE por major, y 21+ como default.
        local name = j.major == 1 and ("JavaSE-1." .. (j.minor or 8)) or ("JavaSE-" .. j.major)
        local rt = { name = name, path = j.path }
        if j.path == launch_jdk.path then
            rt.default = true
        end
        table.insert(runtimes, rt)
    end
    return runtimes
end

-- El ORDEN importa: `vim.fs.root` prioriza por posición en la lista, no por
-- cercanía. Con `.git` en segundo lugar, un proyecto Java dentro de un monorepo
-- heredaba el root del repo entero y jdtls indexaba todo. Los marcadores
-- específicos van primero y `.git` queda como último recurso.
local root_markers = { 'gradlew', 'mvnw', 'build.gradle', 'settings.gradle', 'pom.xml', '.git' }

-- `vim.fs.find` sin `path` empieza desde el cwd, no desde el buffer: por eso
-- reventaba con "attempt to concatenate local 'root_dir' (a nil value)" al abrir
-- un .java fuera de un proyecto. `vim.fs.root` parte del archivo y devuelve nil
-- de forma segura si no hay marcadores.
local root_dir = vim.fs.root(0, root_markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(0))

-- Workspace único por RUTA ABSOLUTA.
--
-- Antes se usaba `fnamemodify(root_dir, ":p:h:t")`, que devuelve el nombre del
-- PADRE: dos proyectos `work1/api` y `work2/api` acababan ambos en
-- `workspace/api`. Al compartir el directorio de workspace de Eclipse, dos jdtls
-- distintos escriben .metadata y la config de classpath en el mismo sitio.
local workspace_dir = vim.fn.stdpath('data') .. '/workspace/'
    .. vim.fn.sha256(vim.fn.fnamemodify(root_dir, ':p')):sub(1, 16)

local is_libgdx = vim.fn.findfile('core/build.gradle', root_dir..';') ~= ''
local jvm_limits = {
    "-Xms256M",
    -- 1G se queda corto para proyectos Java medianos; jdtls indexa todo el classpath.
    "-Xmx2G",
    "-XX:+UseParallelGC",
    "-XX:GCTimeRatio=4",
    "-XX:AdaptiveSizePolicyWeight=90",
    "-Dsun.zip.disableMemoryMapping=true",
}
if is_libgdx then
    table.insert(jvm_limits, "--add-opens")
    table.insert(jvm_limits, "java.base/java.util=ALL-UNNAMED")
end

local cmd = {
    mason .. '/bin/jdtls',
    "--java-executable", launch_jdk.path .. "/bin/java",
    "-data", workspace_dir,
}
for _, arg in ipairs(jvm_limits) do
    table.insert(cmd, "--jvm-arg=" .. arg)
end

-- Agente de Lombok.
--
-- Sin él, jdtls resuelve el proyecto pero NO ve los getters/setters/constructores
-- que Lombok genera: `setNombre() is undefined for the type Ent`. El jar lo trae
-- mason junto a jdtls; el launcher solo lo aplica si se pasa como `--jvm-arg`.
--
-- El agente corre dentro de la JVM de jdtls (siempre la del launch_jdk), no en la
-- del proyecto, así que da igual que el proyecto compile a 1.8, 11 o 21.
local lombok_jar = mason .. "/packages/jdtls/lombok.jar"
if vim.fn.filereadable(lombok_jar) == 1 then
    table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok_jar)
end

local ok_cmp, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')

local config = {
    cmd = cmd,
    root_dir = root_dir,
    -- Sin esto jdtls pierde snippet support en las completions de Java.
    capabilities = ok_cmp and cmp_nvim_lsp.default_capabilities()
        or vim.lsp.protocol.make_client_capabilities(),
    settings = {
        java = {
            configuration = {
                runtimes = build_runtimes(),
            },
        },
        -- Soporte de Lombok en el LS (por si el jar no estuviera disponible).
        ["java.jdt.ls.lombokSupport.enabled"] = true,
        -- Descarga los sources de las dependencias para poder ir a la definición
        -- con el código real, no solo la firma.
        ["java.eclipse.downloadSources"] = true,
        ["java.maven.downloadSources"] = true,
    },
    init_options = {
        bundles = { (function()
            local jar = vim.fn.glob(
                mason .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
                true, true
            )[1]
            return jar
        end)() },
    },
}

vim.keymap.set('n', '<A-o>', function()
    require('jdtls').organize_imports()
end, { buffer = true, desc = 'Organize Java imports' })

vim.keymap.set('n', 'crv', function()
    require('jdtls').extract_variable()
end, { buffer = true, desc = 'Extract variable' })

vim.keymap.set('v', 'crv', function()
    require('jdtls').extract_variable({visual = true})
end, { buffer = true, desc = 'Extract variable (visual)' })

vim.keymap.set('n', 'crc', function()
    require('jdtls').extract_constant()
end, { buffer = true, desc = 'Extract constant' })

vim.keymap.set('v', 'crc', function()
    require('jdtls').extract_constant({visual = true})
end, { buffer = true, desc = 'Extract constant (visual)' })

vim.keymap.set('v', 'crm', function()
    require('jdtls').extract_method({visual = true})
end, { buffer = true, desc = 'Extract method (visual)' })

-- Descubre los main classes del proyecto y registra una config de launch por cada
-- uno, para no tener que teclear mainClass/projectName a mano.
--
-- NO se puede hacer en LspAttach: en ese momento el proyecto todavía no está
-- importado y `vscode.java.resolveMainClass` devuelve 0 main classes. Hay que
-- esperar a que jdtls reporte ServiceReady, que es cuando el classpath ya está
-- resuelto. El guard evita hacerlo dos veces si se abren varios buffers.
local main_configs_done = false
local function discover_main_classes()
    if main_configs_done then
        return
    end
    main_configs_done = true
    local ok, jdtls_dap = pcall(require, 'jdtls.dap')
    if not ok then
        return
    end
    pcall(jdtls_dap.setup_dap_main_class_configs, { verbose = false })
end

-- Augroup + `once`: antes este autocmd se creaba una vez por cada buffer Java
-- abierto y se acumulaban duplicados.
vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('jdtls', { clear = true }),
    once = true,
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not (client and client.name == "jdtls") then
            return
        end

        local ok, dap = pcall(require, 'dap')
        if not ok then
            return
        end
        require('jdtls').setup_dap({ hotcodereplace = 'auto' })

        -- Nos enganchamos al handler de `language/status` antes de que llegue el
        -- primer status, para no perder ServiceReady.
        local previous = client.handlers["language/status"]
        client.handlers["language/status"] = function(err, result, ctx)
            if result and result.type == "ServiceReady" then
                vim.schedule(discover_main_classes)
            end
            if previous then
                return previous(err, result, ctx)
            end
        end
    end
})

require('jdtls').start_or_attach(config)