#!/bin/bash

# Define the user whose Flatpak aliases should be managed.
# This variable is expected to be set by the systemd service.
# If running manually, you might need to set it: export TARGET_USER="your_username"
if [ -z "$TARGET_USER" ]; then
    echo "Error: TARGET_USER environment variable not set. This script should be run via systemd."
    exit 1
fi

# Path to your main alias script for the target user
FLATPAK_ALIAS_SCRIPT="/home/${TARGET_USER}/.local/bin/add-fp-alias.sh"

# Log file for the monitor script's output, in the target user's home directory
LOG_FILE="/home/${TARGET_USER}/.local/state/add-fp-alias/monitor.log"
mkdir -p "$(dirname "$LOG_FILE")" # Ensure log directory exists

# Function to log messages to the dedicated log file
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Flatpak Alias Monitor started."
log_message "Monitoring D-Bus system bus for Flatpak SystemHelper Deploy/Uninstall methods."
log_message "Target user for alias script: $TARGET_USER"

# D-Bus monitor command.
# We listen for method calls on 'org.freedesktop.Flatpak.SystemHelper'.
# Members of interest: 'Deploy' (for installs/updates), 'Uninstall'.
# Note: --system is crucial here as the signals are on the system bus.
dbus-monitor --system \
    "type='method_call',interface='org.freedesktop.Flatpak.SystemHelper',member='Deploy'" \
    "type='method_call',interface='org.freedesktop.Flatpak.SystemHelper',member='Uninstall'" | \
while read -r line; do
    # Simple check for relevant method calls
    if echo "$line" | grep -q "member=Deploy" || \
       echo "$line" | grep -q "member=Uninstall"; then

        log_message "Detected Flatpak activity: $line"

        # Debounce: Add a small delay (e.g., 5 seconds) to allow Flatpak to settle.
        # This prevents running the alias script multiple times for a single complex operation.
        sleep 5

        # Perform alias updates
        log_message "Running Flatpak alias script to update as user $TARGET_USER."
        # Use 'su -l "$TARGET_USER"' to run the alias script as the specified user,
        # ensuring it has access to user-specific files ($HOME, .bashrc.d).
        # We redirect stdout/stderr of the alias script to our monitor's log file.
        # su -l "$TARGET_USER" -c "\"$FLATPAK_ALIAS_SCRIPT\" --add-all --verbose >> \"$LOG_FILE\" 2>&1"
        # su -l "$TARGET_USER" -c "\"$FLATPAK_ALIAS_SCRIPT\" --check-stale-aliases --yes --verbose >> \"$LOG_FILE\" 2>&1"
        runuser -l "$TARGET_USER" -c "\"$FLATPAK_ALIAS_SCRIPT\" --add-all --verbose >> \"$LOG_FILE\" 2>&1"
        runuser -l "$TARGET_USER" -c "\"$FLATPAK_ALIAS_SCRIPT\" --check-stale-aliases --yes --verbose >> \"$LOG_FILE\" 2>&1"
        log_message "Flatpak alias script finished."

        # Optional: Add a longer cool-down period after running, e.g., 10 seconds,
        # to prevent rapid re-triggering if multiple signals fire in quick succession.
        # sleep 10
    fi
done
