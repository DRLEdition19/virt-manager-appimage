#!/bin/sh

# NOME DO APLICATIVO
APP=genymotion
BIN="$APP" #O BINÁRIO TEM O MESMO NOME QUE O APP
DEPENDENCES="virtualbox virtualbox-host-modules-arch android-tools adb libvirt qemu-desktop" #DEPENDÊNCIAS EXTRAS

# ADICIONE UMA VERSÃO, NECESSÁRIA PARA O NOME DO APPIMAGE FINAL
for REPO in { "core" "extra" "community" "multilib" }; do
echo "$(wget -q https://archlinux.org/packages/$REPO/x86_64/$APP/flag/ -O - | grep $APP | grep details | head -1 | grep -o -P '(?<=/a> ).*(?= )' | grep -o '^\S*')" >> version
done
VERSION=$(cat ./version | grep -w -v "" | head -1)
VERSIONAUR=$(wget -q https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$APP -O - | grep pkgver | head -1 | cut -c 8-)

# Se a versão não for encontrada no repositório padrão ou AUR, defina uma versão fixa
if [ -z "$VERSION" ] && [ -z "$VERSIONAUR" ]; then
    VERSION="3.6.0"
fi

# CRIE O APPDIR (NÃO ALTERE ISSO)...
wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod a+x appimagetool
mkdir $APP.AppDir

# ENTRE NO APPDIR
cd $APP.AppDir

# DEFINA O APPDIR COMO UM DIRETÓRIO $HOME TEMPORÁRIO
HOME="$(dirname "$(readlink -f $0)")"

# BAIXE E INSTALE O JUNEST (NÃO ALTERE ISSO)
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
./.local/share/junest/bin/junest setup

# HABILITE MULTILIB (necessário para algumas dependências do Genymotion)
echo "
[multilib]
Include = /etc/pacman.d/mirrorlist" >> ./.junest/etc/pacman.conf

# HABILITE AUR (é necessário para o Genymotion)
echo "
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch" >> ./.junest/etc/pacman.conf
./.local/share/junest/bin/junest -- sudo pacman-key --init
./.local/share/junest/bin/junest -- sudo pacman-key --populate archlinux
./.local/share/junest/bin/junest -- sudo pacman -Syy

# LISTA DE MIRRORS CUSTOMIZADA, ISSO DEVE ACELERAR A INSTALAÇÃO DOS PACOTES NO PACMAN
COUNTRY=$(curl -i ipinfo.io | grep country | cut -c 15- | cut -c -2)
rm -R ./.junest/etc/pacman.d/mirrorlist
wget -q https://archlinux.org/mirrorlist/?country="$(echo $COUNTRY)" -O - | sed 's/#Server/Server/g' >> ./.junest/etc/pacman.d/mirrorlist

# ATUALIZE O ARCH LINUX NO JUNEST
./.local/share/junest/bin/junest -- sudo pacman -Syy
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu

# INSTALE O YAY (GERENCIADOR DE PACOTES AUR)
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -S git base-devel
./.local/share/junest/bin/junest -- bash -c "cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm"

# INSTALE O PROGRAMA USANDO YAY
./.local/share/junest/bin/junest -- yay -Syy
./.local/share/junest/bin/junest -- yay --noconfirm -S gnu-free-fonts $APP $DEPENDENCES

# ADICIONE UMA IMAGEM ANDROID AO GENYMOTION
# É preciso baixar e configurar uma imagem Android
./.local/share/junest/bin/junest -- sudo mkdir -p /opt/genymotion/images
# Crie um script para automatizar a adição da imagem Android
cat << 'EOF' > ./.junest/tmp/setup_genymotion.sh
#!/bin/bash
# Crie um arquivo de configuração de dispositivo
mkdir -p ~/.Genymobile/Genymotion/devices
cat << 'INNEREOF' > ~/.Genymobile/Genymotion/devices/Google_Pixel_3_API_30.ini
[General]
uuid={e24cd194-cfb4-46af-a153-a54213dca4cd}
name=Google Pixel 3 - API 30
model=Google Pixel 3
android_version=11.0
api_level=30
path=/opt/genymotion/images/Google_Pixel_3_API_30
INNEREOF

# Configure o registro do Genymotion
mkdir -p ~/.Genymobile/Genymotion
cat << 'INNEREOF' > ~/.Genymobile/Genymotion/genymotion.conf
[General]
stats=@Variant(\0\0\0\b\0\0\0\x1\0\0\0\x4\xdate\0\0\0\n\0\0\0\x12\0\x32\0\x30\0\x32\0\x33\0\x30\0\x37\0\x31\0\x35)
virtual_device_default_location=/opt/genymotion/images
INNEREOF
EOF
chmod +x ./.junest/tmp/setup_genymotion.sh
./.local/share/junest/bin/junest -- bash /tmp/setup_genymotion.sh

# ...ADICIONE O ÍCONE E O ARQUIVO DESKTOP NA RAIZ DO APPDIR...
rm -R -f ./*.desktop
LAUNCHER=$(grep -iRl $BIN ./.junest/usr/share/applications/* | grep ".desktop" | head -1)
cp -r "$LAUNCHER" ./
ICON=$(cat $LAUNCHER | grep "Icon=" | cut -c 6-)
cp -r ./.junest/usr/share/icons/hicolor/22x22/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/24x24/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/32x32/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/48x48/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/64x64/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/128x128/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/192x192/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/256x256/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/512x512/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/icons/hicolor/scalable/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/pixmaps/*$ICON* ./ 2>/dev/null

# TESTE SE O ARQUIVO DESKTOP E O ÍCONE ESTÃO NA RAIZ DO FUTURO APPIMAGE (./*AppDir/*)
if test -f ./*.desktop; then
	echo "The .desktop file is available in $APP.AppDir/"
else
	cat <<-HEREDOC >> "./$APP.desktop"
	[Desktop Entry]
	Version=1.0
	Type=Application
	Name=Genymotion
	Comment=Android Virtual Device Manager
	Exec=$BIN
	Icon=genymotion
	Categories=Development;Emulator;
	Terminal=false
	StartupNotify=true
	HEREDOC
	wget https://www.genymotion.com/wp-content/uploads/company/icon_512.png -O ./genymotion.png
fi

# ...E FINALMENTE CRIE O APPRUN, O SCRIPT PRINCIPAL PARA EXECUTAR O APPIMAGE!
rm -R -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f $0)")"
export UNION_PRELOAD=$HERE
export JUNEST_HOME=$HERE/.junest
export PATH=$HERE/.local/share/junest/bin/:$PATH
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config
mkdir -p $HOME/.cache
mkdir -p $HOME/.Genymobile
mkdir -p $HOME/.config/genymotion
mkdir -p $XDG_DATA_HOME/genymotion

# Criar symlinks para os dispositivos virtuais
if [ ! -d "$HOME/.Genymobile/Genymotion" ]; then
    mkdir -p "$HOME/.Genymobile/Genymotion"
    if [ -d "$HERE/.junest/root/.Genymobile/Genymotion" ]; then
        cp -r "$HERE/.junest/root/.Genymobile/Genymotion"/* "$HOME/.Genymobile/Genymotion/"
    fi
fi

EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
$HERE/.local/share/junest/bin/junest proot -n -b "--bind=/home --bind=/home/$(echo $USER) --bind=/media --bind=/mnt --bind=/opt --bind=/usr/lib/locale --bind=/etc/fonts --bind=/usr/share/fonts --bind=/usr/share/themes --bind=$HOME/.Genymobile:/root/.Genymobile --bind=/dev --bind=/run" 2> /dev/null -- $EXEC "$@"
EOF
chmod a+x ./AppRun

# REMOVA ERROS "READ-ONLY FILE SYSTEM"
sed -i 's#${JUNEST_HOME}/usr/bin/junest_wrapper#${HOME}/.cache/junest_wrapper.old#g' ./.local/share/junest/lib/core/wrappers.sh
sed -i 's/rm -f "${JUNEST_HOME}${bin_path}_wrappers/#rm -f "${JUNEST_HOME}${bin_path}_wrappers/g' ./.local/share/junest/lib/core/wrappers.sh
sed -i 's/ln/#ln/g' ./.local/share/junest/lib/core/wrappers.sh

# SAIA DO APPDIR
cd ..

# REMOVA ALGUNS ARQUIVOS DESNECESSÁRIOS
find ./$APP.AppDir/.junest/usr/share/doc/* -not -iname "*$BIN*" -a -not -name "." -delete #REMOVA TODA DOCUMENTAÇÃO NÃO RELACIONADA AO APP
find ./$APP.AppDir/.junest/usr/share/locale/*/*/* -not -iname "*$BIN*" -a -not -name "." -delete #REMOVA TODOS OS ARQUIVOS DE LOCALIZAÇÃO ADICIONAIS
rm -R -f ./$APP.AppDir/.junest/etc/makepkg.conf
rm -R -f ./$APP.AppDir/.junest/etc/pacman.conf
rm -R -f ./$APP.AppDir/.junest/usr/include #ARQUIVOS RELACIONADOS AO COMPILADOR
rm -R -f ./$APP.AppDir/.junest/usr/man #APPIMAGES NÃO DEVEM TER O COMANDO MAN
rm -R -f ./$APP.AppDir/.junest/var/* #REMOVA TODOS OS PACOTES BAIXADOS COM O GERENCIADOR DE PACOTES

# NAS PRÓXIMAS 4 ETAPAS, TENTAREMOS DIMINUIR O TAMANHO FINAL DO PACOTE APPIMAGE
# VAMOS MOVER O CONTEÚDO EXCESSIVO PARA PASTAS DE BACKUP (ETAPA 1)
# OS DIRETÓRIOS AFETADOS SERÃO /usr/bin (ETAPA 2), /usr/lib (ETAPA 3) E /usr/share (ETAPA 4)

# ETAPA 1, CRIE UMA PASTA DE BACKUP ONDE SALVAR OS ARQUIVOS A SEREM DESCARTADOS (ÚTIL PARA FINS DE TESTE)
mkdir -p ./junest-backups/usr/bin
mkdir -p ./junest-backups/usr/lib/dri
mkdir -p ./junest-backups/usr/share

# ETAPA 2, FUNÇÃO PARA SALVAR OS BINÁRIOS EM /usr/bin NECESSÁRIOS PARA FAZER O JUNEST FUNCIONAR, ALÉM DO(S) BINÁRIO(S) PRINCIPAL(IS) DO APP
# SE VOCÊ PRECISAR SALVAR MAIS BINÁRIOS, LISTE-OS NA VARIÁVEL "BINSAVED".
_savebins(){
	BINSAVED="virtualbox VBox vboxmanage qemu adb"
	mkdir save
	mv ./$APP.AppDir/.junest/usr/bin/*$BIN* ./save/
	mv ./$APP.AppDir/.junest/usr/bin/bash ./save/
	mv ./$APP.AppDir/.junest/usr/bin/env ./save/
	mv ./$APP.AppDir/.junest/usr/bin/proot* ./save/
	mv ./$APP.AppDir/.junest/usr/bin/sh ./save/
	for arg in $BINSAVED; do
		for var in $arg; do
 			mv ./$APP.AppDir/.junest/usr/bin/*"$arg"* ./save/ 2>/dev/null
		done
	done
	mv ./$APP.AppDir/.junest/usr/bin/* ./junest-backups/usr/bin/ 2>/dev/null
	mv ./save/* ./$APP.AppDir/.junest/usr/bin/ 2>/dev/null
	rmdir save
}
_savebins

# ETAPA 3, MOVA BIBLIOTECAS DESNECESSÁRIAS PARA UMA PASTA DE BACKUP (PARA FINS DE TESTE)
mv ./$APP.AppDir/.junest/usr/lib32 ./junest-backups/usr/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/*.a ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/bfd-plugins/liblto_plugin.so ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/crocus_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/d3d12_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/i* ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/kms_swrast_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/r* ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/nouveau_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/radeonsi_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/virtio_gpu_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/vmwgfx_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/zink_dri.so ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/gcc ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/git-* ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libalpm.so* ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libasan_preinit.o ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libcc* ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libgomp.spec ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libitm.spec ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/liblsan_preinit.o ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libsanitizer.spec ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/libtsan_preinit.o ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/*.o ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/pkgconfig ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/systemd/system/git-daemon@.service ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/systemd/system/git-daemon.socket ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/sysusers.d/git.conf ./junest-backups/usr/lib/ 2>/dev/null

# ETAPA 4, SALVE APENAS ALGUNS DIRETÓRIOS CONTIDOS EM /usr/share
# SE VOCÊ PRECISAR SALVAR MAIS PASTAS, LISTE-AS NA VARIÁVEL "SHARESAVED".
_saveshare(){
	SHARESAVED="virtualbox VBox vbox android qemu"
	mkdir save
	mv ./$APP.AppDir/.junest/usr/share/*$APP* ./save/ 2>/dev/null
 	mv ./$APP.AppDir/.junest/usr/share/*$BIN* ./save/ 2>/dev/null
	mv ./$APP.AppDir/.junest/usr/share/fontconfig ./save/ 2>/dev/null
	mv ./$APP.AppDir/.junest/usr/share/glib-* ./save/ 2>/dev/null
	mv ./$APP.AppDir/.junest/usr/share/locale ./save/ 2>/dev/null
	mv ./$APP.AppDir/.junest/usr/share/mime ./save/ 2>/dev/null
	mv ./$APP.AppDir/.junest/usr/share/wayland ./save/ 2>/dev/null
	mv ./$APP.AppDir/.junest/usr/share/X11 ./save/ 2>/dev/null
	for arg in $SHARESAVED; do
		for var in $arg; do
 			mv ./$APP.AppDir/.junest/usr/share/*"$arg"* ./save/ 2>/dev/null
		done
	done
	mv ./$APP.AppDir/.junest/usr/share/* ./junest-backups/usr/share/ 2>/dev/null
	mv ./save/* ./$APP.AppDir/.junest/usr/share/ 2>/dev/null
	rmdir save
}
_saveshare

# REMOÇÕES ADICIONAIS

# REMOVA O HOME EMBUTIDO
rm -R -f ./$APP.AppDir/.junest/home

# ATIVE PONTOS DE MONTAGEM
mkdir -p ./$APP.AppDir/.junest/home
mkdir -p ./$APP.AppDir/.junest/media
mkdir -p ./$APP.AppDir/.junest/opt/genymotion/images
mkdir -p ./$APP.AppDir/.junest/dev
mkdir -p ./$APP.AppDir/.junest/run

# CRIE O APPIMAGE
ARCH=x86_64 ./appimagetool -n ./$APP.AppDir
mv ./*AppImage ./Genymotion-"$VERSION""$VERSIONAUR"-x86_64.AppImage

# Torne o AppImage executável
chmod +x ./Genymotion-"$VERSION""$VERSIONAUR"-x86_64.AppImage

echo ""
echo "=================================================================================="
echo "AppImage do Genymotion criado com sucesso!"
echo "O arquivo está em: $(pwd)/Genymotion-$VERSION$VERSIONAUR-x86_64.AppImage"
echo "=================================================================================="
