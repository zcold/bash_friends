#!/usr/bin/env bash
# shellcheck disable=SC1091,SC1090,SC2016
# We need to use dynamic source file path

# region: function helper
# check the number of arguments
# e.g. check_args 2 "$@"
function check_args {
    if [[ $# -ge $(( $1+1 )) ]]; then
        return 0
    fi

    local line_number
    local caller_name="${FUNCNAME[1]}"

    line_number="${BASH_LINENO[1]}"
    # shellcheck disable=SC2034
    log_error "${FUNCNAME[1]} requires at least $1 arguments but $(( $# -1 )) is provided"
    unset line_number
    return 1
}

function is_empty {
    check_args 1 "$@"
    if [[ ! -v $1 ]] || [[ -z "${!1}" ]]; then
        return 0
    fi
    return 1
}

function run_cmd {
    local cmd=( "$@" )

    log_info "Running command: ${cmd[*]} ..."

    set -o pipefail
    time ( "${cmd[@]}" )
    set +o pipefail

    local return_code=$?

    if [[ ${return_code} -ne 0 ]]; then
        log_error "Command failed: ${cmd[*]}"
    else
        log_info "Command succeeded: ${cmd[*]}"
    fi

    return ${return_code}
}

function is_function {
    check_args 1 "$@"
    [[ $(type -t "$1") == function ]] || return 1
}

function is_defined {
    check_args 1 "$@"
    [[ -v $1 ]] || return 1
}

function show_variable_value {
    check_args 1 "$@"
    local name=$1
    local log_level=${2:-"info"}

    if is_function "${name}"; then
        declare -f "${name}"
        return 0
    fi

    is_defined "${name}" || return 1
    eval "log_${log_level} '${name} value is ${!name}'"
}

function assert {
    check_args 2 "$@"
    eval "if [[ $1 ]]; then return 0; else log_error $2; exit 1; fi"
}

function rename_function {
    check_args 2 "$@"
    local original_function

    log_info "Renaming function $1 to $2 ..."

    if ! is_function "$1"; then
        log_error "Function $1 does not exist"
        return 1
    fi

    original_function="$(declare -f "$1")"

    if is_function "$2"; then
        if [[ ${3:-""} == "-f" ]] || [[ ${3:-""} != "--force" ]]; then
            log_warning "Function $2 already exists"
        else
            log_error "Function $2 already exists"
            return 1
        fi
    fi

    if eval "function $2 ${original_function#*"()"}"; then
        unset -f "$1"
        log_info "Function $1 has been renamed to $2"
        return 0
    fi

    log_error "Failed to rename function $1 to $2"
    return 1

}
# endregion: function helper

# region: string functions, starts with str_
# replace $1 with $2 in string $3\
# e.g. str_replace "a" "b" "abc" => bbc
function str_replace {
    check_args 3 "$@"

    local pattern=$1
    local replace=$2
    local source=$3

    # shellcheck disable=SC2001
    echo "${source}" | sed "s/${pattern}/${replace}/"
}

# count substring $2 in string $1
# e.g. str_count "abc" "b" => 1
function str_count {  # count substring $2 in string $1
    check_args 2 "$@"

    local old_str=$1
    local substr=$2

    local new_str
    local old_len
    local new_len
    local substr_len

    old_len="${#old_str}"
    new_len="${#new_str}"
    substr_len="${#substr}"
    new_str=$(echo "${old_str}" | tr -d "/")
    echo $(((old_len - new_len)/substr_len))
}
# endregion: string functions, starts with str_

# region: file system functions
function get_this_file {
    echo "${BASH_SOURCE[0]}"
}

function get_this_dir {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# endregion: file system functions

# region: git functions
function get_git_repo_root {
    local repo_root
    if repo_root="$(git rev-parse --show-toplevel)"; then
        echo "${repo_root}"
        return 0
    fi
    return 1
}
# endregion: git functions

# region: logging functions
function define_log_variables {
    if is_empty bash_friends_log_levels; then
        bash_friends_log_levels=(
            "debug:10"
            "info:20"
            "warning:30"
            "critical:40"
            "error:50"
        )
    fi

    if is_empty bash_friends_log_colors; then
        bash_friends_log_colors=(
            "debug:orange"
            "info:lightcyan"
            "warning:yellow"
            "critical:lightred"
            "error:red"
        )
    fi

    if is_empty bash_friends_log_level; then
        bash_friends_log_level="info"
    fi

    if is_empty bash_friends_log_format; then
        bash_friends_log_format='${program_name}:${line_number}:${caller_name}:${log_level^^}: ${log_message}'
    fi

    if is_empty program_name; then
        # shellcheck disable=SC2034
        # program_name="$(get_this_file)"
        program_name="$(basename "$(get_this_file)")"
    fi

    if is_empty caller_name; then
        # caller_name is only used in bash_friends_log_format
        # shellcheck disable=SC2034
        caller_name="${FUNCNAME[3]}"
    fi

    if is_empty line_number; then
        # line_number is only used in bash_friends_log_format
        # shellcheck disable=SC2034
        line_number="${BASH_LINENO[2]}"
    fi
}

function get_log_value {
    check_args 1 "$@"

    local key
    local value
    local current_log_value=""

    for level_value in "${bash_friends_log_levels[@]}"; do
        key="${level_value%%:*}"
        value="${level_value##*:}"
        if [[ "${key}" == "$1" ]]; then
            current_log_value="${value}"
            break
        fi
    done

    if [[ -z "${current_log_value}" ]]; then
        return 1
    fi

    echo "${current_log_value}"
}

function get_log_color {
    check_args 1 "$@"

    local key
    local value
    local current_log_color=""

    for level_value in "${bash_friends_log_colors[@]}"; do
        key="${level_value%%:*}"
        value="${level_value##*:}"
        if [[ "${key}" == "$1" ]]; then
            current_log_color="${value}"
            break
        fi
    done

    if [[ -z "${current_log_color}" ]]; then
        return 1
    fi

    echo "${current_log_color}"
}

function log_ {
    local function_name # function (F) that calls logger
    local log_level  # log level, e.g. info, debug, error, etc.
    local log_level_value  # log level value, e.g. 10, 20, 30, etc.
    local log_level_color  # log level color
    local log_function_prefix  # prefix for log function, e.g. log_info, log_debug, log_error, etc.
    local threshold_level
    local log_message

    define_log_variables

    function_name="${FUNCNAME[1]}"
    log_function_prefix="${FUNCNAME[0]}"
    threshold_level="$(get_log_value "${bash_friends_log_level}")"

    # shellcheck disable=SC2034
    log_message="$*"

    # region: detect log_level
    if [[ ${function_name} == *"${log_function_prefix}"* ]]; then
        log_level=$(str_replace "${log_function_prefix}" "" "${function_name}")
        log_level_value="$(get_log_value "${log_level}")"
        log_level_color="$(get_log_color "${log_level}")"
    else
        # echo to STDERR
        >&2 echo "${FUNCNAME[0]} is not called by function with prefix ${log_function_prefix} but by ${function_name}"
        unset caller_name
        return 1
    fi
    # endregion: detect log_level

    # skip logging when log_level < threshold_level
    if [[ "${log_level_value}" -lt "${threshold_level}" ]]; then
        unset caller_name
        return 0
    fi

    local llc  # color for log level
    case "${log_level_color,,}" in
        "black")
            llc='\033[0;30m'
            ;;
        "red")
            llc='\033[0;31m'
            ;;
        "green")
            llc='\033[0;32m'
            ;;
        "brown")
            llc='\033[0;33m'
            ;;
        "orange")
            llc='\033[0;33m'
            ;;
        "blue")
            llc='\033[0;34m'
            ;;
        "purple")
            llc='\033[0;35m'
            ;;
        "cyan")
            llc='\033[0;36m'
            ;;
        "lightgray")
            llc='\033[0;37m'
            ;;
        "darkgray")
            llc='\033[1;30m'
            ;;
        "lightred")
            llc='\033[1;31m'
            ;;
        "lightgreen")
            llc='\033[1;32m'
            ;;
        "yellow")
            llc='\033[1;33m'
            ;;
        "lightblue")
            llc='\033[1;34m'
            ;;
        "lightpurple")
            llc='\033[1;35m'
            ;;
        "lightcyan")
            llc='\033[1;36m'
            ;;
        "white")
            llc='\033[1;37m'
            ;;
        "nocolor")
            llc='\033[0m'
            ;;
        *)
            llc=""
            ;;
    esac

    local nc='\033[0m'  # No Color
    local msg
    msg=$(eval "echo \"${bash_friends_log_format}\"")

    if [[ "${log_level,,}" == "error" ]]; then
        >&2 echo -e "${llc}${msg}${nc}"
    else
        echo -e "${llc}${msg}${nc}"
    fi


    unset caller_name
}

function log_debug {
    log_ "$@"
}

function log_info {
    log_ "$@"
}

function log_warning {
    log_ "$@"
}

function log_critical {
    log_ "$@"
}

function log_error {
    log_ "$@"
}

function add_log_level {
    check_args 2 "$@"
    local level=$1
    local value=$2
    for key in "${!bash_friends_log_levels[@]}"; do
        if [[ "${key}" == "${level}" ]]; then
            log_error "Logging level ${level} already exists"
            return 1
        fi
    done
    bash_friends_log_levels["${level}"]="${value}"
}

function update_log_level {
    check_args 2 "$@"
    local level=$1
    local value=$2
    for key in "${!bash_friends_log_levels[@]}"; do
        if [[ "${key}" == "${level}" ]]; then
            local old_value
            old_value="${bash_friends_log_levels[${level}]}"
            bash_friends_log_levels["${level}"]="${value}"
            log_warning "Logging level ${level} has been updated to ${value} from ${old_value}"
            return 0
        fi
    done
    add_log_level "${level}" "${value}"
}
# endregion: logging functions

# region: python functions
function check_cmd {
    set -o pipefail
    "$@"
    local returncode=$?
    set +o pipefail
    return $returncode
}

function get_python_version_pep518 {
    grep -m 1 requires-python "$1" | tr -s ' ' | tr -d '"' | tr -d "'" | tr "," " " | cut -d' ' -f3 | tr -d ">="
}

function strip_string {
    echo "$1" | xargs
}

function show_lines {
    local lines=()
    readarray -t lines <<< "$*"
    for line in "${lines[@]}"; do
        line=$(strip_string "${line}")
        echo "  ${line}"
    done
}

function show_help_msg {
    local function
    local description="Show help message.
                       Multiple lines are supported."
    local usage="show_help_msg -d|--description DESCRIPTION -u|--usage USAGE [-h|--help]"

    # 1: show description and usage and return 0
    # 0: show nothing and return 1
    local show_msg=0

    # by default show help message of `show_help_msg` function: ${FUNCNAME[0}
    local show_func_index=0

    # argument parsing errors
    local errors=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_msg=1
                break
                ;;
            -d|--description)
                description=$2
                show_func_index=1
                shift
                shift
                ;;
            -u|--usage)
                usage=$2
                show_func_index=1
                shift
                shift
                ;;
            *)
                errors+=("Unknown option $1")
                shift
                ;;
        esac
    done

    if [[ $show_msg -eq 0 ]]; then
        return 0
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            log_error "${error}"
        done
        return 1
    fi

    if [[ $show_msg -eq 0 ]]; then
        return 1
    fi

    function="${FUNCNAME[${show_func_index}]}"

    echo "Function: ${function}"
    echo "Description:"
    show_lines "${description}"
    echo "Usage:"
    show_lines "${usage}"
}

# show_help_msg "-h"
#  "Show help message" "show_help_msg [description] [usage]"

function remove_from_path {
    if show_help_msg "$1" \
        "Remove path from PATH variable" "remove_from_path [path_to_remove]"; then
        return 0
    fi

    local path_to_remove=$1
    local new_path=()
    local old_ifs=$IFS

    local removed=0

    IFS=":"
    for one_path in $PATH; do
        if [[ $one_path == *"${path_to_remove}:"* ]] || [[ $one_path == *"${path_to_remove}" ]]; then
            log_info "Removed ${path_to_remove} from PATH"
            removed=1
            continue
        fi
        new_path+=("$one_path")
    done

    if [[ $removed -eq 0 ]]; then
        log_info "${path_to_remove} is NOT in PATH"
        return 1
    fi

    export PATH="${new_path[*]}"
    IFS=$old_ifs
}

# shellcheck disable=SC2120
function prepare_python_venv_pep518 {  # Create Python virtual environment from pyproject.toml
    if show_help_msg "$1" \
        -d "Create Python virtual environment" \
        -u "prepare_python_venv_pep518 [pyproject_toml_path] [venv_path] [dependency_name]"; then
        return 0
    fi

    local pyproject_toml
    local code_root
    local python_interpreter
    local venv_path
    local dep_name

    pyproject_toml=${1:-"$(pwd)/pyproject.toml"}
    code_root="$(dirname "${pyproject_toml}")"

    venv_path=${2:-"${code_root}/venv"}
    dep_name=${3:-""}

    if [[ ! -f "${pyproject_toml}" ]]; then
        log_error "pyproject.toml does not exist"
        return 1
    fi

    if [[ -v VIRTUAL_ENV ]]; then
        log_info "Virtual environment is already activated. Deactivate it first."
        remove_from_path "${VIRTUAL_ENV}/bin"
    else
        log_info "Not in a virtual environment"
    fi

    python_interpreter="python$(get_python_version_pep518 "${pyproject_toml}")" || return 1

    if ! python_interpreter=$(which "${python_interpreter}") &>/dev/null; then
        log_error "I cannot find ${python_interpreter}"
        return 1
    fi

    log_info "Python interpreter is ${python_interpreter}"

    if ! "${python_interpreter}" -m venv -h &>/dev/null; then
        log_error "venv module is missing for ${python_interpreter}. Perhaps install ${python_interpreter}-venv first?"
        return 1
    fi

    log_info "Remove existing virtual environment if any ... "
    rm "${venv_path}" -rf || return 1
    log_info "Done"

    log_info "Create virtual environment ... "
    "${python_interpreter}" -m venv "${venv_path}" || return 1
    log_info "Done"

    log_info "Activating virtual environment to install dependencies ..."
    if ! source "${venv_path}/bin/activate"; then
        log_error "Failed to activate virtual environment."
        return 1
    fi
    log_info "Done"

    (
        cd "${code_root}" || return 1
        if [[ -n "${dep_name}" ]]; then
            log_info "Install dependencies with optional [${dep_name}] ... "
            python -m pip install ".[${dep_name}]" -U -q || return 1
        else
            log_info "Install dependencies ... "
            python -m pip install . -U -q || return 1
        fi
        log_info "Done"
    )

    log_info "Run \`source ${venv_path}/bin/activate\` to activate the virtual environment"
}

# endregion: python functions
