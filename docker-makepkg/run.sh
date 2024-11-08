 #!/usr/bin/env bash
set -e

# Make a copy so we never alter the original
echo "Copy PKGBUILD ..."
rsync -av --exclude=".*" /pkg/ /tmp/pkg/
cd /tmp/pkg

# Use bolted LLVM
if [[ -n "$LLVM_BOLT" ]]
then
    export PATH=/home/notroot/llvm/bin:${PATH}
fi

## Create packages directory
mkdir -p /home/notroot/packages
sudo chmod 777 /home/notroot/packages

# makepkg -s cannot install AUR deps !
# Install (official repo + AUR) dependencies using paru if needed.
echo "Installing  dependencies..."
    paru -Syyu --noconfirm --disable-download-timeout
    paru -Sy --noconfirm --disable-download-timeout \
    $(pacman --deptest $(source ./PKGBUILD && echo ${depends[@]} ${checkdepends[@]} ${makedepends[@]}))

# If env $USE_CCACHE, Install ccache & enable it before building
if [[ "$USE_CCACHE" == true ]]
then
  echo "Install ccache and enable it before building ..."
  sudo pacman -S ccache --noconfirm
  rsync -avh --include=".buildcache" --exclude="*" /pkg/ /tmp/pkg/
  mkdir -p /home/notroot/.buildcache
  export USE_CCACHE=1
  export CCACHE_EXEC=/usr/bin/ccache
  export CCACHE_DIR=/home/notroot/.buildcache
  ccache -o compression=true
  sudo sed -i 's/BUILDENV=(!distcc color !ccache check !sign)/BUILDENV=(!distcc color ccache check !sign)/' /etc/makepkg.conf
fi

# If env $BUILD_WITH_CLANG, change the default compiler for building packages to clang
if [[ "$BUILD_WITH_CLANG" == true ]]
then
  echo "change the default compiler for building packages to clang ..."
  sudo pacman -S clang --noconfirm
  sudo sed -i 's/-Wp,-D_GLIBCXX_ASSERTIONS"/-Wp,-D_GLIBCXX_ASSERTIONS -stdlib=libc++"/' /etc/makepkg.conf
  sudo sed -i 's/-Wl,-z,pack-relative-relocs"/-Wl,-z,pack-relative-relocs -fuse-ld=lld"/' /etc/makepkg.conf
  echo "export CC=clang" >> /etc/makepkg.conf
  echo "export CXX=clang++" >> /etc/makepkg.conf
  echo "export QMAKESPEC=linux-clang" >> /etc/makepkg.conf
fi

# Update checksums and generate .SRCINFO & .nvchecker before building
if [[ "$CHECKSUM_SRC" == true ]]
then
  echo "Update checksums in PKGBUILD and generate .SRCINFO & .nvchecker before building ..."
  PKGREL=$(grep -o 'pkgrel=[0-9]*' PKGBUILD | grep -o '[0-9]*')
  NEW_PKGREL=$(echo "$PKGREL + 0.1" | bc)
  sed -i "s/pkgrel=[0-9]*/pkgrel=$NEW_PKGREL/" PKGBUILD
  updpkgsums
  makepkg --printsrcinfo > .SRCINFO
fi

# If env $PGPKEY is empty, do not add the key
if [[ -n "$PGPKEY" ]]
then
  echo "importing the PGP key ..."
  echo "$PGPKEY" | gpg --import -
fi

# Run Custom commands
if [[ -n "$CUSTOM_EXEC" ]]
then
  echo "Run Pre-build commands ..."
  echo "${CUSTOM_EXEC}" > /tmp/custom_exec.sh
  bash /tmp/custom_exec.sh
fi 

# Run the build
echo "Run the Build ..."
# If env $PGPKEY is empty, do not sign the package
if [[ -n "$PGPKEY" ]]
then
  makepkg -cf --sign --key "$PGP_KEY" --log || true
else
  makepkg -cf --log || true
fi

# If $EXPORT_PKG, set permissions like the PKGBUILD file and export the package
if [[ "$EXPORT_PKG" == true ]]
then
    sudo chown "$(stat -c '%u:%g' /pkg/PKGBUILD)" /home/notroot/packages/*.pkg.tar.*
    sudo mv /home/notroot/packages/*.log /pkg || true
    sudo mv /home/notroot/packages/*.pkg.tar.* /pkg || true
fi

# If env $USE_CCACHE, export ccache dir
if [[ "$USE_CCACHE" == true ]]
then
    rsync -avh --delete $CCACHE_DIR /pkg
fi
