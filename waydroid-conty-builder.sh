#!/bin/bash

set -e

# Nome do aplicativo e versão
APP_NAME="Waydroid"
APP_VERSION="1.0"

# Diretório temporário de trabalho
WORKDIR=$(mktemp -d)
APPDIR="$WORKDIR/$APP_NAME.AppDir"

# Dependências necessárias
# DEPENDENCIES="squashfs-tools wget curl fuse"

# Certifique-se de que todas as dependências estão instaladas
for dep in $DEPENDENCIES; do
    if ! command -v $dep &> /dev/null; then
        echo "Erro: $dep não está instalado. Instale-o antes de continuar."
        exit 1
    fi
done

# Criação do AppDir
mkdir -p "$APPDIR"

echo "Baixando Waydroid..."
# Aqui você pode substituir pela URL oficial ou repositório do Waydroid
WAYDROID_URL="https://github.com/waydroid/waydroid/archive/refs/tags/1.5.1.tar.gz"
wget -O "$WORKDIR/waydroid.tar.gz" "$WAYDROID_URL"

echo "Extraindo Waydroid..."
tar -xzf "$WORKDIR/waydroid.tar.gz" -C "$APPDIR"

echo "Criando arquivo AppRun..."
cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE=\$(dirname "\$(readlink -f "\$0")")
export PATH="\$HERE/usr/bin:\$PATH"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$LD_LIBRARY_PATH"
exec \$HERE/usr/bin/waydroid "\$@"
EOF

chmod +x "$APPDIR/AppRun"

echo "Adicionando ícone e metadados..."
# Substitua pelo ícone do Waydroid
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/waydroid.png" "$APPDIR/$APP_NAME.png"

cat > "$APPDIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec=waydroid
Icon=$APP_NAME
Categories=Utility;
EOF

echo "Gerando AppImage..."
APPIMAGE_TOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
wget -O "$WORKDIR/appimagetool" "$APPIMAGE_TOOL_URL"
chmod +x "$WORKDIR/appimagetool"

"$WORKDIR/appimagetool" "$APPDIR" "$WORKDIR/$APP_NAME-$APP_VERSION-x86_64.AppImage"

echo "Movendo AppImage para o diretório atual..."
mv "$WORKDIR/$APP_NAME-$APP_VERSION-x86_64.AppImage" .

echo "Limpando arquivos temporários..."
rm -rf "$WORKDIR"

echo "AppImage criado com sucesso: ./$APP_NAME-$APP_VERSION-x86_64.AppImage"
