function usage() {
    # Use file header as usage guide
    # Usage:
    #     usage
    # Reference: https://samizdat.dev/help-message-for-shell-scripts/

    ${runcmd[sed]} -rn 's/^### ?/ /;T;p' "${0}" 1>&2
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
    if [[ -n "${assume_yes:-}" ]]; then
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

    local num_args num_expect num_min num_max
    num_args=${1}
    num_min=${2}
    num_max=${3:-${num_min}}
    
    if [[ "${FUNCNAME[1]}" != "${FUNCNAME[0]}" ]]; then
        check_pos_args ${#} 2 3
    fi

    if [[ "${num_min}" != "${num_max}" ]]; then
        if (( "${num_args}" < "${num_min}" )); then
            logerror "${FUNCNAME[1]}: at least ${num_min} positional arguments required," \
                "${num_args} provided"
            return 1
	fi
	if [[ "${num_max}" != "-" ]] && (( "${num_args}" > "${num_max}" )); then
            logerror "${FUNCNAME[1]}: at most ${num_max} positional arguments allowed," \
                "${num_args} provided"
            return 1
        fi
    elif (( "${num_args}" != "${num_min}" )); then
        logerror "${FUNCNAME[1]}: exactly ${num_min} positional arguments required," \
            "${num_args} provided"
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
    if [[ -n "${2-}" ]] && [[ -t 2 ]] && [[ -x "${runcmd[tput]:-}" ]]; then
        case "${2}" in
            red) line_color="$(${runcmd[tput]} setaf 1)" ;;
            green) line_color="$(${runcmd[tput]} setaf 2)" ;;
            yellow) line_color="$(${runcmd[tput]} setaf 3)" ;;
            none) line_color="" ;;
            *)
                logerror "Invalid line color \"${2}\""
                return 1
                ;;
        esac
        line_reset="$(${runcmd[tput]} sgr0)"
    else
        line_color=""
        line_reset=""
    fi

    # Add function name and line number if debug flag set
    if [[ -n "${debug-}" ]]; then
        line_prefix=$(printf "${0}: %3d:%-23s --> " "${BASH_LINENO[1]}" "${FUNCNAME[2]}()")
    else
        line_prefix=""
    fi

    # Output log message to stderr
    echo "${line_color}${line_prefix}${1}${line_reset}" \
	 | ${runcmd[sed]} -z 's/\n\([^$]\)/\n         \1/g' >&2
}

function logsuccess() { log "[SUCCESS]: ${*}" green; }
function loginfo() { log "[INFO ]: ${*}" none; }
function logwarn() { log "[WARN ]: ${*}" yellow; }
function logerror() { log "[ERROR]: ${*}" red; }

function logpipe() {
    # Send stdin data to log wrapper functions (success, info, warn, error)
    # Usage:
    #     echo "data to log..." | logpipe ${severity} [${prefix}] [${suffix}]

    check_pos_args ${#} 1 3
    local stdin severity
    stdin="$(${runcmd[cat]} -)"
    severity=${1}

    if [[ -z "${stdin}" ]]; then return; fi
    stdin=$(
	echo "${2-}${stdin}${3-}" | ${runcmd[sed]} -z 's/\n\([^$]\)/'"${3-}"'\n'"${2-}"'\1/g'
    )
    case "${severity}" in
        success) logsuccess "${stdin}" ;;
        info) loginfo "${stdin}" ;;
        warn) logwarn "${stdin}" ;;
        error) logerror "${stdin}" ;;
        *)
            logerror "Invalid logpipe severity \"${severity}\""
            return 1
            ;;
    esac
}

function find_command() {
    # Lookup command ${target_cmd} in PATH ${path_tmp}, send executable file path to stdout
    # Usage:
    #     find_command ${target_cmd} ${path_tmp}

    check_pos_args ${#} 2
    local target_cmd path_tmp target_path
    target_cmd=${1}
    path_tmp=${2}

    target_path="$(PATH="${path_tmp}" command -v "${target_cmd}")"
    if [[ -x "${target_path}" ]]; then
        echo "${target_path}"
        return 0
    fi
    if [[ -n "${target_path}" ]]; then
        logwarn "Command '${target_cmd}' file path was found at '${target_path}', but is not executable"
    fi
    return 1
}

function init_req_commands() {
    # Find required executable commands ${required_exec} in path ${tmp_path}
    # Usage:
    #     init_commands ${path_tmp} ${required_exec}

    check_pos_args ${#} 2 -
    local path_tmp required_exec
    path_tmp=${1}
    shift
    required_exec=( "${@}" )

    # # Declare runcmd as global bash associative-array
    # declare -A -g runcmd

    # Check that all dependencies are in path and executable
    missing_executables=()

    for executable in "${required_exec[@]}"; do
	# shellcheck disable=SC2310
	if ! runcmd["${executable}"]="$(find_command "${executable}" "${path_tmp}")"; then
            missing_executables+=("${executable}")
	fi
    done

    if (("${#missing_executables[@]}")); then
	missing_string="$(printf ", \"%s\"" "${missing_executables[@]}")"
	logerror "Required executable(s) ${missing_string:2} not in path, exiting"
	usage
	exit 1
    fi

    
    missing_opt_executables=()
    
    for executable in "${optional_executables[@]}"; do
	# shellcheck disable=SC2310
	if ! runcmd["${executable}"]="$(find_command "${executable}" "${path_tmp}")"; then
            missing_opt_executables+=("${executable}")
	fi
    done
    
    if (("${#missing_opt_executables[@]}")); then
	missing_string="$(printf ", \"%s\"" "${missing_opt_executables[@]}")"
	logerror "Optional executable(s) ${missing_string:2} not in path, exiting"
	usage
	exit 1
    fi
}

function trap_push() {
    # Push function call ${handler} onto trap ${trap_name} pseudo-stack
    # Usage:
    #     trap_push ${trap_name} ${handler}...

    check_pos_args ${#} 2 -
    local trap_name=${1}
    shift
    local handler="${@}"
    local trap_cur_stack

    # IFS=';' \
    #    read -a trap_cur_stack \
    #    <<< "$(trap -p "${trap_name}" | sed 's/^trap -- '\''\(.*\)'\''.*$/\1/')"
    trap_cur_stack="$(trap -p "${trap_name}" | ${runcmd[sed]} 's/trap -- '\''\(.*\)'\''.*/\1/')"

    # TODO: check if ${handler} is already present on ${trap_stack}
    # TODO: handle case that trap ${trap_name} is empty
    #       (i.e. has no handlers; $(trap -p) will output "")
    
    trap "${handler};${trap_cur_stack}" "${trap_name}"
}
