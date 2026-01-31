#!/bin/bash

sudo apt update && sudo apt install -y build-essential curl clang libclang-dev ripgrep fd-find unzip php8.4 lua5.1 liblua5.1-0-dev luarocks golang-go ruby ruby-dev python3-pip python3-pynvim python3-venv python3-full

echo "Instalando Rust ..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

source "$HOME/.cargo/env"
source "$HOME/.bashrc"

rustc --version && echo "Rust instalado correctamente"

echo "instalando Treesitter cli..."

cargo install --locked tree-sitter-cli

echo "sincronizando plugins de neovim"

nvim --headless "lazy! sync" -c "qa"

echo "instalando npm provider"

npm install -g neovim


echo "Configurar path rubygems"

if ! grep -q 'GEM_HOME' ~/.bashrc; then
    echo 'export GEM_HOME="$HOME/.gems"' >> ~/.bashrc
    echo 'export PATH="$HOME/.gems/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

mkdir -p ~/.local/share/nvim/python_env
python3 -m venv ~/.local/share/nvim/python_env
~/.local/share/nvim/python_env/bin/pip install pynvim

echo "instalar la gema neovim"

gem install neovim
