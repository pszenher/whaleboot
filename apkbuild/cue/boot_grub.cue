package whaleboot

import "strings"

#GrubBootloader: #BootloaderBase & {
    program: "grub"
    config: #GrubConfig

    // Internal Fields
    _tasks: [
	{
	    id: "make_grub_dir"
	    priority: 75,
	    content: "mkdir -p \(chroot_mountpoint)/boot/whaleboot/grub"
	},
	{
	    id: "boot_grub_install",
	    priority: 85,
	    content: "grub-install --removable --target=i386-pc --boot-directory=\(chroot_mountpoint)/boot/whaleboot --efi-directory=\(chroot_mountpoint)/boot/whaleboot/efi /dev/target-disk"
	    // --target=i386-pc
	    // --target=x86_64-efi
	}
    ]
}

#GrubConfig: {
    set: [...string]
    menuentries: [...#GrubMenuentry]

    // Internal Fields
    let set_str = strings.Join(set, "\n")
    let men_str = strings.Join([ for m in menuentries { m._toString } ], "\n")
    _tasks: [{
	    id: "boot_grub_config"
	    priority: 80
	    content: strings.Join(
		[
		    "cat <<EOF > \(chroot_mountpoint)/boot/whaleboot/grub/grub.cfg",
		    "\(set_str)",
		    "\(men_str)",
		    "EOF"
		], "\n" )
	}]
}

#GrubMenuentry: {
    title: string
    commands: [...#GrubCommand]

    // Internal Fields
    _toString: strings.Join( ["menuentry \(title) {"] + [ for c in commands { c._toString }] + ["}"], "\n    ")
}

#GrubCommand: {
    name: string
    args: [...string]

    // Internal Fields
    let argstr = strings.Join( args, " " )
    _toString: "\(name) \(argstr)"
}

