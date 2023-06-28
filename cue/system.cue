package whaleboot

// import "strings"

#System: {
    manifest: bool | *false
    dockerenv: bool | *false
    files: #FileHierarchy
    bootloader: ( *#GrubBootloader | #ExtlinuxBootloader) & ( *#EfiConfig | #BiosConfig | #HybridConfig )
}

#FileHierarchy: {
    etc: #EtcFiles
}

#EtcFiles: self={
    hostname: #File
    hosts: #File
    "resolv.conf": #File

    _commands: [
    	for filename, content in self
	if ( content & string )    != _|_ { "echo '\(content)' > /etc/\(filename)" }
	// if ( content & #LineList ) != _|_ { "echo '\(strings.Join( content, "\n" ))' > /etc/\(filename)" }
    ]
}

// #HybridBootloader:

