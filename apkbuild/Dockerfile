FROM alpine:3.18.2

RUN apk add --no-scripts \
    # Kenel/virtualization packages
    linux-virt \
    mkinitfs \
    qemu-system-x86_64 \
    \
    # Filesystem Utils for Initramfs
    sfdisk \
    e2fsprogs \
    dosfstools \
    \
    # Use full util-linux blkid to have mdev detect partuuid and partlabel
    blkid

# cue-lang command-line tool (from alpine/edge:testing)
# TODO: should probably use a more reliable source here...
RUN apk add \
    -X https://dl-cdn.alpinelinux.org/alpine/edge/testing \
    cue-cli

COPY ./cue /cue

RUN mkdir /whaleboot && \
    ( cd /cue && cue export test.cue  /cue/whaleboot-manifest.yaml -e script --out text ) \
    > /whaleboot/script.sh && \
    chmod +x /whaleboot/script.sh

COPY ./initfile.sh /initfile.sh
COPY ./features.d /tmp/features.d

RUN mkinitfs \
    -i /initfile.sh \
    # -c /etc/mkinitfs/mkinitfs.conf \
    -c /tmp/features.d/mkinitfs.conf \
    # -f /usr/share/mkinitfs/fstab \
    -f /dev/null \
    -P /tmp/features.d \
    -C gzip \
    -o /initfs.test.img \
    6.1.38-0-virt

RUN chmod 444 "/initfs.test.img"

COPY ./entrypoint.sh /entrypoint.sh
CMD /entrypoint.sh
