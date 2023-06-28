FROM alpine:3.18.2

# RUN apk add git abuild alpine-conf

# RUN git clone --depth=1 --single-branch --branch="v3.18.2" \
#     "https://gitlab.alpinelinux.org/alpine/aports.git" \
#     "/tmp/aports"

# RUN SUDO="" abuild-keygen -i -a -n

COPY ./alpine-minirootfs-3.18.2-x86_64.tar /

RUN apk add --no-scripts qemu-system-x86_64 linux-virt mkinitfs dosfstools e2fsprogs

# COPY . /tmp/aports/scripts/.

# RUN /tmp/aports/scripts/mkimage.sh \
#     --tag 3.18 \
#     --outdir /tmp/output \
#     --profile whaleboot \
#     --repository "https://dl-cdn.alpinelinux.org/alpine/v3.18/main"

COPY ./initfile.sh /initfile.sh

RUN mkinitfs \
    -i /initfile.sh \
    -c /etc/mkinitfs/mkinitfs.conf \
    -f /usr/share/mkinitfs/fstab \
    -C gzip \
    -o /initfs.test.img \
    6.1.35-0-virt

# RUN truncate -s 10M test.img && \
#     mkfs.ext4 test.img

# RUN qemu-system-x86_64 \
#     -kernel /boot/vmlinuz-virt \
#     -initrd /initfs.test.img \
#     -drive file="test.img",format=raw,id=vd0 \
#     -drive file="/alpine-minirootfs-3.18.2-x86_64.tar",format=raw,id=vd1 \
#     -append "console=ttyS0" \
#     -serial mon:stdio \
#     -nographic 

COPY ./entrypoint.sh /

CMD /entrypoint.sh

# ================================================================
# | Here Be Trash...
# ================================================================

# -chardev pipe,wait=on,path="/tmp/dockerpipe",id=pipe0 \
# -device isa-serial,chardev=pipe0,index=3

# RUN mkfifo /tmp/dockerpipe

# cat /alpine-minirootfs-3.18.2-x86_64.tar > /tmp/dockerpipe & \
