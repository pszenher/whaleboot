section_whaleboot() {
    return 0
}

create_image_initrd() {
    local _script=$(readlink -f "$scriptdir/geninitrd.sh")
    local output_file="$(readlink -f ${OUTDIR:-.})/$output_filename"

    (cd "$OUTDIR"; fakeroot "$_script" -k "$APKROOT"/etc/apk/keys \
			    -r "$APKROOT"/etc/apk/repositories \
			    -o "$output_file" \
			    -a $ARCH \
			    $initrd_apks)
}

profile_whaleboot() {
    # profile_base
    title="Initial ramdisk filesystem"
    desc="Initial ramdisk filesystem.
		For use as standalone vm rootfs"
    image_ext=img
    output_format=initrd
    arch="x86 x86_64 armhf armv7 aarch64 ppc64le s390x mips64 riscv64"
    initfs_features="ata base bootchart cdrom ext4 mmc nvme raid scsi squashfs usb virtio"
    initrd_apks="busybox alpine-baselayout alpine-keys apk-tools libc-utils"
}
