package whaleboot

#Bootloader: {
    program: "grub" | "extlinux"
    mode: "bios" | "efi" | "hybrid"
	grubconfig?: #GrubConfig
	extlinuxconfig?: #ExtlinuxConfig
	eficonfig?: #EfiConfig
	biosconfig?: #BiosConfig
}
