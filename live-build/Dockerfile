FROM ubuntu:focal

ARG APT_UPDATE="apt-get -qq update"
ARG APT_INSTALL="apt-get -qq install --no-install-recommends -y"
ARG APT_CACHE_PURGE="rm -rf /var/lib/apt/lists/*"

ARG SOURCE_LIVE_SCRIPTS=". /usr/lib/live/build.sh"

ARG BUILD_DIR="/tmp"
WORKDIR "${BUILD_DIR}"

RUN ${APT_UPDATE} && ${APT_INSTALL} \
    \
    # System packages
    ca-certificates \
    # germinate \
    live-build \
    \
    && ${APT_CACHE_PURGE}

# RUN germinate \
#     --no-rdepends \
#     --no-installer \
#     --arch "amd64" \
#     --dist "focal" \
#     --seed-dist "ubuntu.focal" \
#     --seed-source "https://ubuntu-archive-team.ubuntu.com/seeds/" \
#     --mirror "http://archive.ubuntu.com/ubuntu/"

RUN lb config noauto \
    --mode "ubuntu" \
    --distribution "focal" \
    --parent-mirror-bootstrap "http://archive.ubuntu.com/ubuntu/" \
    --bootstrap-keyring "ubuntu-keyring" \
    --cache "false" \
    --source "false" \
    --build-with-chroot "false" \
    --apt-source-archives "false" \
    --memtest "none" \
    --binary-images "none" \
    --linux-flavours "none" \
    --initsystem "none" \
    --bootloader "none" \
    --linux-packages "none" \
    --checksums "none" \
    --initramfs=none \
    --bootstrap-flavour "minimal"

RUN lb bootstrap
RUN rm -f chroot/etc/localtime chroot/etc/timezone

COPY ./chroot/. chroot

RUN ${SOURCE_LIVE_SCRIPTS} && \
    Chroot chroot \
    "dpkg-divert --quiet --add --divert /usr/bin/man.REAL --rename /usr/bin/man"

RUN ${SOURCE_LIVE_SCRIPTS} && \
    Chroot chroot dpkg-query -f '${binary:Package}\n' -W \
    | Chroot chroot xargs -L1 apt-get install --reinstall

RUN touch .build/chroot_devpts && \
    touch .build/chroot_proc && \
    touch .build/chroot_sysfs && \
    touch .build/chroot_hooks

RUN lb chroot

RUN ${SOURCE_LIVE_SCRIPTS} && \
    Chroot chroot \
    "env DEBIAN_FRONTEND=noninteractive apt-get -y purge initramfs-tools busybox-initramfs landscape-common"

RUN rm -f chroot/boot/initrd.img-*

RUN ${SOURCE_LIVE_SCRIPTS} && \
    Chroot chroot \
    "env DEBIAN_FRONTEND=noninteractive apt-mark manual linux-base" \
    && \
    Chroot chroot \
    "env DEBIAN_FRONTEND=noninteractive apt-get -y --purge autoremove"

# clean_debian_chroot()
RUN rm -f chroot/var/cache/debconf/*-old chroot/var/lib/dpkg/*-old && \
    ${SOURCE_LIVE_SCRIPTS} && \
    Chroot chroot apt clean && \
    rm -rf chroot/var/lib/apt/lists/*
    # NOTE: ubuntu build drops device nodes in docker images, lets try
    #       keeping them...
    # 
    # rm -rf chroot/dev/*

RUN ${APT_UPDATE} && ${APT_INSTALL} \
    \
    squashfs-tools \
    \
    && ${APT_CACHE_PURGE}

RUN touch .build/chroot_devpts && \
    touch .build/chroot_proc && \
    touch .build/chroot_sysfs && \
    touch .build/chroot_hooks

RUN lb binary
