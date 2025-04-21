#!/bin/sh

# NAME OF THE APP BY REPLACING "SAMPLE"
APP=waydroid
BIN="$APP" #CHANGE THIS IF THE NAME OF THE BINARY IS DIFFERENT FROM "$APP" (for example, the binary of "obs-studio" is "obs")
DEPENDENCES="wayland lxc python-gbinder python-gobject python-pip python-requests python-yaml python-cryptography python-iniparse" #SYNTAX: "APP1 APP2 APP3 APP4...", LEAVE BLANK IF NO OTHER DEPENDENCES ARE NEEDED
BASICSTUFF="binutils gzip"
COMPILERS="gcc"
KERNELMODULES="binder-linux-dkms"  # Added DKMS package for binder-linux

# ADD A VERSION, THIS IS NEEDED FOR THE NAME OF THE FINEL APPIMAGE, IF NOT AVAILABLE ON THE REPO, THE VALUE COME FROM AUR, AND VICE VERSA
for REPO in { "core" "extra" "community" "multilib" }; do
echo "$(wget -q https://archlinux.org/packages/$REPO/x86_64/$APP/flag/ -O - | grep $APP | grep details | head -1 | grep -o -P '(?<=/a> ).*(?= )' | grep -o '^\S*')" >> version
done
VERSION=$(cat ./version | grep -w -v "" | head -1)
VERSIONAUR=$(wget -q https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$APP -O - | grep pkgver | head -1 | cut -c 8-)

# CREATE THE APPDIR (DON'T TOUCH THIS)...
wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod a+x appimagetool
mkdir $APP.AppDir

# ENTER THE APPDIR
cd $APP.AppDir

# SET APPDIR AS A TEMPORARY $HOME DIRECTORY, THIS WILL DO ALL WORK INTO THE APPDIR
HOME="$(dirname "$(readlink -f $0)")"

# DOWNLOAD AND INSTALL JUNEST (DON'T TOUCH THIS)
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
./.local/share/junest/bin/junest setup

# ENABLE MULTILIB (optional)
echo "
[multilib]
Include = /etc/pacman.d/mirrorlist" >> ./.junest/etc/pacman.conf

# ENABLE CHAOTIC-AUR
./.local/share/junest/bin/junest -- sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
./.local/share/junest/bin/junest -- sudo pacman-key --lsign-key 3056513887B78AEB
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo "
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist" >> ./.junest/etc/pacman.conf

# CUSTOM MIRRORLIST, THIS SHOULD SPEEDUP THE INSTALLATION OF THE PACKAGES IN PACMAN (COMMENT EVERYTHING TO USE THE DEFAULT MIRROR)
COUNTRY=$(curl -i ipinfo.io | grep country | cut -c 15- | cut -c -2)
rm -R ./.junest/etc/pacman.d/mirrorlist
wget -q https://archlinux.org/mirrorlist/?country="$(echo $COUNTRY)" -O - | sed 's/#Server/Server/g' >> ./.junest/etc/pacman.d/mirrorlist

# UPDATE ARCH LINUX IN JUNEST
./.local/share/junest/bin/junest -- sudo pacman -Syy
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu

# INSTALL THE PROGRAM USING YAY
./.local/share/junest/bin/junest -- yay -Syy
./.local/share/junest/bin/junest -- yay --noconfirm -S gnu-free-fonts $(echo "$BASICSTUFF $COMPILERS $DEPENDENCES $APP $KERNELMODULES")

# Download user-space binder-linux module implementation
./.local/share/junest/bin/junest -- bash -c "
mkdir -p /opt/waydroid-modules
cd /opt/waydroid-modules
git clone https://github.com/choff/anbox-binder
cd anbox-binder
make
"

# Clone waydroid repo if not in packages
./.local/share/junest/bin/junest -- bash -c "
if ! pacman -Q waydroid &>/dev/null; then
    cd /tmp
    git clone https://github.com/waydroid/waydroid.git
    cd waydroid
    pip install --user --break-system-packages .
    mkdir -p ~/.config/waydroid
    cp data/configs/* ~/.config/waydroid/
fi
"

# Install userspace LXC tools
./.local/share/junest/bin/junest -- bash -c "
mkdir -p /opt/waydroid-userspace
cd /opt/waydroid-userspace
git clone https://github.com/lxc/lxc.git
cd lxc
./autogen.sh
./configure --prefix=/opt/waydroid-userspace/lxc-install --disable-docs --disable-apparmor --disable-selinux --disable-seccomp --disable-capabilities
make -j$(nproc)
make install
"

# SET THE LOCALE (DON'T TOUCH THIS)
rm ./.junest/etc/locale.conf
sed -i 's/LANG=${LANG:-C}/LANG=$LANG/g' ./.junest/etc/profile.d/locale.sh

# ...ADD THE ICON AND THE DESKTOP FILE AT THE ROOT OF THE APPDIR...
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

# Se não encontramos um arquivo .desktop, vamos criar um
if test -f ./*.desktop; then
	echo "The .desktop file is available in $APP.AppDir/"
else
	cat <<-HEREDOC >> "./$APP.desktop"
	[Desktop Entry]
	Version=1.0
	Type=Application
	Name=Waydroid (No Root)
	Comment=Android Container for Wayland - No Root Required
	Exec=waydroid
	Icon=waydroid
	Categories=Utility;System;
	Terminal=true
	StartupNotify=true
	HEREDOC
	
	# Baixa um ícone para o Waydroid se não encontramos um
	wget https://raw.githubusercontent.com/waydroid/waydroid/main/data/icons/hicolor/128x128/apps/waydroid.png -O ./waydroid.png 2>/dev/null
	if [ ! -f ./waydroid.png ]; then
	    wget https://raw.githubusercontent.com/Portable-Linux-Apps/Portable-Linux-Apps.github.io/main/favicon.ico -O ./waydroid.png
	fi
fi

# ...AND FINALLY CREATE THE APPRUN, IE THE MAIN SCRIPT TO RUN THE APPIMAGE!
# EDIT THE FOLLOWING LINES IF YOU THINK SOME ENVIRONMENT VARIABLES ARE MISSING
rm -R -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f $0)")"
export UNION_PRELOAD=$HERE
export JUNEST_HOME=$HERE/.junest
export PATH=$HERE/.local/share/junest/bin/:$PATH

# Create necessary directories
mkdir -p $HOME/.cache
mkdir -p $HOME/.local/share/waydroid
mkdir -p $HOME/.config/waydroid
mkdir -p $HOME/.local/share/lxc
mkdir -p $HOME/.local/share/waydroid-data

# Set up user-space environment
export WAYDROID_DATA=$HOME/.local/share/waydroid-data
export LXC_PATH=$HOME/.local/share/lxc
export LD_LIBRARY_PATH=$HERE/.junest/opt/waydroid-userspace/lxc-install/lib:$LD_LIBRARY_PATH
export PATH=$HERE/.junest/opt/waydroid-userspace/lxc-install/bin:$PATH

# Load user-space binder module if kernel module is not available
if ! lsmod | grep -q binder_linux; then
    echo "Kernel binder_linux module not detected, using user-space implementation..."
    export LD_PRELOAD=$HERE/.junest/opt/waydroid-modules/anbox-binder/libbionic-binder.so
    export BINDER_DRIVER="user"
else
    echo "Kernel binder_linux module detected, using it..."
    export BINDER_DRIVER="kernel"
fi

# Prepare LXC environment
if [ ! -f $HOME/.local/share/lxc/waydroid/config ]; then
    mkdir -p $HOME/.local/share/lxc/waydroid
    
    # Create basic LXC config for user-space
    cat > $HOME/.local/share/lxc/waydroid/config << 'LXCCONFIG'
lxc.net.0.type = none
lxc.rootfs.path = dir:$WAYDROID_DATA/rootfs
lxc.uts.name = waydroid
LXCCONFIG
    
    echo "LXC environment initialized in user-space mode"
fi

# Set up Waydroid config if not exists
if [ ! -f $HOME/.config/waydroid/waydroid_base.prop ]; then
    cp $HERE/.junest/etc/waydroid/* $HOME/.config/waydroid/ 2>/dev/null
    echo "Copied default Waydroid configuration"
fi

# Start Waydroid
echo "Starting Waydroid in user-space mode..."
echo "Note: This is a modified version that attempts to run without root privileges"
echo "Some features may be limited compared to the full system version"

# Execute the Waydroid command
EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
$HERE/.local/share/junest/bin/junest proot -n -b "--bind=/home --bind=/home/$(echo $USER) --bind=/media --bind=/mnt --bind=/opt --bind=/usr/lib/locale --bind=/etc/fonts --bind=/usr/share/fonts --bind=/usr/share/themes --bind=/run/user/$(id -u) --bind=/tmp" 2> /dev/null -- $EXEC "$@"
EOF
chmod a+x ./AppRun

# REMOVE "READ-ONLY FILE SYSTEM" ERRORS
sed -i 's#${JUNEST_HOME}/usr/bin/junest_wrapper#${HOME}/.cache/junest_wrapper.old#g' ./.local/share/junest/lib/core/wrappers.sh
sed -i 's/rm -f "${JUNEST_HOME}${bin_path}_wrappers/#rm -f "${JUNEST_HOME}${bin_path}_wrappers/g' ./.local/share/junest/lib/core/wrappers.sh
sed -i 's/ln/#ln/g' ./.local/share/junest/lib/core/wrappers.sh

# EXIT THE APPDIR
cd ..

# REMOVE SOME BLOATWARES
find ./$APP.AppDir/.junest/usr/share/doc/* -not -iname "*$BIN*" -a -not -name "." -delete #REMOVE ALL DOCUMENTATION NOT RELATED TO THE APP
find ./$APP.AppDir/.junest/usr/share/locale/*/*/* -not -iname "*$BIN*" -a -not -name "." -delete #REMOVE ALL ADDITIONAL LOCALE FILES
rm -R -f ./$APP.AppDir/.junest/etc/makepkg.conf
rm -R -f ./$APP.AppDir/.junest/etc/pacman.conf
rm -R -f ./$APP.AppDir/.junest/usr/include #FILES RELATED TO THE COMPILER
rm -R -f ./$APP.AppDir/.junest/usr/man #APPIMAGES ARE NOT MENT TO HAVE MAN COMMAND
rm -R -f ./$APP.AppDir/.junest/var/* #REMOVE ALL PACKAGES DOWNLOADED WITH THE PACKAGE MANAGER

# IN THE NEXT 4 STEPS WE WILL TRY TO LIGHTEN THE FINAL APPIMAGE PACKAGE
# WE WILL MOVE EXCESS CONTENT TO BACKUP FOLDERS (STEP 1)
# THE AFFECTED DIRECTORIES WILL BE /usr/bin (STEP 2), /usr/lib (STEP 3) AND /usr/share (STEP 4)

# STEP 1, CREATE A BACKUP FOLDER WHERE TO SAVE THE FILES TO BE DISCARDED (USEFUL FOR TESTING PURPOSES)
mkdir -p ./junest-backups/usr/bin
mkdir -p ./junest-backups/usr/lib/dri
mkdir -p ./junest-backups/usr/share

# STEP 2, FUNCTION TO SAVE THE BINARIES IN /usr/bin THAT ARE NEEDED TO MADE JUNEST WORK, PLUS THE MAIN BINARY/BINARIES OF THE APP
# Adicionamos os binários necessários para o Waydroid
_savebins(){
	BINSAVED="python python3 gbinder lxc lxc-* pip3 anbox-binder"
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
	mv ./$APP.AppDir/.junest/usr/bin/* ./junest-backups/usr/bin/
	mv ./save/* ./$APP.AppDir/.junest/usr/bin/
	rmdir save
}
_savebins

# STEP 3, MOVE UNNECESSARY LIBRARIES TO A BACKUP FOLDER (FOR TESTING PURPOSES)
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

# STEP 4, SAVE ONLY SOME DIRECTORIES CONTAINED IN /usr/share
# Adicionamos os diretórios necessários para o Python e Waydroid
_saveshare(){
	SHARESAVED="python waydroid lxc anbox-binder"
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

# ADDITIONAL REMOVALS

# REMOVE THE INBUILT HOME
rm -R -f ./$APP.AppDir/.junest/home

# ENABLE MOUNTPOINTS
mkdir -p ./$APP.AppDir/.junest/home
mkdir -p ./$APP.AppDir/.junest/media
mkdir -p ./$APP.AppDir/.junest/run
mkdir -p ./$APP.AppDir/.junest/tmp
mkdir -p ./$APP.AppDir/.junest/opt/waydroid-modules

# CREATE README FILE
cat > ./$APP.AppDir/README.txt << 'EOF'
# Waydroid AppImage (No Root Required)

Este AppImage contém o Waydroid, um container Android para Wayland, modificado para funcionar sem permissões de root.

## Recursos desta versão:
1. Implementação de módulo binder em userspace
2. LXC configurado para rodar sem privilégios de superusuário
3. Estrutura de diretórios personalizada dentro do diretório do usuário

## Como usar:
1. Execute o AppImage normalmente (sem sudo)
2. Na primeira execução, use `waydroid init` para configurar
3. Para iniciar o container: `waydroid session start`
4. Para iniciar a interface: `waydroid show-full-ui`

## Limitações:
- Algumas funcionalidades avançadas podem não estar disponíveis
- O desempenho pode ser inferior comparado à versão com root
- Compatibilidade com alguns aplicativos pode ser limitada

## Nota:
Se você tiver o módulo binder_linux carregado no kernel, ele será usado automaticamente.
Se não, o AppImage usará uma implementação em userspace.

Mais informações: https://github.com/waydroid/waydroid
EOF

# CREATE THE APPIMAGE
ARCH=x86_64 ./appimagetool -n ./$APP.AppDir
mv ./*AppImage ./"$(cat ./$APP.AppDir/*.desktop | grep 'Name=' | head -1 | cut -c 6- | sed 's/ /-/g')"_"$VERSION""$VERSIONAUR"-x86_64.AppImage
