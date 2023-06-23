package whaleboot

#Disk: {
	partitiontable: #PartitionTable
	filesystems: [...#Filesystem] & [_, ...]
}

#PartitionTable: {
	unit: "sectors" | *null
	label: "dos" | "gpt" | "hybrid"
	id: #uuid | *null
	device: #UnixPath | *null
	partitions: [...#Partition] & [_, ...]
}

#Partition: {
	start: int | #SuffixedBytes | *"-" | "+"
	size:  int | #SuffixedBytes | *"-" | "+"
	bootable?: bool | *null
	attrs?: string | *null				// TODO: valid sfdisk attrs
	uuid?: #uuid | *null
	name: string				// TODO: valid partlabel strings
	type: string				// TODO: valid part. types
}
