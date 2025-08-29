#!/bin/bash

# X-Seti Jan21 2020 Garuda /Manjaro Linux Package Tracking System
# Tracks all package installations and removals with easy restoration

TRACK_DIR="$HOME/.package_tracker"
LOG_FILE="$TRACK_DIR/package_operations.log"
STATE_FILE="$TRACK_DIR/current_packages.json"
BACKUP_DIR="$TRACK_DIR/backups"

# Create tracking directory structure
init_tracker() {
    mkdir -p "$TRACK_DIR" "$BACKUP_DIR"
    
    # Initialize log if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        echo "# Package Tracking Log - Started $(date)" > "$LOG_FILE"
        echo "# Format: TIMESTAMP|ACTION|MANAGER|PACKAGE|STATUS" >> "$LOG_FILE"
    fi
    
    # Create initial state if it doesn't exist
    if [ ! -f "$STATE_FILE" ]; then
        create_current_state
    fi
}

# Create current package state snapshot
create_current_state() {
    echo "Creating current package state..."
    cat > "$STATE_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "pacman_explicit": [
$(pacman -Qe | awk '{printf "    \"%s\",\n", $1}' | sed '$ s/,$//')
  ],
  "aur_packages": [
$(pacman -Qm | awk '{printf "    \"%s\",\n", $1}' | sed '$ s/,$//')
  ],
  "flatpak_packages": [
$(if command -v flatpak >/dev/null 2>&1; then flatpak list --app --columns=application | tail -n +1 | awk '{printf "    \"%s\",\n", $0}' | sed '$ s/,$//'; fi)
  ]
}
EOF
}

# Log package operation
log_operation() {
    local action=$1
    local manager=$2
    local package=$3
    local status=$4
    
    echo "$(date -Iseconds)|$action|$manager|$package|$status" >> "$LOG_FILE"
}

# Wrapper functions for package managers
track_pacman() {
    local operation=$1
    shift
    local packages=("$@")
    
    echo "Executing: sudo pacman $operation ${packages[*]}"
    
    if sudo pacman "$operation" "${packages[@]}"; then
        for pkg in "${packages[@]}"; do
            # Skip flags and determine actual action
            if [[ "$pkg" != -* ]]; then
                case "$operation" in
                    -S*) log_operation "INSTALL" "pacman" "$pkg" "SUCCESS" ;;
                    -R*) log_operation "REMOVE" "pacman" "$pkg" "SUCCESS" ;;
                esac
            fi
        done
        create_current_state
    else
        for pkg in "${packages[@]}"; do
            if [[ "$pkg" != -* ]]; then
                case "$operation" in
                    -S*) log_operation "INSTALL" "pacman" "$pkg" "FAILED" ;;
                    -R*) log_operation "REMOVE" "pacman" "$pkg" "FAILED" ;;
                esac
            fi
        done
    fi
}

track_yay() {
    local operation=$1
    shift
    local packages=("$@")
    
    echo "Executing: yay $operation ${packages[*]}"
    
    if yay "$operation" "${packages[@]}"; then
        for pkg in "${packages[@]}"; do
            if [[ "$pkg" != -* ]]; then
                case "$operation" in
                    -S*) log_operation "INSTALL" "yay" "$pkg" "SUCCESS" ;;
                    -R*) log_operation "REMOVE" "yay" "$pkg" "SUCCESS" ;;
                esac
            fi
        done
        create_current_state
    else
        for pkg in "${packages[@]}"; do
            if [[ "$pkg" != -* ]]; then
                case "$operation" in
                    -S*) log_operation "INSTALL" "yay" "$pkg" "FAILED" ;;
                    -R*) log_operation "REMOVE" "yay" "$pkg" "FAILED" ;;
                esac
            fi
        done
    fi
}

track_flatpak() {
    local operation=$1
    shift
    local packages=("$@")
    
    echo "Executing: flatpak $operation ${packages[*]}"
    
    if flatpak "$operation" "${packages[@]}"; then
        for pkg in "${packages[@]}"; do
            case "$operation" in
                install*) log_operation "INSTALL" "flatpak" "$pkg" "SUCCESS" ;;
                uninstall*) log_operation "REMOVE" "flatpak" "$pkg" "SUCCESS" ;;
            esac
        done
        create_current_state
    else
        for pkg in "${packages[@]}"; do
            case "$operation" in
                install*) log_operation "INSTALL" "flatpak" "$pkg" "FAILED" ;;
                uninstall*) log_operation "REMOVE" "flatpak" "$pkg" "FAILED" ;;
            esac
        done
    fi
}

# Create restoration script from log
create_restore_script() {
    local output_file="$BACKUP_DIR/restore_$(date +%Y%m%d_%H%M%S).sh"
    
    echo "Creating restoration script: $output_file"
    
    cat > "$output_file" << 'EOF'
#!/bin/bash

# X-Seti - Package Restoration Script
# Generated from package tracking log

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$(dirname "$SCRIPT_DIR")/package_operations.log"

echo "=== Package Restoration from Tracking Log ==="
echo "This will restore packages based on your tracking history."
echo ""

# Function to install packages
install_packages() {
    local manager=$1
    shift
    local packages=("$@")
    
    if [ ${#packages[@]} -eq 0 ]; then
        return
    fi
    
    echo "Installing ${#packages[@]} packages with $manager..."
    
    case "$manager" in
        "pacman")
            sudo pacman -S --needed --noconfirm "${packages[@]}"
            ;;
        "yay")
            yay -S --needed --noconfirm "${packages[@]}"
            ;;
        "flatpak")
            for pkg in "${packages[@]}"; do
                flatpak install -y flathub "$pkg" 2>/dev/null || echo "Failed: $pkg"
            done
            ;;
    esac
}

# Parse log and extract successful installations
echo "Parsing tracking log..."

declare -a pacman_packages=()
declare -a yay_packages=()
declare -a flatpak_packages=()

while IFS='|' read -r timestamp action manager package status; do
    # Skip comments and empty lines
    [[ "$timestamp" =~ ^#.*$ ]] && continue
    [[ -z "$timestamp" ]] && continue
    
    if [[ "$action" == "INSTALL" && "$status" == "SUCCESS" ]]; then
        case "$manager" in
            "pacman") pacman_packages+=("$package") ;;
            "yay") yay_packages+=("$package") ;;
            "flatpak") flatpak_packages+=("$package") ;;
        esac
    fi
done < "$LOG_FILE"

# Remove duplicates
pacman_packages=($(printf "%s\n" "${pacman_packages[@]}" | sort -u))
yay_packages=($(printf "%s\n" "${yay_packages[@]}" | sort -u))
flatpak_packages=($(printf "%s\n" "${flatpak_packages[@]}" | sort -u))

echo "Found packages to restore:"
echo "- Pacman: ${#pacman_packages[@]}"
echo "- YAY: ${#yay_packages[@]}"
echo "- Flatpak: ${#flatpak_packages[@]}"
echo ""

read -p "Continue with restoration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restoration cancelled."
    exit 1
fi

# Update system
echo "Updating system..."
sudo pacman -Syu --noconfirm

# Install packages
install_packages "pacman" "${pacman_packages[@]}"
install_packages "yay" "${yay_packages[@]}"
install_packages "flatpak" "${flatpak_packages[@]}"

echo "=== Restoration Complete ==="
EOF

    chmod +x "$output_file"
    echo "Restoration script created: $output_file"
}

# Create backup of current state
create_backup() {
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    mkdir -p "$backup_path"
    
    # Copy current state and log
    cp "$STATE_FILE" "$backup_path/"
    cp "$LOG_FILE" "$backup_path/"
    
    # Create human-readable lists
    pacman -Qe > "$backup_path/pacman_explicit.txt"
    pacman -Qm > "$backup_path/aur_packages.txt"
    if command -v flatpak >/dev/null 2>&1; then
        flatpak list --app > "$backup_path/flatpak_packages.txt"
    fi
    
    create_restore_script
    
    echo "Backup created: $backup_path"
}

# Show tracking statistics
show_stats() {
    echo "=== Package Tracking Statistics ==="
    echo "Log file: $LOG_FILE"
    echo "State file: $STATE_FILE"
    echo ""
    
    if [ -f "$LOG_FILE" ]; then
        echo "Operations logged:"
        grep -v "^#" "$LOG_FILE" | awk -F'|' '{print $2}' | sort | uniq -c | sort -nr
        echo ""
        echo "Package managers used:"
        grep -v "^#" "$LOG_FILE" | awk -F'|' '{print $3}' | sort | uniq -c | sort -nr
        echo ""
        echo "Recent operations (last 10):"
        grep -v "^#" "$LOG_FILE" | tail -10 | column -t -s'|'
    else
        echo "No operations logged yet."
    fi
}

# Main menu
show_menu() {
    echo "=== Package Tracker Menu ==="
    echo "1. Install packages (tracked)"
    echo "2. Remove packages (tracked)"
    echo "3. Show statistics"
    echo "4. Create backup & restore script"
    echo "5. Initialize/Reset tracker"
    echo "6. Exit"
    echo ""
    echo "Tracked aliases available:"
    echo "  tpac <flags> <packages>  - Tracked pacman"
    echo "  tyay <flags> <packages>  - Tracked yay"
    echo "  tflat <command> <apps>   - Tracked flatpak"
}

# Create alias file
create_aliases() {
    local alias_file="$TRACK_DIR/aliases.sh"
    
    cat > "$alias_file" << EOF
#!/bin/bash
# Package Tracker Aliases
# Source this file in your ~/.bashrc: source ~/.package_tracker/aliases.sh

TRACKER_SCRIPT="$0"

alias tpac='bash "\$TRACKER_SCRIPT" pacman'
alias tyay='bash "\$TRACKER_SCRIPT" yay' 
alias tflat='bash "\$TRACKER_SCRIPT" flatpak'
alias ptrack='bash "\$TRACKER_SCRIPT" menu'
alias pstats='bash "\$TRACKER_SCRIPT" stats'
alias pbackup='bash "\$TRACKER_SCRIPT" backup'
EOF

    echo "Aliases created in: $alias_file"
    echo "Add this to your ~/.bashrc:"
    echo "source $alias_file"
}

# Command line interface
case "${1:-menu}" in
    "init")
        init_tracker
        create_aliases
        echo "Package tracker initialized!"
        ;;
    "pacman")
        init_tracker
        shift
        track_pacman "$@"
        ;;
    "yay")
        init_tracker
        shift
        track_yay "$@"
        ;;
    "flatpak")
        init_tracker
        shift
        track_flatpak "$@"
        ;;
    "backup")
        init_tracker
        create_backup
        ;;
    "stats")
        show_stats
        ;;
    "menu"|*)
        init_tracker
        while true; do
            show_menu
            read -p "Choice: " choice
            case $choice in
                1)
                    echo "Package manager (pacman/yay/flatpak): "
                    read -r manager
                    echo "Packages to install: "
                    read -r packages
                    case $manager in
                        "pacman") track_pacman -S $packages ;;
                        "yay") track_yay -S $packages ;;
                        "flatpak") track_flatpak install $packages ;;
                    esac
                    ;;
                2)
                    echo "Package manager (pacman/yay/flatpak): "
                    read -r manager
                    echo "Packages to remove: "
                    read -r packages
                    case $manager in
                        "pacman") track_pacman -R $packages ;;
                        "yay") track_yay -R $packages ;;
                        "flatpak") track_flatpak uninstall $packages ;;
                    esac
                    ;;
                3) show_stats ;;
                4) create_backup ;;
                5) 
                    echo "This will reset the tracker. Continue? (y/N)"
                    read -r confirm
                    if [[ $confirm =~ ^[Yy]$ ]]; then
                        rm -rf "$TRACK_DIR"
                        init_tracker
                        echo "Tracker reset!"
                    fi
                    ;;
                6) break ;;
                *) echo "Invalid choice" ;;
            esac
            echo ""
        done
        ;;
esac
