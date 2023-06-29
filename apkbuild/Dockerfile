FROM alpine:3.18.2

RUN apk add --no-scripts \
    linux-virt \
    mkinitfs \
    qemu-system-x86_64

COPY ./initfile.sh /initfile.sh

RUN mkinitfs \
    -i /initfile.sh \
    -c /etc/mkinitfs/mkinitfs.conf \
    -f /usr/share/mkinitfs/fstab \
    -C gzip \
    -o /initfs.test.img \
    6.1.35-0-virt

COPY ./entrypoint.sh /entrypoint.sh

CMD /entrypoint.sh
