#!/usr/bin/env bash

set -o errexit -o pipefail -o noclobber -o nounset

function sig_handler() {
    echo "Caught sigterm signal, bailing..."
    ${su_do} docker container kill "${docker_container_name}"
    docker container rm "${temp_docker_container}" >/dev/null
    exit 1
}

trap sig_handler SIGINT SIGTERM

su_do=""
# rootfs_tarfile="alpine-minirootfs-3.18.2-x86_64.tar"
image_name="pszenher/jackal-whaleboot:noetic"
rootfs_tarfile="docker exported image"
host_disk_path="/dev/shm/test.img"
docker_disk_path="/bindmount.img"
docker_container_name="whaleboot_builder"

# Check if script is running as root
effective_uid="$(id -u)"
if [[ "${effective_uid}" != 0 ]]; then
    echo "Not running as root, using sudo for docker commands..." >&2
    su_do="sudo"
fi

if [[ -b "${host_disk_path}" ]] ; then
    echo "Block device targetted, we're not ready for that yet..." >&2
    exit 1
fi

echo "Building wbbuilder..."
${su_do} docker build . -t pszenher/wbbuilder
    # | grep --line-buffered -E "^Step [0-9]*/[0-9]* : " \
    # | sed -E "s/[[:space:]]+/ /g"

echo "Sending tarfile '${rootfs_tarfile}' to disk '${host_disk_path}'" >&2

temp_docker_container="whaleboot-temp-${RANDOM}"
${su_do} docker create --name="${temp_docker_container}" "${image_name}"

${su_do} docker run --rm -i \
	 --mount="type=bind,source=${host_disk_path},target=${docker_disk_path}" \
	 --device="/dev/kvm" \
         --name "${docker_container_name}" \
	 --cap-drop=all \
	 --cap-add="DAC_OVERRIDE" \
	 --cap-add="SETUID" \
	 --cap-add="SETGID" \
	 --security-opt="no-new-privileges=true" \
	 pszenher/wbbuilder:latest \
	 \
	 < <( ${su_do} docker export "${temp_docker_container}" ) &
	 # < "${rootfs_tarfile}" &

docker_run_pid="${!}"
wait "${docker_run_pid}"

