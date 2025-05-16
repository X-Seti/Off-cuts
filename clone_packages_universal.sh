#!/bin/bash

# ========= Configuration =========
# Script to clone user-installed packages from one system to another
# Enhanced vers, 2 with better filtering of system packages - X-Seti

# Use at your own risk!, Works for me, should work for you!

# Create working directory
WORKDIR=~/pkgclone
mkdir -p "$WORKDIR" || { echo "Failed to create working directory"; exit 1; }

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Fix SSH permissions if needed
fix_ssh_permissions() {
    if [ -d "$HOME/.ssh" ]; then
        log_message "🔐 Checking SSH directory permissions and ownership..."
        
        # Get current user and group
        CURRENT_USER=$(whoami)
        CURRENT_GROUP=$(id -gn)
        
        # Fix ownership first (try with and without sudo)
        log_message "Fixing ownership of SSH directory..."
        if command -v sudo &>/dev/null; then
            sudo chown -R "$CURRENT_USER:$CURRENT_GROUP" "$HOME/.ssh" 2>/dev/null || \
            chown -R "$CURRENT_USER:$CURRENT_GROUP" "$HOME/.ssh" 2>/dev/null
        else
            chown -R "$CURRENT_USER:$CURRENT_GROUP" "$HOME/.ssh" 2>/dev/null
        fi
        
        # Fix directory permissions
        chmod 700 "$HOME/.ssh"
        
        # Fix file permissions
        if [ -f "$HOME/.ssh/known_hosts" ]; then
            chmod 644 "$HOME/.ssh/known_hosts"
        fi
        
        if [ -f "$HOME/.ssh/config" ]; then
            chmod 600 "$HOME/.ssh/config"
        fi
        
        # Fix key file permissions
        find "$HOME/.ssh" -name "id_*" -not -name "*.pub" -exec chmod 600 {} \; 2>/dev/null
        find "$HOME/.ssh" -name "*.pub" -exec chmod 644 {} \; 2>/dev/null
        
        log_message "✅ SSH permissions and ownership fixed"
    fi
}

# Run permission fix
fix_ssh_permissions

has() { command -v "$1" &>/dev/null; }

# Alternative SSH connection test using direct command
test_ssh_connection() {
    log_message "🔍 Testing SSH connection to $TARGET_USER@$TARGET_HOST..."
    
    # Try a basic command with connection timeout
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$TARGET_USER@$TARGET_HOST" "echo SSH connection successful" 2>/dev/null; then
        log_message "❌ SSH connection test failed."
        echo "Would you like to try one of these alternatives?"
        echo "1. Continue anyway (might fail later)"
        echo "2. Try with password authentication"
        echo "3. Setup SSH key authentication now"
        echo "4. Exit and fix SSH manually"
        read -p "Choose an option (1/2/3/4): " SSH_OPTION
        
        case "$SSH_OPTION" in
            1)
                log_message "Continuing with the script despite SSH test failure..."
                ;;
            2)
                log_message "Trying password authentication..."
                ssh -o ConnectTimeout=5 "$TARGET_USER@$TARGET_HOST" "echo SSH connection successful" || {
                    log_message "❌ SSH connection still failed. Please check your credentials and try again."
                    exit 1
                }
                ;;
            3)
                log_message "Setting up SSH key authentication..."
                if [ ! -f "$HOME/.ssh/id_rsa.pub" ] && [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
                    log_message "No SSH key found. Generating a new one..."
                    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ""
                fi
                
                KEY_FILE=$(find "$HOME/.ssh" -name "id_*.pub" | head -n 1)
                if [ -z "$KEY_FILE" ]; then
                    log_message "❌ No SSH key found after generation attempt. Please check SSH key generation."
                    exit 1
                fi
                
                log_message "Copying SSH key to target machine..."
                ssh-copy-id -i "$KEY_FILE" "$TARGET_USER@$TARGET_HOST" || {
                    log_message "❌ Failed to copy SSH key. Please check your credentials and try again."
                    exit 1
                }
                
                log_message "Testing SSH connection again..."
                ssh -o ConnectTimeout=5 -o BatchMode=yes "$TARGET_USER@$TARGET_HOST" "echo SSH connection successful" || {
                    log_message "❌ SSH connection still failed after key setup. Please check your configuration."
                    exit 1
                }
                ;;
            *)
                log_message "Exiting script. Please fix SSH connection manually."
                echo "You might need to:"
                echo "1. Run: ssh-keygen -f \"$HOME/.ssh/known_hosts\" -R \"$TARGET_HOST\""
                echo "2. Run: ssh-copy-id $TARGET_USER@$TARGET_HOST"
                echo "3. Ensure the target machine has SSH server enabled"
                exit 1
                ;;
        esac
    else
        log_message "✅ SSH connection successful!"
    fi
}

# Ask for target user and host information
read -p "Enter username on target machine: " TARGET_USER
read -p "Enter hostname or IP of target machine: " TARGET_HOST
read -p "Enter home directory path on target machine (default: /home/$TARGET_USER): " TARGET_DIR
TARGET_DIR=${TARGET_DIR:-/home/$TARGET_USER}

# Test SSH connection
test_ssh_connection

REMOTE_INSTALL_SCRIPT="install_packages_universal.sh"

log_message "🔍 Detecting available package managers..."

# ========== Collect Installed Packages ==========

# APT - with improved filtering of system packages
if has apt; then
    log_message "📦 Collecting APT packages..."
    log_message "Getting list of all manually installed packages..."
    
    # Create a list of common system packages to exclude
    cat > "$WORKDIR/apt-system-packages.txt" << EOF
^linux-
^linux_
^grub-
^u-boot-
^initramfs-
^raspi-
^flash-kernel
^systemd
^udev
^libc-
^gcc-
^binutils
^apt
^dpkg
^base-
^coreutils
^dash
^bash
^busybox
^util-linux
^e2fsprogs
^mount
^fdisk
^parted
^dash
^login
^passwd
^adduser
^sudo
^sysvinit
^init
^console-
^pam-
^debian-
^ubuntu-
^kali-
^elementary-
^dbus
^network-
^netplan
^ifupdown
^iproute2
^resolvconf
^resolveconf
^ufw
^apparmor
^libapparmor
^libnss
^libselinux
^openssh-server
^openssh-client
^openssl
^ca-certificates
^ssl-cert
^dhcpcd
^ntfs-3g
^btrfs-progs
^xfsprogs
^reiserfsprogs
^jfsutils
^dosfstools
^mtools
^alsa-
^pulseaudio
^plymouth
^kbd
^console-setup
^keyboard-
^cryptsetup
^lvm2
^mdadm
^multipath-tools
EOF

    # Get manually installed packages and filter out system packages
    apt-mark showmanual | grep -v -f "$WORKDIR/apt-system-packages.txt" > "$WORKDIR/packages-apt.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-apt.txt") user-installed APT packages"
fi

# Pacman - with improved filtering
if has pacman; then
    log_message "📦 Collecting Pacman packages..."
    
    # Create a comprehensive list of base packages to exclude
    pacman -Qqg base base-devel > "$WORKDIR/pacman-base-packages.txt" 2>/dev/null
    
    # Add more system package patterns
    cat >> "$WORKDIR/pacman-base-packages.txt" << EOF
linux
linux-firmware
linux-headers
grub
efibootmgr
mkinitcpio
systemd
udev
util-linux
e2fsprogs
xfsprogs
btrfs-progs
ntfs-3g
dosfstools
dhcpcd
networkmanager
netctl
openresolv
openssh
openssl
glibc
gcc
binutils
sudo
dbus
EOF

    # Get explicitly installed packages and filter out system packages
    pacman -Qqe | grep -v -f "$WORKDIR/pacman-base-packages.txt" > "$WORKDIR/packages-pacman.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-pacman.txt") user-installed Pacman packages"
fi

# Yay (AUR helper) - only if pacman isn't available
if has yay && [ ! -f "$WORKDIR/packages-pacman.txt" ]; then
    log_message "📦 Collecting Yay packages..."
    
    # Create base package list if it doesn't exist
    if [ ! -f "$WORKDIR/pacman-base-packages.txt" ]; then
        yay -Qqg base base-devel > "$WORKDIR/pacman-base-packages.txt" 2>/dev/null
        
        # Add more system package patterns
        cat >> "$WORKDIR/pacman-base-packages.txt" << EOF
linux
linux-firmware
linux-headers
grub
efibootmgr
mkinitcpio
systemd
udev
util-linux
e2fsprogs
xfsprogs
btrfs-progs
ntfs-3g
dosfstools
dhcpcd
networkmanager
netctl
openresolv
openssh
openssl
glibc
gcc
binutils
sudo
dbus
EOF
    fi
    
    # Get explicitly installed packages and filter out system packages
    yay -Qqe | grep -v -f "$WORKDIR/pacman-base-packages.txt" > "$WORKDIR/packages-pacman.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-pacman.txt") user-installed Yay packages"
fi

# Flatpak - these are already user-installed by definition
if has flatpak; then
    log_message "📦 Collecting Flatpak packages..."
    flatpak list --app --columns=application > "$WORKDIR/packages-flatpak.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-flatpak.txt") Flatpak applications"
fi

# Snap - these are usually user-installed, but we'll filter system snaps
if has snap; then
    log_message "📦 Collecting Snap packages..."
    
    # Create a list of common system snaps to exclude
    cat > "$WORKDIR/snap-system-packages.txt" << EOF
core
core18
core20
core22
snapd
lxd
EOF

    # Get snap packages and filter out system packages
    snap list | awk 'NR>1 {print $1}' | grep -v -f "$WORKDIR/snap-system-packages.txt" > "$WORKDIR/packages-snap.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-snap.txt") user-installed Snap packages"
fi

# DNF/YUM with improved filtering
if has dnf; then
    log_message "📦 Collecting DNF packages..."
    
    # Create a list of common system packages to exclude
    cat > "$WORKDIR/dnf-system-packages.txt" << EOF
^kernel
^grub2
^fedora-
^systemd
^udev
^NetworkManager
^openssh
^openssl
^glibc
^gcc
^binutils
^sudo
^dbus
^e2fsprogs
^xfsprogs
^btrfs-progs
^ntfs-3g
^dosfstools
^dracut
^passwd
^shadow-utils
^util-linux
^coreutils
^bash
^setup
^filesystem
^dnf
^rpm
^yum
EOF

    # Get user-installed packages (excluding those from @anaconda) and filter system packages
    dnf repoquery --userinstalled --qf "%{name}" | grep -v '@anaconda' | grep -v -f "$WORKDIR/dnf-system-packages.txt" > "$WORKDIR/packages-dnf.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-dnf.txt") user-installed DNF packages"
elif has yum; then
    log_message "📦 Collecting YUM packages..."
    
    # Create system package list if it doesn't exist
    if [ ! -f "$WORKDIR/dnf-system-packages.txt" ]; then
        cat > "$WORKDIR/dnf-system-packages.txt" << EOF
^kernel
^grub2
^fedora-
^systemd
^udev
^NetworkManager
^openssh
^openssl
^glibc
^gcc
^binutils
^sudo
^dbus
^e2fsprogs
^xfsprogs
^btrfs-progs
^ntfs-3g
^dosfstools
^dracut
^passwd
^shadow-utils
^util-linux
^coreutils
^bash
^setup
^filesystem
^dnf
^rpm
^yum
EOF
    fi
    
    # Get user-installed packages and filter system packages
    yum list installed | grep -v '@anaconda' | awk 'NR>1 {print $1}' | cut -d. -f1 | grep -v -f "$WORKDIR/dnf-system-packages.txt" > "$WORKDIR/packages-dnf.txt"
    log_message "Found $(wc -l < "$WORKDIR/packages-dnf.txt") user-installed YUM packages"
fi

log_message "✅ Package lists saved in $WORKDIR"

# Check if any package lists were created
if [ ! -f "$WORKDIR/packages-apt.txt" ] && [ ! -f "$WORKDIR/packages-pacman.txt" ] && 
   [ ! -f "$WORKDIR/packages-flatpak.txt" ] && [ ! -f "$WORKDIR/packages-snap.txt" ] &&
   [ ! -f "$WORKDIR/packages-dnf.txt" ]; then
    log_message "❌ No package lists were created. No supported package managers found."
    exit 1
fi

# ========== Transfer Files ==========
log_message "📤 Transferring package lists to target machine..."

# Create directory on remote machine
ssh "$TARGET_USER@$TARGET_HOST" "mkdir -p $TARGET_DIR/pkgclone" || {
    log_message "❌ Failed to create directory on target machine"
    exit 1
}

# Transfer package lists
scp "$WORKDIR"/packages-* "$TARGET_USER@$TARGET_HOST:$TARGET_DIR/pkgclone/" || {
    log_message "❌ Failed to transfer package lists"
    exit 1
}

# Check available package managers on target
log_message "🔍 Checking available package managers on target system..."
TARGET_PKG_MANAGERS=$(ssh "$TARGET_USER@$TARGET_HOST" "command -v apt pacman dnf yum flatpak snap | xargs -n1 basename 2>/dev/null")

if [ -z "$TARGET_PKG_MANAGERS" ]; then
    log_message "⚠️ No supported package managers found on target system. Installation may fail."
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        log_message "Exiting script as requested."
        exit 1
    fi
fi

log_message "📋 Available package managers on target: $TARGET_PKG_MANAGERS"

# ========== Create Remote Install Script ==========
cat << 'EOF' > "$WORKDIR/$REMOTE_INSTALL_SCRIPT"
#!/bin/bash

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cd ~/pkgclone || {
    log_message "❌ Failed to change to pkgclone directory"
    exit 1
}

LOGDIR=~/pkgclone-logs
mkdir -p "$LOGDIR"

log_missing() {
    echo "$1" >> "$LOGDIR/$2-not-found.txt"
}

has() { command -v "$1" &>/dev/null; }

# Check available package managers on target
log_message "🔍 Checking available package managers on target system..."
AVAIL_PKG_MANAGERS=""
if has apt; then AVAIL_PKG_MANAGERS+="apt "; fi
if has pacman; then AVAIL_PKG_MANAGERS+="pacman "; fi
if has dnf; then AVAIL_PKG_MANAGERS+="dnf "; fi
if has yum; then AVAIL_PKG_MANAGERS+="yum "; fi
if has flatpak; then AVAIL_PKG_MANAGERS+="flatpak "; fi
if has snap; then AVAIL_PKG_MANAGERS+="snap "; fi

if [ -z "$AVAIL_PKG_MANAGERS" ]; then
    log_message "❌ No supported package managers found on target system"
    exit 1
fi

log_message "📋 Available package managers: $AVAIL_PKG_MANAGERS"

log_message "📥 Updating package index..."
if has apt; then sudo apt update || log_message "⚠️ apt update failed, continuing anyway"; fi
if has dnf; then sudo dnf makecache || log_message "⚠️ dnf makecache failed, continuing anyway"; fi
if has yum; then sudo yum makecache || log_message "⚠️ yum makecache failed, continuing anyway"; fi
if has pacman; then sudo pacman -Sy || log_message "⚠️ pacman -Sy failed, continuing anyway"; fi

# Check if flatpak is properly set up
if has flatpak; then
    if ! flatpak remotes --columns=name | grep -q "flathub"; then
        log_message "Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || log_message "⚠️ Failed to add Flathub repository"
    fi
fi

# Install packages interactively
read -p "Install packages interactively? (y/n, default: y): " INTERACTIVE
INTERACTIVE=${INTERACTIVE:-y}

# APT
if [ -f packages-apt.txt ] && has apt; then
    log_message "📦 Processing APT packages..."
    PKG_COUNT=$(wc -l < packages-apt.txt)
    log_message "Found $PKG_COUNT packages to install"
    
    if [ "$INTERACTIVE" = "y" ]; then
        while read -r pkg; do
            read -p "Install $pkg? (y/n/q): " choice
            case "$choice" in
                y|Y) 
                    log_message "Installing $pkg..."
                    if apt-cache show "$pkg" >/dev/null 2>&1; then
                        sudo apt install -y "$pkg" || log_missing "$pkg" "apt-failed"
                    else
                        log_missing "$pkg" "apt"
                        log_message "Package not found in repositories"
                    fi
                    ;;
                q|Q) break ;;
                *) log_message "Skipping $pkg" ;;
            esac
        done < packages-apt.txt
    else
        log_message "Installing all APT packages non-interactively..."
        while read -r pkg; do
            if apt-cache show "$pkg" >/dev/null 2>&1; then
                sudo apt install -y "$pkg" || log_missing "$pkg" "apt-failed"
            else
                log_missing "$pkg" "apt"
            fi
        done < packages-apt.txt
    fi
fi

# Pacman
if [ -f packages-pacman.txt ] && has pacman; then
    log_message "📦 Processing Pacman packages..."
    PKG_COUNT=$(wc -l < packages-pacman.txt)
    log_message "Found $PKG_COUNT packages to install"
    
    if [ "$INTERACTIVE" = "y" ]; then
        while read -r pkg; do
            read -p "Install $pkg? (y/n/q): " choice
            case "$choice" in
                y|Y) 
                    log_message "Installing $pkg..."
                    if pacman -Si "$pkg" >/dev/null 2>&1; then
                        sudo pacman -S --noconfirm "$pkg" || log_missing "$pkg" "pacman-failed"
                    else
                        # Try AUR if available
                        if has yay; then
                            log_message "Package not found in main repos, trying AUR with yay..."
                            yay -S --noconfirm "$pkg" || log_missing "$pkg" "aur-failed"
                        elif has paru; then
                            log_message "Package not found in main repos, trying AUR with paru..."
                            paru -S --noconfirm "$pkg" || log_missing "$pkg" "aur-failed"
                        else
                            log_missing "$pkg" "pacman"
                            log_message "Package not found in repositories"
                        fi
                    fi
                    ;;
                q|Q) break ;;
                *) log_message "Skipping $pkg" ;;
            esac
        done < packages-pacman.txt
    else
        log_message "Installing all Pacman packages non-interactively..."
        while read -r pkg; do
            if pacman -Si "$pkg" >/dev/null 2>&1; then
                sudo pacman -S --noconfirm "$pkg" || log_missing "$pkg" "pacman-failed"
            else
                # Try AUR if available
                if has yay; then
                    log_message "Package not found in main repos, trying AUR with yay..."
                    yay -S --noconfirm "$pkg" || log_missing "$pkg" "aur-failed"
                elif has paru; then
                    log_message "Package not found in main repos, trying AUR with paru..."
                    paru -S --noconfirm "$pkg" || log_missing "$pkg" "aur-failed"
                else
                    log_missing "$pkg" "pacman"
                fi
            fi
        done < packages-pacman.txt
    fi
fi

# DNF/YUM
if [ -f packages-dnf.txt ] && (has dnf || has yum); then
    PKG_CMD=$(has dnf && echo "dnf" || echo "yum")
    log_message "📦 Processing $PKG_CMD packages..."
    PKG_COUNT=$(wc -l < packages-dnf.txt)
    log_message "Found $PKG_COUNT packages to install"
    
    if [ "$INTERACTIVE" = "y" ]; then
        while read -r pkg; do
            read -p "Install $pkg? (y/n/q): " choice
            case "$choice" in
                y|Y) 
                    log_message "Installing $pkg..."
                    if $PKG_CMD info "$pkg" >/dev/null 2>&1; then
                        sudo $PKG_CMD install -y "$pkg" || log_missing "$pkg" "$PKG_CMD-failed"
                    else
                        log_missing "$pkg" "$PKG_CMD"
                        log_message "Package not found in repositories"
                    fi
                    ;;
                q|Q) break ;;
                *) log_message "Skipping $pkg" ;;
            esac
        done < packages-dnf.txt
    else
        log_message "Installing all $PKG_CMD packages non-interactively..."
        while read -r pkg; do
            if $PKG_CMD info "$pkg" >/dev/null 2>&1; then
                sudo $PKG_CMD install -y "$pkg" || log_missing "$pkg" "$PKG_CMD-failed"
            else
                log_missing "$pkg" "$PKG_CMD"
            fi
        done < packages-dnf.txt
    fi
fi

# Flatpak
if [ -f packages-flatpak.txt ] && has flatpak; then
    log_message "📦 Processing Flatpak applications..."
    
    # Ensure Flathub repository is configured
    if ! flatpak remotes --columns=name | grep -q "flathub"; then
        log_message "Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    PKG_COUNT=$(wc -l < packages-flatpak.txt)
    log_message "Found $PKG_COUNT Flatpak applications to install"
    
    if [ "$INTERACTIVE" = "y" ]; then
        while read -r app; do
            read -p "Install Flatpak $app? (y/n/q): " choice
            case "$choice" in
                y|Y) 
                    log_message "Installing $app..."
                    if flatpak remote-info flathub "$app" >/dev/null 2>&1; then
                        flatpak install -y flathub "$app" || log_missing "$app" "flatpak-failed"
                    else
                        log_missing "$app" "flatpak"
                        log_message "Application not found in Flathub"
                    fi
                    ;;
                q|Q) break ;;
                *) log_message "Skipping $app" ;;
            esac
        done < packages-flatpak.txt
    else
        log_message "Installing all Flatpak applications non-interactively..."
        while read -r app; do
            if flatpak remote-info flathub "$app" >/dev/null 2>&1; then
                flatpak install -y flathub "$app" || log_missing "$app" "flatpak-failed"
            else
                log_missing "$app" "flatpak"
            fi
        done < packages-flatpak.txt
    fi
fi

# Snap
if [ -f packages-snap.txt ] && has snap; then
    log_message "📦 Processing Snap packages..."
    PKG_COUNT=$(wc -l < packages-snap.txt)
    log_message "Found $PKG_COUNT Snap packages to install"
    
    if [ "$INTERACTIVE" = "y" ]; then
        while read -r app; do
            read -p "Install Snap $app? (y/n/q): " choice
            case "$choice" in
                y|Y) 
                    log_message "Installing $app..."
                    if snap info "$app" >/dev/null 2>&1; then
                        sudo snap install "$app" || log_missing "$app" "snap-failed"
                    else
                        log_missing "$app" "snap"
                        log_message "Application not found in Snap store"
                    fi
                    ;;
                q|Q) break ;;
                *) log_message "Skipping $app" ;;
            esac
        done < packages-snap.txt
    else
        log_message "Installing all Snap packages non-interactively..."
        while read -r app; do
            if snap info "$app" >/dev/null 2>&1; then
                sudo snap install "$app" || log_missing "$app" "snap-failed"
            else
                log_missing "$app" "snap"
            fi
        done < packages-snap.txt
    fi
fi

log_message "✅ Package installation complete."
log_message "Missing packages logged in $LOGDIR"
log_message "Failed installations logged in $LOGDIR with -failed suffix"
EOF

# Transfer and Run the Install Script
scp "$WORKDIR/$REMOTE_INSTALL_SCRIPT" "$TARGET_USER@$TARGET_HOST:$TARGET_DIR/pkgclone/" || {
    log_message "❌ Failed to transfer install script"
    exit 1
}

log_message "🚀 Package lists and install script transferred."
echo ""
echo "To run the install script on the target machine, use:"
echo "   ssh $TARGET_USER@$TARGET_HOST 'cd $TARGET_DIR/pkgclone && bash install_packages_universal.sh'"

# ========== Home Directory Sync ==========
echo ""
echo "How would you like to sync your user configuration files to the target machine?"
echo "1. Sync selected config directories only (.config, .local, etc.)"
echo "2. Sync personal data directories (Documents, Pictures, Music, etc.)"
echo "3. Sync both config and personal data directories"
echo "4. Sync entire home directory (including hidden files/dotfiles)"
echo "5. Don't sync any files"
read -p "Select an option (1/2/3/4/5): " SYNC_OPTION

# Create a more comprehensive exclusion list for system directories
cat > "$WORKDIR/rsync_exclude.txt" << EXCL
# Caches and temporary files
.cache/
.local/share/Trash/
tmp/
Temp/
.thumbnails/

# Runtime/service directories
.gvfs/
.dbus/
.X*/
.esd_auth
.ICEauthority
.Xauthority
.xsession-errors
.pulse/
.pulse-cookie

# Package manager caches
.npm/
node_modules/
.yarn/
.cargo/
.rustup/
.gradle/
.m2/
.ivy2/
.sbt/
.pio/
.platformio/
.pub-cache/
.nuget/
.cpan/
.cpanm/
.gem/
.bundle/
.local/lib/python*/site-packages/
.pyenv/
venv/
__pycache__/
*.pyc

# VMs and containers
.vagrant/
.vagrant.d/
.virtualbox/
.docker/
.containers/
.kube/

# Browser data (often very large)
.mozilla/firefox/*/Cache/
.mozilla/firefox/*/storage/
.mozilla/firefox/*/cookies.sqlite
.config/google-chrome/Default/Cache/
.config/google-chrome/Default/GPUCache/
.config/chromium/Default/Cache/
.config/chromium/Default/GPUCache/
.config/BraveSoftware/*/Cache/
.config/microsoft-edge/*/Cache/
.config/vivaldi/*/Cache/
.config/opera/*/Cache/

# Steam and games
.steam/
.local/share/Steam/
.local/share/lutris/
.local/share/bottles/
.wine/
.dosbox/
.PlayOnLinux/
.local/share/Trash/
.local/share/flatpak/
.var/app/

# Logs
.local/share/xorg/
.local/state/
logs/
log/
.xsession-errors*
*.log
*.old
*.bak
*.swap
*.swp
*~

# ML/Data Science
.keras/
.tensorflow/
.torch/
.ipython/
.jupyter/

# System directories that shouldn't be synced
/dev/
/proc/
/sys/
/run/
/mnt/
/media/
/lost+found/
/boot/
EXCL
