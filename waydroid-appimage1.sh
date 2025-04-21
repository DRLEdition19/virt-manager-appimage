#!/usr/bin/env bash
set -e

# Variáveis
BUILD_DIR="$HOME/waydroid_appimage_build"
APPDIR="$BUILD_DIR/Waydroid.AppDir"
APPIMAGE="$BUILD_DIR/Waydroid.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

# 1. Cria diretórios de build e AppDir
mkdir -p "$APPDIR/usr/"{bin,lib,share}             # estrutura AppDir básica :contentReference[oaicite:7]{index=7}

# 2. Instala pré-requisitos globais
sudo apt update
sudo apt install -y curl ca-certificates lxc wget \
                   gnupg2 squashfs-tools xz-utils \
                   apt-rdepends                    # ferramentas de download e empacotamento :contentReference[oaicite:8]{index=8}

# 3. Adiciona repositório oficial do Waydroid e instala o pacote
curl -s https://repo.waydro.id | sudo bash -s -- -s "$(lsb_release -cs)"  # script oficial de repositório :contentReference[oaicite:9]{index=9}
sudo apt update
sudo apt download waydroid                         # baixa .deb sem instalar :contentReference[oaicite:10]{index=10}

# 4. Baixa todas as dependências recursivamente
DEPS=$(apt-rdepends waydroid | grep -Ev "^\s" | grep -v waydroid)
mkdir -p "$BUILD_DIR/debs"
cd "$BUILD_DIR/debs"
for pkg in $DEPS; do
    apt download "$pkg"                            # baixa cada dependência :contentReference[oaicite:11]{index=11}
done

# 5. Extrai todos os .deb para o AppDir
cd "$BUILD_DIR"
for deb in debs/*.deb; do
    ar x "$deb"                                    # extrai control.tar*, data.tar* :contentReference[oaicite:12]{index=12}
    tar -xf data.tar.* -C "$APPDIR"                # coloca arquivos no AppDir :contentReference[oaicite:13]{index=13}
    rm control.tar.* data.tar.* debian-binary
done

# 6. Cria o launcher AppRun
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:$LD_LIBRARY_PATH"
exec "$HERE/usr/bin/waydroid" "$@"
EOF
chmod +x "$APPDIR/AppRun"                          # AppRun é entrada principal conforme spec :contentReference[oaicite:14]{index=14}

# 7. Cria arquivo .desktop e copia ícone
cat > "$APPDIR/waydroid.desktop" << 'EOF'
[Desktop Entry]
Name=Waydroid
Exec=Waydroid
Icon=waydroid
Type=Application
Categories=Utility;
EOF
cp /usr/share/icons/hicolor/256x256/apps/waydroid.png "$APPDIR/"  # ícone padrão :contentReference[oaicite:15]{index=15}

# 8. Baixa e prepara o appimagetool
wget -O "$BUILD_DIR/appimagetool.AppImage" "$APPIMAGETOOL_URL"     # ferramenta de empacotamento :contentReference[oaicite:16]{index=16}
chmod +x "$BUILD_DIR/appimagetool.AppImage"

# 9. Gera o AppImage final
"$BUILD_DIR/appimagetool.AppImage" "$APPDIR"                        # converte AppDir em AppImage :contentReference[oaicite:17]{index=17}

echo "AppImage gerado em: $BUILD_DIR"
