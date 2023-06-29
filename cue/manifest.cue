package whaleboot

import "list"
import "strings"

#WhalebootManifest: {
    version: int & >= 0
    // system: #System
    disk: #Disk
	files: #FilesSpec
    bootloader: ( *#GrubBootloader | #ExtlinuxBootloader) & ( *#EfiConfig | #BiosConfig | #HybridConfig )

	commands: disk._scripts & files._scripts & bootloader._scripts
	
	// FIXME:  refactor to use "label" key
    // // Validation Fields
    // _#efi_has_partition: true &
	// bootloader."efi-partition".name == disk.partitiontable.partitions[0].name
}

#FilesSpec: self={					// FIXME: near name collision with #FileSpec
	docker: [...#DockerExportSpec]
	keep: #KeepFileSpec
	overrides: [...#OverrideFileSpec]

	// Validation
	_no_double_override: true & list.UniqueItems(
		[ for o in self.overrides { o.path } ] )

	// Transformation
	_scripts: {
		docker: [ for d in self.docker { d._script } ]
		keep: self.keep._scripts
		overrides: [ for o in self.overrides { o._script } ]
	}
}

#DockerExportSpec: {
	label: string				// TODO: valid disk label
	mountpoint: #UnixPath
	exclude: *[] | [...#UnixPath]
	_script: strings.Join(
		[ "tar x -C $chroot\(mountpoint) -f -" ]  +
		[ for e in exclude { "--exclude=\(e)" } ],
		" ")
}

#KeepFileSpec: self={
	manifest: *true | bool
	dockerenv: *true | bool
	_scripts: [
		if ( self.manifest == false ) {
			"rm $chroot/whaleboot-manifest.yaml"
		},
		if ( self.dockerenv == false ) {
			"rm $chroot/.dockerenv"
		}
]
}

#OverrideFileSpec: self={
	path: #UnixPath
	content: #File
	
	// Transformations
	_script: strings.Join(
		[
			if ( (self.content & string) != _|_ ) {
				strings.Join(
					[ "cat <<EOF > \(self.path)", self.content, "EOF" ],
					"\n" )
			}
			if ( (self.content & #LineList) != _|_ ) {
				strings.Join(
					[ "cat <<EOF > \(self.path)", strings.Join( self.content, "\n" ), "EOF" ],
					"\n" )
			}
			if ( (self.content & #FileSpec) != _|_ ) {
				"\(self.content._command) \(self.path)"
			}
	],
		"\n"
	)
	// owner: #ChownSpec			// TODO: implement
	// permissions: #ChmodSpec		// TODO: implement
}
