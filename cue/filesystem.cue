package whaleboot

#Filesystem: #Fatfs | #Ext4fs

#Fatfs: #FsBase & {
	"type": "fat"
	"fat-size": 12 | 16 | *32
	"fat-label": string & =~ #"[A-Z]{1,11}"# | *null // TODO: allow other valid label chars (lowercase, whitespace, etc.)
}

#Ext4fs: #FsBase & {
	"type": "ext4"
	"ext4-label": string | *null
}

#FsBase: {
	partlabel: string
	...
}
