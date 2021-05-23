<div align="center">
  <img src=".logo.svg" width="25%" alt="WhaleBoot logo"/>
</div>

# WhaleBoot
Command-line tooling for creating bootable disks from Docker images.

## Usage

### Bash Script
```
whaleboot.sh [options] DOCKER_IMAGE DISK_FILE
```

### Docker Image
```
docker run -v /var/run/docker.sock:/var/run/docker.sock \
             -v "$PWD" --privileged --rm -it \
             pszenher/whaleboot jackal-kinetic virtual_machine.img
```

For convenience, the following can be run to permenantly add a `whaleboot` alias to the current user's `.bashrc` file:
```
echo $'alias whaleboot=\'sudo docker run \
           -v $PWD:/mnt -v /dev:/dev -v /var/run/docker.sock:/var/run/docker.sock \
           --privileged --rm -it pszenher/whaleboot\'' \
         >> ~/.bashrc
```

## Requirements
The following executables are required to be in the system path for whaleboot to execute properly:
- dd
- docker
- extlinux
- jq
- mkfs.ext4
- mktemp
- pv
- sfdisk
- tar
- truncate
- udevadm

### Alpine Linux
```
# apk install bash docker e2fsprogs eudev jq ncurses pv sfdisk syslinux
```
