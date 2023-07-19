package whaleboot

// import "strings"

#Filesystem: #Fatfs | #Ext4fs | #Ext2fs

#Fatfs: #FsBase & {
    type: "fat"
    fat_size: 12 | 16 | *32
    // TODO: allow other valid label chars (lowercase, whitespace, etc.)
    label: string & (=~ #"[A-Z]{1,11}"# | *"") 

    _mkfs_command: {
	command: "mkfs.fat",
	args: [
	    "-F \(fat_size)",
	    "-n \(label)"
	]
    }
}

#Ext4fs: #FsBase & {
    type: "ext4"
    label: string | *""
    _mkfs_command: {
	command: "yes | mkfs.ext4"
	args: [
	    // FIXME: why does this not yield status output even when -q is disabled?
	    // "-q",
	    // NOTE: unsafe, should pipe yes(1) into this instead...
	    "-F",
	    // TODO: need to disable 64-bit ext4 creation when using sys/extlinux...
	    // "-O ^64bit"
	    "-L \(label)",
	]
    }
}

#Ext2fs: #FsBase & {
    type: "ext2"
    label: string | *""

    _mkfs_command: {
	command: "mkfs.ext2"
	args: [
	    "-L \(label)"
	]
    }
}

#FsBase: {
    partlabel: string
    type: string
    mountpoint: #UnixPath	// TODO: no /../ or /./

    _mkfs_command: #UnixCommand & {
	postfix_args: [ target ]
	...
    }

    let target = "/dev/disk/by-partlabel/\(partlabel)"
    let full_mountpoint = "\(chroot_mountpoint)\(mountpoint)"
    let mountpoint_priority = len(mountpoint) / 4096.0 // assuming 4096-byte max path length
    _tasks: [
	{
	    id: "make_filesystem_\(partlabel)"
	    priority: 20
	    content: _mkfs_command._toString
	},
	{
	    id: "mount_filesystem_\(type)"
	    priority: 25 + mountpoint_priority
	    content: """
mkdir -p \(full_mountpoint)
mount \(target) \(full_mountpoint)
"""
	},
	{
	    id: "unmount_filesystem_\(type)"
	    priority: 95 + (1 - mountpoint_priority)
	    content: "umount \(full_mountpoint)"
	}
    ]
    ...
}
