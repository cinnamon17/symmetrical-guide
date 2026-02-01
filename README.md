# Configuración de neovim

__Probado en:__ Debian 13 (trixie) / WSL

## Requisitos

* **[Neovim 0.11.6+](https://github.com/neovim/neovim/releases)**
* **Clipboard Provider:** `win32yank` (Recomendado para WSL) o `xclip` (Linux nativo).

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
