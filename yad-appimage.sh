#!/bin/sh

# NAME OF THE APP
APP=yad
BIN="$APP"
DEPENDENCES="gtk3 glib2 webkit2gtk" #YAD depends on GTK3 and related libraries
BASICSTUFF="binutils gzip"
COMPILERS="gcc make intltool"

# ADD A VERSION, THIS IS NEEDED FOR THE NAME OF THE FINAL APPIMAGE
for REPO in { "core" "extra" "community" "multilib" }; do
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

# INSTALL THE PROGRAM USING YAY
./.local/share/junest/bin/junest -- yay -Syy
./.local/share/junest/bin/junest -- yay --noconfirm -S gnu-free-fonts $(echo "$BASICSTUFF $COMPILERS $DEPENDENCES $APP")

# SET THE LOCALE
rm ./.junest/etc/locale.conf
sed -i 's/LANG=${LANG:-C}/LANG=$LANG/g' ./.junest/etc/profile.d/locale.sh

# ADD THE ICON AND THE DESKTOP FILE AT THE ROOT OF THE APPDIR
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

# If we don't find a .desktop file, create one
if test -f ./*.desktop; then
    echo "The .desktop file is available in $APP.AppDir/"
else
    cat <<-HEREDOC >> "./$APP.desktop"
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=YAD (Yet Another Dialog)
    Comment=Display GTK+ dialog boxes from command line or shell scripts
    Exec=yad
    Icon=yad
    Categories=GTK;Development;
    Terminal=false
    StartupNotify=true
    HEREDOC
    
    # Download an icon for YAD if we didn't find one
    wget https://raw.githubusercontent.com/v1cont/yad/master/data/icons/48x48/yad.png -O ./yad.png 2>/dev/null
    if [ ! -f ./yad.png ]; then
        wget https://raw.githubusercontent.com/Portable-Linux-Apps/Portable-Linux-Apps.github.io/main/favicon.ico -O ./yad.png
    fi
fi

# CREATE THE APPRUN
rm -R -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f $0)")"
export UNION_PRELOAD=$HERE
export JUNEST_HOME=$HERE/.junest
export PATH=$HERE/.local/share/junest/bin/:$PATH

# Set up environment variables for GTK
export XDG_DATA_DIRS=$HERE/.junest/usr/share:$XDG_DATA_DIRS
export GDK_PIXBUF_MODULE_FILE=$HERE/.junest/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
export GTK_PATH=$HERE/.junest/usr/lib/gtk-3.0

# Execute YAD
EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2- | sed -e 's|%.||g')
$HERE/.local/share/junest/bin/junest proot -n -b "--bind=/home --bind=/home/$(echo $USER) --bind=/media --bind=/mnt --bind=/opt --bind=/usr/lib/locale --bind=/etc/fonts --bind=/usr/share/fonts --bind=/usr/share/themes --bind=/tmp" 2> /dev/null -- $EXEC "$@"
EOF
chmod a+x ./AppRun

# REMOVE "READ-ONLY FILE SYSTEM" ERRORS
sed -i 's#${JUNEST_HOME}/usr/bin/junest_wrapper#${HOME}/.cache/junest_wrapper.old#g' ./.local/share/junest/lib/core/wrappers.sh
sed -i 's/rm -f \"${JUNEST_HOME}${bin_path}_wrappers/#rm -f \"${JUNEST_HOME}${bin_path}_wrappers/g' ./.local/share/junest/lib/core/wrappers.sh
sed -i 's/ln/#ln/g' ./.local/share/junest/lib/core/wrappers.sh

# EXIT THE APPDIR
cd ..

# REMOVE SOME BLOATWARE
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

# SAVE ESSENTIAL BINARIES
_savebins(){
    BINSAVED="gtk3-update-icon-cache gtk-update-icon-cache update-mime-database"
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

# MOVE UNNECESSARY LIBRARIES TO BACKUP
mv ./$APP.AppDir/.junest/usr/lib32 ./junest-backups/usr/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/*.a ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/bfd-plugins/liblto_plugin.so ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/dri/* ./junest-backups/usr/lib/dri/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/gcc ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/git-* ./junest-backups/usr/lib/ 2>/dev/null
mv ./$APP.AppDir/.junest/usr/lib/pkgconfig ./junest-backups/usr/lib/ 2>/dev/null

# SAVE ESSENTIAL SHARED DIRECTORIES
_saveshare(){
    SHARESAVED="gtk-3.0 glib-2.0 icons themes"
    mkdir save
    mv ./$APP.AppDir/.junest/usr/share/*$APP* ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/*$BIN* ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/fontconfig ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/glib-* ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/locale ./save/ 2>/dev/null
    mv ./$APP.AppDir/.junest/usr/share/mime ./save/ 2>/dev/null
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

# REMOVE THE INBUILT HOME
rm -R -f ./$APP.AppDir/.junest/home

# CREATE README FILE
cat > ./$APP.AppDir/README.txt << 'EOF'
# YAD (Yet Another Dialog) AppImage

This AppImage contains YAD, a program that allows you to display GTK+ dialog boxes from command line or shell scripts.

## Features:
1. GTK3-based dialogs
2. Command line interface
3. Rich set of dialog options
4. Support for custom buttons and dialog types
5. Notification icon support

## Usage:
Run the AppImage to access YAD's dialog creation capabilities.
For help and options, run:
  ./YAD-*.AppImage --help

## Examples:
1. Simple message:
   ./YAD-*.AppImage --text="Hello World"
   
2. File selection:
   ./YAD-*.AppImage --file

3. Form dialog:
   ./YAD-*.AppImage --form --field="Name" --field="Email"

More information: https://github.com/v1cont/yad
EOF

# CREATE THE APPIMAGE
ARCH=x86_64 ./appimagetool -n ./$APP.AppDir
mv ./*AppImage ./"$(cat ./$APP.AppDir/*.desktop | grep 'Name=' | head -1 | cut -c 6- | sed 's/ /-/g')"_"$VERSION""$VERSIONAUR"-x86_64.AppImage
