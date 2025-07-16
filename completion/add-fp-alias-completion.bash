#!/bin/bash
# ~/.bash_completion/add-fp-alias-completion.bash
# Bash completion for the add-fp-alias.sh script

_add_fp_alias_completion()
{
    local cur prev
    COMPREPLY=() # Initialize the array that will hold the completion candidates
    cur="${COMP_WORDS[COMP_CWORD]}" # The current word being completed
    prev="${COMP_WORDS[COMP_CWORD-1]}" # The word immediately preceding the current word

    # --- DEBUGGING OUTPUT STARTS HERE ---
    # echo "DEBUG: Called _add_fp_alias_completion" > /dev/tty
    # echo "DEBUG: COMP_WORDS: (${COMP_WORDS[*]})" > /dev/tty
    # echo "DEBUG: COMP_CWORD: ${COMP_CWORD}" > /dev/tty
    # echo "DEBUG: cur: '${cur}'" > /dev/tty
    # echo "DEBUG: prev: '${prev}'" > /dev/tty
    # --- DEBUGGING OUTPUT ENDS HERE ---

    # IMPORTANT: This path MUST match the 'alias_file' variable in your main add-fp-alias.sh script.
    local alias_file="$HOME/.bashrc.d/flatpak-aliases"

    # Define all the primary options your script supports
    local script_options="--list-all --save-alias-list --add-all --interactive-add-all --remove-alias --check-stale-aliases --purge-all-aliases"

    # Define which options expect an existing alias name as their argument
    local commands_for_existing_aliases="--remove-alias"

    # Define options that DO NOT take any further arguments.
    local options_with_no_arguments="--list-all --save-alias-list --add-all --interactive-add-all --check-stale-aliases --purge-all-aliases"

    # ================================================================
    # Case 1: Completing an argument to a specific option (e.g., after --remove-alias)
    # ================================================================
    # SC2076 fix: Removed quotes from right-hand side of =~
    if [[ " ${commands_for_existing_aliases} " =~ ${prev} ]]; then
        # echo "DEBUG: Entered --remove-alias completion block (prev='${prev}')." > /dev/tty
        if [[ -f "$alias_file" ]]; then
            # echo "DEBUG: Alias file '$alias_file' exists." > /dev/tty
            # --- DEBUGGING OUTPUT FOR ALIAS EXTRACTION ---
            # echo "DEBUG: Contents of alias_file: $(cat "$alias_file")" > /dev/tty # DANGEROUS FOR LARGE FILES
            # Consider replacing the above line with:
            # echo "DEBUG: Head of alias_file: $(head "$alias_file")" > /dev/tty

            local existing_aliases # SC2155 fix: Declare separately
            existing_aliases=$(grep '^alias ' "$alias_file" | sed -E 's/^alias[[:space:]]*([^=]+)[[:space:]]*=.*/\1/')
            # echo "DEBUG: Extracted aliases: '${existing_aliases}'" > /dev/tty
            # --- DEBUGGING OUTPUT ENDS HERE ---

            # SC2207 fix: Use mapfile to populate COMPREPLY array
            mapfile -t COMPREPLY < <(compgen -W "${existing_aliases}" -- "${cur}")
            # echo "DEBUG: COMPREPLY after compgen: (${COMPREPLY[*]})" > /dev/tty
        # else
            # echo "DEBUG: Alias file '$alias_file' does NOT exist!" > /dev/tty
        fi
        return 0
    fi

    # ================================================================
    # Case 1.5: Completing after an option that takes NO arguments
    # ================================================================
    # SC2076 fix: Removed quotes from right-hand side of =~
    if [[ " ${options_with_no_arguments} " =~ ${prev} ]]; then
        # echo "DEBUG: Entered no-argument option block (prev='${prev}')." > /dev/tty
        COMPREPLY=() # Set completion list to empty
        return 0     # Indicate that completion has been handled
    fi

    # ================================================================
    # Case 2: Completing the script's options themselves (e.g., after "add-fp-alias --")
    # ================================================================
    if [[ "${cur}" == --* ]]; then
        # echo "DEBUG: Entered script options completion block (cur='${cur}')." > /dev/tty
        # SC2207 fix: Use mapfile to populate COMPREPLY array
        mapfile -t COMPREPLY < <(compgen -W "${script_options}" -- "${cur}")
        return 0
    fi

    # ================================================================
    # Case 3: Completing the first argument (Flatpak app name/ID) when no option is specified
    # ================================================================
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        # echo "DEBUG: Entered Flatpak app ID completion block (cur='${cur}')." > /dev/tty
        local flatpak_app_id_parts # SC2155 fix: Declare separately
        flatpak_app_id_parts=$(flatpak list --app --columns=application | awk -F'.' '{print $NF}' | sort -u)
        # SC2207 fix: Use mapfile to populate COMPREPLY array
        mapfile -t COMPREPLY < <(compgen -W "${flatpak_app_id_parts}" -- "${cur}")
        return 0
    fi

    # ================================================================
    # Default Fallback: If no specific completion logic matches, suggest filenames
    # ================================================================
    # echo "DEBUG: Entered default fallback (filename) completion block (cur='${cur}')." > /dev/tty
    # SC2207 fix: Use mapfile to populate COMPREPLY array
    mapfile -t COMPREPLY < <(compgen -f "${cur}")
}

# Register the completion function with Bash for your script.
complete -F _add_fp_alias_completion add-fp-alias.sh
complete -F _add_fp_alias_completion add-fp-alias
