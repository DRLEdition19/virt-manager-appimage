#!/bin/bash

# Script para instalação do Genymotion e conversão em AppImage
# Criado em: 20/04/2025

# Definição de cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens de log
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Função para exibir mensagens de sucesso
success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

# Função para exibir mensagens de aviso
warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Função para exibir mensagens de erro
error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para verificar se o comando foi executado com sucesso
check_success() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$2"
        exit 1
    fi
}

# Verificar se está executando como root
if [ "$EUID" -ne 0 ]; then
    error "Este script precisa ser executado como root (use sudo)"
    exit 1
fi

# Verificar se o sistema é Linux
if [ "$(uname)" != "Linux" ]; then
    error "Este script só funciona em sistemas Linux"
    exit 1
fi

# Criar diretório de trabalho
WORK_DIR="/tmp/genymotion-appimage"
log "Criando diretório de trabalho: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1

# Detectar distribuição Linux
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    log "Distribuição detectada: $DISTRO"
else
    DISTRO="unknown"
    warning "Não foi possível detectar a distribuição Linux"
fi

# Instalar dependências necessárias
log "Instalando dependências..."
case $DISTRO in
    ubuntu|debian|linuxmint|pop)
        apt-get update
        apt-get install -y wget curl libglu1-mesa qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
            virtualbox virtualbox-qt virtualbox-dkms libappimage-dev cmake build-essential patchelf libssl-dev \
            python3 python3-pip fuse libfuse2 zsync
        check_success "Dependências instaladas com sucesso!" "Falha ao instalar dependências"
        ;;
    fedora)
        dnf -y install wget curl mesa-libGLU qemu-kvm libvirt virt-install bridge-utils \
            VirtualBox cmake gcc-c++ patchelf openssl-devel python3 python3-pip fuse libfuse2 zsync
        check_success "Dependências instaladas com sucesso!" "Falha ao instalar dependências"
        ;;
    arch|manjaro)
        pacman -Sy --noconfirm wget curl mesa qemu libvirt virt-manager bridge-utils \
            virtualbox cmake gcc patchelf openssl python python-pip fuse2 zsync
        check_success "Dependências instaladas com sucesso!" "Falha ao instalar dependências"
        ;;
    *)
        warning "Distribuição não reconhecida. Tentando instalar dependências genéricas..."
        # Tentar instalar com apt, se disponível
        if command -v apt-get >/dev/null; then
            apt-get update
            apt-get install -y wget curl libglu1-mesa qemu-kvm libvirt-daemon-system libvirt-clients \
                bridge-utils virtualbox virtualbox-qt virtualbox-dkms libappimage-dev cmake \
                build-essential patchelf libssl-dev python3 python3-pip fuse libfuse2 zsync
        # Tentar com dnf, se disponível
        elif command -v dnf >/dev/null; then
            dnf -y install wget curl mesa-libGLU qemu-kvm libvirt virt-install bridge-utils \
                VirtualBox cmake gcc-c++ patchelf openssl-devel python3 python3-pip fuse libfuse2 zsync
        # Tentar com pacman, se disponível
        elif command -v pacman >/dev/null; then
            pacman -Sy --noconfirm wget curl mesa qemu libvirt virt-manager bridge-utils \
                virtualbox cmake gcc patchelf openssl python python-pip fuse2 zsync
        else
            error "Não foi possível instalar as dependências. Por favor, instale manualmente."
            exit 1
        fi
        ;;
esac

# Verificar se o módulo do kernel do VirtualBox está carregado
log "Verificando módulo do kernel do VirtualBox..."
if ! lsmod | grep -q "vboxdrv"; then
    log "Carregando o módulo do VirtualBox..."
    modprobe vboxdrv
    check_success "Módulo do VirtualBox carregado com sucesso!" "Falha ao carregar o módulo do VirtualBox"
fi

# Adicionar o usuário atual aos grupos necessários
log "Adicionando o usuário aos grupos necessários..."
usermod -a -G vboxusers,kvm,libvirt "$(logname)"
check_success "Usuário adicionado aos grupos com sucesso!" "Falha ao adicionar o usuário aos grupos"

# Download da versão mais recente do Genymotion
log "Baixando Genymotion..."
GENYMOTION_URL="https://dl.genymotion.com/releases/genymotion-3.5.0/genymotion-3.5.0-linux_x64.bin"
wget -O genymotion.bin "$GENYMOTION_URL"
check_success "Download do Genymotion concluído!" "Falha ao baixar o Genymotion"

# Tornar o instalador executável
chmod +x genymotion.bin
check_success "Permissões do instalador configuradas!" "Falha ao definir permissões do instalador"

# Instalar o Genymotion em um diretório temporário
INSTALL_DIR="$WORK_DIR/genymotion_install"
mkdir -p "$INSTALL_DIR"
log "Instalando Genymotion em $INSTALL_DIR..."
./genymotion.bin -y -d "$INSTALL_DIR"
check_success "Genymotion instalado com sucesso!" "Falha ao instalar o Genymotion"

# Baixar e configurar o linuxdeploy para criar o AppImage
log "Baixando linuxdeploy para criar o AppImage..."
wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" -O linuxdeploy.AppImage
chmod +x linuxdeploy.AppImage
check_success "linuxdeploy baixado com sucesso!" "Falha ao baixar o linuxdeploy"

# Criar estrutura de diretórios para o AppImage
APP_DIR="$WORK_DIR/AppDir"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/scalable/apps"

# Copiar arquivos do Genymotion para a estrutura do AppImage
log "Copiando arquivos do Genymotion para a estrutura do AppImage..."
cp -r "$INSTALL_DIR/"* "$APP_DIR/usr/"

# Criar arquivo .desktop para o Genymotion
log "Criando arquivo .desktop..."
cat > "$APP_DIR/usr/share/applications/genymotion.desktop" << EOF
[Desktop Entry]
Name=Genymotion
Comment=Android Emulator
Exec=genymotion
Icon=genymotion
Terminal=false
Type=Application
Categories=Development;Emulator;
EOF

# Copiar ícone
if [ -f "$INSTALL_DIR/icons/icon.png" ]; then
    cp "$INSTALL_DIR/icons/icon.png" "$APP_DIR/usr/share/icons/hicolor/scalable/apps/genymotion.png"
else
    # Tenta encontrar o ícone em outros locais possíveis
    find "$INSTALL_DIR" -name "*icon*.png" -exec cp {} "$APP_DIR/usr/share/icons/hicolor/scalable/apps/genymotion.png" \; -quit
fi

# Criar script de inicialização para o AppImage
log "Criando script de inicialização..."
cat > "$APP_DIR/AppRun" << 'EOF'
#!/bin/bash
# Obter o diretório onde o AppImage está sendo executado
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"

# Verificar e carregar módulos do kernel necessários
if ! lsmod | grep -q "vboxdrv"; then
    echo "Tentando carregar o módulo vboxdrv..."
    sudo modprobe vboxdrv || echo "Falha ao carregar o módulo vboxdrv. VirtualBox pode não funcionar corretamente."
fi

# Iniciar Genymotion
exec "$HERE/usr/bin/genymotion" "$@"
EOF

chmod +x "$APP_DIR/AppRun"
check_success "Script de inicialização criado com sucesso!" "Falha ao criar o script de inicialização"

# Extrair dependências das bibliotecas do VirtualBox e Genymotion
log "Extraindo dependências..."
mkdir -p "$APP_DIR/usr/lib/virtualbox"
cp -r /usr/lib/virtualbox/* "$APP_DIR/usr/lib/virtualbox/"

# Copiar bibliotecas do sistema necessárias
log "Copiando bibliotecas do sistema necessárias..."
LIBS=(
    "libQtCore.so.4"
    "libQtGui.so.4"
    "libQtNetwork.so.4"
    "libQtOpenGL.so.4"
    "libQtXml.so.4"
    "libGLU.so.1"
    "libvirt.so"
    "libvirtcommon.so"
)

for lib in "${LIBS[@]}"; do
    find /usr/lib -name "$lib*" -exec cp -v {} "$APP_DIR/usr/lib/" \; 2>/dev/null || true
done

# Copiar bibliotecas compartilhadas necessárias usando ldd
log "Analisando e copiando dependências dinâmicas..."

# Função para copiar bibliotecas e suas dependências recursivamente
copy_dependencies() {
    local binary="$1"
    local dest_dir="$2"
    
    # Verificar se o binário existe
    if [ ! -f "$binary" ]; then
        warning "Binário não encontrado: $binary"
        return
    fi
    
    # Usar ldd para listar dependências
    ldd "$binary" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
        # Verificar se a biblioteca já foi copiada
        local basename=$(basename "$lib")
        if [ ! -f "$dest_dir/$basename" ]; then
            cp -v "$lib" "$dest_dir/"
            # Verificar dependências da biblioteca
            copy_dependencies "$lib" "$dest_dir"
        fi
    done
}

# Processar binários principais
for bin in "$APP_DIR/usr/bin/genymotion" "$APP_DIR/usr/bin/genymotion-shell" "$APP_DIR/usr/lib/virtualbox/VirtualBox"; do
    if [ -f "$bin" ]; then
        log "Processando dependências para: $bin"
        copy_dependencies "$bin" "$APP_DIR/usr/lib"
    fi
done

# Utilizar patchelf para corrigir o rpath dos binários
log "Corrigindo rpath dos binários..."
find "$APP_DIR/usr/bin" -type f -executable -exec patchelf --set-rpath '$ORIGIN/../lib:$ORIGIN/../lib/virtualbox' {} \; 2>/dev/null || true

# Criar o AppImage com linuxdeploy
log "Criando AppImage..."
./linuxdeploy.AppImage --appdir="$APP_DIR" --output appimage
check_success "AppImage criado com sucesso!" "Falha ao criar o AppImage"

# Mover o AppImage para o diretório home do usuário
APPIMAGE_FILE=$(find . -name "*.AppImage")
APPIMAGE_DEST_DIR="/home/$(logname)/Desktop"
mkdir -p "$APPIMAGE_DEST_DIR"
cp "$APPIMAGE_FILE" "$APPIMAGE_DEST_DIR/Genymotion.AppImage"
chmod +x "$APPIMAGE_DEST_DIR/Genymotion.AppImage"
chown "$(logname):$(logname)" "$APPIMAGE_DEST_DIR/Genymotion.AppImage"
check_success "AppImage movido para $APPIMAGE_DEST_DIR/Genymotion.AppImage" "Falha ao mover o AppImage"

# Limpeza
log "Realizando limpeza..."
cd /
rm -rf "$WORK_DIR"
check_success "Limpeza concluída!" "Aviso: Falha ao limpar arquivos temporários"

success "========================================================"
success "Instalação concluída com sucesso!"
success "O AppImage do Genymotion está disponível em: $APPIMAGE_DEST_DIR/Genymotion.AppImage"
success "========================================================"

log "Observações importantes:"
log "1. Se o AppImage não iniciar, pode ser necessário carregar o módulo vboxdrv:"
log "   sudo modprobe vboxdrv"
log "2. Para dispositivos virtuais, você pode precisar adicionar seu usuário aos grupos vboxusers e kvm:"
log "   sudo usermod -a -G vboxusers,kvm \$USER"
log "3. Após adicionar aos grupos, pode ser necessário reiniciar o sistema"

exit 0
