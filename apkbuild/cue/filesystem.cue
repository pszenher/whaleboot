package whaleboot

import "strings"

#Filesystem: #Fatfs | #Ext4fs | #Ext2fs

#Fatfs: self={
    #FsBase & {
	"type": "fat"
	"fat-size": 12 | 16 | *32
	// TODO: allow other valid label chars (lowercase, whitespace, etc.)
	"label": string & (=~ #"[A-Z]{1,11}"# | *"") 

	let fatsize=self."fat-size"
	mkfs_command: "mkfs.fat"
	"arguments": [
	    "-F \(fatsize)",
	    "-n \(self.label)"
	]
    }
}

#Ext4fs: self={
    #FsBase & {
	"type": "ext4"
	"label": string | *""
	mkfs_command: "yes | mkfs.ext4"
	"arguments": [
	    // FIXME: why does this not yield status output even when -q is disabled?
	    // "-q",
	    // NOTE: unsafe, should pipe yes(1) into this instead...
	    "-F",
	    // TODO: need to disable 64-bit ext4 creation when using sys/extlinux...
	    // "-O ^64bit"
	    "-L \(self.label)",
	]
    }
}

#Ext2fs: self={
    #FsBase & {
	type: "ext2"
	label: string | *""

	mkfs_command: "mkfs.ext2"
	arguments: [
	    "-L \(self.label)"
	]
    }
}

#FsBase: self={
    partlabel: string
    mkfs: #UnixCommand & {
		command: "\(mkfs_command)"
		args: [ "/dev/disk/by-partlabel/\(self.partlabel)" ]
	}
    mkfs_command: string
    arguments: [...string]
    target: "/dev/disk/by-partlabel/\(self.partlabel)"
    
    _toCommands: [ mkfs._toString ]
    _toTask: {
		id: "make_filesystem_\(partlabel)"
		priority: 20
		content: strings.Join(_toCommands, "\n")
    }
    ...
}

#UnixCommand: {
    command: #UnixPath
    args: [...string]

    let argstr = strings.Join(args, " ")
    _toString: "\(command) \(argstr)"
}
