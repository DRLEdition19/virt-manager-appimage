#!/usr/bin/env bash

# Nome do aplicativo
APP=waydroid
BIN="waydroid" # Altere se o binário tiver um nome diferente
DEPENDENCES="wayland glibc mesa dconf" # Dependências necessárias para o Waydroid

# Criar e entrar no AppDir
if ! test -f ./appimagetool; then
    wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
    chmod a+x appimagetool
fi
mkdir -p "$APP".AppDir && cd "$APP".AppDir || exit 1

# Configurar o diretório temporário como $HOME
HOME="$(dirname "$(readlink -f $0)")"

# Instalar o JuNest
function _install_junest() {
    git clone https://github.com/fsquillace/junest.git ./.local/share/junest
    wget https://github.com/ivan-hc/junest/releases/download/continuous/junest-x86_64.tar.gz
    ./.local/share/junest/bin/junest setup -i junest-x86_64.tar.gz
    rm -f junest-x86_64.tar.gz
    ./.local/share/junest/bin/junest -- sudo pacman -Syy
    ./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu
}

# Restaurar backups, se necessário
function _restore_junest() {
    cd ..
    rsync -av ./junest-backups/* ./"$APP".AppDir/.junest/
    rsync -av ./stock-cache/* ./"$APP".AppDir/.cache/
    rsync -av ./stock-local/* ./"$APP".AppDir/.local/
    cd ./"$APP".AppDir || exit 1
}

if ! test -d "$HOME/.local/share/junest"; then
    _install_junest
else
    _restore_junest
fi

# Instalar dependências e Waydroid
./.local/share/junest/bin/junest -- yay -Syy
if [ ! -z "$DEPENDENCES" ]; then
    ./.local/share/junest/bin/junest -- yay --noconfirm -S "$DEPENDENCES"
fi
./.local/share/junest/bin/junest -- yay --noconfirm -S "$APP"

# Preparar AppImage
function _prepare_appimage() {
    _add_launcher_and_icon
    _create_AppRun
}

function _add_launcher_and_icon() {
    rm -f ./*.desktop
    LAUNCHER=$(grep -iRl "$BIN" ./.junest/usr/share/applications/* | grep ".desktop" | head -1)
    cp "$LAUNCHER" ./
    ICON=$(grep "Icon=" $LAUNCHER | cut -c 6-)
    cp ./.junest/usr/share/icons/hicolor/*x*/apps/*"$ICON"* ./ 2>/dev/null
}

function _create_AppRun() {
    rm -f ./AppRun
    cat <<-EOL >> ./AppRun
    #!/bin/sh
    HERE="\$(dirname "\$(readlink -f \$0)")"
    export UNION_PRELOAD=\$HERE
    export JUNEST_HOME=\$HERE/.junest
    export PATH=\$HERE/.local/share/junest/bin:\$PATH
    \$HERE/.local/share/junest/bin/junest proot -n --bind=/dev --bind=/sys --bind=/tmp --bind=/proc --bind=/var --bind=/home -- \$BIN "\$@"
EOL
    chmod a+x ./AppRun
}

_prepare_appimage

# Criar o AppImage
cd .. || exit 1
ARCH=x86_64 ./appimagetool --comp zstd "$APP".AppDir
mv ./*.AppImage "$APP"-archimage-x86_64.AppImage
