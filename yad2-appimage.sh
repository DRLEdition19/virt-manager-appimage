#!/bin/bash
#
# Script para criar um AppImage do YAD (Yet Another Dialog)
# Este script baixa, compila e empacota o YAD em um arquivo AppImage
# que pode ser executado em praticamente qualquer distribuição Linux
#

set -e

# Função para exibir mensagens coloridas
print_status() {
    echo -e "\e[1;34m[*] $1\e[0m"
}

print_error() {
    echo -e "\e[1;31m[!] $1\e[0m" >&2
}

print_success() {
    echo -e "\e[1;32m[+] $1\e[0m"
}

# Verificar dependências
check_dependencies() {
    print_status "Verificando dependências necessárias..."
    
    local deps=("wget" "git" "make" "automake" "autoconf" "libtool" "pkg-config" "gcc" "g++")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "As seguintes dependências estão faltando:"
        for m in "${missing[@]}"; do
            echo "  - $m"
        done
        
        if command -v apt-get &>/dev/null; then
            print_status "Tentando instalar dependências automaticamente..."
            sudo apt-get update
            sudo apt-get install -y "${missing[@]}" build-essential libgtk-3-dev libwebkit2gtk-4.0-dev
        elif command -v dnf &>/dev/null; then
            print_status "Tentando instalar dependências automaticamente..."
            sudo dnf install -y "${missing[@]}" gtk3-devel webkit2gtk3-devel
        else
            print_error "Por favor, instale as dependências manualmente e execute o script novamente."
            exit 1
        fi
    fi
    
    # Verificar dependências de compilação do YAD
    local pkgs=("gtk+-3.0" "glib-2.0")
    local missing_pkgs=()
    
    for pkg in "${pkgs[@]}"; do
        if ! pkg-config --exists "$pkg"; then
            missing_pkgs+=("$pkg")
        fi
    done
    
    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        print_error "As seguintes bibliotecas de desenvolvimento estão faltando:"
        for m in "${missing_pkgs[@]}"; do
            echo "  - $m"
        done
        
        if command -v apt-get &>/dev/null; then
            print_status "Tentando instalar bibliotecas de desenvolvimento automaticamente..."
            sudo apt-get install -y libgtk-3-dev libglib2.0-dev
        elif command -v dnf &>/dev/null; then
            print_status "Tentando instalar bibliotecas de desenvolvimento automaticamente..."
            sudo dnf install -y gtk3-devel glib2-devel
        else
            print_error "Por favor, instale as bibliotecas de desenvolvimento manualmente."
            exit 1
        fi
    fi
    
    print_success "Todas as dependências estão instaladas!"
}

# Criar diretório de trabalho
create_workdir() {
    WORK_DIR="$(pwd)/yad-appimage-build"
    
    if [ -d "$WORK_DIR" ]; then
        print_status "Limpando diretório de trabalho existente..."
        rm -rf "$WORK_DIR"
    fi
    
    print_status "Criando diretório de trabalho: $WORK_DIR"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
}

# Baixar e compilar YAD
download_and_compile_yad() {
    print_status "Baixando código-fonte do YAD..."
    git clone https://github.com/v1cont/yad.git
    cd yad
    
    print_status "Preparando ambiente de compilação..."
    autoreconf -ivf
    intltoolize
    
    print_status "Configurando compilação..."
    ./configure --prefix=/usr
    
    print_status "Compilando YAD..."
    make -j$(nproc)
    
    print_success "Compilação concluída!"
    cd ..
}

# Preparar estrutura AppDir
prepare_appdir() {
    print_status "Preparando estrutura AppDir..."
    
    mkdir -p AppDir/usr/{bin,lib,share}
    
    # Instalar YAD no AppDir
    cd yad
    make DESTDIR="$WORK_DIR/AppDir" install
    cd ..
    
    # Criar arquivo .desktop
    mkdir -p AppDir/usr/share/applications
    cat > AppDir/usr/share/applications/yad.desktop << EOF
[Desktop Entry]
Name=YAD
GenericName=Yet Another Dialog
Comment=Display graphical dialogs from shell scripts
Exec=yad
Icon=yad
Type=Application
Terminal=false
Categories=GTK;Utility;
StartupNotify=true
EOF
    
    # Criar ícone
    mkdir -p AppDir/usr/share/icons/hicolor/128x128/apps/
    cp yad/data/icons/128x128/yad.png AppDir/usr/share/icons/hicolor/128x128/apps/
    ln -sf usr/share/icons/hicolor/128x128/apps/yad.png AppDir/yad.png
    
    # Criar AppRun
    cat > AppDir/AppRun << 'EOF'
#!/bin/bash

# Pegar o diretório onde o script está sendo executado
HERE="$(dirname "$(readlink -f "${0}")")"

# Configurar variáveis de ambiente
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"
export GSETTINGS_SCHEMA_DIR="${HERE}/usr/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR}"
export GI_TYPELIB_PATH="${HERE}/usr/lib/girepository-1.0:${GI_TYPELIB_PATH}"

# Executar o binário YAD
exec "${HERE}/usr/bin/yad" "$@"
EOF
    
    chmod +x AppDir/AppRun
    
    print_success "Estrutura AppDir preparada!"
}

# Resolver e copiar dependências
copy_dependencies() {
    print_status "Resolvendo e copiando dependências..."
    
    mkdir -p AppDir/usr/lib
    
    # Criar uma função para copiar bibliotecas e suas dependências
    copy_lib_and_deps() {
        local lib="$1"
        local dest="$2"
        
        # Evitar copiar bibliotecas já incluídas
        local libname=$(basename "$lib")
        if [ -e "$dest/$libname" ]; then
            return
        fi
        
        # Copiar a biblioteca
        cp -L "$lib" "$dest/"
        
        # Copiar dependências da biblioteca
        ldd "$lib" | grep "=> /" | awk '{print $3}' | while read -r dep; do
            local depname=$(basename "$dep")
            # Ignorar bibliotecas do sistema
            if [[ "$depname" != libc.so* && "$depname" != libpthread.so* && "$depname" != libdl.so* && 
                  "$depname" != libm.so* && "$depname" != librt.so* && "$depname" != libstdc++.so* && 
                  "$depname" != libgcc_s.so* && "$depname" != linux-vdso.so* && "$depname" != ld-linux*.so* ]]; then
                copy_lib_and_deps "$dep" "$dest"
            fi
        done
    }
    
    # Copiar dependências do YAD
    for bin in AppDir/usr/bin/*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then
            ldd "$bin" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
                copy_lib_and_deps "$lib" "AppDir/usr/lib"
            done
        fi
    done
    
    # Copiar as bibliotecas GTK e relacionadas
    for lib in $(ldconfig -p | grep -E 'libgtk|libgdk|libglib|libgobject|libgio|libpango|libcairo|libatk|libharfbuzz' | awk '{print $4}'); do
        if [ -f "$lib" ]; then
            copy_lib_and_deps "$lib" "AppDir/usr/lib"
        fi
    done
    
    # Copiar esquemas GSettings se existirem
    if [ -d "/usr/share/glib-2.0/schemas" ]; then
        mkdir -p AppDir/usr/share/glib-2.0/schemas
        cp -a /usr/share/glib-2.0/schemas/* AppDir/usr/share/glib-2.0/schemas/
        glib-compile-schemas AppDir/usr/share/glib-2.0/schemas/ || true
    fi
    
    # Copiar ícones GTK comuns
    if [ -d "/usr/share/icons/Adwaita" ]; then
        mkdir -p AppDir/usr/share/icons/
        cp -a /usr/share/icons/Adwaita AppDir/usr/share/icons/
    fi
    
    # Copiar arquivos de tema GTK comuns
    if [ -d "/usr/share/themes/Adwaita" ]; then
        mkdir -p AppDir/usr/share/themes/
        cp -a /usr/share/themes/Adwaita AppDir/usr/share/themes/
    fi
    
    print_success "Dependências copiadas!"
}

# Baixar e configurar o appimagetool
get_appimagetool() {
    print_status "Baixando appimagetool..."
    
    cd "$WORK_DIR"
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
    chmod +x appimagetool
}

# Criar AppImage
create_appimage() {
    print_status "Criando AppImage..."
    
    cd "$WORK_DIR"
    
    # Verificar se a ferramenta FUSE está disponível
    if ! command -v fusermount &>/dev/null; then
        export APPIMAGE_EXTRACT_AND_RUN=1
    fi
    
    # Gerar AppImage
    YAD_VERSION=$(cd yad && git describe --tags || echo "latest")
    ARCH=$(uname -m)
    
    ./appimagetool AppDir "YAD-${YAD_VERSION}-${ARCH}.AppImage"
    
    # Mover AppImage para o diretório atual
    mv "YAD-${YAD_VERSION}-${ARCH}.AppImage" ../
    
    print_success "AppImage criado com sucesso: YAD-${YAD_VERSION}-${ARCH}.AppImage"
}

# Função de limpeza
cleanup() {
    print_status "Limpando arquivos temporários..."
    rm -rf "$WORK_DIR"
    print_success "Limpeza concluída!"
}

# Função principal
main() {
    print_status "Iniciando processo de criação do AppImage do YAD..."
    
    check_dependencies
    create_workdir
    download_and_compile_yad
    prepare_appdir
    copy_dependencies
    get_appimagetool
    create_appimage
    cleanup
    
    print_success "Processo concluído! O AppImage do YAD está pronto para uso."
    echo ""
    echo "Você pode executar o AppImage com:"
    echo "./YAD-*-$(uname -m).AppImage"
}

# Executar a função principal
main
