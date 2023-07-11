package whaleboot

import "list"
import "strings"

#Disk: {
    partitiontable: #PartitionTable
    filesystems: [...#Filesystem] & [_, ...]
    _scripts: {
	disk_partition: [
	    (#PipeStrToProg & { prog: "sfdisk",
				args: [ // "-q",
					"/dev/target-disk" ],
				content: partitiontable._sfdisk_fmt
			      })._script & { id: "disk_partition_sfdisk"
					     priority: 10 }
			],
	disk_format: [ for f in filesystems { f._string }]
    }
}

#PipeStrToProg: self={
    prog: string
    args: [...string]
    content: string
    let argstr = strings.Join(args, " ")
    _script: {
	id: string
	priority: number
	content: strings.Join( [ "cat <<EOF | \(prog) \(argstr)", self.content, "EOF" ], "\n" )
    }
}

#RunProg: {
    prog: string
    args: [...string]
    let argstr = strings.Join(args, " ")
    _script: "\(prog) \(argstr)"
}    

#PartitionTable: self={
    unit?: "sectors"
    label: "dos" | "gpt" | "hybrid"
    id?: #uuid
    device?: #UnixPath
	firstlba?: int
	lastlba?: int
    partitions: [...#Partition] & [_, ...]

    // Transformation Fields
    _sfdisk_fmt: strings.Join(
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
	    for p in partitions { p._sfdisk_fmt }
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

    _sfdisk_fmt: strings.Join(
	[
	    for key, val in self
	    if (key != "bootable" || (val & false) == _|_ ) {
		if (key == "bootable") { "bootable" }
		if (key != "bootable") { "\(key)=\(val)" }
	    }
	],
	", "
    )
}
