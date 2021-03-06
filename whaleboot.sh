#!/usr/bin/env bash

# Copyright (C) 2021 Paul Szenher
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
###   -H HOST   --hostname=HOST    Hostname of disk image (default: "whale")
###   -m FILE   --mbr-path=FILE    Path of syslinux mbr.bin file (default: /usr/lib/syslinux/mbr/mbr.bin)
###   -s SIZE   --size=SIZE        Size of disk image (see man truncate(1) for SIZE arg semantics)
###   -y        --assume-yes       Automatic yes to prompts, run non-interactively
###

function usage() {
    # Use file header as usage guide
    # Usage:
    #     usage
    # Reference: https://samizdat.dev/help-message-for-shell-scripts/

    sed -rn 's/^### ?/ /;T;p' "${0}"
}

function ask() {
    # General-purpose y-or-n function
    # Usage:
    #     ask ${prompt} [${Y|N}]

    check_pos_args ${#} 1 2
    local prompt default reply

    # Parse passed default argument
    case ${2:-} in
        Y) prompt='Y/n' ;;
        N) prompt='y/N' ;;
        "") prompt="y/n" ;;
        *)
            logerror "Invalid default option \"${2:-}\""
            exit 1
            ;;
    esac
    default="${2:-}"

    # Return yes if ${assume_yes} variable is set
    if [ -n "${assume_yes:-}" ]; then
        echo "${1} [${prompt}] (assuming yes)"
        return 0
    fi

    # Loop until valid input is provided
    while true; do
        echo -n "${1} [${prompt}] " && read -r reply </dev/tty
        if [[ -z ${reply} ]]; then reply=${default}; fi
        case "${reply}" in
            Y | y) return 0 ;;
            N | n) return 1 ;;
            *) ;;
        esac
    done
}

function check_pos_args() {
    # Assert num passed args = num expected, else return nonzero
    # Usage:
    #     check_pos_args ${nargs} {${nexact}|${nmin} ${nmax}}

    if [[ "${FUNCNAME[1]}" != "${FUNCNAME[0]}" ]]; then
        check_pos_args ${#} 2 3
    fi

    if [ -n "${3-}" ]; then
        if [[ "${1}" < "${2}" ]]; then
            logerror "${FUNCNAME[1]}: at least ${2} positional arguments required," \
                "${1} provided"
            return 1
        elif [[ "${1}" > "${3}" ]]; then
            logerror "${FUNCNAME[1]}: at most ${3} positional arguments allowed," \
                "${1} provided"
            return 1
        fi
    elif [[ "${1}" != "${2}" ]]; then
        logerror "${FUNCNAME[1]}: exactly ${2} positional arguments required," \
            "${1} provided"
        return 1
    fi
}

function log() {
    # Log data to console with set format (cannot be invoked directly)
    # Usage:
    #     log ${string} [${color}]

    check_pos_args ${#} 1 2

    # Only allow calls from log wrapper functions
    if [[ "${FUNCNAME[1]}" != log* ]]; then
        logerror "log() function illegally invoked by ${FUNCNAME[1]}, use wrapper function" \
            "(loginfo, etc.) instead"
        return 1
    fi

    # Log in color if tty is available and tput is installed
    if [ -n "${2-}" ] && [ -t 2 ] && [ -x "$(command -v tput)" ]; then
        case "${2}" in
            red) line_color="$(tput setaf 1)" ;;
            green) line_color="$(tput setaf 2)" ;;
            yellow) line_color="$(tput setaf 3)" ;;
            none) line_color="" ;;
            *) logerror "Invalid line color \"${2}\"" && return 1 ;;
        esac
        line_reset="$(tput sgr0)"
    else
        line_color=""
        line_reset=""
    fi

    # Add function name and line number if debug flag set
    if [ -n "${debug-}" ]; then
        line_prefix=$(printf "${0}: %3d:%-23s --> " "${BASH_LINENO[1]}" "${FUNCNAME[2]}()")
    else
        line_prefix=""
    fi

    # Output log message to stderr
    echo "${line_color}${line_prefix}${1}${line_reset}" >&2
}

function logsuccess() { log "[SUCCESS]: ${*}" green; }
function loginfo() { log "[INFO]: ${*}" none; }
function logwarn() { log "[WARN]: ${*}" yellow; }
function logerror() { log "[ERROR]: ${*}" red; }

function logpipe() {
    # Send stdin data to log wrapper functions (success, info, warn, error)
    # Usage:
    #     echo "data to log..." | logpipe ${severity} [${prefix}] [${suffix}]

    check_pos_args ${#} 1 3
    local stdin severity
    stdin="$(cat -)"
    severity=${1}

    if [ -z "${stdin}" ]; then return; fi
    if [ -n "${2-}" ]; then stdin="${2}${stdin}"; fi
    if [ -n "${3-}" ]; then stdin="${stdin}${3}"; fi

    case "${severity}" in
        success) logsuccess "${stdin}" ;;
        info) loginfo "${stdin}" ;;
        warn) logwarn "${stdin}" ;;
        error) logerror "${stdin}" ;;
        *) logerror "Invalid logpipe severity \"${severity}\"" && return 1 ;;
    esac
}

function cleanup() {
    # Cleanup function to run on exit
    # Usage:
    #     cleanup

    # Unmount and delete loopback device if it is defined
    if [ -n "${loopback_dev-}" ]; then
        loginfo "Unmounting disk image device ${loopback_dev}"
        umount "${loopback_dev}" && sync
        losetup -d "${loopback_dev}"
    fi

    # Remove temporary mount directory
    if [ -d "${mount_dir-}" ]; then
        loginfo "Removing temporary mount dir ${mount_dir}"
        rmdir "${mount_dir}"
    fi

    # Remove temporary docker container if it is defined
    if [ -n "${docker_container-}" ]; then
        loginfo "Removing temporary docker container"
        docker container rm "${docker_container}" >/dev/null
    fi
}

function catch() {
    # Handler function for trapping process signals
    # Usage:
    #     trap "catch" EXIT

    exit_code=${?}
    cleanup
    exit "${exit_code}"
}

function init_disk_image() {
    # Initialize ${filename} disk image
    # Usage:
    #     init_disk_image ${filename} ${filesize}

    check_pos_args ${#} 2
    local filename filesize
    filename=${1}
    filesize=${2}

    # If target image filename doesn't exist, create the file
    if [ ! -e "${filename}" ]; then
        logwarn "Image file ${filename} does not exist"
        if ! ask "Create new image file ${filename} of size ${filesize}?"; then
            logerror "disk image creation cancelled, exiting"
            return 1
        fi
        truncate -s "${filesize}" "${filename}"
    fi

}

function init_disk_partitions() {
    # Initialize ${filename} disk partitions
    # Usage:
    #     init_disk_partition ${filename}

    check_pos_args ${#} 1
    local filename disk_model file_details
    filename=${1}

    if [ -z "${filename-}" ]; then
        logerror "No image filename provided"
        return 1
    fi

    if [ -b "${filename}" ]; then
        loginfo "Image file ${filename} is a block device, using physical disk methods"
        disk_model=$(udevadm info "${filename}" -q property | sed -rn 's/^ID_MODEL=//;T;p')
        file_details="block device ${filename} ${disk_model:+(${disk_model})}"
    elif [ -f "${filename}" ]; then
        loginfo "Image file ${filename} is a regular file, using disk image methods"
        file_details="image file ${filename}"
    else
        logerror "Image file is neither a block device nor a regular file"
        return 1
    fi

    logwarn "This action will erase ALL DATA on ${file_details}"
    if ! ask "Overwrite ${file_details}?" "N"; then
        logerror "disk partitioning cancelled, exiting"
        return 1
    fi

    loginfo "Writing partition table to disk image"

    echo "label: dos" \
        | sfdisk -q "${filename}" 2>&1 \
        | logpipe "warn" "sfdisk: "
    echo "start=2048, type=83, bootable" \
        | sfdisk -q "${filename}" 2>&1 \
        | logpipe "warn" "sfdisk: "
}

function init_system_hostname() {
    # Set hostname ${hostname} of filesystem at ${rootdir}
    # Usage:
    #     init_system_hostname ${hostname} ${rootdir}

    check_pos_args ${#} 2
    local hostname rootdir
    hostname=${1}
    rootdir=${2}

    echo "${hostname}" | tee "${rootdir}/etc/hostname" >/dev/null
    cat <<EOF | tee "${rootdir}/etc/hosts" >/dev/null
127.0.0.1	localhost
127.0.1.1	${hostname}
EOF
}

function init_disk_mount() {
    # Initialize ${partition} disk mount location and mount
    # Usage:
    #     init_disk_mount ${partition} ${mountdir}

    check_pos_args ${#} 2
    local partition mountdir
    partition=${1}
    mountdir=${2}

    if [ ! -d "${mountdir}" ]; then
        logerror "Target mount dir ${mountdir} is not a directory"
        return 1
    fi

    loginfo "Mounting formatted disk partition at ${mountdir}"
    mount -t ext4 "${partition}" "${mountdir}"
}

function main() {
    loginfo "Initializing disk image"
    init_disk_image "${file_name}" "${image_file_size}"

    loginfo "Initializing disk partitions"
    init_disk_partitions "${file_name}"

    loginfo "Configuring loopback block device for disk image"
    loopback_dev=$(losetup -f)
    losetup -o $((512 * 2048)) "${loopback_dev}" "${file_name}" 2>&1 | logpipe "error"
    loginfo "Loopback device configured, \"${loopback_dev}\""

    loginfo "Formatting disk partition as ext4"
    mkfs.ext4 -q "${loopback_dev}" | logpipe "warn" "mkfs.ext4: "

    mount_dir="$(mktemp -d)"
    init_disk_mount "${loopback_dev}" "${mount_dir}"

    loginfo "Copying filesystem from docker image to disk image"
    docker_container=$(
        docker run -d "${image_name}" /bin/true \
            2> >(logpipe "error" "docker run: ")
    )

    docker export "${docker_container}" 2> >(logpipe "error" "docker export: ") \
        | pv -ptebars "$(docker image inspect "${image_name}" | jq '.[0].Size')" \
        | tar -xf - --exclude="{tmp,sys,proc}" -C "${mount_dir}"

    loginfo "Writing system hostname \"${system_hostname}\" to disk image"
    init_system_hostname "${system_hostname}" "${mount_dir}"

    loginfo "Installing extlinux bootloader on disk image"
    extlinux --install "${mount_dir}"/boot 2>&1 \
        | logpipe "warn" "extlinux: "

    loginfo "Writing syslinux mbr to disk image"
    dd if="${mbr_path}" of="${file_name}" \
        bs=440 count=1 conv=notrunc status=none 2>&1 \
        | logpipe "warn" "syslinux dd: "

    logsuccess "disk image creation complete"

}

# Set sane bash options and catch EXIT signal
set -o errexit -o pipefail -o noclobber -o nounset
trap "catch" EXIT

# Check if system getopt is GNU enhanced version
if getopt --test >/dev/null; then
    logerror "\"getopt --test\" failed, this script requires GNU enhanced getopt"
    logerror "Cannot parse args, exiting"
    exit 1
fi

# Set getopt command-line options
OPTIONS=hH:ms:y
LONGOPTS=help,debug,hostname:,mbr-path:,size:,assume-yes

# Parse arguments with getopt
PARSED=$(getopt --options="${OPTIONS}" --longoptions="${LONGOPTS}" --name "${0}" -- "${@}")

# Set positional arguments to getopt output
eval set -- "${PARSED}"

# Set variable defaults
system_hostname="whale"
image_file_size="5G"
mbr_path="/usr/lib/syslinux/mbr/mbr.bin"

# Handle named arguments
while true; do
    case "${1}" in
        -h | --help)
            usage
            exit 1
            ;;
        --debug)
            debug=y
            shift
            ;;
        -H | --hostname)
            system_hostname="${2}"
            shift 2
            ;;
        -m | --mbr-path)
            mbr_path="${2}"
            shift 2
            ;;
        -s | --size)
            image_file_size="${2}"
            shift 2
            ;;
        -y | --assume-yes)
            assume_yes="y"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            logerror "Case statement doesn't match getopt for arg: ${1}, exiting"
            exit 1
            ;;
    esac
done

# Handle positional arguments
if [[ ${#} -ne 2 ]]; then
    logerror "${0}: exactly 2 positional arguments required, ${#} provided"
    usage
    exit 1
fi
image_name=${1}
file_name=${2}

# Set script dependencies
required_executables=(
    "dd"
    "docker"
    "extlinux"
    "jq"
    "mkfs.ext4"
    "mktemp"
    "pv"
    "sfdisk"
    "tar"
    "truncate"
    "udevadm"
)

# Check that all dependencies are in path and executable
missing_executables=()
for executable in "${required_executables[@]}"; do
    if ! [ -x "$(command -v "${executable}")" ]; then
        missing_executables+=("${executable}")
    fi
done
if (("${#missing_executables[@]}")); then
    missing_string="$(printf ", \"%s\"" "${missing_executables[@]}")"
    logerror "Required executable(s) ${missing_string:2} not in path, exiting"
    exit 1
fi

# Check that mbr.bin file exists
if ! [ -f "${mbr_path}" ]; then
    logerror "mbr.bin file could not be found at ${mbr_path} (is --mbr-path set properly?), exiting"
    exit 1
fi

# Check if script is running as root
if [[ $(id -u) != 0 ]]; then
    logerror "${0}: must run as root"
    exit 1
fi

# Check if script is running interactively (if assume_yes not passed)
if [ -z "${assume_yes:-}" ] && ! [ -t 0 ]; then
    logerror "${0}: must run in a tty (unless -y flag is passed)"
    exit 1
fi

# Check if selected docker image is available locally, else ask to pull
if [[ "$(docker images -q "${image_name}" 2>/dev/null)" == "" ]]; then
    logwarn "Failed to find docker image ${image_name} locally"
    if ! ask "Attempt to pull from remote source?" "Y"; then
        logerror "Docker image fetch cancelled, exiting"
        exit 1
    fi
    docker pull "${image_name}" 2> >(logpipe "error" "Docker pull: ") | logpipe "warn" "Docker pull: "
fi

# Invoke main function
main
