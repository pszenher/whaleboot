package whaleboot

#WhalebootManifest: {
    version: int & >= 0
    system: #System 
    disk: #Disk

    // Validation Fields
    _#efi_has_partition: true &
	system.bootloader."efi-partition".name == disk.partitiontable.partitions[0].name
}
