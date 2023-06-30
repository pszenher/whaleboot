package whaleboot

#Filesystem: #Fatfs | #Ext4fs | #Ext2fs

#Fatfs: self={
    #FsBase & {
	"type": "fat"
	"fat-size": 12 | 16 | *32
	// TODO: allow other valid label chars (lowercase, whitespace, etc.)
	"label": string & (=~ #"[A-Z]{1,11}"# | *"") 

	let fatsize=self."fat-size"
	"command": "mkfs.fat"
	"arguments": [
	    "-F \(fatsize)",
	    "-L \(self.label)"
	]
    }
}

#Ext4fs: self={
    #FsBase & {
	"type": "ext4"
	"label": string | *""

	"command": "mkfs.ext4"
	"arguments": [
	    "-q",
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

	command: "mkfs.ext2"
	arguments: [
	    "-L \(self.label)"
	]
    }
}

#FsBase: self={
    partlabel: string
    command: string
    arguments: [...string]
    target: "/dev/by-partlabel/\(self.partlabel)"
    _script: #RunProg & {
	prog: self.command
	args: self.arguments + [ self.target ]
    }
    _string: {
	id: "make_filesystem_\(partlabel)"
	priority: 20
	content: self._script._script
    }
    ...
}
