#!/bin/bash

# Script para instalar Waydroid em uma pasta local e convertê-lo em AppImage
# Autor: Claude (baseado no ArchImage de Ivan Hc)
# Data: 20/04/2025

set -e
set -u

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretórios de trabalho
WORK_DIR="$HOME/waydroid-appimage-build"
APPDIR="$WORK_DIR/AppDir"
BIN_DIR="$APPDIR/usr/bin"
LIB_DIR="$APPDIR/usr/lib"
SHARE_DIR="$APPDIR/usr/share"
WAYDROID_DIR="$APPDIR/opt/waydroid"

# Dependências necessárias
DEPENDENCIES=(
    "wget"
    "curl"
    "tar"
    "gzip"
    "squashfs-tools"
    "fuse"
    "python3"
    "git"
)

# Função para exibir mensagens
print_message() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Verificar dependências
check_dependencies() {
    print_message "Verificando dependências necessárias..."
    MISSING_DEPS=()
    
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        fi
    done
    
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        print_error "As seguintes dependências estão faltando:"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "  - $dep"
        done
        print_message "Por favor, instale as dependências acima e execute o script novamente."
        exit 1
    else
        print_success "Todas as dependências necessárias estão instaladas!"
    fi
}

# Criar estrutura de diretórios
create_directory_structure() {
    print_message "Criando estrutura de diretórios..."
    
    mkdir -p "$WORK_DIR"
    mkdir -p "$APPDIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$LIB_DIR"
    mkdir -p "$SHARE_DIR/applications"
    mkdir -p "$SHARE_DIR/icons/hicolor/scalable/apps"
    mkdir -p "$WAYDROID_DIR"
    
    print_success "Estrutura de diretórios criada!"
}

# Baixar e instalar o Waydroid
download_and_install_waydroid() {
    print_message "Baixando e instalando o Waydroid..."
    
    # Clone do repositório do Waydroid
    cd "$WORK_DIR"
    git clone https://github.com/waydroid/waydroid.git waydroid-source
    
    # Instalar os arquivos do Waydroid no AppDir
    cp -r "$WORK_DIR/waydroid-source/tools" "$WAYDROID_DIR/"
    cp -r "$WORK_DIR/waydroid-source/data" "$WAYDROID_DIR/"
    cp -r "$WORK_DIR/waydroid-source/waydroid" "$WAYDROID_DIR/"
    
    # Copiar os binários principais
    cp "$WORK_DIR/waydroid-source/bin/waydroid" "$BIN_DIR/"
    chmod +x "$BIN_DIR/waydroid"
    
    print_success "Waydroid baixado e instalado no diretório AppDir!"
}

# Baixar dependências adicionais necessárias para o Waydroid
download_dependencies() {
    print_message "Baixando dependências do Waydroid..."
    
    # Instalar libs Python necessárias
    mkdir -p "$APPDIR/usr/lib/python3/dist-packages"
    pip3 install --target="$APPDIR/usr/lib/python3/dist-packages" gbinder-python dbus-python pyclip

    # Baixar e instalar lxc
    cd "$WORK_DIR"
    git clone https://github.com/lxc/lxc.git
    cd lxc
    ./autogen.sh
    ./configure --prefix="$APPDIR/usr"
    make -j$(nproc)
    make install
    
    # Baixar e instalar gbinder (libgbinder)
    cd "$WORK_DIR"
    git clone https://github.com/mer-hybris/libgbinder.git
    cd libgbinder
    make -j$(nproc) KEEP_SYMBOLS=1 release
    make install DESTDIR="$APPDIR" PREFIX="/usr"
    
    print_success "Dependências baixadas e instaladas!"
}

# Criar os arquivos necessários para o AppImage
create_appimage_files() {
    print_message "Criando arquivos para o AppImage..."
    
    # Criar o AppRun
    cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash

# Diretório do AppImage
APPDIR="$(dirname "$(readlink -f "$0")")"

# Configurar variáveis de ambiente
export PATH="$APPDIR/usr/bin:$PATH"
export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export PYTHONPATH="$APPDIR/usr/lib/python3/dist-packages:$PYTHONPATH"
export XDG_DATA_DIRS="$APPDIR/usr/share:$XDG_DATA_DIRS"
export WAYDROID_DATA_DIR="$HOME/.local/share/waydroid-appimage"

# Criar diretório de dados se não existir
mkdir -p "$WAYDROID_DATA_DIR"

# Se nenhum argumento for passado, inicie a interface gráfica
if [ $# -eq 0 ]; then
    exec "$APPDIR/usr/bin/waydroid" show-full-ui
else
    exec "$APPDIR/usr/bin/waydroid" "$@"
fi
EOF
    chmod +x "$APPDIR/AppRun"
    
    # Criar o arquivo .desktop
    cat > "$SHARE_DIR/applications/waydroid.desktop" << EOF
[Desktop Entry]
Name=Waydroid
Comment=Android in a box
Exec=waydroid show-full-ui
Icon=waydroid
Type=Application
Categories=System;Emulator;
Terminal=false
EOF
    
    # Baixar o ícone do Waydroid
    wget -q -O "$SHARE_DIR/icons/hicolor/scalable/apps/waydroid.svg" \
        "https://raw.githubusercontent.com/waydroid/waydroid/main/data/AppIcon.svg"
    
    # Link o ícone para o diretório raiz (necessário para o AppImage)
    ln -sf "./usr/share/icons/hicolor/scalable/apps/waydroid.svg" "$APPDIR/waydroid.svg"
    
    print_success "Arquivos para o AppImage criados!"
}

# Baixar o appimagetool e criar o AppImage
create_appimage() {
    print_message "Criando o AppImage..."
    
    cd "$WORK_DIR"
    
    # Baixar o appimagetool
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
    
    # Criar o AppImage
    ./appimagetool-x86_64.AppImage "$APPDIR" "Waydroid-x86_64.AppImage"
    
    # Mover para o diretório home
    mv "Waydroid-x86_64.AppImage" "$HOME/"
    chmod +x "$HOME/Waydroid-x86_64.AppImage"
    
    print_success "AppImage do Waydroid criado com sucesso em $HOME/Waydroid-x86_64.AppImage!"
}

# Limpar os arquivos temporários
cleanup() {
    read -p "Deseja remover os arquivos temporários? (S/n): " choice
    case "$choice" in
        n|N)
            print_message "Arquivos temporários mantidos em $WORK_DIR"
            ;;
        *)
            print_message "Removendo arquivos temporários..."
            rm -rf "$WORK_DIR"
            print_success "Arquivos temporários removidos!"
            ;;
    esac
}

# Função principal
main() {
    print_message "Iniciando a criação do AppImage do Waydroid..."
    
    check_dependencies
    create_directory_structure
    download_and_install_waydroid
    download_dependencies
    create_appimage_files
    create_appimage
    cleanup
    
    print_success "AppImage do Waydroid criado com sucesso!"
    print_message "Você pode executá-lo com: $HOME/Waydroid-x86_64.AppImage"
    print_warning "Para que o Waydroid funcione corretamente, o sistema precisa ter suporte a kernel android (anbox-modules ou waydroid-modules)"
}

# Executar função principal
main
