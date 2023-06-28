package whaleboot

#Filesystem: #Fatfs | #Ext4fs | #Ext2fs

#Fatfs: self={
    #FsBase & {
	"type": "fat"
	"fat_size": 12 | 16 | *32
	// TODO: allow other valid label chars (lowercase, whitespace, etc.)
	"label": string & (=~ #"[A-Z]{1,11}"# | *"") 

	"command": "mkfs.fat"
	"arguments": [
	    "-F\(self.fat_size)",
	    "-L\(self.label)",
	]
    }
}

#Ext4fs: self={
    #FsBase & {
	"type": "ext4"
	"label": string | *""

	"command": "mkfs.ext4"
	"arguments": [
	    "-L\(self.label)"
	]
    }
}

#Ext2fs: self={
    #FsBase & {
	"type": "ext2"
	"label": string | *""

	"command": "mkfs.ext2"
	"arguments": [
	    "-L\(self.label)"
	]
    }
}

#FsBase: {
    partlabel: string
    command: string
    arguments: [...string]
    ...
}
