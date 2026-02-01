# Configuración de neovim

__Probado en:__ Debian 13 (trixie) / WSL

## Requisitos

* **[Neovim 0.11.6+](https://github.com/neovim/neovim/releases)**
* **Clipboard Provider:** `win32yank` (Recomendado para WSL) o `xclip` (Linux nativo).
* **JDK21+:** (temurin) Necesario para el linter de Java. Instalar desde los repositorios oficiales de [Adoptium](https://adoptium.net/es/installation/linux#_deb_installation_on_debian_or_ubuntu)

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

## Características

* __LSP Integrados:__ Java, PHP, Rust
* __Treesitter:__ Resaltado de sitanxis avanzado
* __Fuzzy finder:__ Búsqueda rápida de archivos y texto

