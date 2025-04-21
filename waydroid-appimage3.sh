#!/usr/bin/env bash
# build_waydroid_appimage.sh
# Script para instalar Waydroid dentro de um sandbox (junest) e empacotar como AppImage
# Não requer acesso root; toda instalação ocorre em uma pasta no home do usuário.

set -euo pipefail
IFS=$'\n\t'

# Configurações iniciais
overwrite=false
BASE_DIR="$HOME/waydroid_appimage_build"
JUNEST_DIR="$BASE_DIR/junest"
PREFIX="$JUNEST_DIR/rootfs"
APPDIR="$BASE_DIR/Waydroid.AppDir"
OUTPUT="$BASE_DIR/Waydroid-x86_64.AppImage"
APPIMAGETOOL="$BASE_DIR/appimagetool"

# Função para log
log() {
    echo -e "[\033[1;34mINFO\033[0m] $*"
}

# Criar diretórios de trabalho
log "Criando diretórios de trabalho em $BASE_DIR"
mkdir -p "$BASE_DIR"
mkdir -p "$JUNEST_DIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons"

# Baixar e configurar junest
if [[ ! -x "$HOME/.local/bin/junest" ]]; then
    log "Instalando junest localmente"
    git clone https://github.com/Easi/junest.git "$JUNEST_DIR/junest"
    ln -sf "$JUNEST_DIR/junest/junest" "$HOME/.local/bin/junest"
else
    log "Junest já instalado"
fi

# Inicializar junest e sincronizar pacman
log "Inicializando junest e sincronizando pacman"
junest -u

# Instalar Waydroid e dependências dentro do sandbox
log "Instalando Waydroid e dependências"
junest pacman -Sy --noconfirm waydroid

# Criar AppDir: copiar executáveis e libs de Waydroid
log "Copiando arquivos do sandbox para AppDir"
# Localizar binários
BINARIES=("waydroid" "waydroid-container" "waydroid-session"")
for bin in "${BINARIES[@]}"; do
    src="$PREFIX/usr/bin/$bin"
    if [[ -f "$src" ]]; then
        cp -a "$src" "$APPDIR/usr/bin/"
    else
        log "Aviso: binário $bin não encontrado em $src"
    fi
done

# Copiar bibliotecas necessárias (ldd)
log "Detectando e copiando dependências de bibliotecas"
for bin in "$APPDIR/usr/bin/"*; do
    ldd "$bin" | grep '=> /' | awk '{print \$3}' | while read -r lib; do
        dest="$APPDIR/usr/lib/$(basename "$lib")"
        [[ -f "$dest" ]] || cp -a "$lib" "$dest"
    done
done

# Arquivos de dados (system files, configs)
log "Copiando arquivos de dados e ícones"
cp -a "$PREFIX/usr/share/waydroid" "$APPDIR/usr/share/" 2>/dev/null || log "Pasta waydroid em share não encontrada"
cp -a "$PREFIX/usr/share/icons/hicolor" "$APPDIR/usr/share/icons/" 2>/dev/null || true

# Download appimagetool se necessário
if [[ ! -x "$APPIMAGETOOL" ]]; then
    log "Baixando appimagetool"
    curl -L -o "$APPIMAGETOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$APPIMAGETOOL"
fi

# Criar arquivo desktop
cat > "$APPDIR/Waydroid.desktop" <<EOF
[Desktop Entry]
Name=Waydroid
Exec=waydroid session start
Icon=waydroid
Type=Application
Categories=Utility;
EOF

# Empacotar como AppImage
log "Empacotando AppImage"
"$APPIMAGETOOL" "$APPDIR" "$OUTPUT"

log "Concluído! AppImage disponível em: $OUTPUT"
