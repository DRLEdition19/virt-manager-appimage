#!/bin/sh

set -u
APP=virt-manager

# CREATE A TEMPORARY DIRECTORY
mkdir -p tmp && cd tmp || exit 1

# DOWNLOADING APPIMAGETOOL
if test -f ./appimagetool; then
    echo "appimagetool already exists" 1> /dev/null
else
    echo "Downloading appimagetool..."
    wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
fi
chmod a+x ./appimagetool

# CREATE AND ENTER THE APPDIR
mkdir -p "$APP".AppDir && cd "$APP".AppDir || exit 1

# ICON
if ! test -f ./*.svg; then
    wget -q https://raw.githubusercontent.com/virt-manager/virt-manager/master/icons/virt-manager.svg
fi

# LAUNCHER
echo "[Desktop Entry]
Name=Virt-Manager
Comment=Virtual Machine Manager
Icon=virt-manager
Exec=AppRun
TryExec=virt-manager
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=true
MimeType=application/x-virt-manager;
Keywords=virtualization;vm;manager;
X-GNOME-UsesNotifications=true" > com.virt-manager.virt-manager.desktop

# APPRUN
rm -f ./AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
case "$1" in
    '') "${HERE}"/conty.sh virt-manager;;
    *) "${HERE}"/conty.sh virt-manager "$@";;
esac
EOF
chmod a+x ./AppRun

# DOWNLOAD CONTY
if ! test -f ./*.sh; then
    conty_download_url=$(curl -Ls https://api.github.com/repos/ivan-hc/Conty/releases | sed 's/[()",{} ]/\n/g' | grep -oi "https.*virt-manager.*sh$" | head -1)
    echo "Downloading Conty..."
    if wget --version | head -1 | grep -q ' 1.'; then
        wget -q --no-verbose --show-progress --progress=bar "$conty_download_url"
    else
        wget "$conty_download_url"
    fi
    chmod a+x ./conty.sh
fi

# EXIT THE APPDIR
cd .. || exit 1

# EXPORT THE APPDIR TO AN APPIMAGE
VERSION=$(curl -Ls https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=virt-manager | grep "^pkgver=" | cut -c 8-)
ARCH=x86_64 ./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 1 \
    -u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|Virt-Manager-appimage|continuous|*x86_64.AppImage.zsync" \
    ./"$APP".AppDir ./Virt-Manager-"$VERSION"-x86_64.AppImage
cd .. && mv ./tmp/*.AppImage* ./ || exit 1
