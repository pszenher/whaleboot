package whaleboot

#FirmwareConfig: {
    "root-partition": #PartitionRef
    ...
}

#EfiConfig: #FirmwareConfig & {
    "mode": *"efi" | "hybrid"
    "efi-partition": #PartitionRef
    "efi-srcpath": #UnixPath
    "efi-installpath": #UnixPath
    ...
}

#BiosConfig: #FirmwareConfig & {
    "mode": *"bios" | "hybrid"
    "mbr-srcpath": string
    ...
}

#HybridConfig: #EfiConfig & #BiosConfig & {
    "mode": "hybrid"
    ...
}

#PartitionRef: {
	name?: string | *null
	label?: string | *null
}
