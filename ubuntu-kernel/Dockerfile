FROM ubuntu:focal

ARG APT_UPDATE="apt-get -qq update"
ARG APT_INSTALL="apt-get -qq install --no-install-recommends -y"
ARG APT_BUILD_DEP="apt-get -qq build-dep --no-install-recommends -y"
ARG APT_CACHE_PURGE="rm -rf /var/lib/apt/lists/*"

ARG GIT_CLONE="git clone --quiet --depth=1 --single-branch --config advice.detachedHead=false"

RUN ${APT_UPDATE} && ${APT_INSTALL} \
    \
    ca-certificates \
    git \
    \
    && ${APT_CACHE_PURGE}

RUN ${GIT_CLONE} \
    "git://kernel.ubuntu.com/ubuntu/ubuntu-focal.git" \
    "/tmp/ubuntu-kernel" \
    --branch "Ubuntu-5.4.0-150.167"

RUN sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list

RUN apt-get update --no-install-recommends -y && \
    DEBIAN_FRONTEND='noninteractive' \
    apt-get build-dep --no-install-recommends -y \
    \
    linux-image-unsigned-5.4.0-150-generic \
    \
    && ${APT_CACHE_PURGE}

# RUN ${APT_UPDATE} && DEBIAN_FRONTEND='noninteractive' ${APT_INSTALL} \
#     \
#     libncurses-dev \
#     gawk \
#     flex \
#     bison \
#     openssl \
#     libssl-dev \
#     dkms \
#     libelf-dev \
#     libudev-dev \
#     libpci-dev \
#     libiberty-dev \
#     autoconf \
#     llvm \
#     \
#     && ${APT_CACHE_PURGE}

RUN ${APT_UPDATE} && DEBIAN_FRONTEND='noninteractive' ${APT_INSTALL} \
    \
    fakeroot \
    libncurses-dev \
    gawk \
    flex \
    bison \
    openssl \
    libssl-dev \
    dkms \
    libelf-dev \
    libudev-dev \
    libpci-dev \
    libiberty-dev \
    autoconf \
    llvm \
    \
    && ${APT_CACHE_PURGE}

WORKDIR /tmp/ubuntu-kernel

RUN chmod +x \
    debian/rules \
    debian/scripts/* \
    debian/scripts/misc/*

RUN LANG=C fakeroot debian/rules clean

# RUN LANG=C fakeroot debian/rules editconfigs

