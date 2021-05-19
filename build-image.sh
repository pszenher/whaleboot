#!/usr/bin/env bash

### build-image.sh -- build bootable disk image from docker image
###
### Usage:
###   build-image.sh [options] DOCKER_IMAGE DISK_FILE
###
### Parameters:
###   DOCKER_IMAGE             Name of docker image to use
###   DISK_FILE                File to write disk image to
###
### Options:
###   --help,     -h           Display this message.
###   --debug                  Print debug messages
###   --hostname, -H HOST      Hostname of disk image (default: "jackal")
###   --size,     -s SIZE      Size of disk image (see man truncate(1) for SIZE arg semantics)
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
    #     ask ${prompt} ${Y|N}
    # Reference: https://gist.github.com/davejamesmiller/1965569

    local prompt default reply
    if [[ ${2:-} = 'Y' ]]; then
        prompt='Y/n'
        default='Y'
    elif [[ ${2:-} = 'N' ]]; then
        prompt='y/N'
        default='N'
    else
        prompt='y/n'
        default=''
    fi
    while true; do
        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "${1} [${prompt}] "
        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read -r reply </dev/tty
        # Default?
        if [[ -z ${reply} ]]; then
            reply=${default}
        fi
        # Check if the reply is valid
        case "${reply}" in
            Y* | y*) return 0 ;;
            N* | n*) return 1 ;;
        esac
    done
}

function check_pos_args() {
    # Assert num passed args = num expected, else return nonzero
    # Usage:
    #     check_pos_args ${nargs} ${nexact}|[${nmin} ${nmax}]

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
    #     log ${string}

    if [[ "${FUNCNAME[1]}" != log* ]]; then
        logerror "log() function illegally invoked by ${FUNCNAME[1]}, use wrapper function" \
            "(loginfo, etc.) instead"
        return 1
    fi
    if [ -n "${debug-}" ]; then
        line_prefix=$(printf "${0}: %3d:%-23s --> " "${BASH_LINENO[1]}" "${FUNCNAME[2]}()")
    else
        line_prefix=""
    fi
    echo "${line_prefix}${*}" >&2
}

function logsuccess() { log "$(tput setaf 2)[SUCCESS]: ${*}$(tput sgr0)"; }
function loginfo() { log "[INFO]: ${*}"; }
function logwarn() { log "$(tput setaf 3)[WARN]: ${*}$(tput sgr0)"; }
function logerror() { log "$(tput setaf 1)[ERROR]: ${*}$(tput sgr0)"; }

function logpipe() {
    # Send stdin data to log functions
    # Usage:
    #     echo "data to log..." | logpipe ${severity} [${prefix} ${suffix}]

    check_pos_args ${#} 1 3
    local stdin severity
    stdin="$(cat -)"
    severity=${1}

    if [ -z "${stdin}" ]; then
        return
    fi

    if [ -n "${2-}" ]; then stdin="${2}${stdin}"; fi
    if [ -n "${3-}" ]; then stdin="${stdin}${3}"; fi

    if [[ "${severity}" == "success" ]]; then
        logsuccess "${stdin}"
    elif [[ "${severity}" == "info" ]]; then
        loginfo "${stdin}"
    elif [[ "${severity}" == "warn" ]]; then
        logwarn "${stdin}"
    elif [[ "${severity}" == "error" ]]; then
        logerror "${stdin}"
    else
        logerror "Invalid logpipe severity \"${severity}\", exiting"
        return 1
    fi
}

function cleanup() {
    # Cleanup function to run on exit
    # Usage:
    #     cleanup

    # Unmount and delete loopback device if it is defined
    if [ -n "${loopback_dev-}" ]; then
        loginfo "Unmounting disk image device ${loopback_dev}"
        sudo umount "${loopback_dev}" && sync
        sudo losetup -d "${loopback_dev}"
    fi

    # Remove mount dir if it was created by this script
    if [ -d "${mount_dir-}" ] && [ -z "${mount_dir_existed-}" ]; then
        loginfo "Removing mount dir ${mount_dir}"
        rm -d "${mount_dir}"
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
    exit ${exit_code}
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
        loginfo "Image file ${filename} does not yet exist, creating"
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
        file_details="block device ${filename} (${disk_model})"
    elif [ -f "${filename}" ]; then
        loginfo "Image file ${filename} is a regular file, using disk image methods"
        file_details="image file ${filename}"
    else
        logerror "Image file is neither a block device nor a regular file"
        return 1
    fi

    logwarn "This action will erase ALL DATA on ${file_details}"
    if ! ask "Are you sure?" "N"; then
        logwarn "disk partitioning cancelled, exiting"
        return 1
    fi

    loginfo "Writing partition table to disk image"

    echo "label: dos" \
        | sudo sfdisk -q "${filename}" 2>&1 \
        | logpipe "warn" "sfdisk: "
    echo "start=2048, type=83, bootable" \
        | sudo sfdisk -q "${filename}" 2>&1 \
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

    echo "${hostname}" | sudo tee "${rootdir}/etc/hostname" >/dev/null
    cat <<EOF | sudo tee "${rootdir}/etc/hosts" >/dev/null
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

    if [ ! -e "${mountdir}" ]; then
        mkdir -p "${mountdir}"
    elif [ ! -d "${mountdir}" ]; then
        logerror "Target mount dir ${mountdir} is not a directory"
        return 1
    fi

    loginfo "Mounting formatted disk partition at ${mountdir}"
    sudo mount -t ext4 "${partition}" "${mountdir}"
}

function main() {
    loginfo "Initializing disk image"
    init_disk_image "${file_name}" "${image_file_size}"

    loginfo "Initializing disk partitions"
    init_disk_partitions "${file_name}"

    loginfo "Configuring loopback block device for disk image"
    loopback_dev=$(sudo losetup -o $((512 * 2048)) -f "${file_name}" --show)
    loginfo "Loopback device configured, \"${loopback_dev}\""

    loginfo "Formatting disk partition as ext4"
    sudo mkfs.ext4 -q "${loopback_dev}" | logpipe "warn" "mkfs.ext4: "

    init_disk_mount "${loopback_dev}" "${mount_dir}"

    loginfo "Copying filesystem from docker image to disk image"
    docker_container=$(docker run -d "${image_name}" /bin/true)
    docker export "${docker_container}" \
        | pv -ptebars "$(docker image inspect "${image_name}" | jq '.[0].Size')" \
        | sudo tar -xf - --exclude="{tmp,sys,proc}" -C "${mount_dir}"

    loginfo "Writing system hostname \"${system_hostname}\" to disk image"
    init_system_hostname "${system_hostname}" "${mount_dir}"

    loginfo "Installing extlinux bootloader on disk image"
    sudo extlinux --install "${mount_dir}"/boot 2>&1 \
        | logpipe "warn" "extlinux: "

    loginfo "Writing syslinux mbr to disk image"
    sudo dd if=/usr/lib/syslinux/mbr/mbr.bin of="${file_name}" \
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
OPTIONS=hH:s:
LONGOPTS=help,debug,hostname:,size:

# Parse arguments with getopt
PARSED=$(getopt --options=${OPTIONS} --longoptions=${LONGOPTS} --name "${0}" -- "${@}")

# Set positional arguments to getopt output
eval set -- "${PARSED}"

# Set variable defaults
system_hostname="jackal"
mount_dir="tmp_mnt"
image_file_size="5G"

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
        -s | --size)
            image_file_size="${2}"
            shift 2
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

if [ -e "${mount_dir}" ]; then
    mount_dir_existed=y
fi

# Invoke main function
main
