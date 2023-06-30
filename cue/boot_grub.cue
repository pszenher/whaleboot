package whaleboot

import "strings"

#GrubBootloader: self=(#BootloaderBase & {
    program: "grub"
    config: #GrubConfig
    _scripts: {
	boot_config: [ self.config._script ]
	boot_install: [ { id: "boot_grub_install", priority: 85, content: "grub-install --removable" } ]
    }
})

#GrubConfig: {
    set: [...string]
    menuentries: [...#GrubMenuentry]
    let set_str = strings.Join(set, "\n")
    let men_str = strings.Join([ for m in menuentries { m._script } ], "\n")
    _script: {
	id: "boot_grub_config"
	priority: 80
	content: strings.Join(
	    [
		"cat <<EOF > /boot/grub/grub.cfg",
		"\(set_str)",
		"\(men_str)",
		"EOF"
	    ], "\n" )
    }
}

#GrubMenuentry: self={
    title: string
    commands: [...#GrubCommand]
    _script: strings.Join( ["menuentry \(self.title)"] + [ for c in self.commands { c._script }], "\n    ")
}

#GrubCommand: self={
    name: string
    args: [...string]
    _script: strings.Join( [ self.name ] + self.args, " " )
}

