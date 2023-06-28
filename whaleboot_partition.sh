

# one-liner to test if running in container
# cat /proc/self/cgroup | grep -qE '^[0-9]*:[a-z]*:/docker/[0-9a-f]*$'; then in_container=true; 

# jq '.disk.partitiontable | to_entries | .[] | if .key != "partitions" then "\(.key): \(.value)" else .value | .[] | [ to_entries | .[] | "\(.key)=\(.value), " ] | add end' | xargs -n1 echo
