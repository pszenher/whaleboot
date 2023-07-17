#!/bin/sh

set -e

serial_log_dev="/dev/hvc0"

catch_exit() {
    retval="$?"
    if [ "$retval" -eq "0" ] ; then
	echo "Task completed successfully" >> "$serial_log_dev"
    else
	echo "Unexpected failure in virtual machine" >> "$serial_log_dev"
    fi
    # Need -f to force because we are init...
    busybox poweroff -f
}

# Trap exit signals so we (hopefully) don't hard panic
trap 'catch_exit' EXIT INT HUP

/bin/busybox mkdir -p \
	     "$ROOT"/usr/bin \
	     "$ROOT"/usr/sbin \
	     "$ROOT"/proc \
	     "$ROOT"/sys \
	     "$ROOT"/dev \
	     "$ROOT"/mnt \
	     "$ROOT"/tmp \
	     "$ROOT"/etc

/bin/busybox --install -s
export PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"

# Make sure /dev/null is a device node. If /dev/null does not exist yet, the command
# mounting the devtmpfs will create it implicitly as an file with the "2>" redirection.
# The -c check is required to deal with initramfs with pre-seeded device nodes without
# error message.
[ -c /dev/null ] || mknod -m 666 /dev/null c 1 3

mount -t sysfs -o noexec,nosuid,nodev sysfs /sys
mount -t devtmpfs -o exec,nosuid,mode=0755,size=2M devtmpfs /dev 2>/dev/null \
	|| mount -t tmpfs -o exec,nosuid,mode=0755,size=2M tmpfs /dev

# Make sure /dev/kmsg is a device node. Writing to /dev/kmsg allows the use of the
# earlyprintk kernel option to monitor early init progress. As above, the -c check
# prevents an error if the device node has already been seeded.
[ -c /dev/kmsg ] || mknod -m 660 /dev/kmsg c 1 11

mount -t proc -o noexec,nosuid,nodev proc /proc
# pty device nodes (later system will need it)
[ -c /dev/ptmx ] || mknod -m 666 /dev/ptmx c 5 2
[ -d /dev/pts ] || mkdir -m 755 /dev/pts
mount -t devpts -o gid=5,mode=0620,noexec,nosuid devpts /dev/pts

# shared memory area (later system will need it)
[ -d /dev/shm ] || mkdir /dev/shm
mount -t tmpfs -o nodev,nosuid,noexec shm /dev/shm

# Load relevant modules
# crc32c_generic
for mod in loop vfat ext4 sd_mod virtio_blk virtio_scsi virtio_console ; do
    echo -n "Loading module $mod ..." >> "$serial_log_dev"
    modprobe $mod 2>> "$serial_log_dev"
    echo " [DONE]" >> "$serial_log_dev"
done

# Configure alternative logging point which strips newlines (for
# pipe_progress formatting)
mkfifo "/tmp/ttyS1_no_newline"
cat "/tmp/ttyS1_no_newline" | tr -d '\n' >> "$serial_log_dev" &

echo -n "Mounting /dev/vdc1 on /whaleboot ..." >> "$serial_log_dev"
mkdir -p /whaleboot/mounts
mkdir -p /whaleboot/scripts
mount -t vfat /dev/vdc1 /whaleboot/scripts 2>> "$serial_log_dev"
echo " [SUCCESS]" >> "$serial_log_dev"

echo -n "Symlinking target device /dev/vda to /dev/target-disk..." >> "$serial_log_dev"
ln -s /dev/vda /dev/target-disk
echo " [SUCCESS]" >> "$serial_log_dev"

echo -n "Symlinking docker rootfs tar archive /dev/vdb to /docker-rootfs.tar..." >> "$serial_log_dev"
ln -s /dev/vdb /docker-rootfs.tar
echo " [SUCCESS]" >> "$serial_log_dev"

echo -n "Populating persistent device names with mdev..." >> "$serial_log_dev"
mdev -s 2>> "$serial_log_dev"
ls -la /dev/disk/by-*/ >> "$serial_log_dev"
# blkid /dev/vda1 >> "$serial_log_dev"
echo " [SUCCESS]" >> "$serial_log_dev"

# echo "/dev/vda sample:" >> "$serial_log_dev"
# echo "$(hexdump -c /dev/vda | head -n5)" >> "$serial_log_dev"

/whaleboot/scripts/script.sh >&2 2>> "$serial_log_dev"

# echo -n "Partitioning /dev/vda with fdisk ..." >> "$serial_log_dev"
# echo "label: dos" | sfdisk --wipe always /dev/vda 2>> "$serial_log_dev"
# echo "start=2048, type=83, bootable" | sfdisk -q /dev/vda 2>> "$serial_log_dev"
# echo " [SUCCESS]" >> "$serial_log_dev"

# echo -n "Formatting /dev/vda1 to ext4 ..." >> "$serial_log_dev"
# yes | mkfs.ext4 -q /dev/vda1 2>> "$serial_log_dev"
# echo " [SUCCESS]" >> "$serial_log_dev"

# echo -n "Mounting /dev/vda1 on /mnt ..." >> "$serial_log_dev"
# mount -t ext4 /dev/vda1 /mnt 2>> "$serial_log_dev"
# echo " [SUCCESS]" >> "$serial_log_dev"

# echo -n "Unpacking tarred stdin to /mnt ..." >> "$serial_log_dev"
# cat /dev/vdb | pipe_progress 2>> /tmp/ttyS1_no_newline | tar x -C /mnt -f- 2>> "$serial_log_dev"
# echo " [SUCCESS]" >> "$serial_log_dev"

# echo "running emergency shell..."
# sh

# NOTE: We should never call this from an init script, but we have a
#       trap on EXIT so *shrug*
exit 0
