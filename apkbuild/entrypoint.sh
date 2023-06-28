#!/bin/sh

set -e

echo -n "Extracting tarfile from stdin, unpacking to bind mount..." >&2
cat "/dev/stdin" | pipe_progress > "/tmp/rootfs.tar"

if [ -e /dev/kvm ] ; then
    echo "KVM device node found, enabling virt accel..." >&2
    kvm_if_avail=",accel=kvm"
else
    echo "No KVM device node found, disabling virt accel..." >&2
    kvm_if_avail=""
fi

echo "Starting virtual machine..." >&2
qemu-system-x86_64 \
    -nodefaults \
    -nographic \
    -runas nobody \
    -name "WhalebootVirtBuilder" \
    -machine "q35$kvm_if_avail" \
    -kernel "/boot/vmlinuz-virt" \
    -initrd "/initfs.test.img" \
    -smp "8" \
    -m "4G" \
    -drive "file=/bindmount.img,format=raw,id=vd0,if=virtio,index=0" \
    -drive "file=/tmp/rootfs.tar,format=raw,id=vd1,if=virtio,index=1" \
    -append "console=ttyS0" \
    \
    -chardev "null,id=hide-boot0" \
    -device "isa-serial,chardev=hide-boot0,index=0" \
    \
    -chardev "stdio,id=show-output0,signal=off" \
    -device "isa-serial,chardev=show-output0,index=1"

# -enable-kvm \
    # -serial mon:stdio \

# echo "Successfully wrote bindmount.img" >&2

exit 0
