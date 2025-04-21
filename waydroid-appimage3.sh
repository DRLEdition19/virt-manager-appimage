#!/bin/bash

# Nome da pasta temporária para a instalação
INSTALL_DIR="$HOME/waydroid_build"
APPIMAGE_DIR="$INSTALL_DIR/AppImage"
WAYDROID_SOURCE_DIR="$INSTALL_DIR/waydroid_source"
APP_NAME="WayDroid"
APPIMAGE_NAME="WayDroid.AppImage"

# Dependências necessárias para criar o AppImage
DEPENDENCIES=(
    "git"
    "wget"
    "squashfs-tools"
    "pkg-config"
    "cmake"
    "libfuse-dev"
    "build-essential"
    "python3"
    "python3-pip"
    "python3-setuptools"
)

# Função que verifica se o script está sendo executado como root
check_if_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "Não execute este script como root. Saindo."
        exit 1
    fi
}

# Função para instalar dependências
install_dependencies() {
    echo "Instalando dependências..."
    for package in "${DEPENDENCIES[@]}"; do
        if ! dpkg -s "$package" &>/dev/null; then
            echo "Instalando $package..."
            sudo apt-get install -y "$package"
        else
            echo "$package já está instalado."
        fi
    done
}

# Função para configurar o diretório de instalação
setup_directories() {
    echo "Criando diretórios..."
    mkdir -p "$INSTALL_DIR" "$APPIMAGE_DIR" "$WAYDROID_SOURCE_DIR"
}

# Função para clonar e construir o WayDroid
build_waydroid() {
    echo "Clonando WayDroid do repositório oficial..."
    git clone https://github.com/waydroid/waydroid.git "$WAYDROID_SOURCE_DIR"

    echo "Construindo WayDroid..."
    cd "$WAYDROID_SOURCE_DIR" || exit
    python3 setup.py build
    python3 setup.py install --root="$APPIMAGE_DIR" --optimize=1
}

# Função para criar o AppImage
create_appimage() {
    echo "Criando AppImage para $APP_NAME..."

    # Diretório AppDir necessário para o AppImage
    APPDIR="$APPIMAGE_DIR/$APP_NAME.AppDir"
    mkdir -p "$APPDIR"

    # Copiar arquivos do WayDroid para AppDir
    cp -r "$APPIMAGE_DIR/usr" "$APPDIR"
    cp -r "$APPIMAGE_DIR/etc" "$APPDIR"

    # Criar arquivo AppRun
    echo "#!/bin/bash
HERE=\$(dirname \"\$(readlink -f \"\$0\")\")
export PATH=\"\$HERE/usr/bin:\$PATH\"
export LD_LIBRARY_PATH=\"\$HERE/usr/lib:\$LD_LIBRARY_PATH\"
exec \$HERE/usr/bin/waydroid \"\$@\"
" > "$APPDIR/AppRun"
    chmod +x "$APPDIR/AppRun"

    # Criar arquivo de desktop
    echo "[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Exec=waydroid
Icon=$APP_NAME
Categories=Utility;
Terminal=false
" > "$APPDIR/$APP_NAME.desktop"

    # Copiar ícone (substitua pelo ícone real do WayDroid)
    wget -O "$APPDIR/$APP_NAME.png" https://raw.githubusercontent.com/waydroid/waydroid/main/assets/logo.png

    # Baixar AppImageTool
    APPIMAGETOOL="$INSTALL_DIR/appimagetool"
    if [ ! -f "$APPIMAGETOOL" ]; then
        echo "Baixando AppImageTool..."
        wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O "$APPIMAGETOOL"
        chmod +x "$APPIMAGETOOL"
    fi

    # Criar AppImage
    "$APPIMAGETOOL" "$APPDIR" "$INSTALL_DIR/$APPIMAGE_NAME"
    echo "AppImage criado em: $INSTALL_DIR/$APPIMAGE_NAME"
}

# Função para limpar diretórios temporários
cleanup() {
    echo "Limpando arquivos temporários..."
    rm -rf "$INSTALL_DIR"
}

# Execução do script
check_if_root
install_dependencies
setup_directories
build_waydroid
create_appimage
cleanup

echo "Instalação e criação de AppImage concluídas com sucesso!"
