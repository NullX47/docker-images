FROM archlinux:base-devel
LABEL maintainer="NullX47 <nullx47@gmail.com>"

# COPY needed files
COPY run.sh /run.sh
COPY pacman.conf /etc/pacman.conf
COPY paru.conf /etc/paru.conf
COPY rust.conf /etc/makepkg.conf.d/rust.conf
COPY ccache.conf /etc/ccache.conf
COPY cachyos-mirrorlist /etc/pacman.d/cachyos-mirrorlist
COPY cachyos-v3-mirrorlist /etc/pacman.d/cachyos-v3-mirrorlist
COPY cachyos-v4-mirrorlist /etc/pacman.d/cachyos-v4-mirrorlist
COPY mirrorlist /etc/pacman.d/mirrorlist

RUN \
  # Fix script permissions
  chmod 755 /run.sh && \
  # makepkg cannot (and should not) be run as root:
  useradd -m notroot && \
  # Allow notroot to run stuff as root (to install dependencies):
  echo "notroot ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/notroot

# Continue execution (and CMD) as notroot:
USER notroot
WORKDIR /home/notroot

RUN \
    # Auto-fetch GPG keys (for checking signatures):
    mkdir .gnupg && \
    touch .gnupg/gpg.conf && \
    echo "keyserver-options auto-key-retrieve" > .gnupg/gpg.conf && \
    find ~/.gnupg -type f -exec chmod 600 {} \; && \
    find ~/.gnupg -type d -exec chmod 700 {} \; && \
    # fetch CachyOS GPG key
    sudo pacman-key --init && \
    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com && \
    sudo pacman-key --lsign-key F3B607488DB35A47 && \
    # Install needed packages
    sudo pacman -U --noconfirm 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-18-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-18-1-any.pkg.tar.zst' 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-6-1-any.pkg.tar.zst' && \
    sudo pacman -Sy --noconfirm cachyos-rate-mirrors && sudo cachyos-rate-mirrors && \
    sudo pacman -Syyu --noconfirm --needed archlinux-keyring binutils cmake debugedit fakeroot git wget namcap python rsync sudo base-devel multilib-devel paru pacman-contrib zstd zlib-ng-compat lib32-zlib-ng-compat bc && \
    # cleanup
    sudo rm -Rf /var/cache/pacman/pkg/ && \
    sudo rm -rf ~/.cache/*
    
COPY makepkg.conf /etc/makepkg.conf

# Build the package
WORKDIR /pkg
ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/run.sh"]
