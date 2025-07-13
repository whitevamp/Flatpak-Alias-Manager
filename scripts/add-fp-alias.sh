#!/bin/bash

# add-fp-alias.sh - Flatpak Alias Management Script
# Version: 1.3.5 # <-- UPDATED VERSION NUMBER
# Manages aliases for Flatpak applications, integrating with your shell.

# --- Configuration ---
FLATPAK_ALIASES_DIR="${HOME}/.bashrc.d"
FLATPAK_ALIASES_FILE="${FLATPAK_ALIASES_DIR}/flatpak-aliases"
SKIPPED_ALIASES_FILE="${HOME}/.config/add-fp-alias/skipped-aliases"

# --- Globals for script options ---
ADD_ALL_ALIASES=false
INTERACTIVE_ADD_ALL_ALIASES=false
ADD_SINGLE_ALIAS=false
REMOVE_SINGLE_ALIAS=false
CHECK_STALE_ALIASES=false
PURGE_ALL_ALIASES=false
ALIAS_NAME=""
APP_ID=""
FORCE_ACTION=false
ASSUME_YES=false # Controls --yes flag for auto-confirmation
VERBOSE=false    # Controls --verbose flag for detailed output

# --- Function Definitions ---

# print_version - Displays script version information
print_version() {
    echo "Flatpak Alias Management Script - Version ${VERSION}"
    echo "Developed to simplify running Flatpak applications via shell aliases."
}

# usage - Displays detailed help information for the script
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Manage aliases for Flatpak applications. This script helps you create, update, and"
    echo "remove shell aliases for your Flatpak apps, making them runnable directly from your"
    echo "terminal without typing 'flatpak run <app.id>'."
    echo ""
    echo "Aliases are stored in: ${FLATPAK_ALIASES_FILE}"
    echo "Skipped aliases are stored in: ${SKIPPED_ALIASES_FILE}"
    echo ""
    echo "Options:"
    echo "  --add-all                           Add or update aliases for ALL currently installed"
    echo "                                      Flatpak applications. This is typically used after"
    echo "                                      installing or updating Flatpak apps."
    echo "                                      Example: $0 --add-all"
    echo ""
    echo "  --interactive-add-all               Interactively add/update aliases for all installed"
    echo "                                      Flatpaks. You will be prompted for each application"
    echo "                                      to add, skip, or rename its alias."
    echo "                                      Example: $0 --interactive-add-all"
    echo ""
    echo "  --add-alias <app_id> [alias_name]   Add or update an alias for a specific Flatpak"
    echo "                                      application by its App ID. If 'alias_name' is"
    echo "                                      omitted, a default alias is generated from the App ID."
    echo "                                      Example (default alias): $0 --add-alias org.gnome.TextEditor"
    echo "                                      Example (custom alias): $0 --add-alias org.gnome.TextEditor textedit"
    echo ""
    echo "  --remove-alias <app_id_or_alias>    Remove an alias for a specific Flatpak application"
    echo "                                      using either its App ID or the alias name itself."
    echo "                                      Example (by App ID): $0 --remove-alias org.gnome.Contacts"
    echo "                                      Example (by alias name): $0 --remove-alias contacts"
    echo ""
    echo "  --check-stale-aliases               Identify and optionally remove aliases in"
    echo "                                      '${FLATPAK_ALIASES_FILE}' that no longer correspond"
    echo "                                      to installed Flatpak applications. Useful for cleanup."
    echo "                                      Example: $0 --check-stale-aliases"
    echo ""
    echo "  --purge-all                         Remove ALL Flatpak aliases from '${FLATPAK_ALIASES_FILE}'."
    echo "                                      This action is irreversible without a backup."
    echo "                                      Example: $0 --purge-all"
    echo ""
    echo "  --skip-alias <app_id>               Add a Flatpak App ID to the skip list."
    echo "                                      Aliases for skipped App IDs will NOT be created/updated"
    echo "                                      when '--add-all' is used. This is useful for apps"
    echo "                                      you don't want aliases for."
    echo "                                      Example: $0 --skip-alias org.gnome.Calendar"
    echo ""
    echo "  --unskip-alias <app_id>             Remove a Flatpak App ID from the skip list."
    echo "                                      Aliases for this App ID will again be considered"
    echo "                                      when '--add-all' is used."
    echo "                                      Example: $0 --unskip-alias org.gnome.Calendar"
    echo ""
    echo "  --list-skipped                      Display all Flatpak App IDs currently in the skip list."
    echo "                                      Example: $0 --list-skipped"
    echo ""
    echo "  --list-all                          List all existing Flatpak aliases found in the alias file."
    echo "                                      Example: $0 --list-all"
    echo ""
    echo "  --save-alias-list [file_path]       Saves a copy of all current Flatpak aliases to a file."
    echo "                                      If 'file_path' is omitted, it defaults to a timestamped"
    echo "                                      file in your home directory (e.g., ~/flatpak_aliases_backup_YYYYMMDDHHMMSS.sh)."
    echo "                                      Example: $0 --save-alias-list ~/my_flatpak_aliases_backup.sh"
    echo ""
    echo "  --force                             Force an operation (e.g., overwrite existing custom"
    echo "                                      aliases with default ones if they conflict). Currently"
    echo "                                      only affects '--add-alias'."
    echo ""
    echo "  --yes                               Assume 'yes' to all prompts, useful for automation."
    echo "                                      Example: $0 --check-stale-aliases --yes"
    echo ""
    echo "  --verbose                           Enable verbose output, showing more details about"
    echo "                                      what the script is doing."
    echo ""
    echo "  --version                           Display the script's version information and exit."
    echo ""
    echo "  -h, --help                          Display this help message and exit."
    echo ""
    echo "Combinations:"
    echo "  To add aliases for all apps and then clean up stale ones (e.g., after an update):"
    echo "    $0 --add-all --check-stale-aliases --yes"
    echo ""
    echo "  To ensure a specific alias exists, then list all currently skipped aliases:"
    echo "    $0 --add-alias org.gnome.Calculator calc --list-skipped"
    echo ""
    exit 1
}

# ensure_aliases_dir_exists - Ensures the directory for aliases exists
ensure_aliases_dir_exists() {
    if [ ! -d "$FLATPAK_ALIASES_DIR" ]; then
        mkdir -p "$FLATPAK_ALIASES_DIR"
        $VERBOSE && verbose_echo "Created alias directory: $FLATPAK_ALIASES_DIR"
    fi
    # Ensure the aliases file exists (create if not)
    if [ ! -f "$FLATPAK_ALIASES_FILE" ]; then
        touch "$FLATPAK_ALIASES_FILE"
        $VERBOSE && verbose_echo "Created alias file: $FLATPAK_ALIASES_FILE"
    fi
}

# verbose_echo - Logs a message if verbose mode is enabled
verbose_echo() {
    if "$VERBOSE"; then
        echo "VERBOSE: $@" >&2 # Redirect to stderr for debug output
    fi
}

# load_skipped_aliases - Reads skipped aliases into an associative array
declare -A SKIPPED_FLATPAKS
load_skipped_aliases() {
    SKIPPED_FLATPAKS=() # Clear existing
    if [ -f "$SKIPPED_ALIASES_FILE" ]; then
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then # Ignore comments and empty lines
                SKIPPED_FLATPAKS["$line"]=1
            fi
        done < "$SKIPPED_ALIASES_FILE"
    fi
}

# save_skipped_aliases - Writes skipped aliases from array to file
save_skipped_aliases() {
    mkdir -p "$(dirname "$SKIPPED_ALIASES_FILE")" # Ensure directory exists
    {
        echo "# List of Flatpak App IDs to skip when generating aliases via --add-all."
        echo "# Add one App ID per line. Lines starting with '#' are comments."
        for app_id in "${!SKIPPED_FLATPAKS[@]}"; do
            echo "$app_id"
        done
    } > "$SKIPPED_ALIASES_FILE"
    $VERBOSE && verbose_echo "Saved skipped aliases to $SKIPPED_ALIASES_FILE"
}

# is_skipped - Checks if an App ID is in the skipped list
is_skipped() {
    local app_id="$1"
    [[ -n "${SKIPPED_FLATPAKS[$app_id]}" ]]
}

# confirm_action - Prompts user for confirmation unless --yes is used
confirm_action() {
    local prompt_message="$1"
    if "$ASSUME_YES"; then
        $VERBOSE && verbose_echo "Auto-confirming: $prompt_message"
        return 0 # True (yes)
    fi
    read -rp "$prompt_message (y/N)? " response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]]
}

# get_app_name - Extracts a user-friendly name from Flatpak app output
get_app_name() {
    local app_id="$1"
    flatpak info --show-metadata "$app_id" 2>/dev/null | grep -iE '^(name|app-name)=' | head -n 1 | cut -d'=' -f2- | tr -d '\n\r'
}

# generate_default_alias_name - Generates a default alias from app ID
generate_default_alias_name() {
    local app_id="$1"
    local name=$(get_app_name "$app_id")
    local alias_candidate=""

    # Prioritize the human-readable name if it exists and is not just the app_id itself
    if [ -n "$name" ] && [ "$name" != "$app_id" ]; then
        alias_candidate="$name"
    else
        # If no good name, or name is just the ID, take the part after the last dot in the app_id
        alias_candidate="${app_id##*.}"
    fi

    # Now, process the candidate
    # 1. Convert to lowercase
    alias_candidate=$(echo "$alias_candidate" | tr '[:upper:]' '[:lower:]')

    # 2. Replace dots and other non-alphanumeric characters (excluding hyphens) with hyphens
    alias_candidate=$(echo "$alias_candidate" | sed 's/\./-/g' | sed 's/[^a-z0-9]/-/g')

    # 3. Remove duplicate hyphens and leading/trailing hyphens
    alias_candidate=$(echo "$alias_candidate" | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    # 4. Remove common suffixes like "text-editor" or "flatpak" if they appear
    alias_candidate=$(echo "$alias_candidate" | sed -E 's/(-text-editor|-flatpak)? *$//i')

    echo "$alias_candidate"
}

# get_current_alias_info - Retrieves existing alias for an App ID if any
get_current_alias_info() {
    local app_id_pattern=$(echo "$1" | sed 's/\./\\./g') # Escape dots for grep
    # Find line with alias for this app_id, extract alias name and command
    grep -E "^alias ([^=]+)=\"flatpak run $app_id_pattern\"" "$FLATPAK_ALIASES_FILE" | head -n 1 | \
    sed -E 's/^alias ([^=]+)="flatpak run ([^"]+)"$/\1 \2/'
}

# get_alias_target_app_id - Retrieves app ID from an alias name
get_alias_target_app_id() {
    local alias_name="$1"
    # Find line with alias, extract app_id
    grep -E "^alias ${alias_name}=\"flatpak run ([^\"/]+)\"" "$FLATPAK_ALIASES_FILE" | head -n 1 | \
    sed -E 's/^alias [^=]+="flatpak run ([^"]+)"$/\1/'
}

# add_update_alias - Adds or updates an alias in the file
add_update_alias() {
    local app_id="$1"
    local desired_alias_name="${2:-}" # Default to empty if not provided
    local app_name=$(get_app_name "$app_id")
    local default_alias_name=$(generate_default_alias_name "$app_id")
    local alias_to_write=""
    local current_alias_info=$(get_current_alias_info "$app_id") # "alias_name app_id" if exists

    # Determine the alias name to use
    if [ -n "$desired_alias_name" ]; then
        # User specified an alias
        if [ -n "$current_alias_info" ]; then
            local existing_alias_name=$(echo "$current_alias_info" | awk '{print $1}')
            if [ "$existing_alias_name" != "$desired_alias_name" ] && [ ! "$FORCE_ACTION" = true ]; then
                verbose_echo "Alias '$existing_alias_name' already exists for '$app_id'. Desired alias '$desired_alias_name' is different."
                if ! confirm_action "Overwrite alias '$existing_alias_name' with '$desired_alias_name' for '$app_name'?"; then
                    echo "Skipping alias update for '$app_name' (ID: $app_id)."
                    return 1
                fi
            fi
        fi
        alias_to_write="$desired_alias_name"
    elif [ -n "$current_alias_info" ]; then
        # App already has an alias, keep it (unless forced to default, not implemented for --add-all yet)
        alias_to_write=$(echo "$current_alias_info" | awk '{print $1}')
        verbose_echo "Alias '$alias_to_write' already exists for '$app_name'. Skipping."
        return 0 # Already exists, nothing to do
    else
        # No alias specified, no current alias, use default
        alias_to_write="$default_alias_name"
    fi

    if [ -z "$alias_to_write" ]; then
        echo "Error: Could not determine alias name for $app_id. Skipping."
        return 1
    fi

    local new_alias_line="alias $alias_to_write=\"flatpak run $app_id\""
    $VERBOSE && verbose_echo "Attempting to add/update alias '$alias_to_write' for command 'flatpak run $app_id'."

    # Check if the exact alias line already exists
    if grep -q "^alias ${alias_to_write}=\"flatpak run ${app_id}\"$" "$FLATPAK_ALIASES_FILE"; then
        verbose_echo "Alias '$alias_to_write' already exists and points to the correct command. Skipping."
        return 0
    fi

    local app_id_pattern_escaped=$(echo "$app_id" | sed 's/\./\\./g')

    # Remove any existing alias for this app_id (if it points to this specific app_id)
    sed -i -E "/^alias ([^=]+)=\"flatpak run ${app_id_pattern_escaped}\"$/d" "$FLATPAK_ALIASES_FILE" 2>/dev/null

    # Remove any alias with the desired_alias_name (if it points to a *different* app)
    sed -i -E "/^alias ${alias_to_write}=\"flatpak run ([^\"/]+)\"$/d" "$FLATPAK_ALIASES_FILE" 2>/dev/null

    # Append the new alias
    echo "$new_alias_line" >> "$FLATPAK_ALIASES_FILE"
    $VERBOSE && verbose_echo "Successfully wrote alias '$alias_to_write' to '$FLATPAK_ALIASES_FILE'."
    echo "-> Added/Overwrote alias '$alias_to_write' for '$app_name'."
    return 0
}

# remove_alias_entry - Removes an alias from the file
remove_alias_entry() {
    local target="$1" # Can be app_id or alias_name
    local found_alias_name=""
    local found_app_id=""

    # Try to find by alias name first
    found_app_id=$(get_alias_target_app_id "$target")
    if [ -n "$found_app_id" ]; then
        found_alias_name="$target"
        $VERBOSE && verbose_echo "Identified '$target' as an alias for App ID '$found_app_id'."
    else
        # Try to find by App ID
        local current_alias_info=$(get_current_alias_info "$target")
        if [ -n "$current_alias_info" ]; then
            found_alias_name=$(echo "$current_alias_info" | awk '{print $1}')
            found_app_id="$target"
            $VERBOSE && verbose_echo "Identified '$target' as an App ID with alias '$found_alias_id'."
        fi
    fi

    if [ -z "$found_alias_name" ]; then
        echo "Error: No alias found for '$target' (neither as alias name nor App ID)."
        return 1
    fi

    if ! confirm_action "Are you sure you want to remove alias '$found_alias_name' (for App ID: '$found_app_id')?"; then
        echo "Removal cancelled for '$found_alias_name'."
        return 0
    fi

    # Remove the alias line
    local found_app_id_pattern_escaped=$(echo "$found_app_id" | sed 's/\./\\./g')
    sed -i -E "/^alias ${found_alias_name}=\"flatpak run ${found_app_id_pattern_escaped}\"$/d" "$FLATPAK_ALIASES_FILE"
    echo "-> Removed alias '$found_alias_name' for '$found_app_id'."
    return 0
}

# --- Main Operations ---

# operation_add_all_aliases - Adds/updates aliases for all installed Flatpaks (non-interactive)
operation_add_all_aliases() {
    echo "Adding aliases for all installed Flatpak applications (non-interactive)..."
    local total_added=0
    local installed_flatpaks=$(flatpak list --app-ids --columns=application | grep -E '^([a-z0-9]+\.)+[a-z0-9]+$')

    for app_id in $installed_flatpaks; do
        if is_skipped "$app_id"; then
            $VERBOSE && verbose_echo "Skipping '$app_id' as it's in the skip list."
            continue
        fi
        local app_name=$(get_app_name "$app_id")
        $VERBOSE && verbose_echo "Processing: App ID: '$app_id', App Name: '$app_name'."

        if add_update_alias "$app_id"; then
            total_added=$((total_added + 1))
        fi
    done
    echo "Non-interactive Flatpak alias process complete. Total aliases added/overwritten: $total_added."
}

# operation_interactive_add_all_flatpaks - Interactively adds/updates aliases for all installed Flatpaks
operation_interactive_add_all_flatpaks() {
    echo "Interactively adding aliases for installed Flatpak applications..."

    declare -A existing_aliases # alias_name -> full_command_string
    if [ -f "$FLATPAK_ALIASES_FILE" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^alias[[:space:]]*([^=]+)=\"([^\"]+)\" ]]; then
                local alias_name_key="${BASH_REMATCH[1]}"
                local alias_command="${BASH_REMATCH[2]}"
                existing_aliases["$alias_name_key"]="$alias_command"
                verbose_echo "Loaded existing alias: '$alias_name_key' -> '$alias_command'"
            fi
        done < "$FLATPAK_ALIASES_FILE"
    fi

    local new_aliases_added=0

    local loop_output=$(flatpak list --app --columns=application,name | while IFS=$'\t' read -r app_id app_name; do
        if [ -n "$app_id" ]; then
            if is_skipped "$app_id"; then
                $VERBOSE && verbose_echo "Skipping '$app_id' as it's in the skip list."
                continue
            fi

            local suggested_alias=$(generate_default_alias_name "$app_id")
            local full_command="flatpak run $app_id"

            local current_alias_name="$suggested_alias"
            local action_taken=false

            echo ""
            echo "--- Processing: '$app_name' (App ID: '$app_id') ---"
            verbose_echo "DEBUG: App ID: '$app_id', App Name: '$app_name'"
            verbose_echo "DEBUG: Suggested alias: '$suggested_alias', Full Command: '$full_command'"

            # Check if an alias for this specific Flatpak already exists
            local existing_alias_for_this_app=""
            for alias_name_key in "${!existing_aliases[@]}"; do
                if [[ "${existing_aliases[$alias_name_key]}" == "$full_command" ]]; then
                    existing_alias_for_this_app="$alias_name_key"
                    verbose_echo "DEBUG: Found existing alias '$alias_name_key' for this app."
                    break
                fi
            done

            if [ -n "$existing_alias_for_this_app" ]; then
                echo "  Note: Alias '$existing_alias_for_this_app' already exists for this Flatpak."
                read -r -p "  Keep existing alias or re-process? [K]eep existing / [P]rocess (potential overwrite/rename): " keep_or_process </dev/tty
                if [[ "$keep_or_process" =~ ^[Kk]$ ]]; then
                    echo "  -> Keeping existing alias '$existing_alias_for_this_app'."
                    verbose_echo "User chose to keep existing alias."
                    action_taken=true
                    continue # Skip to next Flatpak
                fi
            fi

            # Check if the suggested alias name is already used by a *different* command
            if [[ -n "${existing_aliases[$suggested_alias]}" && "${existing_aliases[$suggested_alias]}" != "$full_command" ]]; then
                echo "  Conflict detected for suggested alias '$suggested_alias'!"
                echo "    Currently points to: '${existing_aliases[$suggested_alias]}'"
                echo "    New app '$app_name' wants to use it for: '$full_command'"
                read -r -p "  [O]verwrite '$suggested_alias' / [R]ename '$app_name' / [S]kip '$app_name': " conflict_choice </dev/tty
                verbose_echo "Conflict detected: alias '$suggested_alias' points to different command."

                case "$conflict_choice" in
                    [Oo])
                        current_alias_name="$suggested_alias" # Use the suggested name, it will overwrite
                        verbose_echo "User chose to overwrite alias '$suggested_alias'."
                        ;;
                    [Rr])
                        local new_name_chosen=false
                        while ! "$new_name_chosen"; do
                            read -rp "    Enter new alias name for '$app_name' (Current: '$suggested_alias'): " temp_new_alias </dev/tty
                            if [ -z "$temp_new_alias" ]; then
                                echo "    Alias name cannot be empty. Please try again."
                                verbose_echo "User entered empty alias name during rename. Prompting again."
                            elif [[ -n "${existing_aliases[$temp_new_alias]}" && "${existing_aliases[$temp_new_alias]}" != "$full_command" ]]; then
                                echo "    Error: Alias '$temp_new_alias' is already used by a different command. Please choose another name."
                                verbose_echo "User entered conflicting alias name during rename. Prompting again."
                            else
                                current_alias_name="$temp_new_alias"
                                new_name_chosen=true
                                verbose_echo "User chose new alias name: '$current_alias_name'."
                            fi
                        done
                        ;;
                    [Ss])
                        echo "  -> Skipping alias for '$app_name' due to conflict."
                        action_taken=true
                        verbose_echo "User chose to skip due to conflict."
                        continue # Skip to next Flatpak
                        ;;
                    *)
                        echo "  Invalid choice. Please enter O, R, or S."
                        verbose_echo "Invalid conflict resolution choice."
                        ;;
                esac
            fi

            # If no conflict or conflict resolved by renaming, prompt for general action
            if ! "$action_taken"; then
                local user_action_choice=""
                while true; do
                    read -rp "  Add alias '$current_alias_name' for '$app_name' ('$app_id')? [Y]es/[N]o/[E]dit name: " user_action_choice </dev/tty
                    case "$user_action_choice" in
                        [Yy])
                            add_update_alias "$app_id" "$current_alias_name"
                            echo "+" # Marker for counting aliases
                            verbose_echo "User confirmed adding alias '$current_alias_name'."
                            action_taken=true
                            break
                            ;;
                        [Nn])
                            echo "  -> Skipping alias for '$app_name'."
                            verbose_echo "User chose to skip alias '$app_name'."
                            action_taken=true
                            break
                            ;;
                        [Ee])
                            local new_name_chosen=false
                            while ! "$new_name_chosen"; do
                                read -rp "    Enter new alias name for '$app_name' (Current: '$current_alias_name'): " temp_new_alias </dev/tty
                                if [ -z "$temp_new_alias" ]; then
                                    echo "    Alias name cannot be empty. Please try again."
                                    verbose_echo "User entered empty alias name during edit. Prompting again."
                                elif [[ -n "${existing_aliases[$temp_new_alias]}" && "${existing_aliases[$temp_new_alias]}" != "$full_command" ]]; then
                                    echo "    Error: Alias '$temp_new_alias' is already used by a different command. Please choose another name."
                                    verbose_echo "User entered conflicting alias name during edit. Prompting again."
                                else
                                    current_alias_name="$temp_new_alias"
                                    new_name_chosen=true
                                    verbose_echo "User chose new alias name: '$current_alias_name'."
                                fi
                            done
                            ;;
                        *)
                            echo "  Invalid choice. Please enter Y, N, or E."
                            verbose_echo "Invalid choice during general action prompt."
                            ;;
                    esac
                done
            fi
        fi # End if app_id is not empty
    done) # End of the while loop and redirection to 'loop_output'

    local new_aliases_added=$(echo "$loop_output" | grep -c '+')

    echo ""
    echo "Interactive Flatpak alias process complete. Total aliases added/overwritten: $new_aliases_added."
    if [ "$new_aliases_added" -gt 0 ]; then
        echo "Remember to source your shell configuration (e.g., 'source $FLATPAK_ALIASES_FILE' or 'source ~/.bashrc') to make the new aliases active."
    fi
}


# operation_add_single_alias - Adds/updates a single alias
operation_add_single_alias() {
    if flatpak info "$APP_ID" >/dev/null 2>&1; then
        if add_update_alias "$APP_ID" "$ALIAS_NAME"; then
            echo "Alias operation for '$APP_ID' completed."
        else
            echo "Alias operation for '$APP_ID' failed or was skipped."
        fi
    else
        echo "Error: Flatpak App ID '$APP_ID' not found."
        exit 1
    fi
}

# operation_remove_single_alias - Removes a single alias
operation_remove_single_alias() {
    remove_alias_entry "$ALIAS_NAME"
}

# operation_check_stale_aliases - Checks and removes stale aliases
operation_check_stale_aliases() {
    echo "Checking for stale Flatpak aliases..."
    local stale_aliases_found=0
    local aliases_to_check=()

    # Read existing aliases from the file
    while IFS='=' read -r alias_part command_part; do
        if [[ "$alias_part" =~ ^alias[[:space:]]+([^[:space:]]+)$ ]]; then
            local alias_name="${BASH_REMATCH[1]}"
            if [[ "$command_part" =~ ^\"flatpak[[:space:]]+run[[:space:]]+([^\"/]+)\"$ ]]; then
                local app_id="${BASH_REMATCH[1]}"
                aliases_to_check+=("$alias_name:$app_id")
            fi
        fi
    done < "$FLATPAK_ALIASES_FILE"

    for entry in "${aliases_to_check[@]}"; do
        IFS=':' read -r alias_name app_id <<< "$entry"
        $VERBOSE && verbose_echo "Checking alias: '$alias_name' for App ID: '$app_id'."

        if ! flatpak info "$app_id" >/dev/null 2>&1; then
            echo "-> Found stale alias: '$alias_name' for uninstalled Flatpak App ID: '$app_id'."
            stale_aliases_found=$((stale_aliases_found + 1))
            if confirm_action "Remove stale alias '$alias_name'?"; then
                local app_id_pattern_escaped=$(echo "$app_id" | sed 's/\./\\./g')
                sed -i -E "/^alias ${alias_name}=\"flatpak run ${app_id_pattern_escaped}\"$/d" "$FLATPAK_ALIASES_FILE"
                echo "--> Removed stale alias '$alias_name'."
            else
                echo "--> Skipped removal of stale alias '$alias_name'."
            fi
        fi
    done

    if [ "$stale_aliases_found" -eq 0 ]; then
        echo "No stale Flatpak aliases found."
    else
        echo "Stale alias check complete. Total stale aliases found: $stale_aliases_found."
    fi
    $VERBOSE && verbose_echo "Stale alias check complete."
}

# operation_purge_all_aliases - Purges all Flatpak aliases
operation_purge_all_aliases() {
    echo "Purging all Flatpak aliases from '$FLATPAK_ALIASES_FILE'..."
    verbose_echo "Attempting to purge all Flatpak aliases."

    if [ ! -f "$FLATPAK_ALIASES_FILE" ]; then
        echo "Error: Alias file not found: $FLATPAK_ALIASES_FILE"
        verbose_echo "Alias file '$FLATPAK_ALIASES_FILE' not found. Nothing to purge."
        return 1
    fi

    if confirm_action "Are you sure you want to remove ALL Flatpak aliases? This cannot be undone."; then
        local temp_file=$(mktemp)
        local aliases_removed=0

        # Copy non-Flatpak aliases and comments to temp file
        while IFS= read -r line; do
            # Check if it's an alias line and if it's a flatpak run command
            if [[ "$line" =~ ^alias[[:space:]]*[^=]+=\"flatpak[[:space:]]run.*\"$ ]]; then
                aliases_removed=$((aliases_removed + 1))
                verbose_echo "Purging: '$line'"
            else
                echo "$line" >> "$temp_file"
            fi
        done < "$FLATPAK_ALIASES_FILE"

        mv "$temp_file" "$FLATPAK_ALIASES_FILE"
        echo "-> Removed $aliases_removed Flatpak aliases."
        verbose_echo "Purge complete. Total aliases removed: $aliases_removed."
        if [ "$aliases_removed" -gt 0 ]; then
            echo "Remember to source your shell configuration to apply changes."
        fi
    else
        echo "Purge cancelled."
        verbose_echo "Purge operation cancelled by user."
    fi
    rm -f "$temp_file" 2>/dev/null
}


# operation_skip_alias - Adds an App ID to the skip list
operation_skip_alias() {
    if ! is_skipped "$APP_ID"; then
        SKIPPED_FLATPAKS["$APP_ID"]=1
        save_skipped_aliases
        echo "-> Added '$APP_ID' to the skip list."
    else
        echo "'$APP_ID' is already in the skip list."
    fi
}

# operation_unskip_alias - Removes an App ID from the skip list
operation_unskip_alias() {
    if is_skipped "$APP_ID"; then
        unset SKIPPED_FLATPAKS["$APP_ID"]
        save_skipped_aliases
        echo "-> Removed '$APP_ID' from the skip list."
    else
        echo "'$APP_ID' is not in the skip list."
    fi
}

# operation_list_skipped - Lists all skipped App IDs
operation_list_skipped() {
    load_skipped_aliases # Ensure current state
    if [ "${#SKIPPED_FLATPAKS[@]}" -eq 0 ]; then
        echo "No Flatpak App IDs are currently skipped."
    else
        echo "Currently skipped Flatpak App IDs:"
        for app_id in "${!SKIPPED_FLATPAKS[@]}"; do
            echo "- $app_id"
        done | sort
    fi
}

# operation_list_all_aliases - Lists all Flatpak aliases
list_all_flatpak_aliases() {
    $VERBOSE && verbose_echo "Listing all Flatpak aliases from '$FLATPAK_ALIASES_FILE'."
    if [ -f "$FLATPAK_ALIASES_FILE" ]; then
        echo "Existing Flatpak Aliases:"
        if grep -q '^alias ' "$FLATPAK_ALIASES_FILE"; then
            grep '^alias ' "$FLATPAK_ALIASES_FILE" | sed 's/^alias //' | sort # Just show the alias part
        else
            echo "  (No Flatpak aliases found in '$FLATPAK_ALIASES_FILE'.)"
        fi
    else
        echo "Error: Alias file not found: $FLATPAK_ALIASES_FILE"
        $VERBOSE && verbose_echo "Alias file '$FLATPAK_ALIASES_FILE' not found when trying to list aliases."
    fi
}

# save_alias_list - Saves the current list of aliases to a backup file
save_alias_list() {
    local target_file="${1:-$HOME/flatpak_aliases_backup_$(date +%Y%m%d%H%M%S).sh}" # Default backup file
    $VERBOSE && verbose_echo "Attempting to save current aliases to '$target_file'."

    if [ -f "$FLATPAK_ALIASES_FILE" ]; then
        cp "$FLATPAK_ALIASES_FILE" "$target_file"
        echo "-> Current aliases saved to '$target_file'."
        $VERBOSE && verbose_echo "Successfully saved '$FLATPAK_ALIASES_FILE' to '$target_file'."
    else
        echo "Error: Alias file not found: $FLATPAK_ALIASES_FILE"
        $VERBOSE && verbose_echo "Alias file '$FLATPAK_ALIASES_FILE' not found, cannot save list."
    fi
}

# --- Main Script Logic ---

# Set script version
VERSION="1.3.5"

# Argument parsing
# Loop through arguments and parse them
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --add-all)
            ADD_ALL_ALIASES=true
            ;;
        --interactive-add-all)
            INTERACTIVE_ADD_ALL_ALIASES=true
            ;;
        --add-alias)
            ADD_SINGLE_ALIAS=true
            APP_ID="$2"
            if [ -z "$APP_ID" ]; then
                echo "Error: --add-alias requires an App ID."
                usage
            fi
            # Check if next argument is not another flag and not empty, then it's alias_name
            if [[ "$3" != --* ]] && [[ -n "$3" ]]; then
                ALIAS_NAME="$3"
                shift # Consume alias_name
            fi
            shift # Consume App ID
            ;;
        --remove-alias)
            REMOVE_SINGLE_ALIAS=true
            ALIAS_NAME="$2" # This can be App ID or alias name
            if [ -z "$ALIAS_NAME" ]; then
                echo "Error: --remove-alias requires an App ID or alias name."
                usage
            fi
            shift # Consume App ID/alias name
            ;;
        --check-stale-aliases)
            CHECK_STALE_ALIASES=true
            ;;
        --purge-all)
            PURGE_ALL_ALIASES=true
            ;;
        --skip-alias)
            APP_ID="$2"
            if [ -z "$APP_ID" ]; then
                echo "Error: --skip-alias requires an App ID."
                usage
            fi
            operation_skip_alias
            exit 0 # Exit after operation
            ;;
        --unskip-alias)
            APP_ID="$2"
            if [ -z "$APP_ID" ]; then
                echo "Error: --unskip-alias requires an App ID."
                usage
            fi
            operation_unskip_alias
            exit 0 # Exit after operation
            ;;
        --list-skipped)
            operation_list_skipped
            exit 0 # Exit after operation
            ;;
        --list-all)
            list_all_flatpak_aliases
            exit 0 # Exit after operation
            ;;
        --save-alias-list)
            local save_target_file=""
            # Check if next argument is not another flag and not empty, then it's the target file
            if [[ "$2" != --* ]] && [[ -n "$2" ]]; then
                save_target_file="$2"
                shift # Consume file_path
            fi
            save_alias_list "$save_target_file"
            exit 0 # Exit after operation
            ;;
        --force)
            FORCE_ACTION=true
            ;;
        --yes)
            ASSUME_YES=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        --version)
            print_version
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift # Consume current argument
done

# Ensure alias directory and file exist
ensure_aliases_dir_exists
load_skipped_aliases # Load skipped aliases at the start

# Execute operations based on flags
# If no specific operation flags are set, print usage
if ! "$ADD_ALL_ALIASES" && ! "$INTERACTIVE_ADD_ALL_ALIASES" && ! "$ADD_SINGLE_ALIAS" && ! "$REMOVE_SINGLE_ALIAS" && ! "$CHECK_STALE_ALIASES" && ! "$PURGE_ALL_ALIASES"; then
    usage # Default to showing usage if no action is specified
fi

if "$ADD_ALL_ALIASES"; then
    operation_add_all_aliases
fi

if "$INTERACTIVE_ADD_ALL_ALIASES"; then
    operation_interactive_add_all_flatpaks
fi

if "$ADD_SINGLE_ALIAS"; then
    operation_add_single_alias
fi

if "$REMOVE_SINGLE_ALIAS"; then
    operation_remove_single_alias
fi

if "$CHECK_STALE_ALIASES"; then
    operation_check_stale_aliases
fi

if "$PURGE_ALL_ALIASES"; then
    operation_purge_all_aliases
fi

# Note: The `source ~/.bashrc` command should be run manually after script execution
# for changes to take effect in the current shell session.
# For automation, the `flatpak-alias-monitor.sh` handles this.
