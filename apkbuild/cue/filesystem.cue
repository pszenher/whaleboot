package whaleboot

// import "strings"

#Filesystem: #Fatfs | #Ext4fs | #Ext2fs

#Fatfs: #FsBase & {
    type: "fat"
    fat_size: 12 | 16 | *32
    // TODO: allow other valid label chars (lowercase, whitespace, etc.)
    label: string & (=~ #"[A-Z]{1,11}"# | *"") 

    command: {
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
    command: {
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

#Ext2fs: {
    #FsBase & {
	type: "ext2"
	label: string | *""

	command: {
	    command: "mkfs.ext2"
	    args: [
		"-L \(label)"
	    ]
	}
    }
}

#FsBase: {
    partlabel: string
    target: "/dev/disk/by-partlabel/\(partlabel)"
    command: #UnixCommand & {
	postfix_args: [ target ]
	...
    }
    
    _tasks: [{
		id: "make_filesystem_\(partlabel)"
		priority: 20
		content: command._toString
    }]
    ...
}
