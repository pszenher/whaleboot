package whaleboot

#GrubBootloader: #BootloaderBase & {
    program: "grub"
    config: #GrubConfig
}

#GrubConfig: {
	set: [...string]
	menuentries: [...#GrubMenuentry]
}

#GrubMenuentry: {
	title: string
	commands: [...#GrubCommand]
}

#GrubCommand: {
	name: string
	args: [...string]
}

