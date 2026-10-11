# AGENTS.md

Contexto de trabajo para esta config de Neovim. Documenta qué se verificó, cómo
se verificó y qué queda abierto. Actualizado 2026-10-11.

## Entorno

| | |
|---|---|
| Neovim | 0.11.6 |
| Java | temurin-21 + temurin-8 en `/usr/lib/jvm` (**no hay JDK 11**) |
| Node | v24.13.0 |
| Maven / Gradle en PATH | **ninguno** (no están instalados) |
| SO | Linux, proyecto en `~/Documentos/git/` |

## Regla de oro al trabajar aquí

**Toda afirmación sobre el LSP tiene que ir acompañada del comando que la
sostiene.** Durante la sesión anterior se emitieron varias conclusiones que
resultaron ser falsos positivos porque el método de prueba era inválido (ver
"Sobretests no fiables"). Antes de escribir "X funciona", ejecuta el test y pega
la salida real.

Metodología que sí funcionó:

```bash
# probe en fichero, salida a disco (nunca por stdout de nvim)
cd <proyecto> && cat > probe.lua <<'EOF'
vim.defer_fn(function()
  local b = vim.api.nvim_get_current_buf()
  vim.wait(90000, function() return #vim.diagnostic.get(b) > 0 end, 800)
  local f = io.open('out.txt', 'w')
  f:write('diagnósticos: ' .. #vim.diagnostic.get(b) .. '\n')
  f:close(); vim.cmd('qa!')
end, 20000)
EOF
rm -f out.txt
nvim --headless -u ~/.config/nvim/init.lua -c "luafile probe.lua" <archivo>
cat out.txt
```

Notas importantes del harness:

- `nvim --headless` **sí** levanta LSP. El fallo histórico de "clients: 0" era
  por orden de argumentos: con `-c 'sleep N'` **antes** del archivo, el `-c` se
  ejecuta antes de leerlo y no hay buffer.
- Para procesos largos usar `timeout` generoso (>120 s) y lanzar en background.
- Un harness Python que hable JSON-RPC directo **no es válido** para juzgar si
  ngserver responde: no completa el import del proyecto y devuelve `null`
  siempre. Se descartó por eso.
- **Si se trabaja sobre una copia del proyecto, validarla SIEMPRE antes:**
  ```bash
  cd <copia> && node -e "console.log(require.resolve('@angular/core'))"
  ```
  `cp -al` / `cp -a` sobre `node_modules` deja la copia rota y produce "fallos"
  fantasma. Preferir `ln -s` al `node_modules` real. Si la validación falla,
  ningún resultado de esa copia sirve.
- **Cambiar una variable por vez.** Si se tocan varias cosas a la vez (probes,
  versión, orden) y el control deja de funcionar, se pierde la capacidad de
  aislar la causa.

## Estado del repo

```
rama:  main (o lo que sea; commit base a54093d "update neovim config")
sin commitear:  lua/config/lsp.lua   (+30 -13, el fix de language-service)
```

Todo lo demás está commiteado en `a54093d`.

## Arquitectura de la config

```
init.lua                  -> require("config")
lua/config/init.lua       -> opciones, lazy.setup(), require("config.lsp").setup()
lua/config/lsp.lua        -> TODA la config LSP (vim.lsp.config + vim.lsp.enable)
lua/plugins/*.lua         -> specs de lazy
ftplugin/*.lua            -> solo keymaps y accioness específicas de lenguaje
```

Dos decisiones que costaron sangre y **no hay que revertir**:

**1. No usar el directorio `lsp/` en la raíz.** Neovim 0.11 resuelve
`vim.lsp.config[nombre]` fusionando con `tbl_deep_extend` todos los
`lsp/<nombre>.lua` del runtimepath, en orden, y **el último gana**. Como
`nvim-lspconfig` va después de la config del usuario en el rtp, sus valores
pisaban los nuestros silenciosamente. Por eso todo va en
`vim.lsp.config()` explícito, que sí se aplica al final.

**2. `vim.lsp.enable()` se llama en config-load, NO en los ftplugins.**
`lsp.enable` registra un autocmd `FileType` y solo hace catch-up con `doautoall`
si `vim.v.vim_did_enter == 1`. Si se llama desde un ftplugin, el `FileType` del
buffer de arranque ya ocurrió con `did_enter == 0`, el autocmd se crea tarde y
**ese primer buffer nunca recibe cliente LSP**.

## LSPs: qué usa cada lenguaje

| Lenguaje | Servidor | Notas |
|---|---|---|
| Lua | `lua_ls` | |
| Rust | `rust_analyzer` | clippy + allFeatures |
| PHP | `phpactor` | |
| TS/JS | `ts_ls` | solo si **no** es proyecto Angular |
| Angular | `angularls` | ver sección abierta |
| Java | `jdtls` | vía `jdtls.start_or_attach`, no `vim.lsp.enable` |

## Verificado y funcionando

### Arranque
- `cmp` con `lazy = false` a propósito: `lua/config/lsp.lua` pide
  `cmp_nvim_lsp.default_capabilities()` en config-load, y con carga diferida el
  require falla y los servidores pierden snippet support.
- Startup: **~94 ms**.

### Java (todo verificado con proyectos de prueba reales)

**Lombok** — el agente se inyecta como `--jvm-arg=-javaagent:<mason>/jdtls/lombok.jar`.
Sin él, jdtls resuelve el proyecto pero no ve los getters/setters generados
(`setNombre() is undefined for the type Ent`).

Resultados medidos con el agente activo:

| Escenario | Resultado |
|---|---|
| Java 8 (`source/target 1.8`) + Lombok 1.18.30 | 0 diagnósticos |
| Java 21 + Lombok 1.18.34 | 0 errores (solo warnings correctos) |
| Spring Boot 3.3 + `@Value` + `@Getter` | 0 diagnósticos |

Prueba negativa que confirma que no es falso positivo:
`getNoExiste() is undefined for the type Cfg` → dice "for the type **Cfg**", o
sea conoce el tipo y su getter generado.

El agente corre en la JVM de jdtls (siempre la del launch_jdk), no en la del
proyecto, así que el `source/target` del proyecto es irrelevante para él.

**Workspace de Eclipse** — único por **ruta absoluta hasheada** (sha256, 16
chars). Antes usaba `fnamemodify(root_dir, ":p:h:t")` que devuelve el nombre del
**padre**: `work1/api` y `work2/api` acababan ambos en `workspace/api`,
compartiendo `.metadata` de Eclipse.

**Descubrimiento de JDK** — recorre `/usr/lib/jvm`, `/usr/java`, `/opt/java`,
`~/.sdkman/candidates/java`, `~/.asdf/installs/java`, etc., y lee la versión
real de cada uno con `bin/java -version`. Se usa el más alto **≥ 17**.
`JAVA_HOME` se ignora a propósito: si apunta a un JDK 8, jdtls no arranca.
Comprobado que ya no se inyecta `path = nil` en los runtimes (el JDK 11 no está
instalado y antes mandaba un `nil` a jdtls).

**Root markers** — el orden importa: `vim.fs.root` prioriza por posición, no por
cercanía. Con `.git` en segundo lugar, un proyecto Java dentro de un monorepo
heredaba el root del repo entero. Ahora: `{gradlew, mvnw, build.gradle,
settings.gradle, pom.xml, .git}`.

**Maven/Gradle del sistema: descartado a propósito.** jdtls lleva **m2e y
buildship embebidos**; se comprobó que resuelve `commons-lang3` sin `mvn`
instalado. Meter el Maven del sistema mezclaría dos resolvers de classpath.

**Debug discovers** — `setup_dap_main_class_configs()` genera las configs de
launch. Importante: **no puede llamarse en `LspAttach`** (el proyecto aún no
está importado y `resolveMainClass` devuelve 0); se engancha al handler de
`language/status` y dispara con `ServiceReady`.

```
CONFIGS: 2
  Attach java | attach | mainClass=nil
  Launch sb: p.App | launch | mainClass=p.App project=sb | classpaths=1
```

Bug conocido de nvim-jdtls: si el proyecto no tiene ningún `main`,
`fetch_main_configs` nunca llama al callback (se queda colgado). No rompe nada.

**Spring Boot** — comprobado que jdtls detecta los main classes sin nada
especial. Inyección por constructor implícita funciona:
`private Repo repo;` sin `@Autowired` → 0 diagnósticos.

### Angular (cacheado automático)

`@angular/language-service` se instala **fuera del proyecto**, con
`npm install --prefix ~/.local/share/nvim/angular/ng-<major>/`. El proyecto no
modifica su `node_modules` (verificado: sigue sin aparecer).

Ciclo verificado:
```
Proyecto Angular ^21.0.0, sin node_modules, caché vacía
  → cachea ng-21, instala @angular/language-service@21.2.25
  → proyecto intacto
  → tiempo en frío: ~1 s
Proyecto sin package.json → no puede deducir versión → ts_ls + aviso
```

**Bug encontrado y arreglado (sin commitear):**
`@angular/language-service` **no declara ninguna dependencia ni peerDependency**
en su package.json. Instalarlo solo dejaba una caché con un único directorio
`@angular/` y sin TypeScript. Ahora `install_language_service` instala además
`@angular/compiler`, `@angular/compiler-cli`, `@angular/core` y `typescript`,
y `cached_language_service` verifica que exista `typescript` para considerar
válida una caché (una caché vieja e incompleta se detecta y se reinstala sola).

### ⚠️ HALLAZGO GRANDE: mason YA trae el language-service correcto

Verificado el 2026-10-11. El paquete de mason **empaqueta su propio
`@angular/language-service` y su propio `typescript`**, versionados entre sí:

```
~/.local/share/nvim/mason/packages/angular-language-server/node_modules/
├── @angular/
│   └── language-server/
│       └── node_modules/
│           ├── @angular/language-service   ← 21.1.3
│           └── typescript                  ← 5.9.3
```

ngserver (mason) es **21.1.3**. Es decir: el language-service empaquetado tiene
**exactamente la misma versión que el ngserver que lo va a cargar**.

Eso es precisamente lo que apunta **nvim-lspconfig upstream**
(`lsp/<angularls>.lua`):

```lua
local ngserver_path = vim.fs.dirname(vim.uv.fs_realpath(exe))
local extension_path = vim.fs.joinpath(ngserver_path, '../../../')
-- ts_probe_dirs = extension_path, proyecto/node_modules
-- ng_probe_dirs = extension_path/@angular/language-server/node_modules,
--                 proyecto/node_modules/@angular/language-server/node_modules
```

**La "trampa 6" del documento original es FALSA.** Decía:

> lspconfig upstream añade `/@angular/language-server/node_modules`, que no
> aplica al layout de mason

Aplica exactamente. La afirmación correcta es la contraria.

**Consecuencia:** toda la maquinaria de la caché
(`install_language_service`, `cached_language_service`,
`detect_angular_core_version`) **puede que no hiciera falta nunca**, y peor:
instalaba un language-service **21.2.25** para un ngserver **21.1.3**. Un
desajuste de versión entre el LS y el servidor que lo carga es una causa
plausible de "arranca pero responde `null` a todo".

**Hipótesis principal a partir de aquí:** el fix correcto no es mejorar la
caché, sino **eliminarla** y usar los probes empaquetados de mason, como hace
upstream.

> **Nota (2026-10-11, tarde):** esto es una simplificación **opcional**. La
> causa real de que angularls pareciera mudo fue el `languageId` del `.html`
> (`htmlangular`), no los probes ni la caché. Ver "RESUELTO".

## ✅ RESUELTO (2026-10-11, tarde): angserver NO estaba mudo; era el `languageId`

El síntoma "angularls mudo en `componente`" eran **dos cosas distintas**:

1. **Artefactos de método** (los "0 diagnósticos / nil" de la sesión anterior).
2. Un **bug real** que rompía solo las plantillas externas `.html`: el
   `languageId`.

### 1. angularls nunca estuvo mudo

Control positivo correcto: un `.ts` con **template inline** (`angtest/src/app/bad.ts`),
no un `.html`, no un error TS plano. En el proyecto real, inyectando el
componente en el **buffer** (sin tocar disco):

```
TAG tsdefault
bufname .../componente/src/app/src/components/saludo/saludo.ts
client angularls root=/home/cinnamon17/Documentos/git/angular/componente
wait ok=true found=true
diagnosticos 1
  [ngtsc] Property 'propiedadQueNoExiste' does not exist on type 'BadComponent'.
```

Los "0" previos venían de tests inválidos:

- Errores de tipos TS planos (`const x: number = "str"`): ngserver los ignora
  (trampa 7).
- Posiciones inválidas: `probe_completing.lua` pedía completion en
  `character 17` sobre una línea de 16, `probe_comp.lua` en el hueco de
  `styleUrl`, `probe_comp2.lua` sobre líneas en blanco / `import`. `nil` ahí es
  legítimo (trampa 12).
- Los probes sobre `.html` caían, además, en el bug 2.

### 2. El bug real: `languageId` del HTML (`htmlangular` vs `html`)

Cadena verificada:

1. Neovim detecta el `.html` como filetype **`htmlangular`**
   (`runtime/lua/vim/filetype/detect.lua`, `M.html`: basta un `@if`/`@for`/
   `ngIf`/`ng-template` en el contenido):
   ```
   $ nvim --headless -u init.lua -c "verbose setlocal filetype?" src/app/src/components/saludo/saludo.html
     filetype=htmlangular
       Last set from ~/.local/share/nvim/runtime/filetype.lua
   ```
2. Neovim manda ese filetype literal como `languageId` (RPC volcado):
   ```
   "rpc.send" { method = "textDocument/didOpen", params = { textDocument = { languageId = "htmlangular", uri = ".../saludo.html" } } }
   ```
3. ngserver solo hace el manejo de plantilla si `languageId === "html"`
   (`@angular/language-server/index.js`, `Session.onDidOpenTextDocument`):
   ```js
   if (result.configFileName === void 0 && languageId === LanguageId.HTML) { /* abre el .ts hermano, asocia al proyecto */ }
   ```
   Con `htmlangular` se salta esa rama → el `.html` queda en un proyecto
   inferido, `languageServiceEnabled === false` → **no publica nada**.

### Fix aplicado

En `lua/config/lsp.lua`, `servers.angularls()`:

```lua
get_language_id = function(_, ft)
    return ft == "htmlangular" and "html" or ft
end,
```

Evidencia (proyecto real, error inyectado en el buffer, sin tocar disco):

| Config | Fichero | Resultado |
|---|---|---|
| Sin el fix | `.html` | ❌ `diagnosticos: 0`, `hover: {}` |
| Sin el fix | `.ts` inline | ✅ `[ngtsc] ... on type 'BadComponent'` |
| **Con el fix** | `.html` | ✅ `[ngtsc] Property 'propiedadQueNoExisteXYZ' does not exist on type 'Saludo'` |
| **Con el fix** | `.html` | ✅ completion con items reales (`data.filePath = .../saludo.html`) |

Comandos del control positivo (ver "Regla de oro"):

```bash
cd /tmp/opencode && rm -f fix_out.txt
NGPROBE_TAG=fix timeout 200 nvim --headless \
  -u ~/.config/nvim/init.lua -c "luafile /tmp/opencode/probe_html.lua" \
  ~/Documentos/git/angular/componente/src/app/src/components/saludo/saludo.html
cat /tmp/opencode/fix_out.txt
```

**Nota sobre la hipótesis de versión:** queda **descartada**. Con el LS 21.2.25
del proyecto (y `@angular/core` 21.2.25) y ngserver 21.1.3, el `.ts` sí
diagnostica. El desajuste LS↔ngserver no era la causa del síntoma.

**Probes de upstream:** verificados contra el proyecto **real** (antes solo se
habían probado en `angtest`): los probes empaquetados de mason también dan el
diagnóstico ngtsc. Cambiar a ellos (y quitar la caché) es una simplificación
**opcional**, no necesaria para el fix.

### Segundo fix: `ts_ls` ya no cede el paso en proyectos Angular

`ngserver` arranca el plugin Angular con **`angularOnly: true` hardcodeado**
(`index.js:247871`, `pluginConfig = { angularOnly: true }`). Consecuencia: en un
`.ts` de proyecto Angular, `angularls` **no aporta nada de TypeScript** — ni
diagnósticos, ni completions, ni hover. Y como `servers.ts_ls()` hacía `return`
en proyectos Angular cuando había language-service, **ningún cliente** cubría el
TypeScript plano: se quedaba el `.ts` sin errores TS y sin completions.

Medido sobre el proyecto real (sin tocar disco):

| Prueba | Clientes | Resultado |
|---|---|---|
| Error TS en `app.ts` (`const __err: number = "…"`) | `angularls` | `diag: 0` |
| Idem | `angularls, ts_ls` | `diag: 2` → `[typescript] Type 'string' is not assignable to type 'number'.` |
| Completion en `this.` de `saludo.ts` | `angularls` | `nil` |
| Idem | `ts_ls` | `13 items` |

**No hay solapamiento**: pedí completion a cada cliente en la misma posición;
`angularls` devuelve `nil` y `ts_ls` los items. Por eso se deja que `ts_ls`
corra siempre (se eliminó el bloque de cesión en `servers.ts_ls()`).

Alternativa descartada: repartir por filetype (`angularls` solo
`html`/`htmlangular`). Resolvería el `.ts` pero **perdería** los diagnósticos de
plantillas inline en `.ts` sin ganar nada, porque `angularls` no aporta
TypeScript.

### ⚠️ Harness roto: por qué los "fallos" de la copia NO valían

Se intentó bisecar copiando el proyecto con `cp -al` / `cp -a`. Esas copias
**dejaban `node_modules` roto**:

```bash
cd /tmp/opencode/realcopy && node -e "console.log(require.resolve('@angular/core'))"
# Error: Cannot find module '@angular/core'
```

Los "diagnósticos: 0" que salieron de `realcopy` y `v_nospec` **no eran del
proyecto, eran del harness**. Cualquier conclusión sacada de esas copias es
basura. Lección: **siempre validar la copia antes de usarla** (ver "Regla de
oro" y el paso 0 del plan).

### Lo que ya se puede descartar (con reservas)

- El cliente está conectado (`attached_buffers` = 1).
- Los argumentos de arranque se construyen bien (se volcaron con un interceptor
  sobre `vim.lsp.rpc.start`).
- El árbol `src/` real no es la causa (probado).
- `tsconfig.spec.json` / `vitest/globals` no es la causa.
- El bundle `language-service.js` no requiere paquetes externos.
- Un `ngserver` que **muere** con "Failed to resolve" es otro problema distinto
  de "arranca y responde null".

### Hipótesis (cerradas)

1. ~~Desajuste de versión LS↔ngserver~~ → **descartada**: con LS 21.2.25 y
   ngserver 21.1.3 el `.ts` diagnostica.
2. ~~Estado interno del proyecto real~~ → **descartada**: el proyecto real
   responde bien (`.ts` inline y `.html` tras el fix).
3. Pruebas en posiciones inválidas / sin plantilla → **confirmada**: era parte
   del falso positivo.

### Nota sobre diagnóstico de errores TS planos

ngserver **no reporta errores de tipos TypeScript normales** en ficheros sin
decorador Angular. Se inyectó `const __err: number = "no"` en un buffer del
proyecto real (sin tocar disco) y devolvió 0 diagnósticos. Eso es **esperado**,
no un fallo. Para probar hay que usar un componente con error de template
(idealmente template **inline** en un `.ts`, o un `.html` con el fix del
`languageId`).

### Verificado tras los dos fixes

```
CONFIG OK
NVIM STARTED: 95 ms / 91 ms

.ts  (app.ts, error TS inyectado en el buffer):
  clients: angularls,ts_ls
  diag: 2
    [typescript] Type 'string' is not assignable to type 'number'.
    [typescript] '__err' is declared but its value is never read.

.html (saludo.html, error de plantilla inyectado en el buffer):
  client angularls
  diagnosticos 1
    [ngtsc] Property 'propiedadQueNoExisteXYZ' does not exist on type 'Saludo'.
```

### Tareas opcionales pendientes (no bloquean)

- **Simplificar a upstream:** quitar la caché (`install_language_service`,
  `cached_language_service`, `detect_angular_version`) y usar los probes
  empaquetados de mason. Verificado que funciona en el proyecto real, pero los
  dos fixes son independientes y ya resuelven el problema.
- **`ftplugin/htmlangular.lua`:** no existe; si se quieren keymaps
  específicos de plantilla, crearlo.

## Por qué no se resolvió antes (análisis de método)

Recopilado el 2026-10-11 tras revisar la investigación previa. Cuatro causas,
todas de método, ninguna de conocimiento técnico:

1. **Se perdió el caso de control.** Se modificaron caché, probe locations,
   `--angularCoreVersion` y el orden de las rutas a la vez. Cuando el proyecto
   limpio dejó de dar 1 diagnóstico, ya no se podía saber qué cambio lo rompió.
   Sin control no hay aislamiento posible.

2. **El harness estaba roto y no se detectó.** Se hicieron copias del proyecto
   con `cp -al` / `cp -a` que dejaban `node_modules` inválido. Los "0
   diagnósticos" resultantes parecían un fallo del LSP, pero eran un fallo del
   método. Reproducido y confirmado: `require.resolve('@angular/core')` falla
   desde esas copias.

3. **Se construyó maquinaria para resolver un problema que no existía.** Todo el
   sistema de caché de `@angular/language-service` (instalación, detección de
   versión, validación) es innecesario: mason ya trae el language-service
   correcto, versionado con su propio ngserver. La caché instalaba una versión
   distinta (21.2.25) a la del ngserver (21.1.3); se creyó que *eso* era la
   causa, pero quedó **descartado**: con ese desajuste el `.ts` sí diagnostica.

4. **Se dio por buena una premisa falsa.** La "trampa 6" (que
   `/@angular/language-server/node_modules` "no aplica al layout de mason")
   es incorrecta, y se usó para justificar desviarse de la configuración de
   upstream, que era la correcta.

5. **Nunca se probó el control positivo correcto en el proyecto real.** El
   control es un `.ts` con **template inline** (o un `.html` con el fix del
   `languageId`), no un error TS plano ni un completion en una posición
   arbitraria. Al hacerlo, el proyecto real respondió a la primera. Además
   nadie había mirado el `languageId` que envía Neovim (`htmlangular`), que era
   la causa real de que las plantillas `.html` no respondieran.

**Lecciones para esta sesión y las siguientes:**

- Un control que funciona **en la misma ejecución** es obligatorio.
- Validar el harness (copia) antes de usarlo.
- Cambiar una variable por vez.
- Preferir la configuración de upstream salvo razón demostrada para no hacerlo.
- Documentar el *comando* que sostiene cada afirmación, no solo la conclusión.

## Trampas encontradas (no volver a caer)

1. **`require("lspconfig")` y `lspconfig.util.root_pattern` están eliminados** en
   0.11. El error de sintaxis que tenía `lsp/angularls.lua` (coma suelta) hacía
   que `vim.lsp.config` **lanzara un error** al resolver cualquier config LSP,
   porque Neovim hace `loadfile()` de todos los `lsp/*.lua` del rtp.
2. **`vim.fs.realpath` no existe**; es `vim.uv.fs_realpath`.
3. **`vim.notify` no interpola `%s`**. Hay que pasar la tabla a `string.format`
   explícitamente.
4. **`nvim -u <copia>` no aísla el runtimepath**: el `ftplugin/` de la config
   real sigue cargándose. Para probar una copia hay que usar `XDG_CONFIG_HOME`.
5. **Probing del path de mason**: `exepath("ngserver")` da
   `.../node_modules/.bin/ngserver`, pero es un symlink; `fs_realpath` lo sigue
   hasta `.../node_modules/@angular/language-server/bin/ngserver`. Para llegar a
   `node_modules` (donde está `typescript`) hay que subir **tres** niveles, no
   dos. Con dos se llega a `@angular`, que no contiene typescript, y el fallback
   queda inútil sin error visible.
6. ~~`ngProbeLocations` ... lspconfig upstream añade
   `/@angular/language-server/node_modules`, que no aplica al layout de mason.~~
   **CORREGIDO 2026-10-11: esto es FALSO.** Sí aplica y es la ruta correcta.
   Mason empaqueta `@angular/language-service` + `typescript` dentro de
   `@angular/language-server/node_modules/`, versionados entre sí. Ver
   "HALLAZGO GRANDE".
7. **ngserver solo diagnostica código Angular.** Un `.ts` con errores de tipos
   pero sin decorador produce 0 diagnósticos — eso no significa que esté roto.
   Hay que probar con un componente y `strictTemplates`. Verificado de nuevo:
   inyectar `const x: number = "str"` da 0 diagnósticos.
8. **jdtls y `find_java_path`**: buscar por nombre (`temurin-21`) solo funciona
   con ese layout. Se cambió a leer la versión real.
9. **NUNCA copiar `node_modules` con `cp -al` / `cp -a` para tests.** Deja la
   copia rota (`require.resolve('@angular/core')` falla) sin avisar, y produce
   "fallos" fantasma. Usar `ln -s` al `node_modules` real, o validar con
   `require.resolve` antes de usar la copia.
10. **Un `harness` inválido puede invalidar toda una investigación.** Antes de
    sacar cualquier conclusión, comprobar que el control positivo funciona **en
    la misma ejecución**. Si el control da 0, no es que "algo se rompió": es que
    el método no mide.
11. **No cambiar varias cosas a la vez.** La investigación previa tocó caché,
    probes, `angularCoreVersion` y orden de rutas simultáneamente y perdió el
    caso de control, quedando sin capacidad de aislar la causa.
12. **`result: null` / `nil` no siempre significa "roto".** Puede ser una
    posición inválida (p. ej. completion sobre `})`), o un método que ngserver
    legítimamente no responde (hover en un import). Elegir posiciones donde la
    respuesta sea inequívoca.
13. **Un `.html` de Angular se detecta como filetype `htmlangular`.** Neovim lo
    manda literalmente como `languageId`, y ngserver **solo** trata el documento
    como plantilla si `languageId === "html"` (`Session.onDidOpenTextDocument`);
    con `htmlangular` no publica nada (ni diagnósticos, ni hover, ni
    completion). Se arregla con `get_language_id` en la config de `angularls`
    (ver "RESUELTO"). Verificado 2026-10-11.
14. **Los errores de tipo TS planos no sirven de control para ngserver.**
    `const x: number = "str"` da 0 diagnósticos (trampa 7). El control positivo
    es un componente con error de plantilla (inline en `.ts`, o `.html` con el
    fix del `languageId`), y hay que confirmarlo *en la misma ejecución* que el
    caso que se mide.
15. **`ngserver` es `angularOnly` (hardcodeado).** En un `.ts` de proyecto
    Angular no reporta errores TS, ni completions, ni hover — solo cosas de
    plantilla. Por eso `ts_ls` **debe** correr también en proyectos Angular;
    si se le hace ceder el paso, el `.ts` se queda sin nada de TypeScript
    (medido: `angularls -> nil`, `ts_ls -> 13 items`). No hay solapamiento.

## Cómo seguir

El problema de Angular está **cerrado** (dos fixes aplicados y verificados:
`get_language_id` para las plantillas `.html`, y `ts_ls` corriendo siempre para
los `.ts`). Si se retoma:

1. Leer "RESUELTO" de este fichero (y "Trampas 13, 14 y 15").
2. **Controles positivos obligatorios**: `.ts` con **error TS** (lo cubre
   `ts_ls`), `.ts` con template inline / `.html` con error de plantilla (lo
   cubre `angularls`), *en la misma ejecución*.
3. **Verificar antes de concluir** (sintaxis + arranque + ambos controles):
   ```bash
   cd ~/.config/nvim && nvim --headless -u init.lua -c "lua print('CONFIG OK')" -c "qa!"
   nvim --headless --startuptime /tmp/st.txt -u init.lua -c "qa!"; grep "NVIM STARTED" /tmp/st.txt

   # .ts -> debe dar clients: angularls,ts_ls y diag 2 [typescript]
   cd /tmp/opencode && rm -f fix2_out.txt
   NGPROBE_TAG=fix2 timeout 160 nvim --headless -u ~/.config/nvim/init.lua \
     -c "luafile /tmp/opencode/probe_tserr2.lua" \
     ~/Documentos/git/angular/componente/src/app/app.ts
   cat /tmp/opencode/fix2_out.txt

   # .html -> debe dar diagnosticos 1 ... on type 'Saludo'
   NGPROBE_TAG=fix timeout 200 nvim --headless -u ~/.config/nvim/init.lua \
     -c "luafile /tmp/opencode/probe_html.lua" \
     ~/Documentos/git/angular/componente/src/app/src/components/saludo/saludo.html
   cat /tmp/opencode/fix_out.txt
   ```
4. **Opcional (simplificación, no urgente):** reemplazar la caché por los probes
   empaquetados de mason, como hace nvim-lspconfig upstream:
   ```lua
   local exe = vim.fn.exepath('ngserver')
   local ngserver_path = vim.fs.dirname(vim.uv.fs_realpath(exe))
   local extension_path = vim.fs.normalize(vim.fs.joinpath(ngserver_path, '../../../'))
   -- tsProbeLocations: extension_path, <root>/node_modules
   -- ngProbeLocations: extension_path/@angular/language-server/node_modules,
   --                   <root>/node_modules/@angular/language-server/node_modules
   ```
   Eliminaría `install_language_service`, `cached_language_service` y
   `detect_angular_version` (y la caché en `~/.local/share/nvim/angular/`).
   Verificado que funciona en el proyecto real, pero hazlo como paso aparte.

Estado del repo: commit base `a54093d`. **Sin commitear**: `lua/config/lsp.lua`
(el fix del language-service, el `get_language_id` **y** la retirada del bloque
de cesión de `ts_ls`) y `AGENTS.md`.