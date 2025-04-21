#!/bin/bash

# Script para instalar o Waydroid e convertê-lo em AppImage
# Este script instala o Waydroid e cria um AppImage compatível com qualquer distribuição Linux

set -e  # Sai em caso de erro

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para exibir mensagens de status
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Função para exibir mensagens de erro
error() {
    echo -e "${RED}[ERRO]${NC} $1"
    exit 1
}

# Função para exibir mensagens de sucesso
success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

# Função para exibir mensagens de aviso
warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verificar se está rodando como root
if [ "$(id -u)" -ne 0 ]; then
    error "Este script precisa ser executado como root. Use 'sudo $0'"
fi

# Detectar sistema operacional
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        log "Sistema operacional detectado: $OS"
    else
        error "Não foi possível detectar o sistema operacional"
    fi
}

# Verificar dependências essenciais
check_dependencies() {
    local deps=("wget" "git" "curl" "tar" "rsync" "fuse" "squashfs-tools" "libfuse2" "python3" "pip" "lxc" "libgbinder" "linux-modules-extra" "binutils")
    log "Verificando dependências essenciais..."
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null && ! dpkg -l | grep -q $dep; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        warning "As seguintes dependências estão faltando: ${missing_deps[*]}"
        install_dependencies
    else
        log "Todas as dependências essenciais estão instaladas."
    fi
}

# Instalar dependências com base na distribuição
install_dependencies() {
    log "Instalando dependências necessárias..."
    
    case $ID in
        ubuntu|debian|linuxmint|pop|elementary|zorin)
            apt-get update
            apt-get install -y wget git curl tar rsync squashfs-tools build-essential libfuse2 fuse python3 python3-pip \
                lxc libgbinder-dev linux-modules-extra-$(uname -r) binutils policykit-1 wayland-utils \
                libgl1 libgles2 zlib1g-dev libavcodec-dev libffi-dev libdrm-dev libsystemd-dev
            ;;
        fedora|rhel|centos)
            dnf install -y wget git curl tar rsync squashfs-tools fuse fuse-libs libfuse2 python3 python3-pip \
                lxc libgbinder kernel-modules-extra binutils polkit wayland-utils libglvnd libglvnd-gles \
                zlib-devel ffmpeg-devel libffi-devel libdrm-devel systemd-devel
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm wget git curl tar rsync squashfs-tools fuse2 fuse3 python python-pip \
                lxc gbinder extra-modules binutils polkit wayland-utils libglvnd zlib ffmpeg libffi libdrm systemd
            ;;
        opensuse*|suse*)
            zypper install -y wget git curl tar rsync squashfs fuse fuse2 python3 python3-pip \
                lxc libgbinder kernel-default-extra binutils polkit wayland-utils libglvnd zlib-devel \
                ffmpeg-devel libffi-devel libdrm-devel systemd-devel
            ;;
        *)
            warning "Distribuição não reconhecida. Tentando instalar dependências manualmente..."
            # Tentar instalar com apt, se disponível
            if command -v apt-get &> /dev/null; then
                apt-get update
                apt-get install -y wget git curl tar rsync squashfs-tools fuse libfuse2 python3 python3-pip \
                    lxc libgbinder-dev linux-modules-extra-$(uname -r) binutils
            else
                error "Não foi possível instalar dependências automaticamente. Por favor, instale manualmente: wget git curl tar rsync squashfs-tools fuse libfuse2 python3 python3-pip lxc libgbinder"
            fi
            ;;
    esac
    
    log "Dependências instaladas com sucesso."
}

# Instalar o appimage-builder
install_appimage_builder() {
    log "Instalando appimage-builder..."
    
    pip3 install --upgrade appimage-builder
    
    if ! command -v appimage-builder &> /dev/null; then
        error "Falha ao instalar appimage-builder"
    fi
    
    log "appimage-builder instalado com sucesso."
}

# Instalar o Waydroid
install_waydroid() {
    log "Instalando o Waydroid..."
    
    # Criar diretório temporário
    mkdir -p /tmp/waydroid_install
    cd /tmp/waydroid_install
    
    # Clonar o repositório Waydroid
    git clone https://github.com/waydroid/waydroid.git
    cd waydroid
    
    # Instalar o Waydroid
    pip3 install --user .
    
    # Criar diretórios de configuração
    mkdir -p /etc/waydroid
    
    # Instalar scripts e binários
    cp -r data/* /usr/share/
    cp tools/waydroid-launcher.desktop /usr/share/applications/
    cp tools/waydroid.desktop /usr/share/applications/
    cp tools/waydroid.png /usr/share/icons/hicolor/256x256/apps/
    
    # Instalar o serviço systemd se disponível
    if [ -d "/etc/systemd/system" ]; then
        cp debian/waydroid-container.service /etc/systemd/system/
        systemctl enable waydroid-container
    fi
    
    # Verificar a instalação
    if ! command -v waydroid &> /dev/null; then
        # Se não estiver no PATH, criar um link simbólico
        ln -sf ~/.local/bin/waydroid /usr/local/bin/waydroid
    fi
    
    log "Waydroid instalado com sucesso."
}

# Inicializar o Waydroid para baixar imagens do sistema Android
init_waydroid() {
    log "Inicializando o Waydroid e baixando imagens do sistema Android..."
    
    # Inicializar waydroid com imagem GAPPS
    waydroid init -s GAPPS
    
    # Verificar se a inicialização foi bem-sucedida
    if [ ! -f "/var/lib/waydroid/waydroid_base.prop" ]; then
        error "Falha na inicialização do Waydroid"
    fi
    
    log "Waydroid inicializado com sucesso."
}

# Criar a estrutura do AppImage
create_appimage_structure() {
    log "Criando estrutura do AppImage..."
    
    # Criar diretório para o AppImage
    mkdir -p /tmp/WaydroidAppDir
    cd /tmp/WaydroidAppDir
    
    # Criar diretório AppDir
    mkdir -p AppDir
    
    # Copiar arquivos do Waydroid para o AppDir
    mkdir -p AppDir/usr/bin
    mkdir -p AppDir/usr/share
    mkdir -p AppDir/usr/lib
    mkdir -p AppDir/etc/waydroid
    mkdir -p AppDir/var/lib/waydroid
    
    # Copiar binários e scripts
    cp $(which waydroid) AppDir/usr/bin/
    cp $(which python3) AppDir/usr/bin/
    cp -r /usr/share/waydroid AppDir/usr/share/
    cp -r /usr/share/applications/waydroid*.desktop AppDir/usr/share/applications/
    cp -r /usr/share/icons/hicolor/256x256/apps/waydroid.png AppDir/waydroid.png
    
    # Copiar configurações do Waydroid
    cp -r /etc/waydroid/* AppDir/etc/waydroid/
    
    # Copiar imagens do sistema Android
    cp -r /var/lib/waydroid/* AppDir/var/lib/waydroid/
    
    # Copiar bibliotecas necessárias
    ldd $(which waydroid) | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' AppDir/usr/lib/
    ldd $(which python3) | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' AppDir/usr/lib/
    
    # Copiar módulos Python necessários
    mkdir -p AppDir/usr/lib/python3/dist-packages
    cp -r /usr/lib/python3/dist-packages/waydroid* AppDir/usr/lib/python3/dist-packages/
    
    # Copiar dependências adicionais
    if [ -d "/usr/lib/gbinder" ]; then
        mkdir -p AppDir/usr/lib/gbinder
        cp -r /usr/lib/gbinder/* AppDir/usr/lib/gbinder/
    fi
    
    # Criar arquivo AppRun
    cat > AppDir/AppRun << 'EOL'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export PYTHONPATH="${HERE}/usr/lib/python3/dist-packages:${PYTHONPATH}"

# Configurar variáveis de ambiente do Waydroid
export WAYDROID_DATA_DIR="${HERE}/var/lib/waydroid"
export WAYDROID_CONFIG_DIR="${HERE}/etc/waydroid"

# Executar o Waydroid
exec "${HERE}/usr/bin/waydroid" "$@"
EOL
    
    # Tornar o AppRun executável
    chmod +x AppDir/AppRun
    
    # Criar arquivo desktop para o AppImage
    cat > AppDir/waydroid.desktop << EOL
[Desktop Entry]
Name=Waydroid
GenericName=Android Runtime
Comment=Android Runtime Container
Exec=waydroid
Icon=waydroid
Terminal=true
Type=Application
Categories=System;Emulator;
EOL
    
    log "Estrutura do AppImage criada com sucesso."
}

# Gerar o AppImage
generate_appimage() {
    log "Gerando o AppImage..."
    
    cd /tmp/WaydroidAppDir
    
    # Criar arquivo de configuração para o appimage-builder
    cat > appimage-builder.yml << EOL
version: 1
script:
  - rm -rf AppDir || true
  - cp -r AppDir/ AppDir/
AppDir:
  path: ./AppDir
  app_info:
    id: org.waydroid.Waydroid
    name: Waydroid
    icon: waydroid
    version: 1.0.0
    exec: usr/bin/waydroid
  apt:
    arch: amd64
    sources:
      - sourceline: 'deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse'
    include:
      - python3
      - libfuse2
      - lxc
  runtime:
    env:
      WAYDROID_DATA_DIR: '${APPDIR}/var/lib/waydroid'
      WAYDROID_CONFIG_DIR: '${APPDIR}/etc/waydroid'
      PYTHONPATH: '${APPDIR}/usr/lib/python3/dist-packages:${PYTHONPATH}'
AppImage:
  arch: x86_64
  update-information: None
  sign-key: None
EOL
    
    # Compilar o AppImage
    appimage-builder --recipe appimage-builder.yml --skip-tests
    
    # Mover o AppImage para o diretório do usuário
    mkdir -p ~/WaydroidAppImage
    mv *.AppImage ~/WaydroidAppImage/Waydroid-x86_64.AppImage
    chmod +x ~/WaydroidAppImage/Waydroid-x86_64.AppImage
    
    success "AppImage do Waydroid criado com sucesso em ~/WaydroidAppImage/Waydroid-x86_64.AppImage"
}

# Função de limpeza
cleanup() {
    log "Limpando arquivos temporários..."
    rm -rf /tmp/waydroid_install
    rm -rf /tmp/WaydroidAppDir
    log "Limpeza concluída."
}

# Função principal
main() {
    log "Iniciando o processo de criação do AppImage do Waydroid..."
    
    check_os
    check_dependencies
    install_appimage_builder
    install_waydroid
    init_waydroid
    create_appimage_structure
    generate_appimage
    cleanup
    
    success "Processo concluído com sucesso! O AppImage do Waydroid está pronto para uso."
    success "Localização do AppImage: ~/WaydroidAppImage/Waydroid-x86_64.AppImage"
    
    warning "IMPORTANTE: O AppImage do Waydroid requer privilégios de root para funcionar corretamente."
    warning "Use 'sudo ~/WaydroidAppImage/Waydroid-x86_64.AppImage' para executá-lo."
}

# Executar a função principal
main
