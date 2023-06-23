package whaleboot

#File: string | #LineList | #FileSpec

#LineList: [...string & !~ #"\n"#] & [_, ...]
#FileSpec: {
    type: "file" | "symlink"
    path: #UnixPath
}

#SuffixedBytes: string & =~ "^[0-9]+[KMGTPEZY]iB"

#UnixPath: string & =~ #"^[^\000]+"#
#uuid: string & =~ "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
