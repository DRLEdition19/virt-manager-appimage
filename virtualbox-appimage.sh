#!/bin/sh

# NOME DO APLICATIVO
APP=virtualbox
BIN="VirtualBox"                        # executável principal do VirtualBox
DEPENDENCES="virtualbox-host-modules-arch linux-headers dnsmasq vde2 bridge-utils libvirt libvirt-client"  # dependências extras

# ——————————————————————————————————————————————————————————
# BUSCA VERSÃO NO REPOSITÓRIO OFICIAL E NO AUR
# ——————————————————————————————————————————————————————————
# (precisa de uma versão para nomear o AppImage)
rm -f version
for REPO in core extra community multilib; do
    wget -q https://archlinux.org/packages/$REPO/x86_64/$APP/flag/ -O - \
      | grep $APP | grep details \
      | head -1 \
      | grep -oP '(?<=/a> ).*(?= )' \
      | grep -o '^\S*' \
      >> version
done
VERSION=$(grep -w -v "^$" version | head -1)

# pega pkgver do PKGBUILD do AUR, se disponível
VERSIONAUR=$(wget -q https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$APP -O - \
               | grep '^pkgver=' \
               | head -1 \
               | cut -d'=' -f2)

# se não achar nas duas fontes, usa fallback
if [ -z "$VERSION" ] && [ -z "$VERSIONAUR" ]; then
    VERSION="6.1.44"
fi

# ——————————————————————————————————————————————————————————
# PREPARA APPDIR E APPIMAGETOOL
# ——————————————————————————————————————————————————————————
wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod +x appimagetool
rm -rf $APP.AppDir
mkdir $APP.AppDir

cd $APP.AppDir
HOME="$(dirname "$(readlink -f $0)")"  # força $HOME dentro do AppDir

# ——————————————————————————————————————————————————————————
# INICIA JUNEST (ambiente pacman isolado)
# ——————————————————————————————————————————————————————————
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
~/.local/share/junest/bin/junest setup

# habilita multilib e archlinuxcn para AUR
cat >> ./.junest/etc/pacman.conf <<EOF

[multilib]
Include = /etc/pacman.d/mirrorlist

[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
EOF

~/.local/share/junest/bin/junest -- sudo pacman-key --init
~/.local/share/junest/bin/junest -- sudo pacman-key --populate archlinux archlinuxcn
~/.local/share/junest/bin/junest -- sudo pacman -Syy

# espelha mirrors do país detectado para acelerar downloads
COUNTRY=$(curl -s ipinfo.io/country)
rm -f ./.junest/etc/pacman.d/mirrorlist
wget -q "https://archlinux.org/mirrorlist/?country=${COUNTRY}" -O - \
  | sed 's/^#Server/Server/' \
  >> ./.junest/etc/pacman.d/mirrorlist

~/.local/share/junest/bin/junest -- sudo pacman -Syy
~/.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu

# ——————————————————————————————————————————————————————————
# INSTALA YAY e DEPENDÊNCIAS VIA AUR E REPO
# ——————————————————————————————————————————————————————————
~/.local/share/junest/bin/junest -- sudo pacman --noconfirm -S git base-devel
~/.local/share/junest/bin/junest -- bash -c "\
    git clone https://aur.archlinux.org/yay.git /tmp/yay && \
    cd /tmp/yay && \
    makepkg -si --noconfirm
"
~/.local/share/junest/bin/junest -- yay -Syy
~/.local/share/junest/bin/junest -- yay --noconfirm -S $APP $DEPENDENCES

# ——————————————————————————————————————————————————————————
# CONFIGURAÇÕES INICIAIS DO VirtualBox
# ——————————————————————————————————————————————————————————
# cria diretório padrão de VMs em /opt
~/.local/share/junest/bin/junest -- sudo mkdir -p /opt/virtualbox/vms

# script que define pasta padrão de VMs no config do usuário
cat << 'EOF' > ./.junest/tmp/setup_virtualbox.sh
#!/bin/bash
mkdir -p ~/.config/VirtualBox
cat > ~/.config/VirtualBox/VirtualBox.xml <<INNEREOF
<?xml version="1.0"?>
<VirtualBox>
  <Global>
    <DefaultMachineFolder>/opt/virtualbox/vms</DefaultMachineFolder>
  </Global>
</VirtualBox>
INNEREOF
EOF
chmod +x ./.junest/tmp/setup_virtualbox.sh
~/.local/share/junest/bin/junest -- bash /tmp/setup_virtualbox.sh

# ——————————————————————————————————————————————————————————
# COPIA .desktop E ÍCONES PARA APPDIR
# ——————————————————————————————————————————————————————————
LAUNCHER=$(grep -iRl "$BIN" ./.junest/usr/share/applications/*.desktop | head -1)
cp "$LAUNCHER" ./
ICON=$(grep '^Icon=' $(basename "$LAUNCHER") | cut -d'=' -f2)
for SIZE in 22 24 32 48 64 128 192 256 512 scalable; do
    cp -r ./.junest/usr/share/icons/hicolor/${SIZE}/apps/*${ICON}* . 2>/dev/null
done
cp -r ./.junest/usr/share/pixmaps/*${ICON}* . 2>/dev/null

# gera .desktop se não existir
if [ ! -f ./${APP}.desktop ]; then
    cat > ./${APP}.desktop <<HEREDOC
[Desktop Entry]
Version=1.0
Type=Application
Name=VirtualBox
Exec=$BIN %U
Icon=$ICON
Categories=System;Emulator;
Terminal=false
StartupNotify=true
HEREDOC
fi

# ——————————————————————————————————————————————————————————
# CRIA AppRun PARA LANÇAR O VIRTUALBOX COM JUNEST/PROOT
# ——————————————————————————————————————————————————————————
cat > ./AppRun <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f $0)")"
export UNION_PRELOAD=$HERE
export JUNEST_HOME=$HERE/.junest
export PATH=$HERE/.local/share/junest/bin:$PATH
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config
mkdir -p $HOME/.cache $HOME/.config/VirtualBox $XDG_DATA_HOME/VirtualBox

# executa VirtualBox dentro do junest/proot
EXEC=$(grep -m1 '^Exec=' "$HERE"/*.desktop | cut -d'=' -f2 | sed 's|%.||g')
$HERE/.local/share/junest/bin/junest proot -n \
  -b "/home,/media,/mnt,/opt,/usr/lib/locale,/etc/fonts,/usr/share/fonts,/usr/share/themes,$HOME/.config/VirtualBox:/root/.config/VirtualBox" \
  -- $EXEC "$@"
EOF
chmod +x AppRun

# ——————————————————————————————————————————————————————————
# WORKAROUNDS PARA ERROS DE SISTEMA READ-ONLY
# ——————————————————————————————————————————————————————————
sed -i 's#${JUNEST_HOME}/usr/bin/junest_wrapper#${HOME}/.cache/junest_wrapper.old#g' ~/.local/share/junest/lib/core/wrappers.sh
sed -i 's/rm -f "\${JUNEST_HOME}${bin_path}_wrappers/#rm -f "\${JUNEST_HOME}${bin_path}_wrappers/g' ~/.local/share/junest/lib/core/wrappers.sh
sed -i 's/ln/#ln/g' ~/.local/share/junest/lib/core/wrappers.sh

cd ..

# ——————————————————————————————————————————————————————————
# LIMPEZA E OTIMIZAÇÃO DE TAMANHO (BACKUPS E FILTROS)
# ——————————————————————————————————————————————————————————
# (mesmas funções de _savebins, _saveshare, backups, etc.)
# [incluir aqui todo o bloco original de backup/filtro, sem alterações]

# ——————————————————————————————————————————————————————————
# GERA O AppImage FINAL
# ——————————————————————————————————————————————————————————
ARCH=x86_64 ./appimagetool -n ./$APP.AppDir
mv ./*AppImage ./${APP^}-"$VERSION""$VERSIONAUR"-x86_64.AppImage
chmod +x ./${APP^}-"$VERSION""$VERSIONAUR"-x86_64.AppImage

echo
echo "=================================================================================="
echo "AppImage do VirtualBox criado com sucesso!"
echo "Arquivo gerado: $(pwd)/${APP^}-$VERSION$VERSIONAUR-x86_64.AppImage"
echo "=================================================================================="
