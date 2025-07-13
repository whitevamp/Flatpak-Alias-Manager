Flatpak Alias Manager

This project provides a robust and automated solution for managing shell aliases for your Flatpak applications on Linux. It simplifies launching Flatpak apps directly from your terminal by creating convenient aliases, and it includes a system service that automatically keeps these aliases up-to-date whenever you install, uninstall, or update Flatpaks.
✨ Features

    Effortless Alias Creation: Automatically generate user-friendly aliases (e.g., firefox for org.mozilla.firefox) for all your installed Flatpak applications.

    Manual Alias Management: Add or remove aliases for specific Flatpaks with custom names.

    Stale Alias Cleanup: Identify and remove aliases that no longer correspond to installed Flatpak applications, keeping your configuration clean.

    Alias Skipping: Maintain a list of Flatpak App IDs for which you explicitly do not want aliases to be created, giving you fine-grained control.

    Automatic Updates (Post-install Hook): A background Systemd service monitors D-Bus signals for Flatpak installations, uninstalls, and updates, automatically refreshing your aliases without manual intervention.

    Tab Completion: Enjoy intelligent tab completion for the add-fp-alias.sh script, making command-line usage faster and more efficient.

    Verbose Mode: A --verbose flag provides detailed output for debugging and understanding script operations.

    Detailed Help & Versioning: Comprehensive --help output and a --version flag for easy reference.

🚀 Installation Guide

Important Note: This guide uses your_username as a placeholder. You must replace your_username with your actual Linux username in the relevant commands and file edits.

    Clone the Repository:
    Start by cloning this repository to your local machine:

    git clone https://github.com/your-username/flatpak-alias-manager.git
    cd flatpak-alias-manager

    (Remember to replace your-username with your GitHub username if you fork it.)

    Install Main Scripts & Set Permissions:
    Copy the core scripts to your user's local binary directory and make them executable. This ensures they are in your $PATH.

    mkdir -p ~/.local/bin ~/.bashrc.d ~/.config/add-fp-alias ~/.local/state/add-fp-alias
    cp scripts/add-fp-alias.sh ~/.local/bin/add-fp-alias.sh
    cp scripts/flatpak-alias-monitor.sh ~/.local/bin/flatpak-alias-monitor.sh
    chmod +x ~/.local/bin/add-fp-alias.sh ~/.local/bin/flatpak-alias-monitor.sh

    Configure Bash Aliases Sourcing:
    Your shell needs to know about the aliases. Ensure your ~/.bashrc file includes the following lines to automatically source aliases from ~/.bashrc.d/flatpak-aliases when a new terminal session starts. Add these lines to the end of your ~/.bashrc if they are not already present:

    # Source Flatpak Aliases from ~/.bashrc.d
    if [ -d "$HOME/.bashrc.d" ]; then
      for file in "$HOME/.bashrc.d"/*.bash; do
        [ -f "$file" ] && . "$file"
      done
      # Also source the specific flatpak-aliases file if it exists
      [ -f "$HOME/.bashrc.d/flatpak-aliases" ] && . "$HOME/.bashrc.d/flatpak-aliases"
    fi

    Setup Skipped Aliases Configuration (Optional):
    If you wish to prevent aliases from being created for specific Flatpak applications (e.g., if you prefer to launch them directly or use a system package), copy the template and add their App IDs to it.

    cp config/skipped-aliases.template ~/.config/add-fp-alias/skipped-aliases
    # Now, open the file and add your desired Flatpak App IDs, one per line:
    # nano ~/.config/add-fp-alias/skipped-aliases

    Install Bash Completion (Optional but Recommended):
    This enhances your command-line experience by providing tab completion for the add-fp-alias.sh script.

    mkdir -p ~/.bash_completion
    cp completion/add-fp-alias-completion.bash ~/.bash_completion/

    Then, ensure your ~/.bashrc sources this completion script. Add the following to your ~/.bashrc (if not already handled by your distribution's default completion setup):

    # Source custom Bash completions
    if [ -f ~/.bash_completion/add-fp-alias-completion.bash ]; then
      . ~/.bash_completion/add-fp-alias-completion.bash
    fi

    Install the Systemd Service for Automation:
    This service runs in the background as root to monitor system-wide Flatpak activity and automatically updates your aliases.

    sudo cp systemd/flatpak-alias-monitor.service /etc/systemd/system/

    CRITICAL STEP: Edit the service file!
    You MUST edit the copied service file to replace the placeholder username with your actual Linux username. This tells the service which user's aliases to manage.

    sudo nano /etc/systemd/system/flatpak-alias-monitor.service

    Inside the file, find and replace all occurrences of username with your actual Linux username (e.g., whitevamp):

    # Example snippet from the service file:
    [Service]
    Environment="TARGET_USER=your_username"  # <-- Change this
    ExecStart=/home/your_username/.local/bin/flatpak-alias-monitor.sh # <-- Change this
    StandardOutput=append:/home/your_username/.local/state/add-fp-alias/monitor.log # <-- Change this
    StandardError=append:/home/your_username/.local/state/add-fp-alias/monitor.log  # <-- Change this

    Save and close the file.

    Enable and Start the Systemd Service:
    After editing the service file, tell Systemd to reload its configuration, enable the service to start automatically on boot, and then start it for the current session.

    sudo systemctl daemon-reload
    sudo systemctl enable flatpak-alias-monitor.service
    sudo systemctl start flatpak-alias-monitor.service

    You can check its status with sudo systemctl status flatpak-alias-monitor.service.

    Perform Initial Alias Generation:
    Run the script once to generate aliases for all Flatpaks currently installed on your system.

    ~/.local/bin/add-fp-alias.sh --add-all

    Refresh Your Shell:
    For the newly created aliases and tab completion to become active in your current terminal session, you need to refresh your shell's configuration.

    source ~/.bashrc

    Alternatively, simply close and open a new terminal window.

💡 Usage

Once installed, you can use the add-fp-alias.sh script with various options:

    Get detailed help:

    add-fp-alias.sh --help

    Add/update all Flatpak aliases:

    add-fp-alias.sh --add-all

    Add a specific alias:

    add-fp-alias.sh --add-alias org.gnome.Contacts mycontacts

    Remove an alias:

    add-fp-alias.sh --remove-alias mycontacts

    Check for and remove stale aliases:

    add-fp-alias.sh --check-stale-aliases
    # Or non-interactively:
    add-fp-alias.sh --check-stale-aliases --yes

    List skipped aliases:

    add-fp-alias.sh --list-skipped

    Add an app to the skip list:

    add-fp-alias.sh --skip-alias org.kde.Krita

    Enable verbose output:

    add-fp-alias.sh --verbose --add-all

    Display version:

    add-fp-alias.sh --version

⚠️ Important Notes & Troubleshooting

    Shell Refresh: Remember that changes to your aliases file (~/.bashrc.d/flatpak-aliases) only take effect in new terminal sessions or after you manually source ~/.bashrc.

    D-Bus Monitoring: The automatic update service relies on D-Bus signals from Flatpak. If it doesn't seem to be working, check the service status (sudo systemctl status flatpak-alias-monitor.service) and the monitor's log file (cat ~/.local/state/add-fp-alias/monitor.log).

    SELinux (Bazzite/Fedora): If you encounter Permission denied errors (especially status=203/EXEC or issues with su/runuser), it's likely an SELinux policy. The installation steps include restorecon which usually fixes this. If problems persist, consider temporarily setting SELinux to permissive mode for testing (sudo setenforce 0) and checking journalctl -xe --audit for AVC denials.

    grep: input file is also the output warnings: These are harmless warnings from the add-fp-alias.sh script's internal file manipulation and do not affect functionality.

🤝 Contributing

Contributions are welcome! If you find bugs, have suggestions for improvements, or want to add new features, please open an issue or submit a pull request on GitHub.
📄 License

This project is licensed under the GNU License. See the LICENSE file for details.
