package whaleboot

import "list"
import "strings"

#HasTasks: self={
    _tasks: [...#BuildTask]

    let maintasks = _tasks

    let struct_subtasks = list.Concat([ for field_val in self {
	(*(#HasTasks & field_val) | {_toTaskList: []})._toTaskList
    }])
    let list_subtasks = list.Concat([ for field_val in self {
	list.Concat([ for entry in (*([...#HasTasks] & field_val) | []) {
	    entry._toTaskList
	}])
    }])

    // Transformation Fields
    _toTaskList: list.Sort(
	maintasks + struct_subtasks + list_subtasks,
	{
	    x: {},
	    y: {},
	    less: x.priority < y.priority
	}
    ) & [...#BuildTask]
    ...
}

#BuildTask: {
	id: string
	priority: int // & >=10 & <=99
	content: string
}

#UnixPipeList: {
    commands: [...#UnixCommand]
    
    _toString: strings.Join( commands, " | " )
}

#UnixFileRedirection: {
    operator: ">" | ">>" | "2>" | "2>>" | "<"
    filepath: #UnixPath
    
    _toString: "\(operator) \(filepath)"
}

#UnixHeredoc: {
    command: #UnixCommand
    redirections: [...#UnixFileRedirection] | *[{_toString: ""}]
    content: string

    let cmd_str = command._toString
    let redir_str = strings.Join( [ for r in redirections { r._toString } ], " " )
    _toString: strings.Join( [ "\(cmd_str) <<EOF \(redir_str) ", content, "EOF" ], "\n" )
}

#UnixCommand: {
    // TODO: rename field (command -> name) to prevent confusion in nesting...
    command: #UnixPath
    args: [...string]
    prefix_args:  [...string]
    postfix_args: [...string]
    
    let argstr = strings.Join(prefix_args + args + postfix_args, " ")
    _toString: "\(command) \(argstr)"
}

#WhalebootManifest: self=(#HasTasks & {
    version: int & >= 0
    disk: #Disk
    files: #FilesSpec
    bootloader: ( *#GrubBootloader | #ExtlinuxBootloader) & ( *#EfiConfig | #BiosConfig | #HybridConfig )

    // Transformation Fields
    let num_tasks = len(self._toTaskList)
    tasks: self._toTaskList
    script: strings.Join( [ "#!/bin/sh", "set -e" ] +
			  [
			      for index, task in self._toTaskList {
				  strings.Join( [
				      "echo -n 'Step [\(index + 1) / \(num_tasks)]:  \(task.id)' >&2",
				      task.content,
				      "echo '[SUCCESS]' >&2"
				  ], "\n" )
			      }
			  ], "\n\n")

    // Validation Fields
    // FIXME: more elegant way to test this than hard-copy...
    // 
    // NOTE: reason hack is needed is let-binding the task blocklist
    //       creates a circular-ref on the 'script' field of
    //       '#WhaleBootManifest' (during #HasTasks recursion)
    _#all_tasks_generated: true & len([
			      for index, task in self._toTaskList {
				  strings.Join( [
				      "echo -n 'Step [\(index + 1) / \(num_tasks)]:  \(task.id)' >&2",
				      task.content,
				      "echo '[SUCCESS]' >&2"
				  ], "\n" )
			      }
			  ]) == num_tasks

    // FIXME:  refactor to use "label" key
    // _#efi_has_partition: true &
    // bootloader."efi-partition".name == disk.partitiontable.partitions[0].name
})

#FilesSpec: self={					// FIXME: near name collision with #FileSpec
    docker: [#DockerExportSpec]
    keep: #KeepFileSpec
    overrides: [...#OverrideFileSpec]

    // Validation
    _no_double_override: true & list.UniqueItems(
	[ for o in self.overrides { o.path } ] )
}

#DockerExportSpec: {
    label: string				// TODO: valid disk label
    mountpoint: #UnixPath
    exclude: *[] | [...#UnixPath]
    
    _tasks: [{
	id: "docker_export_\(label)"
	priority: 50
	content: strings.Join(
	    // FIXME: pipe_progress redirection file should be
	    // standardized (or reroute stdout another way... subshell?)
	    [ "cat /docker-rootfs.tar | pipe_progress 2>> /tmp/ttyS1_no_newline | tar x -C \(mountpoint) -f -" ]  +
		[ for e in exclude { "--exclude=\(e)" } ],
	    " ")
    }]
}

#KeepFileSpec: self={
    manifest: *true | bool
    dockerenv: *true | bool
    _tasks: [
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

#OverrideFileSpec: {
    path: #UnixPath
    content: #File

    let raw_string = content
    let list_string = strings.Join( content & #LineList, "\n" )

    let literal_text_string = #UnixHeredoc & {
	command: {
	    command: "cat"
	}
	redirections: [{
	    operator: ">"
	    filepath: path
	}]
	content: raw_string | list_string
    }
	
    // Transformations
    // FIXME:  binding the "to" element here is an abstraction-busting hack...
    let file_spec_string = content & #FileSpec & { to: path, ... }
    let command_string = literal_text_string | file_spec_string
    _tasks: [{
	id: "docker_override_\(path)"
	priority: 70
	content: command_string._toString
    }]
    // owner: #ChownSpec			// TODO: implement
    // permissions: #ChmodSpec		// TODO: implement
}
