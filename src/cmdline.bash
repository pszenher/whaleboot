
# Check if system getopt is GNU enhanced version
if ${runcmd[getopt]} --test >/dev/null; then
    logerror "\"getopt --test\" failed, this script requires GNU enhanced getopt"
    logerror "Cannot parse args, exiting"
    exit 1
fi

# Set getopt command-line options
OPTIONS=hs:y
LONGOPTS=help,debug,dryrun,size:,assume-yes

# Parse arguments with getopt
PARSED=$(
    ${runcmd[getopt]} --options="${OPTIONS}" \
		      --longoptions="${LONGOPTS}" \
		      --name "${0}" \
		      -- \
		      "${@}"
)

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
	--dryrun)
            dryrun=y
            shift
            ;;
        -H | --hostname)
            system_hostname="${2}"
            shift 2
            ;;
        # -m | --mbr-path)
        #     mbr_path="${2}"
        #     shift 2
        #     ;;
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
