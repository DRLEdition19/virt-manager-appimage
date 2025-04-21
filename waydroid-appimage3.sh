#!/bin/bash
set -e

#############################################
# Script para instalar o Waydroid e converter #
# para AppImage, empacotando todas as dependências #
#############################################

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, execute este script como root (ex.: sudo ./instala_waydroid_appimage.sh)"
    exit 1
fi

echo "=============================================="
echo "Atualizando repositórios e instalando dependências básicas..."
echo "=============================================="
apt-get update
apt-get install -y curl wget lxc bsdtar squashfs-tools

# Se o ImageMagick não estiver instalado, recomendamos instalá-lo (necessário para criar um ícone placeholder se necessário)
if ! command -v convert &> /dev/null; then
    echo "ImageMagick não encontrado. Instalando imagemagick para criação de ícone placeholder..."
    apt-get install -y imagemagick
fi

echo "=============================================="
echo "Adicionando repositório do Waydroid e importando chave GPG..."
echo "=============================================="
curl -s https://repo.waydro.id/waydroid.gpg | apt-key add -
echo "deb https://repo.waydro.id/ bullseye main" > /etc/apt/sources.list.d/waydroid.list
apt-get update

echo "=============================================="
echo "Instalando o Waydroid..."
echo "=============================================="
apt-get install -y waydroid

echo "Waydroid instalado com sucesso!"

echo "=============================================="
echo "Configurando estrutura do AppDir para o AppImage..."
echo "=============================================="
# Cria a estrutura básica do AppImage
mkdir -p AppDir/usr/bin

# Copia o executável do Waydroid (ajuste o caminho se necessário)
if [ -f /usr/bin/waydroid ]; then
    cp /usr/bin/waydroid AppDir/usr/bin/
else
    echo "O binário do Waydroid não foi encontrado em /usr/bin/waydroid. Verifique a instalação."
    exit 1
fi

# Cria o arquivo AppRun que servirá de entrypoint para o AppImage
cat << 'EOF' > AppDir/AppRun
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
# Executa o Waydroid a partir da pasta empacotada
exec "$HERE/usr/bin/waydroid" "$@"
EOF
chmod +x AppDir/AppRun

# Cria o arquivo desktop (necessário para que o linuxdeploy configure corretamente o AppImage)
cat << 'EOF' > waydroid.desktop
[Desktop Entry]
Type=Application
Name=Waydroid
Exec=waydroid
Icon=waydroid
Terminal=false
Categories=Utility;
EOF

echo "=============================================="
echo "Baixando ícone para o Waydroid..."
echo "=============================================="
# Tenta baixar um ícone do repositório do Waydroid; se falhar, cria um placeholder
wget -O waydroid.png "https://raw.githubusercontent.com/waydroid/waydroid/master/waydroid.png" || echo "Ícone não encontrado. Será gerado um placeholder."
if [ ! -f waydroid.png ] || [ ! -s waydroid.png ]; then
    echo "Gerando ícone placeholder..."
    convert -size 128x128 xc:gray waydroid.png
fi

echo "=============================================="
echo "Baixando o linuxdeploy AppImage..."
echo "=============================================="
wget -O linuxdeploy.AppImage "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
chmod +x linuxdeploy.AppImage

echo "=============================================="
echo "Gerando o AppImage do Waydroid..."
echo "=============================================="
# O linuxdeploy irá empacotar o AppDir, pegando as dependências detectadas
./linuxdeploy.AppImage --appdir AppDir --desktop-file waydroid.desktop --icon-file waydroid.png --output appimage

echo "=============================================="
echo "AppImage gerado com sucesso! Verifique o arquivo *.AppImage na pasta."
echo "=============================================="
