package whaleboot

#File: string | #LineList | #FileSpec

#LineList: [...string & !~ #"\n"#] & #OneOrMore

#FileSpec: self={
    type: "file" | "symlink" | "directory"
    path: #UnixPath
    _command: {
    	if self.type == "file"      { "cp \(path)" }
	if self.type == "symlink"   { "ln -s \(path)" }
	if self.type == "directory" { "cp -r \(path)" }
    }
}

#OneOrMore: [_, ...]

#SuffixedBytes: string & =~ "^[0-9]+[KMGTPEZY]iB"

#UnixPath: string & =~ #"^[^\000]+"#

#uuid: string & =~ "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
