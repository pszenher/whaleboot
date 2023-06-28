function init_extlinux_config() {
    # Setup extlinux bootloader configuration of filesystem at ${rootdir}
    # Usage:
    #     init_extlinux_config ${rootdir}

    check_pos_args ${#} 1
    local rootdir
    rootdir=${1}

    ${runcmd[mkdir]} -p "${rootdir}/boot/extlinux"
    ${runcmd[cat]} <<EOF | ${runcmd[tee]} "${rootdir}/boot/extlinux/extlinux.conf" >/dev/null
DEFAULT WhaleBoot
LABEL WhaleBoot
  KERNEL /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND rw root=/dev/sda1 console=tty0 console=ttyS0,115200
TIMEOUT 10
PROMPT 0
EOF
    # boot=live toram=filesystem.squashfs
}

function install_bootloader_kernel() {
    # Copy linux kernel and init ramdisk from docker image to ${rootdir}/boot
    # Usage:
    #     install_bootloader_kernel ${rootdir}

    check_pos_args ${#} 1
    local rootdir
    rootdir=${1}

    # # Take boot directory from internal image (when using squashfs)
    # unsquashfs \
    #     -f -d "${rootdir}" \
    #     -extract-file <( echo "/boot" ) \
    #     "${rootdir}/live/filesystem.squashfs"

    # # TODO:  This is pretty jank, refactor
    # unsquashfs \
    # 	-f -d "${rootdir}" \
    # 	-extract-file <( echo "/boot/vmlinuz";     \
    # 			 echo "/boot/initrd.img" ) \
    # 	"${rootdir}/live/filesystem.squashfs"

    # unsquashfs \
    # 	-f -d "${rootdir}" \
    # 	-extract-file <( echo "/boot/$(readlink ${rootdir}/boot/vmlinuz)";     \
    # 			 echo "/boot/$(readlink ${rootdir}/boot/initrd.img)" ) \
    # 	"${rootdir}/live/filesystem.squashfs"

}
