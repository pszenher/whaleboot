package whaleboot

import "list"
import "strings"

#Disk: {
    partitiontable: #PartitionTable
    filesystems: [...#Filesystem] & [_, ...]
    _scripts: {
	disk_partition: [
	    (#PipeStrToProg & { prog: "sfdisk",
				args: [ "-q" ],
				content: partitiontable.sfdisk_fmt
			      })._script & { id: "disk_partition_sfdisk"
					     priority: 10 }
			],
	disk_format: [ for f in filesystems { f._string }]
    }
	    // strings.Join(
	    // 	[ "sfdisk -q < cat <<EOF", partitiontable.sfdisk_fmt, "EOF"],
	    // 	"\n")
	    // [ for fs in filesystems {
	    // 	strings.Join(
	    // 	    [ fs.command ] + fs.arguments + [ "/dev/by-partlabel/\(fs.partlabel)" ],
	    // 	    " ")
	    // } ],
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
		if ( key == "bootable" ) {
		    if ( val == true  ) { "bootable" }
		}
		// FIXME:  there has to be a better way to make an else clause...
		if ( key != "firstlba" && key != "lastlba" && key != "id" && key != "bootable" ) {
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
