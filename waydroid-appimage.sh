#!/bin/sh

# Nome do aplicativo
APP=waydroid
BIN="$APP" # O nome do binário é o mesmo do aplicativo, ajuste caso seja diferente.
DEPENDENCES="wayland lxc" # Dependências necessárias, ajuste conforme necessário.

# Adicionar uma versão para o AppImage
for REPO in { "core" "extra" "community" "multilib" }; do
echo "$(wget -q https://archlinux.org/packages/$REPO/x86_64/$APP/flag/ -O - | grep $APP | grep details | head -1 | grep -o -P '(?<=/a> ).*(?= )' | grep -o '^\S*')" >> version
done
VERSION=$(cat ./version | grep -w -v "" | head -1)
VERSIONAUR=$(wget -q https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$APP -O - | grep pkgver | head -1 | cut -c 8-)

# Criar o AppDir
wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod a+x appimagetool
mkdir $APP.AppDir

# Entrar no AppDir
cd $APP.AppDir

# Configurar o diretório temporário como home
HOME="$(dirname "$(readlink -f $0)")"

# Baixar e configurar Junest
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
./.local/share/junest/bin/junest setup

# Habilitar multilib
echo "
[multilib]
Include = /etc/pacman.d/mirrorlist" >> ./.junest/etc/pacman.conf

# Configurar mirrorlist baseado no país
COUNTRY=$(curl -i ipinfo.io | grep country | cut -c 15- | cut -c -2)
rm -R ./.junest/etc/pacman.d/mirrorlist
wget -q https://archlinux.org/mirrorlist/?country="$(echo $COUNTRY)" -O - | sed 's/#Server/Server/g' >> ./.junest/etc/pacman.d/mirrorlist

# Atualizar o Arch Linux no Junest
./.local/share/junest/bin/junest -- sudo pacman -Syy
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu

# Instalar o programa e dependências
./.local/share/junest/bin/junest -- yay -Syy
./.local/share/junest/bin/junest -- yay --noconfirm -S $DEPENDENCES $APP

# Adicionar o ícone e arquivo desktop
rm -R -f ./*.desktop
LAUNCHER=$(grep -iRl $BIN ./.junest/usr/share/applications/* | grep ".desktop" | head -1)
cp -r "$LAUNCHER" ./
ICON=$(cat $LAUNCHER | grep "Icon=" | cut -c 6-)
cp -r ./.junest/usr/share/icons/hicolor/*/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/pixmaps/*$ICON* ./ 2>/dev/null

# Criar arquivo desktop se necessário
if test -f ./*.desktop; then
	echo "O arquivo .desktop está disponível em $APP.AppDir/"
else
	cat <<-HEREDOC >> "./$APP.desktop"
	[Desktop Entry]
	Version=1.0
	Type=Application
	Name=WAYDROID
	Comment=
	Exec=$BIN
	Icon=tux
	Categories=Utility;
	Terminal=true
	StartupNotify=true
	HEREDOC
	wget https://raw.githubusercontent.com/Portable-Linux-Apps/Portable-Linux-Apps.github.io/main/favicon.ico -O ./tux.png
fi

# Criar o AppRun, script principal
rm -R -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f $0)")"
export UNION_PRELOAD=$HERE
export JUNEST_HOME=$HERE/.junest
export PATH=$HERE/.local/share/junest/bin/:$PATH
mkdir -p $HOME/.cache
EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
$HERE/.local/share/junest/bin/junest proot -n -b "--bind=/home --bind=/media --bind=/mnt --bind=/opt --bind=/usr/lib/locale --bind=/etc/fonts --bind=/usr/share/fonts" -- $EXEC
EOF
chmod a+x ./AppRun

# Remover arquivos desnecessários
find ./$APP.AppDir/.junest/usr/share/doc/* -not -iname "*$BIN*" -a -not -name "." -delete
rm -R -f ./$APP.AppDir/.junest/usr/include
rm -R -f ./$APP.AppDir/.junest/usr/man
rm -R -f ./$APP.AppDir/.junest/var/*

# Criar o AppImage
ARCH=x86_64 ./appimagetool -n ./$APP.AppDir
mv ./*AppImage ./"$(cat ./$APP.AppDir/*.desktop | grep 'Name=' | head -1 | cut -c 6- | sed 's/ /-/g')"_"$VERSION""$VERSIONAUR"-x86_64.AppImage
