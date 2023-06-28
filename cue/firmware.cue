package whaleboot

#FirmwareConfig: {
    "root-partition": {
	name: string
    }
    ...
}

#EfiConfig: #FirmwareConfig & {
    "mode": *"efi" | "hybrid"
    "efi-partition": {
	name: string
    }
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
