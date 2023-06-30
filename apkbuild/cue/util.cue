package whaleboot

#File: string | #LineList | #FileSpec

#LineList: [...string & !~ #"\n"#] & #OneOrMore

#FileSpec: self={
	action: "copy" | "symlink"
    from: #UnixPath
    _command: {
    	if self.action == "copy"      { "cp \(from)" }
		if self.action == "symlink"   { "ln -s \(from)" }
    }
}

#OneOrMore: [_, ...]

#SuffixedBytes: string & =~ "^[0-9]+[KMGTPEZY]iB"

#UnixPath: string & =~ #"^[^\000]+"#

#uuid: string & =~ "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
