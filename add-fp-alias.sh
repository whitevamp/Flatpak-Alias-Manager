# scripts/lib/_functions.sh
#
# Contains helper and utility functions for the Flatpak Alias Management scripts.
# These functions perform common tasks like logging, file existence checks,
# alias name generation, and user confirmation prompts.
# This file is intended to be sourced, NOT executed directly.

# --- Dependencies ---
# This file expects _config.sh to be sourced beforehand for global variables.
# It relies on VERBOSE and ASSUME_YES flags being defined.

# verbose_echo - Logs a message if verbose mode is enabled
# Arguments:
#   $@ - The message to log.
verbose_echo() {
    if "$VERBOSE"; then
        # Corrected: Quoted "$*" to prevent SC2145 warning and ensure proper argument handling.
        echo "VERBOSE: $*" >&2 # Using $* here is also fine, as it expands to a single string.
                                # Alternatively, echo "VERBOSE: ${@}" would also work.
    fi
}

# print_version - Displays script version information
# This function is now part of _functions.sh for modularity.
print_version() {
    echo "Flatpak Alias Management Script - Version ${VERSION}"
    echo "Developed to simplify running Flatpak applications via shell aliases."
}

# usage - Displays detailed help information for the script
# This function is now part of _functions.sh for modularity.
usage() {
    echo "DEBUG: Entering usage function." # <-- NEW DEBUG MESSAGE
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
    echo ""
    echo "  --interactive-add-all               Interactively add/update aliases for all installed"
    echo "                                      Flatpaks. You will be prompted for each application"
    echo "                                      to add, skip, or rename its alias."
    echo ""
    echo "  --add-alias <app_id> [alias_name]   Add or update an alias for a specific Flatpak"
    echo "                                      application by its App ID. If 'alias_name' is"
    echo "                                      omitted, a default alias is generated from the App ID."
    echo ""
    echo "  --remove-alias <app_id_or_alias>    Remove an alias for a specific Flatpak application"
    echo "                                      using either its App ID or the alias name itself."
    echo ""
    echo "  --check-stale-aliases               Identify and optionally remove aliases in"
    echo "                                      '${FLATPAK_ALIASES_FILE}' that no longer correspond"
    echo "                                      to installed Flatpak applications. Useful for cleanup."
    echo ""
    echo "  --purge-all                         Remove ALL Flatpak aliases from '${FLATPAK_ALIASES_FILE}'."
    echo "                                      This action is irreversible without a backup."
    echo ""
    echo "  --skip-alias <app_id>               Add a Flatpak App ID to the skip list."
    echo "                                      Aliases for skipped App IDs will NOT be created/updated"
    echo "                                      when '--add-all' is used. This is useful for apps"
    echo "                                      you don't want aliases for."
    echo ""
    echo "  --unskip-alias <app_id>             Remove a Flatpak App ID from the skip list."
    echo "                                      Aliases for this App ID will again be considered"
    echo "                                      when '--add-all' is used."
    echo ""
    echo "  --list-skipped                      Display all Flatpak App IDs currently in the skip list."
    echo ""
    echo "  --list-all                          List all existing Flatpak aliases found in the alias file."
    echo ""
    echo "  --save-alias-list [file_path]       Saves a copy of all current Flatpak aliases to a file."
    echo "                                      If 'file_path' is omitted, it defaults to a timestamped"
    echo "                                      file in your home directory (e.g., ~/flatpak_aliases_backup_YYYYMMDDHHMMSS.sh)."
    echo ""
    echo "  --force                             Force an operation (e.g., overwrite existing custom"
    echo "                                      aliases with default ones if they conflict). Currently"
    echo "                                      only affects '--add-alias'."
    echo ""
    echo "  --yes                               Assume 'yes' to all prompts, useful for automation."
    echo ""
    echo "  --verbose                           Enable verbose output, showing more details about"
    echo "                                      what the script is doing."
    echo ""
    echo "  --version                           Display the script's version information and exit."
    echo ""
    echo "  -h, --help                          Display this help message and exit."
    echo ""
    echo "Examples:"
    echo "  $0 --add-all"
    echo "  $0 --interactive-add-all"
    echo "  $0 --add-alias org.gnome.TextEditor textedit"
    echo "  $0 --remove-alias textedit"
    echo "  $0 --check-stale-aliases --yes"
    echo "  $0 --purge-all --yes"
    echo "  $0 --skip-alias org.gnome.Calendar"
    echo "  $0 --list-skipped"
    echo "  $0 --save-alias-list ~/my_aliases.sh"
    echo ""
    exit 1
}

# ensure_aliases_dir_exists - Ensures the directory and file for aliases exist
# This function creates the necessary directory structure if it doesn't exist.
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

# load_skipped_aliases - Reads skipped aliases into an associative array (SKIPPED_FLATPAKS)
# This function populates the global SKIPPED_FLATPAKS array from the configuration file.
load_skipped_aliases() {
    # Ensure the associative array is declared globally if not already
    declare -gA SKIPPED_FLATPAKS
    SKIPPED_FLATPAKS=() # Clear existing entries before loading
    if [ -f "$SKIPPED_ALIASES_FILE" ]; then
        while IFS= read -r line; do
            # Ignore comments (lines starting with #) and empty lines
            if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
                SKIPPED_FLATPAKS["$line"]=1
            fi
        done < "$SKIPPED_ALIASES_FILE"
        $VERBOSE && verbose_echo "Loaded ${#SKIPPED_FLATPAKS[@]} skipped aliases from $SKIPPED_ALIASES_FILE"
    else
        $VERBOSE && verbose_echo "Skipped aliases file not found: $SKIPPED_ALIASES_FILE (this is normal on first run)"
    fi
}

# save_skipped_aliases - Writes skipped aliases from the associative array to file
# This function persists the current state of the SKIPPED_FLATPAKS array to the configuration file.
save_skipped_aliases() {
    mkdir -p "$(dirname "$SKIPPED_ALIASES_FILE")" # Ensure directory exists
    {
        echo "# List of Flatpak App IDs to skip when generating aliases via --add-all."
        echo "# Add one App ID per line. Lines starting with '#' are comments."
        # Iterate over the keys (App IDs) of the associative array
        for app_id in "${!SKIPPED_FLATPAKS[@]}"; do
            echo "$app_id"
        done
    } > "$SKIPPED_ALIASES_FILE"
    $VERBOSE && verbose_echo "Saved skipped aliases to $SKIPPED_ALIASES_FILE"
}

# is_skipped - Checks if an App ID is in the skipped list
# Arguments:
#   $1 - The Flatpak App ID to check.
# Returns:
#   0 (true) if the App ID is skipped, 1 (false) otherwise.
is_skipped() {
    local app_id="$1"
    [[ -n "${SKIPPED_FLATPAKS[$app_id]}" ]]
}

# confirm_action - Prompts user for confirmation unless --yes is used
# Arguments:
#   $1 - The message to display as a prompt.
# Returns:
#   0 (true) if confirmed (or --yes is active), 1 (false) otherwise.
confirm_action() {
    local prompt_message="$1"
    if "$ASSUME_YES"; then
        $VERBOSE && verbose_echo "Auto-confirming: $prompt_message"
        return 0 # True (yes)
    fi
    # Read response from /dev/tty to ensure it works in subshells/pipes
    read -rp "$prompt_message (y/N)? " response </dev/tty
    [[ "$response" =~ ^[Yy]$ ]]
}

# get_app_name - Extracts a user-friendly name from Flatpak app metadata
# Arguments:
#   $1 - The Flatpak App ID.
# Returns:
#   The human-readable application name, or an empty string if not found.
get_app_name() {
    local app_id="$1"
    local name # Declare separately for SC2155
    name=$(flatpak info --show-metadata "$app_id" 2>/dev/null | grep -iE '^(name|app-name)=' | head -n 1 | cut -d'=' -f2- | tr -d '\n\r')
    echo "$name"
}

# generate_default_alias_name - Generates a default alias from app ID or name
# This function attempts to create a short, clean, and intuitive alias name.
# Arguments:
#   $1 - The Flatpak App ID.
# Returns:
#   A suggested default alias name.
generate_default_alias_name() {
    local app_id="$1"
    local name # Declare separately for SC2155
    name=$(get_app_name "$app_id")
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
    
    # 2. Remove common Flatpak prefixes (org., com., io., etc.) from the start of the string
    # Using word boundaries (\b) to prevent partial matches like "com-pany"
    # Added a specific pattern for common prefixes followed by a dot, only at the beginning of the string
    alias_candidate=$(echo "$alias_candidate" | sed -E 's/^(org\.|com\.|net\.|io\.|md\.|de\.|it\.|one\.)//g')

    # 3. Replace dots and other non-alphanumeric characters (excluding hyphens) with hyphens
    alias_candidate=$(echo "$alias_candidate" | sed 's/\./-/g' | sed 's/[^a-z0-9]/-/g')

    # 4. Remove duplicate hyphens and leading/trailing hyphens
    alias_candidate=$(echo "$alias_candidate" | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    # 5. Remove common suffixes like "text-editor" or "flatpak" if they appear
    alias_candidate=$(echo "$alias_candidate" | sed -E 's/(-text-editor|-flatpak|-community|-desktop|-hgl|-gui2|-code|-zgui)? *$//i')

    echo "$alias_candidate"
}

# get_current_alias_info - Retrieves existing alias for an App ID if any
# Arguments:
#   $1 - The Flatpak App ID.
# Returns:
#   A string "alias_name app_id" if an alias exists for the given App ID, empty string otherwise.
get_current_alias_info() {
    local app_id_pattern # Declare separately for SC2155
    app_id_pattern=$(echo "$1" | sed 's/\./\\./g') # Escape dots for grep
    local info # Declare separately for SC2155
    # Find line with alias for this app_id, extract alias name and command
    info=$(grep -E "^alias ([^=]+)=\"flatpak run $app_id_pattern\"" "$FLATPAK_ALIASES_FILE" | head -n 1 | \
    sed -E 's/^alias ([^=]+)="flatpak run ([^"]+)"$/\1 \2/')
    echo "$info"
}

# get_alias_target_app_id - Retrieves app ID from an alias name
# Arguments:
#   $1 - The alias name.
# Returns:
#   The Flatpak App ID that the alias points to, or an empty string if not found.
get_alias_target_app_id() {
    local alias_name="$1"
    local app_id # Declare separately for SC2155
    # Find line with alias, extract app_id
    app_id=$(grep -E "^alias ${alias_name}=\"flatpak run ([^\"/]+)\"" "$FLATPAK_ALIASES_FILE" | head -n 1 | \
    sed -E 's/^alias [^=]+="flatpak run ([^"]+)"$/\1/')
    echo "$app_id"
}

# add_update_alias - Adds or updates an alias in the alias file
# Arguments:
#   $1 - The Flatpak App ID.
#   $2 - (Optional) The desired alias name. If empty, a default is generated.
# Returns:
#   0 on success, 1 on failure or if skipped by user.
add_update_alias() {
    local app_id="$1"
    local desired_alias_name="${2:-}" # Default to empty if not provided
    local app_name # Declare separately for SC2155
    app_name=$(get_app_name "$app_id")
    local default_alias_name # Declare separately for SC2155
    default_alias_name=$(generate_default_alias_name "$app_id")
    local alias_to_write=""
    local current_alias_info # Declare separately for SC2155
    current_alias_info=$(get_current_alias_info "$app_id") # "alias_name app_id" if exists

    # Determine the alias name to use
    if [ -n "$desired_alias_name" ]; then
        # User specified an alias
        if [ -n "$current_alias_info" ]; then
            local existing_alias_name # Declare separately for SC2155
            existing_alias_name=$(echo "$current_alias_info" | awk '{print $1}')
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

    local app_id_pattern_escaped # Declare separately for SC2155
    app_id_pattern_escaped=$(echo "$app_id" | sed 's/\./\\./g')

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

# remove_alias_entry - Removes an alias from the alias file
# Arguments:
#   $1 - The alias name or Flatpak App ID to remove.
# Returns:
#   0 on success, 1 on failure or if cancelled by user.
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
        local current_alias_info # Declare separately for SC2155
        current_alias_info=$(get_current_alias_info "$target")
        if [ -n "$current_alias_info" ]; then
            found_alias_name=$(echo "$current_alias_info" | awk '{print $1}')
            found_app_id="$target"
            # Corrected: Changed 'found_alias_id' to 'found_app_id' for SC2154
            $VERBOSE && verbose_echo "Identified '$target' as an App ID with alias '$found_alias_name'."
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

    local found_app_id_pattern_escaped # Declare separately for SC2155
    found_app_id_pattern_escaped=$(echo "$found_app_id" | sed 's/\./\\./g')
    sed -i -E "/^alias ${found_alias_name}=\"flatpak run ${found_app_id_pattern_escaped}\"$/d" "$FLATPAK_ALIASES_FILE"
    echo "-> Removed alias '$found_alias_name' for '$found_app_id'."
    return 0
}
