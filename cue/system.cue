package whaleboot

#System: {
    manifest: bool | *false
    dockerenv: bool | *false
    files: #FileHierarchy
    bootloader: #Bootloader
}

#FileHierarchy: {
    etc: #EtcFiles
}

#EtcFiles: {
    hostname: #File
    hosts: #File
    "resolv.conf": #File
}

// #HybridBootloader:

