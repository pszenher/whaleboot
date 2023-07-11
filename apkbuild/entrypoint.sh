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

# mkfifo /tmp/qemu_console_out
# mkfifo /tmp/qemu_script_out

# cat /tmp/qemu_console_out | sed 's/^/[QEMU CONSOLE]:  /' >> /dev/stderr &
# cat /tmp/qemu_script_out  | sed 's/^/[QEMU SCRIPT ]:  /' >> /dev/stderr &

echo "Starting virtual machine..." >&2
time qemu-system-x86_64 \
    \
    -runas nobody \
    -nodefaults \
    -nographic \
    \
    -name "WhalebootVirtBuilder" \
    -machine "q35$kvm_if_avail" \
    -smp "$(nproc)" \
    -m "4G" \
    \
    -drive "file=/bindmount.img,format=raw,id=vd0,if=virtio,index=0" \
    -drive "file=/tmp/rootfs.tar,format=raw,id=vd1,if=virtio,index=1" \
    -drive "file=fat:rw:/whaleboot,format=raw,id=vd2,if=virtio,index=2" \
    \
    -chardev "null,id=bootlog" \
    -chardev "stdio,id=initlog,mux=on,signal=off" \
    \
    -device "virtio-serial,id=ser0,max_ports=2" \
    -device "virtconsole,bus=ser0.0,chardev=initlog,id=port0,nr=0" \
    -device "isa-serial,chardev=bootlog,index=1" \
    \
    -kernel "/boot/vmlinuz-virt" \
    -initrd "/initfs.test.img" \
    -append "console=ttyS1"



# -enable-kvm \
    # -serial mon:stdio \

# echo "Successfully wrote bindmount.img" >&2

exit 0
