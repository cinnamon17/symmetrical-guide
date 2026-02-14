local function find_java_path(version)
    local jvm_path = "/usr/lib/jvm/"
    local res = vim.fs.find(function(name)
        return name:match("temurin%-" .. version) and not name:match("^%.")
    end, { path = jvm_path, type = 'directory', limit = 1 })
    return res[1]
end

local function find_java_debug_path()
    local mason_path = vim.env.MASON or (vim.fn.stdpath("data") .. "/mason")
    local jar_pattern = mason_path .. "/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
    return vim.fn.glob(jar_pattern, true, true)[1]
end

local path_21 = find_java_path("21")
local path_11 = find_java_path("11")
local path_8  = find_java_path("8")

if not path_21 then
    vim.notify("JDTLS: No se encontró Java 21", vim.log.levels.ERROR)
    return
end

local root_markers = {'gradlew', '.git', 'mvnw', 'build.gradle', 'pom.xml', 'settings.gradle'}
local root_dir = vim.fs.dirname(vim.fs.find(root_markers, { upward = true })[1])
local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.stdpath('data') .. '/workspace/' .. project_name

local is_libgdx = vim.fn.findfile('core/build.gradle', root_dir..';') ~= ''

local config = {
    cmd = {
        (vim.env.MASON or (vim.fn.stdpath("data") .. "/mason")) .. '/bin/jdtls',
        "--java-executable", path_21 .. "/bin/java"
    },
    root_dir = root_dir,
    settings = {
        java = {
            configuration = {
                runtimes = {
                    { name = "JavaSE-1.8", path = path_8 },
                    { name = "JavaSE-11",  path = path_11 },
                    { name = "JavaSE-21",  path = path_21, default = true },
                },
            },
        }
    },
    init_options = {
        bundles = { find_java_debug_path() },
        workspace = workspace_dir,
        jvm_args = is_libgdx and { "-Xms1g", "-Xmx4g", "--add-opens", "java.base/java.util=ALL-UNNAMED" } or nil
    },
}

local opts = { buffer = true, silent = true }

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
end, { buffer = true, desc = 'Extract method' })


vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "jdtls" then
            require('jdtls').setup_dap({ hotcodereplace = 'auto' })
        end
    end
})

require('jdtls').start_or_attach(config)

local status_ok, cmp = pcall(require, 'cmp')
if status_ok then
    cmp.setup.buffer({
        completion = { completeopt = 'menu,menuone,noinsert,noselect' },
        sources = cmp.config.sources({
            { name = 'nvim_lsp' },
            { name = 'buffer' },
            { name = 'path' }
        })
    })
end

