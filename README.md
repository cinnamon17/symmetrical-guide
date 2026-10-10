# Configuración de neovim

__Probado en:__ Debian 13 (trixie) / WSL

## Requisitos

* **[Neovim 0.11.6+](https://github.com/neovim/neovim/releases)**
* **Clipboard Provider:** `win32yank` (Recomendado para WSL) o `xclip` (Linux nativo).
* **JDK 21,11 y 8:** (Temurin) Necesario para el linter de Java. Instalar desde los repositorios oficiales de [Adoptium](https://adoptium.net/es/installation/linux#_deb_installation_on_debian_or_ubuntu)
* **Node.js 18+ & npm:** Necesario para Angular, TypeScript y Lua. Fácil instalación con [nvm](https://github.com/nvm-sh/nvm)
* **Soporte Angular:** Para que el LSP funcione correctamente, el proyecto debe tener las librerías de tipos (solo en dev):

~~~
npm install @angular/language-service@latest --save-dev
~~~

## Instalación

Crear el directorio de configuración y clonar el repositorio:

~~~
mkdir -p ~/.config/nvim
cd ~/.config/nvim
git clone https://github.com/cinnamon17/symmetrical-guide.git .
~~~

Ejecutar el instalador 

~~~
chmod u+x ./installer.sh
./installer.sh
~~~

En la terminal entrar en Neovim

~~~
nvim 
~~~

Los language servers se instalan solos al arrancar: `ensure_installed` en
`lua/plugins/mason.lua` los declara y mason los descarga si faltan. Para
instalarlos a mano:

~~~
:MasonInstall phpactor lua-language-server jdtls java-debug-adapter php-debug-adapter rust-analyzer angular-language-server typescript-language-server
~~~

## Características

* __LSP Integrados:__ Java, PHP, Rust, Lua, Angular/TypeScript
* __Depuración:__ nvim-dap con codelldb (Rust), jdtls (Java) y xdebug (PHP)
* __Treesitter:__ Resaltado de sintaxis avanzado
* __Fuzzy finder:__ Búsqueda rápida de archivos y texto

## Notas

* __Angular:__ en proyectos Angular se usa `angularls`; en el resto de proyectos
  TypeScript, `ts_ls`. La commutable automáticamente según la presencia de
  `angular.json` / `project.json` / `.angular`, así que solo uno de los dos se
  attaches a cada buffer.
* __Angular (language-service):__ `ngserver` necesita
  `@angular/language-service`; sin él arranca pero responde NADA a completion,
  hover y definition. La config lo resuelve sola: lee el major de
  `@angular/core` del `package.json` y, si no lo tiene cacheado, lo instala con
  `npm install --prefix` en `~/.local/share/nvim/angular/ng-<major>/`. **No toca
  el proyecto**: no aparece un `node_modules` en tu repo. El primer arranque de
  cada major bloquea ~1s mientras se instala; después es instantáneo. Si no se
  puede determinar la versión, cae a `ts_ls` con un aviso.
* __Java:__ jdtls se configura en `ftplugin/java.lua`.
  - El root se detecta por los marcadores del build (`gradlew`, `pom.xml`, ...)
    y no por `.git`, para no indexar el repo entero en monorepos.
  - El workspace de Eclipse es único por ruta absoluta (hash), así que dos
    proyectos con el mismo nombre no colisionan.
  - Los JDKs se descubren leyendo la versión real de cada uno en
    `/usr/lib/jvm`, `~/.sdkman/candidates/java`, `~/.asdf/installs/java`, etc.
    Se usa el más alto que sea ≥ 17. `JAVA_HOME` se ignora a propósito: si apunta
    a un JDK 8, jdtls no arranca.
  - __Lombok__ funciona automáticamente: se pasa el agente que trae mason
    (`jdtls/lombok.jar`) como `--jvm-arg=-javaagent`. Funciona igual en
    proyectos Java 8, 11 o 21, y con Spring Boot.
  - Maven y Gradle **no** hacen falta en el PATH: jdtls lleva m2e y buildship
    embebidos y resuelve el classpath por su cuenta. Basta con `pom.xml` o
    `build.gradle`, sin wrapper.
* __Debug Java:__ `F5` lanza el main class que jdtls detecta (no hay que
  teclear `mainClass`). `<leader>dj` hace attach a un puerto concreto (5005 por
  defecto). `<leader>ds` lanza Spring Boot (`bootRun` / `spring-boot:run`,
  usando el wrapper si existe) y se le attacha.

