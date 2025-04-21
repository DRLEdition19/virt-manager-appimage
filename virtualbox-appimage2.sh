#!/bin/sh

# NAME OF THE APP
APP=virtualbox
BIN="VirtualBox" #The binary name is "VirtualBox" for VirtualBox
DEPENDENCES="sdl2 libvpx libjpeg-turbo libpng libvorbis qt5-base" #Main dependencies for VirtualBox
BASICSTUFF="binutils gzip"
COMPILERS="gcc"
KERNELMODULES="virtualbox-host-modules-arch" #VirtualBox kernel modules

# ADD A VERSION
for REPO in { "community" "multilib" }; do
echo "$(wget -q https://archlinux.org/packages/$REPO/x86_64/$APP/flag/ -O - | grep $APP | grep details | head -1 | grep -o -P '(?<=/a> ).*(?= )' | grep -o '^\\S*')" >> version
done
VERSION=$(cat ./version | grep -w -v "" | head -1)
VERSIONAUR=$(wget -q https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$APP -O - | grep pkgver | head -1 | cut -c 8-)

# CREATE THE APPDIR
wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod a+x appimagetool
mkdir $APP.AppDir

# ENTER THE APPDIR
cd $APP.AppDir

# SET APPDIR AS A TEMPORARY $HOME DIRECTORY
HOME="$(dirname "$(readlink -f $0)")"

# DOWNLOAD AND INSTALL JUNEST
git clone https://github.com/fsquillace/junest.git ~/.local/share/junest
./.local/share/junest/bin/junest setup

# ENABLE MULTILIB
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

# CUSTOM MIRRORLIST
COUNTRY=$(curl -i ipinfo.io | grep country | cut -c 15- | cut -c -2)
rm -R ./.junest/etc/pacman.d/mirrorlist
wget -q https://archlinux.org/mirrorlist/?country="$(echo $COUNTRY)" -O - | sed 's/#Server/Server/g' >> ./.junest/etc/pacman.d/mirrorlist

# UPDATE ARCH LINUX IN JUNEST
./.local/share/junest/bin/junest -- sudo pacman -Syy
./.local/share/junest/bin/junest -- sudo pacman --noconfirm -Syu

# INSTALL VIRTUALBOX AND DEPENDENCIES
./.local/share/junest/bin/junest -- yay -Syy
./.local/share/junest/bin/junest -- yay --noconfirm -S $(echo "$BASICSTUFF $COMPILERS $DEPENDENCES $APP $KERNELMODULES")

# SET THE LOCALE
rm ./.junest/etc/locale.conf
sed -i 's/LANG=${LANG:-C}/LANG=$LANG/g' ./.junest/etc/profile.d/locale.sh

# ADD ICON AND DESKTOP FILE
rm -R -f ./*.desktop
LAUNCHER=$(grep -iRl $BIN ./.junest/usr/share/applications/* | grep ".desktop" | head -1)
cp -r "$LAUNCHER" ./
ICON=$(cat $LAUNCHER | grep "Icon=" | cut -c 6-)
cp -r ./.junest/usr/share/icons/hicolor/*/apps/*$ICON* ./ 2>/dev/null
cp -r ./.junest/usr/share/pixmaps/*$ICON* ./ 2>/dev/null

# CREATE APPRUN
rm -R -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f $0)")"
export UNION_PRELOAD=$HERE
export JUNEST_HOME=$HERE/.junest
export PATH=$HERE/.local/share/junest/bin/:$PATH

# Create VirtualBox config directory
mkdir -p "$HOME/.config/VirtualBox"

# Set VirtualBox paths
export VBOX_USER_HOME="$HOME/.config/VirtualBox"
export VBOX_APP_HOME="$HERE/.junest/usr/lib/virtualbox"

# Start VirtualBox
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

# REMOVE BLOATWARE
find ./$APP.AppDir/.junest/usr/share/doc/* -not -iname "*$BIN*" -a -not -name "." -delete
find ./$APP.AppDir/.junest/usr/share/locale/*/*/* -not -iname "*$BIN*" -a -not -name "." -delete
rm -R -f ./$APP.AppDir/.junest/etc/makepkg.conf
rm -R -f ./$APP.AppDir/.junest/etc/pacman.conf
rm -R -f ./$APP.AppDir/.junest/usr/include
rm -R -f ./$APP.AppDir/.junest/usr/man
rm -R -f ./$APP.AppDir/.junest/var/*

# CREATE BACKUP FOLDERS
mkdir -p ./junest-backups/usr/bin
mkdir -p ./junest-backups/usr/lib/dri
mkdir -p ./junest-backups/usr/share

# SAVE NECESSARY BINARIES
_savebins(){
    BINSAVED="VirtualBox VBoxManage VBoxHeadless vboxdrv"
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

# MOVE UNNECESSARY LIBRARIES
mv ./$APP.AppDir/.junest/usr/lib32 ./junest-backups/usr/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/*.a ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/bfd-plugins/liblto_plugin.so ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/* ./junest-backups/usr/lib/dri/ 2>/dev/null

# SAVE NECESSARY SHARE DIRECTORIES
_saveshare(){
    SHARESAVED="virtualbox VirtualBox qt5"
    mkdir save
    mv ./$APP.AppDir/.junest/usr/share/*$APP* ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/*$BIN* ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/fontconfig ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/glib-* ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/locale ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/mime ./save/ 2>/dev/null
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

# REMOVE INBUILT HOME
rm -R -f ./$APP.AppDir/.junest/home

# ENABLE MOUNTPOINTS
mkdir -p ./$APP.AppDir/.junest/home
mkdir -p ./$APP.AppDir/.junest/media
mkdir -p ./$APP.AppDir/.junest/run
mkdir -p ./$APP.AppDir/.junest/tmp

# CREATE README FILE
cat > ./$APP.AppDir/README.txt << 'EOF'
# VirtualBox AppImage

This AppImage contains VirtualBox, a powerful x86 and AMD64/Intel64 virtualization product.

## Features:
1. Portable VirtualBox installation
2. No system-wide installation required
3. Runs from any location

## How to use:
1. Make the AppImage executable: chmod +x VirtualBox*.AppImage
2. Run the AppImage
3. Create and manage virtual machines as usual

## Note:
- Some features might require additional system permissions
- Performance might vary depending on system configuration
- For best performance, consider installing VirtualBox system-wide

More information: https://www.virtualbox.org
EOF

# CREATE THE APPIMAGE
ARCH=x86_64 ./appimagetool -n ./$APP.AppDir
mv ./*AppImage ./"$(cat ./$APP.AppDir/*.desktop | grep 'Name=' | head -1 | cut -c 6- | sed 's/ /-/g')"_"$VERSION""$VERSIONAUR"-x86_64.AppImage
