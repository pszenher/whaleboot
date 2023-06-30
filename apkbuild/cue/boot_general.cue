package whaleboot

#BootloaderBase: {
    program: string
    mode: string
	// _scripts: {
	// 	bootloader: [
	// 		strings.Join( [ "cat <<EOF /boot/grub/grub.cfg", "\(self.config._script)" ] )
	// ]
	// }
    ...
}
