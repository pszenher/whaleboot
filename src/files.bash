function init_system_hostname() {
    # Set hostname ${hostname} of filesystem at ${rootdir}
    # Usage:
    #     init_system_hostname ${hostname} ${rootdir}

    check_pos_args ${#} 2
    local hostname rootdir
    hostname=${1}
    rootdir=${2}

    echo "${hostname}" | ${runcmd[tee]} "${rootdir}/etc/hostname" >/dev/null
    ${runcmd[cat]} <<EOF | ${runcmd[tee]} "${rootdir}/etc/hosts" >/dev/null
127.0.0.1	localhost
127.0.1.1	${hostname}
EOF
}
