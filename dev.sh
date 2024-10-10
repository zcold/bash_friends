#!/usr/bin/env bash
# shellcheck disable=SC1091,SC1090,SC2016
# Temporal development code

bash_friends_root="$( dirname "${BASH_SOURCE[0]}" )"
source "${bash_friends_root}/bash_friends.sh"

function parse_args {
    declare -A arguments
    declare -A arg_aliases
    local arg_action=()
    # argument parsing errors
    local errors=()
    # local old_ifs=$IFS
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                help_msg=$2
                shift
                shift
                ;;
            *)
                # config arguments
                # IFS is only effective in this line
                IFS='>' read -r -a arg_action <<< "$1"
                # echo "Found argument ${arg_action[*]} #${#arg_action[@]}"
                if [[ ${#arg_action[@]} -ne 2 ]]; then
                    errors+=("Unsupported option $1. Use > to separate option name and action")
                    # echo "Found unsupported argument $1"
                else
                    arg_names=$(strip_string "${arg_action[0]}")
                    IFS='|' read -r -a arg_names <<< "${arg_names}"
                    for arg_name in "${arg_names[@]}"; do
                        arguments[$arg_name]=$(strip_string "${arg_action[1]}")
                        arg_aliases[$arg_name]=$(strip_string "${arg_names[*]}")
                    done
                    # for arg_name in "${!arguments[@]}"; do
                    #     echo "$arg_name -=- ${arguments[${arg_name}]}";
                    # done
                    # for arg_name in "${!arg_aliases[@]}"; do
                    #     echo "$arg_name === ${arg_aliases[${arg_name}]}";
                    # done
                    IFS='|'echo "${arg_names[*]}"
                    # IFS=' ' read -r -a action <<< "$(strip_string "${arg_action[1]}")"
                    # echo "Found keyword argument ${arg_names} and action ${action[*]}"
                    # case "${action[0]}" in
                    #     show_lines)
                    #         var_name="${action[1]}"
                    #         show_lines "${!var_name}"
                    #         ;;
                    #     *)
                    #         ;;
                    # esac

                    # arg_names=( ${arg//\|/ } )
                    # for arg in "${arg_names[@]}"; do
                    #     echo "Found keyword argument ${arg} and action ${action}"
                    # done

                fi
                shift
                ;;
        esac
    done

    # echo "${arguments["-h|--help"]}"
    return 0
    # if [[ ${#errors[@]} -gt 0 ]]; then
    #     for error in "${errors[@]}"; do
    #         log_error "${error}"
    #     done
    #     return 1
    # fi
}

# parse_args \
    # "-h|--help > show_msg:help_msg store_variable:is_help"
    # "-d|--description > store_variable" \
    # "-u|--usage > store_variable usage_var" \
    # "-s|--strip > store_true do_strip_string" \
    # "> store_variable position_var" \
    # "> store_variable position_var2" \
    # --help description "-d|--description help message" \
    # --help d "-d|--description help message" \
    # --help position_var "position_var help message" \
