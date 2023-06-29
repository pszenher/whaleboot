package whaleboot

import "list"
import "strings"

#Disk: {
    partitiontable: #PartitionTable
    filesystems: [...#Filesystem] & [_, ...]
	_scripts: {
		sfdisk:  strings.Join(
			[ "sfdisk -q < cat <<EOF", partitiontable.sfdisk_fmt, "EOF"],
			"\n")
		mkfs: [ for fs in filesystems {
			strings.Join(
				[ fs.command ] + fs.arguments + [ "/dev/by-partlabel/\(fs.partlabel)" ],
				" ")
		} ],
	}
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
    sfdisk_fmt: strings.Join(
		[
			for key, val in self
      				 if ( key != "partitions" && key != "sfdisk_fmt" ) {
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
		[
			for key, val in self
					 if (key != "sfdisk_fmt")
					 {
						 "\(key)=\(val)"
					 }
	],
		", "
				   )
}
