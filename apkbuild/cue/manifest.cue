package whaleboot

import "list"
import "strings"

#WhalebootManifest: {
    version: int & >= 0
    disk: #Disk
    files: #FilesSpec
    bootloader: ( *#GrubBootloader | #ExtlinuxBootloader) & ( *#EfiConfig | #BiosConfig | #HybridConfig )

    commands: list.Sort(
	list.Concat(
	    [ for _, val in (disk._scripts & files._scripts & bootloader._scripts) { val } ]
	),
	{x: {}, y: {}, less: x.priority < y.priority}
    )

    script: strings.Join(
		[
			"#!/bin/sh",
			"set -e"
	] + [
			for index, command in commands {
				"echo 'Step [\(index + 1) / \(len(commands))]:  \(command.id)' >&2\n" + command.content
			}
	],
		"\n\n")
	
    // FIXME:  refactor to use "label" key
    // // Validation Fields
    // _#efi_has_partition: true &
    // bootloader."efi-partition".name == disk.partitiontable.partitions[0].name
}

#FilesSpec: self={					// FIXME: near name collision with #FileSpec
    docker: [#DockerExportSpec]
    keep: #KeepFileSpec
    overrides: [...#OverrideFileSpec]

    // Validation
    _no_double_override: true & list.UniqueItems(
	[ for o in self.overrides { o.path } ] )

    // Transformation
    _scripts: {
	image_extract: [ for d in self.docker { d._script } ]
	image_keep: self.keep._scripts
	image_overrides: [ for o in self.overrides { o._script } ]
    }
}

#DockerExportSpec: {
    label: string				// TODO: valid disk label
    mountpoint: #UnixPath
    exclude: *[] | [...#UnixPath]
    _script: {
	id: "docker_export_\(label)"
	priority: 50
	content: strings.Join(
	    // FIXME: pipe_progress redirection file should be
	    // standardized (or reroute stdout another way... subshell?)
	    [ "cat /docker-rootfs.tar | pipe_progress 2>> /tmp/ttyS1_no_newline | tar x -C \(mountpoint) -f -" ]  +
		[ for e in exclude { "--exclude=\(e)" } ],
	    " ")
    }
}

#KeepFileSpec: self={
    manifest: *true | bool
    dockerenv: *true | bool
    _scripts: [
	if ( self.manifest == false ) {
	    {
		id: "no_keep_manifest"
		priority: 60
		content: "rm /whaleboot-manifest.yaml"
	    }
	},
	if ( self.dockerenv == false ) {
	    {
		id: "no_keep_dockerenv"
		priority: 60
		content: "rm /.dockerenv"
	    }
	}
    ]
}

#OverrideFileSpec: self={
    path: #UnixPath
    content: #File
    
    // Transformations
    _script: {
	id: "docker_override_\(path)"
	priority: 70
	content: strings.Join(
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
    }
    // owner: #ChownSpec			// TODO: implement
    // permissions: #ChmodSpec		// TODO: implement
}
