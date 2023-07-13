package whaleboot

#File: string | #LineList | #FileSpec

#LineList: [...string & !~ #"\n"#] & #OneOrMore

#FileSpec: self={
    action: "copy" | "symlink"
    from: #UnixPath
    to: string
    _toString: {
    	if self.action == "copy"      { "cp \(from) \(to)" }
	if self.action == "symlink"   { "ln -s \(from) \(to)" }
    }
}

#OneOrMore: [_, ...]

#SuffixedBytes: string & =~ "^[0-9]+[KMGTPEZY]iB"

#UnixPath: string & =~ #"^[^\000]+"#

#uuid: string & =~ "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
