#!/bin/sh

set -o errexit -o noclobber -o nounset -o pipefail

# Trap exit signals so we (hopefully) don't hard panic
trap 'busybox poweroff -f' EXIT INT HUP

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

# # Make sure /dev/kmsg is a device node. Writing to /dev/kmsg allows the use of the
# # earlyprintk kernel option to monitor early init progress. As above, the -c check
# # prevents an error if the device node has already been seeded.
# [ -c /dev/kmsg ] || mknod -m 660 /dev/kmsg c 1 11

mount -t proc -o noexec,nosuid,nodev proc /proc

# # pty device nodes (later system will need it)
# [ -c /dev/ptmx ] || mknod -m 666 /dev/ptmx c 5 2
# [ -d /dev/pts ] || mkdir -m 755 /dev/pts
# mount -t devpts -o gid=5,mode=0620,noexec,nosuid devpts /dev/pts

# # shared memory area (later system will need it)
# [ -d /dev/shm ] || mkdir /dev/shm
# mount -t tmpfs -o nodev,nosuid,noexec shm /dev/shm

# Load relevant kernel modules 
for mod in sd_mod ; do
    modprobe $mod
done

# Configure alternative logging point which strips newlines (for
# pipe_progress formatting)
mkfifo /tmp/ttyS1_no_newline
cat /tmp/ttyS1_no_newline | tr -d '\n' >> /dev/ttyS1 &

echo -n "Mounting /dev/sda on /mnt ..." >> /dev/ttyS1
mount -t ext4 /dev/sda /mnt 2>> /dev/ttyS1
echo " [SUCCESS]" >> /dev/ttyS1

echo -n "Unpacking tarred stdin to /mnt ..." >> /dev/ttyS1
cat /dev/sdb \
    | pipe_progress \
	  2>> /tmp/ttyS1_no_newline \
    | tar x -f "-" -C "/mnt" --exclude="{tmp,sys,proc}" \
	  2>> /dev/ttyS1
echo " [SUCCESS]" >> /dev/ttyS1

# echo "running emergency shell..."
# sh

# NOTE: We should never call this from an init script, but we have a
#       trap on EXIT so *shrug*
exit 0
