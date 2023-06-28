import "strings"

system: {
    manifest:  false
    dockerenv: false
    files: {
        etc: {
            hostname: "jackal"
            hosts: {
                type: "file"
                path: "/tmp/hosts.whaleboot"
            }
            "resolv.conf": {
                type: "symlink"
                path: "/run/systemd/resolve/stub-resolv.conf"
            }
        }
    }
    bootloader: {
        program: "grub"
        mode:    "efi"
        "efi-partition": {
            name: "efiroot"
        }
        "root-partition": {
            name: "rootfs"
        }
        "efi-srcpath":     "/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi"
        "efi-installpath": "/EFI/BOOT/BOOTX64.EFI"
        config: {
            set: ["default=0", "timeout=0"]
            menuentries: [{
                title: "WhaleBoot"
                commands: [{
                    name: "search"
                    args: ["--no-floppy", "--set=root", "--label whaleboot-root"]
                }, {
                    name: "kernel"
                    args: ["/boot/vmlinuz", "rw console=tty0 console=ttyS0,115200"]
                }, {
                    name: "initrd"
                    args: ["/boot/initrd.img"]
                }]
            }]
        }
    }
}
disk: {
    partitiontable: {
        label: "gpt"
        id:    "f9a7f215-32e0-4787-a37d-ab5144d6d7eb"
        partitions: [{
            start:    "-"
            size:     "1MiB"
            bootable: true
            attrs:    "RequiredPartition"
            name:     "efiroot"
            type:     "uefi"
        }, {
            start:    "-"
            size:     "-"
            bootable: false
            name:     "rootfs"
            type:     "Linux"
        }]
    }
    filesystems: [{
        partlabel:   "efiroot"
        type:        "fat"
        "fat-size":  32
        "fat-label": "EFI"
    }, {
        partlabel:    "rootfs"
        type:         "ext4"
        "ext4-label": "whaleboot-root"
    }]
}
version: 0

sfdisk: [
	for key, val in disk.partitiontable
      	if ( key != "partitions" ) {"\(key): \(val)"}
] + [
    for partition in disk.partitiontable.partitions
    {
	strings.Join(
	    [ for key, val in partition { "\(key)=\(val)" } ],
	    ", "
	)
    }
]

format: [
    for fsconfig in disk.filesystems {
	[
	    for key, val in fsconfig
	    
	]
    }
    
]
