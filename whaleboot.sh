#!/usr/bin/env bash

# Copyright (C) 2023 Paul Szenher
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

### whaleboot -- build bootable disk image from docker image
###
### Usage:
###   whaleboot [options] DOCKER_IMAGE DISK_FILE
###
### Parameters:
###   DOCKER_IMAGE                 Name of docker image to use
###   DISK_FILE                    Path of output disk file
###
### Options:
###   -h        --help             Display this message
###             --debug            Print debug messages
###             --dryrun           Simulate run, don't write to disk
# ###   -H HOST   --hostname=HOST    Hostname of disk image (default: "whale")
# ###   -m FILE   --mbr-path=FILE    Path of syslinux mbr.bin file (default: /usr/lib/syslinux/mbr/mbr.bin)
###   -s SIZE   --size=SIZE        Size of disk image (default: "5G")
###                                (see man truncate(1) for SIZE arg semantics)
###   -y        --assume-yes       Automatic yes to prompts, run non-interactively
###

# Set sane bash options and catch EXIT and ERR signals
set -o errexit -o pipefail -o noclobber -o nounset
trap "catch_exit" EXIT
trap "catch_err" ERR

script_path="$(dirname ${0})"

path_real="${PATH}"
# shellcheck disable=SC2123
PATH=""

# Declare runcmd as global bash associative-array
declare -A -g runcmd

source "${script_path}/src/util.bash"

function catch_exit() {
    # Handler function for trapping process signals
    # Usage:
    #     trap "catch_exit" EXIT

    local exit_code=${?}

    cleanup
    exit "${exit_code}"
}

function catch_err() {
    # Handler function for trapping process signals
    # Usage:
    #     trap "catch_err" ERR

    local err_code=${?} caller_info err_line err_file

    caller_info="$(caller)"
    err_line="${caller_info%% *}"
    err_file="${caller_info#* }"
    logerror "Internal error with exit code ${err_code}"
    logerror "${err_file} L${err_line} | $(${runcmd[sed]} -n "${err_line}"'{p;q}' "${err_file}" || true)"
    exit "${err_code}"
}

function cleanup() {
    # Cleanup function to run on exit
    # Usage:
    #     cleanup

    # Unmount and delete loopback device if it is defined
    if [[ -n "${loopback_dev-}" ]]; then
        loginfo "Unmounting disk image device ${loopback_dev}"
        ${runcmd[umount]} "${loopback_dev}" && ${runcmd[sync]}
        ${runcmd[losetup]} -d "${loopback_dev}"
    fi

    # Remove temporary mount directory
    if [[ -d "${mount_dir-}" ]]; then
        loginfo "Removing temporary mount dir ${mount_dir}"
        ${runcmd[rmdir]} "${mount_dir}"
    fi

    # Remove temporary docker container if it is defined
    if [[ -n "${docker_container-}" ]]; then
        loginfo "Removing temporary docker container"
        ${runcmd[docker]} container rm "${docker_container}" >/dev/null
    fi
}

source "${script_path}/src/disk.bash"
source "${script_path}/src/bootloader.bash"
source "${script_path}/src/files.bash"

function main() {
    local loopback_device \
	  loopback_partition_nums \
	  container_name \
	  whaleboot_utils_image
	  # manifest_content
    
    loginfo "Identifying/creating disk target"
    init_disk_image "${file_name}" "${image_file_size}"

    loginfo "Reading manifest from target Docker image"
    container_name="whaleboot-temp-${RANDOM}"
    ${runcmd[docker]} create --name="${container_name}" "${image_name}" \
        2> >(logpipe "error" "Docker create: ") \
	| logpipe "warn" "Docker create: "
    loginfo "Created temporary container '${container_name}'"
    
    # manifest_content="$(${runcmd[docker]} cp "${container_name}:/whaleboot-manifest.yaml" -)"
    # loginfo "Read manifest content '${manifest_content}'"
    
    loginfo "Building whaleboot-utils docker image"
    whaleboot_utils_image="$(${runcmd[cat]} <<EOF | ${runcmd[docker]} build -q -f - "." 2> >(logpipe "error" "Docker build: ")

FROM ${image_name} AS root-image
FROM alpine:3.18
# need GNU sed for '-z' flag
RUN apk add syslinux \
    	    grub \
	    bash \
	    sed
RUN apk add -X https://dl-cdn.alpinelinux.org/alpine/edge/testing \
    cue-cli
COPY . /whaleboot
COPY --from=root-image /whaleboot-manifest.yaml /
WORKDIR /whaleboot/cue
RUN cue eval --out json -cE /whaleboot-manifest.yaml /whaleboot/cue/test.cue > /whaleboot-manifest.json
WORKDIR /
EOF

)"

    loginfo "Binding loopback block device"
    loopback_device="$(init_loopback_dev "${file_name}")"
    loginfo "Loopback device configured on '${loopback_device}'"

    # Prepare trap to cleanup loop device on process exit
    trap_push "EXIT" "cleanup_loopback_dev" "${loopback_device}"
    
    # Perform partition of loopback device according to whaleboot-manifest.json
    ${runcmd[docker]} \
	run --rm --device="${loopback_device}" \
	"${whaleboot_utils_image}" \
	/whaleboot/whaleboot.sh partition -c "/whaleboot-manifest.json" "${loopback_device}" \
	2> >(logpipe "error" "docker whaleboot-utils: ")

    # Destroy loop device and recreate, this time with PARTSCAN for
    # new loop[0-9]+p[0-9]+ device detection
    # TODO: verify that the below runs:
    #           'cleanup_loopback_dev "${loopback_device}"'
    trap_pop "EXIT"
    
    loopback_device="$(init_loopback_dev "${file_name}")"
    loginfo "Loopback device reconfigured on '${loopback_device}'"

    # Install whaleboot docker image to disk
    # 
    # FIXME: using the api this way will require that the docker
    #        daemon socket be mounted on the guest, do we want this?
    #        SOLUTION: instead, we can just pipe the tarfile from
    #        export -> stdin on the host...
    #
    # TODO: add each partition index from ${part_num} above as
    #       separate "--device=" flag.  DONE:  now test that it lexes...
    loopback_partition_nums=( "$(${runcmd[partx]} -sgo nr /dev/loop0)" )
    ${runcmd[docker]} export "${container_name}" \
		      2> >(logpipe "error" "docker export: ") \
	| ${runcmd[docker]} \
	      run --rm -i \
	      --device="${loopback_device}" \
	      $(printf "--device=${loopback_device}p%s\n" "${loopback_partitions[@]}") \
	      "${whaleboot_utils_image}" \
	      whaleboot install "${loopback_device}" \
	      2> >(logpipe "error" "docker export: ")

    if [[ -n "${enable_qemu_test:-}" ]]; then
	loginfo "Testing created image using qemu"
	${runcmd[docker]} \
	    run --rm \
	    --device="${loopback_device}" \
	    "${whaleboot_utils_image}" \
	    whaleboot test "${loopback_device}"
    else
	loginfo "Testing not enabled, skipping qemu tests"
    fi

    exit 0
}

function main_old() {
    loginfo "Initializing disk image"
    init_disk_image "${file_name}" "${image_file_size}"

    loginfo "Initializing disk partitions"
    init_disk_partitions "${file_name}"

    loginfo "Configuring loopback block device for disk image"
    loopback_dev=$(
        ${runcmd[losetup]} -f
    )
    # ${runcmd[losetup]} \
    #     -o $((512 * 2048)) "${loopback_dev}" "${file_name}" 2>&1 \
    #     | logpipe "error"
    ${runcmd[losetup]} \
	-P "${loopback_dev}" "${file_name}" 2>&1 \
        | logpipe "error"

    loginfo "Loopback device configured, \"${loopback_dev}\""

    # loginfo "Formatting disk partition as ext4"
    # NOTE: Option flag ~-O ^64bit~ added to force 32bit ext4 formatting
    #       (syslinux does not support booting from ext4-64bit)
    loginfo "Formatting disk partition as ext4"
    ${runcmd[mkfs.ext4]} \
        -O ^64bit -q "${loopback_dev}" \
        | logpipe "warn" "mkfs.ext4: "
    # loginfo "Formatting disk partition as ext2"
    # mkfs.ext2 -L "whaleboot-root" -q "${loopback_dev}" | logpipe "warn" "mkfs.ext2: "

    mount_dir="$(${runcmd[mktemp]} -d)"
    init_disk_mount "${loopback_dev}" "${mount_dir}"

    loginfo "Writing extlinux configuration files to disk image"
    init_extlinux_config "${mount_dir}"

    loginfo "Installing extlinux bootloader on disk image"
    ${runcmd[extlinux]} \
        --install "${mount_dir}"/boot/extlinux 2>&1 \
        | logpipe "warn" "extlinux: "

    loginfo "Writing syslinux mbr to disk image"
    ${runcmd[dd]} \
        if="${mbr_path}" of="${file_name}" \
        bs=440 count=1 conv=notrunc status=none 2>&1 \
        | logpipe "error" "syslinux dd: "

    loginfo "Copying filesystem from docker image to disk image"
    docker_container=$(
        # shellcheck disable=SC2312
        ${runcmd[docker]} run -d "${image_name}" /bin/true \
            2> >(logpipe "error" "docker run: ")
    )
    
    docker_image_size=$(
        ${runcmd[docker]} \
	    image inspect "${image_name}" \
	    | ${runcmd[jq]} '.[0].Size'
    )

    # shellcheck disable=SC2312
    ${runcmd[docker]} export "${docker_container}" 2> >(logpipe "error" "docker export: ") \
        | ${runcmd[pv]} -ptebars "${docker_image_size}" \
        | ${runcmd[tar]} -xf - --exclude="{tmp,sys,proc}" -C "${mount_dir}"
    # | ${runcmd[sqfstar]} -quiet -no-progress -exit-on-error "${mount_dir}/live/filesystem.squashfs"

    # loginfo "Installing kernel and initrd at bootloader path"
    # install_bootloader_kernel "${mount_dir}"

    loginfo "Writing system hostname \"${system_hostname}\" to disk image"
    init_system_hostname "${system_hostname}" "${mount_dir}"

    logsuccess "disk image creation complete"
}

# Set script dependencies
required_executables=(
    # coreutils
    "cat"
    "getopt"
    "id"
    "sed"
    "mktemp"
    "truncate"
    "dd"
    "sync"
    "tee"
    "rmdir"
    "mkdir"

    # archive utils
    "tar"

    # kernel utils
    "losetup"
    "mount"
    "umount"

    # disk format/partition/boot utils
    "extlinux"
    "mkfs.ext4"
    "sfdisk"

    # container utils
    "docker"
)

optional_executables=(
    "jq"
    "pv"
    "tput"
    "udevadm"
)

init_req_commands "${path_real}" "${required_executables[@]}"
# init_opt_commands "${path_real}" "${optional_executables[@]}"

source "${script_path}/src/cmdline.bash"

# # Check that mbr.bin file exists
# if ! [[ -f "${mbr_path}" ]]; then
#     logerror "mbr.bin file could not be found at ${mbr_path} (is --mbr-path set properly?), exiting"
#     exit 1
# fi

# Check if script is running as root
effective_uid="$(${runcmd[id]} -u)"
if [[ "${effective_uid}" != 0 ]]; then
    logerror "${0}: must run as root"
    usage
    exit 1
fi

# Check if script is running interactively (if assume_yes not passed)
if [[ -z "${assume_yes:-}" ]] && ! [[ -t 0 ]]; then
    logerror "${0}: must run in a tty (unless -y flag is passed)"
    usage
    exit 1
fi

# Check if selected docker image is available locally, else ask to pull
# shellcheck disable=SC2312
docker_image_query="$(${runcmd[docker]} images -q "${image_name}" 2> >(logpipe "error" "docker images -q: "))"
if [[ -z "${docker_image_query}" ]]; then
    logwarn "Failed to find docker image ${image_name} locally"
    # shellcheck disable=SC2310
    if ! ask "Attempt to pull from remote source?" "Y"; then
        logerror "Docker image fetch cancelled, exiting"
        exit 1
    fi
    # shellcheck disable=SC2312
    ${runcmd[docker]} pull "${image_name}" 2> >(logpipe "error" "Docker pull: ") | logpipe "warn" "Docker pull: "
fi

# Invoke main function
main
