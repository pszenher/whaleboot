function init_disk_image() {
    # Initialize ${filename} disk image
    # Usage:
    #     init_disk_image ${filename} ${filesize}

    check_pos_args ${#} 2
    local filename filesize
    filename=${1}
    filesize=${2}

    # If target image filename doesn't exist, create the file
    if [[ ! -e "${filename}" ]]; then
        logwarn "Image file ${filename} does not exist"
        # shellcheck disable=SC2310
        if ! ask "Create new image file ${filename} of size ${filesize}?"; then
            logerror "disk image creation cancelled, exiting"
            return 1
        fi
        ${runcmd[truncate]} -s "${filesize}" "${filename}"
    fi

}

function init_loopback_dev() {
    # Initialize loopback block device on image-file/block-dev "${filename}"
    # Usage:
    #     init_loopback_dev ${filename}

    check_pos_args ${#} 1
    local filename loopback_dev
    filename=${1}

    # Bind disk[ image] to next available loopback device
    loopback_dev=$(
	${runcmd[losetup]} \
	    -fP "${file_name}" --show \
	    2> >(logpipe "error" "losetup: ")
    )

    echo "${loopback_dev}"
}

function cleanup_loopback_dev() {
    # Destroy loopback block device on image-file/block-dev "${loopback_dev}"
    # Usage:
    #     cleanup_loopback_dev ${loopback_dev}

    check_pos_args ${#} 1
    local loopback_dev=${1}

    # TODO: could verify that loop device is still bound
    #       EXAMPLE:
    #           'if losetup -lnO name | grep -wq "${loopback_dev}"; then...'
    if [[ -b "${loopback_dev}" ]]; then
	logwarn "Destroying loopback device ${loopback_dev}"
	${runcmd[losetup]} -d "${loopback_dev}"
    else
	logwarn "Loopback device ${loopback_dev} not found, cannot destroy"
    fi
}

function init_disk_partitions() {
    # Initialize ${filename} disk partitions
    # Usage:
    #     init_disk_partition ${filename}

    check_pos_args ${#} 1
    local filename disk_model file_details
    filename=${1}

    if [[ -z "${filename-}" ]]; then
        logerror "No image filename provided"
        return 1
    fi

    if [[ -b "${filename}" ]]; then
        loginfo "Image file ${filename} is a block device, using physical disk methods"
        disk_model=$(
	    ${runcmd[udevadm]} \
		info "${filename}" -q property \
		| ${runcmd[sed]} -rn 's/^ID_MODEL=//;T;p'
	)
        file_details="block device ${filename} ${disk_model:+(${disk_model})}"
    elif [[ -f "${filename}" ]]; then
        loginfo "Image file ${filename} is a regular file, using disk image methods"
        file_details="image file ${filename}"
    else
        logerror "Image file is neither a block device nor a regular file"
        return 1
    fi

    logwarn "This action will erase ALL DATA on ${file_details}"
    # shellcheck disable=SC2310
    if ! ask "Overwrite ${file_details}?" "N"; then
        logerror "disk partitioning cancelled, exiting"
        return 1
    fi

    loginfo "Writing partition table to disk image"

    echo "label: dos" \
        | ${runcmd[sfdisk]} -q "${filename}" 2>&1 \
        | logpipe "warn" "sfdisk: "
    echo "start=2048, type=83, bootable" \
        | ${runcmd[sfdisk]} -q "${filename}" 2>&1 \
        | logpipe "warn" "sfdisk: "
}

function init_disk_mount() {
    # Initialize ${partition} disk mount location and mount
    # Usage:
    #     init_disk_mount ${partition} ${mountdir}

    check_pos_args ${#} 2
    local partition mountdir
    partition=${1}
    mountdir=${2}

    if [[ ! -d "${mountdir}" ]]; then
        logerror "Target mount dir ${mountdir} is not a directory"
        return 1
    fi

    loginfo "Mounting formatted disk partition at ${mountdir}"
    ${runcmd[mount]} -t ext4 "${partition}" "${mountdir}"
}
