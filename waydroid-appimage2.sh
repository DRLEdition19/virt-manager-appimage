#!/bin/bash

# Script para instalar Waydroid e criar um AppImage
# Autor: Claude
# Data: 20/04/2025
# Descrição: Este script instala o Waydroid e cria um AppImage executável
# que contém todas as dependências necessárias para executar o Waydroid em qualquer distribuição Linux.

set -e

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções auxiliares
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "Comando '$1' não encontrado. Instalando..."
        return 1
    fi
    return 0
}

# Verificar permissões de administrador
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como administrador (root)."
    echo "Por favor, execute com sudo: sudo $0"
    exit 1
fi

# Verificar espaço em disco
SPACE_NEEDED=5 # GB
AVAILABLE_SPACE=$(df -BG --output=avail / | tail -n 1 | tr -d 'G')

if [ "$AVAILABLE_SPACE" -lt "$SPACE_NEEDED" ]; then
    print_error "Espaço insuficiente em disco. Necessário: ${SPACE_NEEDED}GB, Disponível: ${AVAILABLE_SPACE}GB"
    exit 1
fi

# Detectar distribuição Linux
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION_ID=$VERSION_ID
    print_info "Distribuição detectada: $DISTRO $VERSION_ID"
else
    print_warning "Não foi possível detectar a distribuição Linux."
    echo "Você deseja continuar com a instalação? [s/N]"
    read -r response
    if [[ ! "$response" =~ ^([sS]|[sS][iI][mM])$ ]]; then
        print_info "Instalação cancelada pelo usuário."
        exit 0
    fi
    DISTRO="generic"
fi

# Diretório temporário para trabalho
TEMP_DIR=$(mktemp -d)
print_info "Diretório temporário: $TEMP_DIR"
cd $TEMP_DIR

# Diretório para o AppImage
APPDIR="${TEMP_DIR}/WaydroidAppImage.AppDir"
mkdir -p "${APPDIR}"

# Função para instalar dependências de acordo com a distribuição
install_dependencies() {
    print_info "Instalando dependências necessárias..."
    
    # Dependências comuns
    COMMON_DEPS="curl wget git lsb-release software-properties-common python3 python3-pip"
    
    # Dependências específicas para o AppImage
    APPIMAGE_DEPS="cmake build-essential libglib2.0-dev libfuse-dev"
    
    # Instalar de acordo com a distribuição
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            apt-get update
            apt-get install -y $COMMON_DEPS $APPIMAGE_DEPS
            apt-get install -y dbus systemd systemd-container lxc python3-gi python3-gi-cairo \
                                gobject-introspection gir1.2-gtk-3.0 policykit-1 \
                                libgbinder-dev libglibutil-dev
            ;;
        fedora|centos|rhel)
            dnf install -y $COMMON_DEPS $APPIMAGE_DEPS
            dnf install -y dbus systemd systemd-container lxc python3-gobject python3-cairo \
                          gobject-introspection gtk3 polkit
            ;;
        arch|manjaro|endeavouros)
            pacman -Sy --noconfirm
            pacman -S --noconfirm $COMMON_DEPS $APPIMAGE_DEPS
            pacman -S --noconfirm dbus systemd systemd-container lxc python-gobject python-cairo \
                                  gobject-introspection gtk3 polkit
            ;;
        *)
            print_warning "Distribuição não reconhecida. Tentando instalar dependências genéricas..."
            print_warning "Você pode precisar instalar manualmente algumas dependências."
            ;;
    esac
    
    # Instalar appimagetool
    print_info "Instalando appimagetool..."
    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool
    chmod +x /usr/local/bin/appimagetool
    
    print_success "Dependências instaladas com sucesso."
}

# Instalar o Waydroid
install_waydroid() {
    print_info "Instalando Waydroid..."
    
    # Clone o repositório do Waydroid
    git clone https://github.com/waydroid/waydroid.git
    cd waydroid
    
    # Instalar o Waydroid
    pip3 install --user .
    
    # Copiar os arquivos necessários para o AppDir
    mkdir -p "${APPDIR}/usr/bin"
    mkdir -p "${APPDIR}/usr/lib/waydroid"
    mkdir -p "${APPDIR}/usr/share/waydroid"
    mkdir -p "${APPDIR}/etc/waydroid"
    mkdir -p "${APPDIR}/var/lib/waydroid"
    
    # Copiar arquivos executáveis e bibliotecas
    cp -r ./tools "${APPDIR}/usr/lib/waydroid/"
    cp -r ./data "${APPDIR}/usr/share/waydroid/"
    cp ./waydroid.py "${APPDIR}/usr/lib/waydroid/"
    
    print_success "Waydroid instalado com sucesso."
}

# Configurar os componentes necessários para o Waydroid
configure_waydroid() {
    print_info "Configurando componentes adicionais do Waydroid..."
    
    # Criar scripts auxiliares
    cat > "${APPDIR}/usr/bin/waydroid" << 'EOF'
#!/bin/bash
export PYTHONPATH="${APPDIR}/usr/lib:${PYTHONPATH}"
export XDG_DATA_DIRS="${APPDIR}/usr/share:${XDG_DATA_DIRS}"
export LD_LIBRARY_PATH="${APPDIR}/usr/lib:${LD_LIBRARY_PATH}"

# Verificar se o módulo do kernel binder está carregado
if ! lsmod | grep -q binder; then
    echo "Carregando módulo binder_linux..."
    sudo modprobe binder_linux
fi

# Iniciar o Waydroid
python3 "${APPDIR}/usr/lib/waydroid/waydroid.py" "$@"
EOF

    chmod +x "${APPDIR}/usr/bin/waydroid"
    
    # Criar o arquivo AppRun para o AppImage
    cat > "${APPDIR}/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}

export PATH="${HERE}/usr/bin:${PATH}"
export PYTHONPATH="${HERE}/usr/lib:${PYTHONPATH}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"

# Verificar dependências
if ! command -v lxc > /dev/null; then
    echo "ERRO: LXC não encontrado. Por favor, instale-o antes de executar o Waydroid."
    exit 1
fi

# Verificar se systemd está em execução
if ! systemctl --version > /dev/null 2>&1; then
    echo "ERRO: systemd não encontrado. O Waydroid requer systemd."
    exit 1
fi

# Executar o comando waydroid
exec "${HERE}/usr/bin/waydroid" "$@"
EOF

    chmod +x "${APPDIR}/AppRun"
    
    # Criar estrutura de diretórios necessários
    mkdir -p "${APPDIR}/usr/share/applications"
    mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"
    
    # Criar o arquivo .desktop
    cat > "${APPDIR}/usr/share/applications/waydroid.desktop" << 'EOF'
[Desktop Entry]
Name=Waydroid
Comment=Android in a container
Exec=waydroid
Icon=waydroid
Terminal=true
Type=Application
Categories=Utility;System;
EOF

    # Criar link simbólico para o .desktop na raiz do AppDir
    ln -sf ./usr/share/applications/waydroid.desktop "${APPDIR}/waydroid.desktop"
    
    # Baixar ícone para Waydroid
    wget -O "${APPDIR}/usr/share/icons/hicolor/256x256/apps/waydroid.png" \
        "https://raw.githubusercontent.com/waydroid/waydroid/main/data/icons/hicolor/256x256/apps/waydroid.png"
    
    # Criar link simbólico para o ícone na raiz do AppDir
    ln -sf ./usr/share/icons/hicolor/256x256/apps/waydroid.png "${APPDIR}/waydroid.png"
    
    print_success "Configuração concluída com sucesso."
}

# Coletar dependências dinâmicas
collect_dependencies() {
    print_info "Coletando bibliotecas e dependências dinâmicas..."
    
    # Criar diretório para bibliotecas
    mkdir -p "${APPDIR}/usr/lib"
    
    # Lista de executáveis e bibliotecas a serem verificados
    EXECS=("${APPDIR}/usr/bin/waydroid")
    
    # Função para coletar bibliotecas
    collect_libs() {
        local binary="$1"
        ldd "$binary" | grep '=>' | awk '{print $3}' | sort | uniq | while read lib; do
            if [ -f "$lib" ] && [ ! -f "${APPDIR}/usr/lib/$(basename $lib)" ]; then
                cp "$lib" "${APPDIR}/usr/lib/"
                collect_libs "$lib"
            fi
        done
    }
    
    # Processar cada executável
    for exec_file in "${EXECS[@]}"; do
        if [ -f "$exec_file" ]; then
            collect_libs "$exec_file"
        fi
    done
    
    # Copiar Python e bibliotecas necessárias
    PYTHON_LIB_DIR=$(python3 -c "import sysconfig; print(sysconfig.get_path('purelib'))")
    mkdir -p "${APPDIR}/usr/lib/python3/site-packages"
    cp -r "$PYTHON_LIB_DIR"/* "${APPDIR}/usr/lib/python3/site-packages/"
    
    print_success "Dependências coletadas com sucesso."
}

# Criar o AppImage
create_appimage() {
    print_info "Criando AppImage..."
    
    cd "${TEMP_DIR}"
    
    # Criar o AppImage
    ARCH=$(uname -m)
    appimagetool "${APPDIR}" "Waydroid-${ARCH}.AppImage"
    
    # Mover o AppImage para o diretório atual
    mv "Waydroid-${ARCH}.AppImage" "${PWD}/Waydroid-${ARCH}.AppImage"
    chmod +x "${PWD}/Waydroid-${ARCH}.AppImage"
    
    print_success "AppImage criado com sucesso: ${PWD}/Waydroid-${ARCH}.AppImage"
}

# Função principal
main() {
    print_info "Iniciando processo de instalação do Waydroid e criação do AppImage..."
    
    # Instalar Waydroid
    install_waydroid
    
    # Configurar componentes
    configure_waydroid
    
    # Coletar dependências dinâmicas
    collect_dependencies
    
    # Criar o AppImage
    create_appimage
    
    print_success "Processo concluído com sucesso!"
    print_info "Você pode executar o Waydroid usando: ./Waydroid-$(uname -m).AppImage"
    
    # Limpeza
    print_info "Removendo arquivos temporários..."
    rm -rf "${TEMP_DIR}"
    
    print_success "Limpeza concluída."
}

# Executar função principal
main

exit 0
