FROM alpine:3.13
ARG script_name="whaleboot.sh"

# Install whaleboot dependencies
RUN apk add --no-cache \
    bash \
    docker \
    e2fsprogs \
    eudev \
    jq \
    ncurses \
    pv \
    sfdisk \
    syslinux

# Copy whaleboot script to image root
COPY "./$script_name" "/"

# Remove help text for mbr-path in docker image script (it is hard-coded in ENTRYPOINT)
RUN sed -i '/### *-m FILE *--mbr-path=FILE/d' "$script_name"

# Set working directory
WORKDIR "/mnt"

# Set entrypoint to run image as executable
ENTRYPOINT [ "/whaleboot.sh", "--mbr-path=/usr/share/syslinux/mbr.bin" ]
