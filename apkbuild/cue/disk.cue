package whaleboot

import "list"
import "strings"

#Disk: {
    partitiontable: #PartitionTable
    filesystems: [...#Filesystem] & [_, ...]
    // _toTaskList: partitiontable._toTaskList + [ for f in filesystems { f._toTask }]
}

#PartitionTable: self=( {
    unit?: "sectors"
    label: "dos" | "gpt" | "hybrid"
    id?: #uuid
    device?: #UnixPath
    firstlba?: int
    lastlba?: int
    partitions: [...#Partition] & [_, ...]

    // Internal Fields
    _tasks: [
	{
	    id: "disk_partition_sfdisk"
	    priority: 10
	    content: sfdisk_heredoc._toString
	},
	{
	    id: "disk_refresh_kernel"
	    priority: 11
	    content: "mdev -s"
	}
    ]

    // Validation Fields
    _#unique_partition_labels: list.UniqueItems(
	[ for disk_part in partitions { disk_part.name } ]
    ) & true

    // Intermediate bindings
    let sfdisk_string = strings.Join(
	[
	    for key, val in self
      	    if ( key != "partitions" ) {
		if ( key == "firstlba" ) {
		    "first-lba: \(val)"
		}
		if ( key == "lastlba" ) {
		    "last-lba: \(val)"
		}
		if ( key == "id" ) {
		    "label-id: \(val)"
		}
		// FIXME:  there has to be a better way to make an else clause...
		if ( key != "firstlba" && key != "lastlba" && key != "id" ) {
		    "\(key): \(val)"
		}
	    }
	] + [
	    for p in partitions { p._toString }
	],
	"\n"
    )

    let sfdisk_heredoc = #UnixHeredoc & {
	command: {
	    command: "sfdisk",
	    args: [
		// "-q",
		"/dev/target-disk"
	    ],
	},
	content: sfdisk_string
    }
})

#Partition: self={
    start?: int | #SuffixedBytes | "-" | "+"
    size?:  int | #SuffixedBytes | "-" | "+"
    bootable?: bool
    attrs?: string				// TODO: valid sfdisk attrs
    uuid?: #uuid
    name?: string				// TODO: valid partlabel strings
    type: string				// TODO: valid part. types

    _toString: string & sfdisk_fmt
    
    let sfdisk_fmt = strings.Join(
	[
	    for key, val in self
	    if (key != "bootable" || (val & false) == _|_ ) {
		if (key == "bootable") { "bootable" }
		if (key != "bootable") { "\(key)=\"\(val)\"" }
	    }
	],
	", "
    )
}
