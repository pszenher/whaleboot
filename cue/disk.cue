package whaleboot

import "list"
import "strings"

#Disk: {
    partitiontable: #PartitionTable
    filesystems: [...#Filesystem] & [_, ...]
}

#PartitionTable: self={
    unit?: "sectors"
    label: "dos" | "gpt" | "hybrid"
    id?: #uuid
    device?: #UnixPath
    partitions: [...#Partition] & [_, ...]

    // Transformation Fields
    sfdisk_fmt: strings.Join(
	[
	    for key, val in self
      	    if ( key != "partitions" && key != "sfdisk_fmt" ) {"\(key): \(val)"}
	] + [
	    for p in partitions { p.sfdisk_fmt }
	],
	"\n"
    )
    
    // Validation Fields
    _#unique_partlabel: true & list.UniqueItems(
	[ for p in partitions { p.name } ]
    ) 
}

#Partition: self={
    start: int | #SuffixedBytes | *"-" | "+"
    size:  int | #SuffixedBytes | *"-" | "+"
    bootable?: bool
    attrs?: string				// TODO: valid sfdisk attrs
    uuid?: #uuid
    name: string				// TODO: valid partlabel strings
    type: string				// TODO: valid part. types

    sfdisk_fmt: strings.Join(
	[ for key, val in self if (key != "sfdisk_fmt") { "\(key)=\(val)" } ],
	", "
    )
}
