<div align="center">
  <img src=".logo.svg" width="25%" alt="WhaleBoot logo"/>
</div>

# WhaleBoot - bootable disks from Docker images

WhaleBoot is a command-line script that writes Docker images to bootable disks and disk images.


### Why :whale::boot:?
Most tooling in the infrastructure as code (IaC) space are ill-suited to provisioning bare-metal systems with intermittent power-on status or network connectivity.  To meet this use-case, WhaleBoot aims to provide a workflow for defining a system configuration and writing a bootable image directly to a physical disk.

### Why Docker?
- Uses a well-known and battle-tested system definition syntax
- Easily run on any modern GNU/Linux operating system
- Buildable and distributable via robust, low-cost cloud infrastructure

## Usage
[@@@]:usage-start
```
whaleboot [options] DOCKER_IMAGE DISK_FILE

Parameters:
  DOCKER_IMAGE                 Name of docker image to use
  DISK_FILE                    Path of output disk file

Options:
  -h        --help             Display this message
            --debug            Print debug messages
  -H HOST   --hostname=HOST    Hostname of disk image (default: "whale")
  -m FILE   --mbr-path=FILE    Path of syslinux mbr.bin file (default: /usr/lib/syslinux/mbr/mbr.bin)
  -s SIZE   --size=SIZE        Size of disk image (see man truncate(1) for SIZE arg semantics)
  -y        --assume-yes       Automatic yes to prompts, run non-interactively
```
[@@@]:usage-end

For WhaleBoot to produce a bootable image, the input Docker image must contain the components necessary to bring up a full operating system (that would otherwise be absent from a standard Docker image).  This includes:
- compiled Linux kernel (`vmlinuz`)
- initial ramdisk (`initrd`)
- syslinux config file (at `/boot/syslinux.cfg`)
- init system (e.g. `systemd`, `openrc`, etc.)

WhaleBoot will not create these files automatically, nor enforce that they exist within the image prior to creation of a disk image.  It is the responsibility of the user to either ensure that these files are present within the input Docker image, or to add them to the final output image.

For examples of `Dockerfile`'s that demonstrate conformity to the above requirements, see [pszenher/jackal-docker](https://github.com/pszenher/jackal-docker).

## Dependencies
The following executables are required to be in the system path for whaleboot to run:

`dd, docker, extlinux, jq, mkfs.ext4, mktemp, pv, sfdisk, tar, truncate, udevadm`

#### Ubuntu
```
# apt-get install docker.io git syslinux-common extlinux jq pv udev 
```

#### Alpine Linux
```
# apk install bash docker e2fsprogs eudev git jq ncurses pv sfdisk syslinux
```

## Installation

#### From GitHub:
```
$ git clone https://github.com/pszenher/whaleboot.git
# make -C "./whaleboot" install
```
The `whaleboot` script will be installed into `/usr/local/bin` by default.

#### From Docker Hub:
```
$ docker run -v /var/run/docker.sock:/var/run/docker.sock \
             -v "$PWD:/mnt" -v /dev:/dev --privileged --rm -it \
             pszenher/whaleboot \
             [options] DOCKER_IMAGE OUTPUT_FILE
```
**Note:** When using the Docker image method, output image filenames must be restricted to paths under shell's current working directory or `/dev`, else the image will be discarded upon container termination.

The above `docker run` command is somewhat verbose as a result of the many permissions and volume mounts required by `whaleboot`.  For convenience, the following one-liner can be run in a terminal session to permanently add a `whaleboot` bash alias to the current user's `.bashrc` file:
```
$ echo $'alias whaleboot=\'sudo docker run \
           -v $PWD:/mnt -v /dev:/dev -v /var/run/docker.sock:/var/run/docker.sock \
           --privileged --rm -it pszenher/whaleboot\'' \
         >> ~/.bashrc
```
The `sudo` command prefix can be omitted if the current user is a member of the `docker` Unix group (for how user access to the `docker` group impacts system security, see [the Docker documentation](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)).

## See Also
- [docker-to-linux](https://github.com/iximiuz/docker-to-linux)
    - similar project specifically targeting virtual machine image generation
- [Hashicorp Packer](https://github.com/hashicorp/packer)
    - tool for creating virtual machine images and provisioning them on cloud-infrastructure
