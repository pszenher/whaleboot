import "github.com/pszenher/whaleboot:whaleboot"

[ for key, val in whaleboot.disk.partitiontable
  if val & (bool|string|bytes|number) {"\(key): \(val)"} ]
