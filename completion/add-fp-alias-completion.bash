# ~/.bash_completion/add-fp-alias-completion.bash
# Bash completion for the add-fp-alias.sh script
# add-fp-alias-completion.bash
#
# Bash completion script for the add-fp-alias.sh utility.
# This script provides tab completion for commands, options, and Flatpak App IDs.
#
# To install:
# 1. Copy this file to ~/.bash_completion/ (or a similar directory sourced by your shell).
#    e.g., cp add-fp-alias-completion.bash ~/.bash_completion/
# 2. Ensure your ~/.bashrc (or equivalent) sources this file:
#    if [ -f ~/.bash_completion/add-fp-alias-completion.bash ]; then
#      . ~/.bash_completion/add-fp-alias-completion.bash
#    fi
# 3. Source your ~/.bashrc or open a new terminal session.

_add_fp_alias_completion() {
    local cur prev # Removed cmd_index
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Determine the current command being completed
    # This loop finds the last non-option argument, which is likely the command
    # The 'command' variable was unused, so this loop is no longer strictly necessary for its original purpose
    # but could be kept if future logic requires identifying the main command.
    # For now, it's removed as per SC2034.
    # for (( i=${#COMP_WORDS[@]}-2; i>=0; i-- )); do
    #     if [[ "${COMP_WORDS[i]}" != -* ]]; then
    #         cmd_index=$i
    #         break
    #     fi
    # done
    # local command="${COMP_WORDS[cmd_index]}" # Removed this line

    # Define all possible script options
    local script_options="--add-all --interactive-add-all --add-alias --remove-alias --check-stale-aliases --purge-all --skip-alias --unskip-alias --list-skipped --list-all --save-alias-list --force --yes --verbose --version -h --help"

    # Options that do not take arguments
    local options_with_no_arguments="--add-all --interactive-add-all --check-stale-aliases --purge-all --list-skipped --list-all --force --yes --verbose --version -h --help"

    # Flatpak App IDs (cached for performance)
    # This assumes `flatpak list` is available and returns app IDs.
    local flatpak_app_ids_cache_file="${HOME}/.local/state/add-fp-alias/flatpak_app_ids_cache"
    local flatpak_app_ids=""

    # Cache Flatpak App IDs for faster completion
    if [ -f "$flatpak_app_ids_cache_file" ] && [ $(( $(date +%s) - $(stat -c %Y "$flatpak_app_ids_cache_file") )) -lt 3600 ]; then
        # Cache is less than 1 hour old
        flatpak_app_ids=$(<"$flatpak_app_ids_cache_file")
    else
        # Cache is old or doesn't exist, regenerate
        local flatpak_list_output # Declare separately for SC2155
        flatpak_list_output=$(flatpak list --app-ids --columns=application | grep -E '^([a-z0-9]+\.)+[a-z0-9]+$' | sort -u)
        flatpak_app_ids="${flatpak_list_output}"
        mkdir -p "$(dirname "$flatpak_app_ids_cache_file")"
        echo "$flatpak_app_ids" > "$flatpak_app_ids_cache_file"
    fi

    # Logic for specific commands
    case "${prev}" in
        --add-alias|--skip-alias|--unskip-alias)
            # Complete with Flatpak App IDs
            # SC2207 fix: Use mapfile to populate COMPREPLY array
            mapfile -t COMPREPLY < <(compgen -W "${flatpak_app_ids}" -- "${cur}")
            return 0
            ;;
        --remove-alias)
            # Complete with Flatpak App IDs OR existing alias names
            local existing_aliases # SC2155 fix: Declare separately
            existing_aliases=$(grep '^alias ' "$HOME/.bashrc.d/flatpak-aliases" 2>/dev/null | sed -E 's/^alias[[:space:]]*([^=]+)[[:space:]]*=.*/\1/')
            local aliases_and_ids="${flatpak_app_ids} ${existing_aliases}"
            # SC2207 fix: Use mapfile to populate COMPREPLY array
            mapfile -t COMPREPLY < <(compgen -W "${aliases_and_ids}" -- "${cur}")
            return 0
            ;;
        --save-alias-list)
            # Complete with file paths
            # SC2207 fix: Use mapfile to populate COMPREPLY array
            mapfile -t COMPREPLY < <(compgen -f "${cur}")
            return 0
            ;;
    esac

    # If the previous argument was an option that takes no arguments, then no further completion
    # SC2076 fix: Remove quotes from right-hand side of =~
    if [[ " ${options_with_no_arguments} " =~ ${prev} ]]; then
        return 0
    fi

    # Default completion: suggest script options
    # SC2207 fix: Use mapfile to populate COMPREPLY array
    mapfile -t COMPREPLY < <(compgen -W "${script_options}" -- "${cur}")

    return 0
}

# Register the completion function for `add-fp-alias.sh`
complete -F _add_fp_alias_completion add-fp-alias.sh
# Also register for `add-fp-alias-m.sh` for your testing purposes
complete -F _add_fp_alias_completion add-fp-alias-m.sh
