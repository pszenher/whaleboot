package whaleboot

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

