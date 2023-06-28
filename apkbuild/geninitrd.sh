#!/bin/sh -e

cleanup() {
	rm -rf "$tmp"
}

tmp="$(mktemp -d)"
trap cleanup EXIT
chmod 0755 "$tmp"

arch="$(apk --print-arch)"
repositories_file=/etc/apk/repositories
keys_dir=/etc/apk/keys

while getopts "a:r:k:o:" opt; do
	case $opt in
	a) arch="$OPTARG";;
	r) repositories_file="$OPTARG";;
	k) keys_dir="$OPTARG";;
	o) outfile="$OPTARG";;
	esac
done
shift $(( $OPTIND - 1))

cat "$repositories_file"

if [ -z "$outfile" ]; then
	outfile=$name-$arch.img
fi

${APK:-apk} add --keys-dir "$keys_dir" --no-cache \
	--repositories-file "$repositories_file" \
	--no-script --root "$tmp" --initdb --arch "$arch" \
	"$@"
for link in $("$tmp"/bin/busybox --list-full); do
	[ -e "$tmp"/$link ] || ln -s /bin/busybox "$tmp"/$link
done

${APK:-apk} fetch --keys-dir "$keys_dir" --no-cache \
	--repositories-file "$repositories_file" --root "$tmp" \
	--stdout --quiet alpine-release | tar -zx -C "$tmp" etc/

# make sure root login is disabled
sed -i -e 's/^root::/root:*:/' "$tmp"/etc/shadow

branch=edge
VERSION_ID=$(awk -F= '$1=="VERSION_ID" {print $2}'  "$tmp"/etc/os-release)
case $VERSION_ID in
*_alpha*|*_beta*) branch=edge;;
*.*.*) branch=v${VERSION_ID%.*};;
esac

cat > "$tmp"/etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/$branch/main
https://dl-cdn.alpinelinux.org/alpine/$branch/community
EOF

# tar --numeric-owner --exclude='dev/*' -c -C "$tmp" . | gzip -9n > "$outfile"

cat > "$tmp"/init <<EOF
#!/bin/sh

set -e

echo "hello there..."

tree /

modprobe -a loop

while ! [ -b "/dev/sda" ]; do
      echo "waiting for /dev/sda..."
      ls -la /dev
      sleep 1
done

mount /dev/sda /mnt

poweroff -f
EOF
chmod +x "$tmp"/init

# find "$tmp" | cpio --quiet -H newc -o | gzip -9n > "$outfile"

(cd "$tmp" && find . | sort | cpio --quiet --renumber-inodes -o -H newc | gzip -9n) > "$outfile"
