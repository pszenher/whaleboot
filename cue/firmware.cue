package whaleboot

#EfiConfig: {
    "efi-partition": {
		name: string
    }
    "root-partition": {
		name:string
    }
    "efi-srcpath": #UnixPath
    "efi-installpath": #UnixPath
}

#BiosConfig: {
    rootpartition: {
		name:string
    }
    mbrbinpath: string
}

