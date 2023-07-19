package whaleboot

#File: string | #LineList | #FileSpec

#LineList: [...string & !~ #"\n"#] & #OneOrMore

#FileSpec: self={
    action: "copy" | "symlink"
    from: #UnixPath
    to: string

    let from_chroot = chroot_mountpoint + from
    let to_chroot = chroot_mountpoint + to

    
    
    _toString: {
    	if self.action == "copy"      { "cp \(from_chroot) \(to_chroot)" }
	// NOTE: non-prefixed \(from) token used for symlink target to avoid hardcoding chroot prefix
	if self.action == "symlink"   { "ln -s -f \(from) \(to_chroot)" }
    }
}

#OneOrMore: [_, ...]

#SuffixedBytes: string & =~ "^[0-9]+[KMGTPEZY]iB"

#UnixPath: string & =~ #"^[^\000]+"#

#uuid: string & =~ "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
