#!/bin/bash
# This little script is meant to backup Plasma desktop 5/6
# All files and dependencies - X-Seti
# Use at your own risk!, Works for me, should work for you!

# Set colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define variables
BACKUP_DIR="$HOME/plasma_backup_$(date +%Y%m%d)"
TIMESTAMP=$(date +%Y%m%d)
PACKAGE_NAME="plasma-backup-${TIMESTAMP}"
PACKAGE_VERSION="1.0"
PACKAGE_DESCRIPTION="Plasma desktop environment backup and configuration"
PACKAGE_MAINTAINER="User <user@example.com>"
CREATE_PACKAGE="false"
PACKAGE_TYPE=""
INSTALL_DEPS="false"
ADDITIONAL_FILES=()
BACKUP_ONLY="true"
REMOVEPKGDIR="false"

# Show help message
show_help() {
    echo -e "${BLUE}Plasma Backup and Package Creation Script${NC}"
    echo "This script creates a comprehensive backup of your Plasma desktop environment"
    echo "and can optionally create a .deb, .pkg, or .rpm package from the backup."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -d, --deb                  Create a .deb package after backup"
    echo "  -p, --pkg                  Create a .pkg package after backup"
    echo "  -r, --rpm                  Create a .rpm package after backup"
    echo "  -n, --name <name>          Set package name (default: plasma-backup-YYYYMMDD)"
    echo "  -a, --addother <file/dir>  Add other files to the archive (can be used multiple times)"
    echo "  -v, --version <version>    Set package version (default: 1.0)"
    echo "  -m, --maintainer <info>    Set package maintainer (default: User <user@example.com>)"
    echo "  -R, --remove-pkg-dir       Remove working package directory when backup is done"
    echo "  -i, --install-deps         Install dependencies needed for package creation"
    echo ""
    echo "Example:"
    echo "  $0 --deb --name my-plasma-theme --version 2.1 --maintainer \"John Doe <john@example.com>\""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -d|--deb)
            CREATE_PACKAGE="true"
            PACKAGE_TYPE="deb"
            BACKUP_ONLY="false"
            shift
            ;;
        -p|--pkg)
            CREATE_PACKAGE="true"
            PACKAGE_TYPE="pkg"
            BACKUP_ONLY="false"
            shift
            ;;
        -r|--rpm)
            CREATE_PACKAGE="true"
            PACKAGE_TYPE="rpm"
            BACKUP_ONLY="false"
            shift
            ;;
        -n|--name)
            PACKAGE_NAME="$2"
            shift 2
            ;;
        -a|--addother)
            if [ -e "$2" ]; then
                ADDITIONAL_FILES+=("$2")
                echo -e "${GREEN}Added '$2' to additional files${NC}"
            else
                echo -e "${YELLOW}Warning: File/directory '$2' does not exist and will be skipped${NC}"
            fi
            shift 2
            ;;
        -v|--version)
            PACKAGE_VERSION="$2"
            shift 2
            ;;
        -m|--maintainer)
            PACKAGE_MAINTAINER="$2"
            shift 2
            ;;
        -i|--install-deps)
            INSTALL_DEPS="true"
            shift
            ;;
        -R|--remove-pkg-dir)
            REMOVEPKGDIR="true"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    else
        echo "unknown"
    fi
}

# Install required dependencies for package creation
install_dependencies() {
    echo -e "${BLUE}Installing package creation dependencies...${NC}"
    
    PKG_MANAGER=$(detect_package_manager)
    
    case "$PKG_MANAGER" in
        apt)
            if [ "$PACKAGE_TYPE" = "deb" ]; then
                sudo apt-get update
                sudo apt-get install -y build-essential debhelper devscripts fakeroot
                echo -e "${GREEN}Dependencies for .deb packaging installed.${NC}"
            fi
            ;;
        pacman)
            if [ "$PACKAGE_TYPE" = "pkg" ]; then
                sudo pacman -Sy --needed --noconfirm base-devel
                echo -e "${GREEN}Dependencies for .pkg packaging installed.${NC}"
            fi
            ;;
        dnf|yum)
            if [ "$PACKAGE_TYPE" = "rpm" ]; then
                if [ "$PKG_MANAGER" = "dnf" ]; then
                    sudo dnf install -y rpm-build rpmdevtools
                else
                    sudo yum install -y rpm-build rpmdevtools
                fi
                echo -e "${GREEN}Dependencies for .rpm packaging installed.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Unsupported package manager. Please install packaging tools manually.${NC}"
            exit 1
            ;;
    esac
}

# Create backup directory
create_backup() {
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    echo -e "${BLUE}Creating backup in: ${NC}$BACKUP_DIR"

    # Backup user config files (.config and .local)
    echo -e "${BLUE}Backing up user configuration files...${NC}"
    mkdir -p "$BACKUP_DIR/home_configs"
    
    # KDE/Plasma specific configs (including uppercase directories)
    for config_dir in plasma* kde* KDE* Plasma*; do
        cp -r "$HOME/.config/$config_dir" "$BACKUP_DIR/home_configs/" 2>/dev/null
        cp -r "$HOME/.local/share/$config_dir" "$BACKUP_DIR/home_configs/" 2>/dev/null
    done

    # Important cache files (kiosk profiles, icon cache, etc.)
    echo -e "${BLUE}Backing up relevant cache files...${NC}"
    mkdir -p "$BACKUP_DIR/home_configs/cache"
    cp -r "$HOME/.cache/icon-cache.kcache" "$BACKUP_DIR/home_configs/cache/" 2>/dev/null
    cp -r "$HOME/.cache/plasma"* "$BACKUP_DIR/home_configs/cache/" 2>/dev/null
    cp -r "$HOME/.cache/kde"* "$BACKUP_DIR/home_configs/cache/" 2>/dev/null
    cp -r "$HOME/.cache/KDE"* "$BACKUP_DIR/home_configs/cache/" 2>/dev/null

    # Theme related configurations
    cp -r "$HOME/.themes" "$BACKUP_DIR/home_configs/" 2>/dev/null
    cp -r "$HOME/.icons" "$BACKUP_DIR/home_configs/" 2>/dev/null
    cp -r "$HOME/.local/share/icons" "$BACKUP_DIR/home_configs/local_icons" 2>/dev/null
    cp -r "$HOME/.local/share/themes" "$BACKUP_DIR/home_configs/local_themes" 2>/dev/null
    cp -r "$HOME/.local/share/aurorae" "$BACKUP_DIR/home_configs/aurorae" 2>/dev/null
    cp -r "$HOME/.local/share/color-schemes" "$BACKUP_DIR/home_configs/color-schemes" 2>/dev/null
    cp -r "$HOME/.local/share/wallpapers" "$BACKUP_DIR/home_configs/wallpapers" 2>/dev/null
    cp -r "$HOME/Wallpapers" "$BACKUP_DIR/home_configs/Wallpapers" 2>/dev/null

    # Backup system-wide themes and icons
    echo -e "${BLUE}Backing up system-wide themes and icons...${NC}"
    mkdir -p "$BACKUP_DIR/system_themes_icons"
    sudo cp -r "/usr/share/backgrounds" "$BACKUP_DIR/system_themes_icons/" 2>/dev/null
    sudo cp -r "/usr/share/themes" "$BACKUP_DIR/system_themes_icons/" 2>/dev/null
    sudo cp -r "/usr/share/icons" "$BACKUP_DIR/system_themes_icons/" 2>/dev/null
    sudo cp -r "/usr/share/aurorae" "$BACKUP_DIR/system_themes_icons/" 2>/dev/null
    sudo cp -r "/usr/share/color-schemes" "$BACKUP_DIR/system_themes_icons/" 2>/dev/null
    sudo cp -r "/usr/share/wallpapers" "$BACKUP_DIR/system_themes_icons/" 2>/dev/null

    # Backup Plasma/KDE system components
    echo -e "${BLUE}Backing up Plasma system components...${NC}"
    mkdir -p "$BACKUP_DIR/system_components"

    # Backup KDE/Plasma binaries (optimized)
    echo -e "${BLUE}Backing up KDE/Plasma binaries...${NC}"
    mkdir -p "$BACKUP_DIR/system_components/bin"
    for dir in /usr/bin /bin /usr/local/bin; do
        if [ -d "$dir" ]; then
            find "$dir" -type f -name "plasma*" -o -name "kde*" | 
            while read -r file; do
                target_dir="$BACKUP_DIR/system_components/bin/$(dirname "${file#/}")"
                mkdir -p "$target_dir"
                sudo cp -a "$file" "$target_dir/" 2>/dev/null
            done
        fi
    done

    # Backup KDE/Plasma libraries (optimized)
    echo -e "${BLUE}Backing up KDE/Plasma libraries...${NC}"
    mkdir -p "$BACKUP_DIR/system_components/lib"
    for dir in /usr/lib /usr/lib64 /lib /lib64 /usr/local/lib; do
        if [ -d "$dir" ]; then
            # Copy KDE/Plasma specific libraries
            find "$dir" -type f -name "libplasma*" -o -name "libkde*" -o -name "libKF*" | 
            while read -r file; do
                target_dir="$BACKUP_DIR/system_components/lib/$(dirname "${file#/}")"
                mkdir -p "$target_dir"
                sudo cp -a "$file" "$target_dir/" 2>/dev/null
            done
            
            # Copy KDE/Plasma directories
            for plasma_dir in plasma{,-desktop,-5,-6} "qt"*/plugins/plasma "qt"*/qml/org/kde kf*; do
                if [ -d "$dir/$plasma_dir" ]; then
                    target_dir="$BACKUP_DIR/system_components/lib/$(dirname "${plasma_dir}")"
                    mkdir -p "$target_dir"
                    sudo cp -r "$dir/$plasma_dir" "$target_dir/" 2>/dev/null
                fi
            done
        fi
    done

    # Backup KDE/Plasma share directories
    echo -e "${BLUE}Backing up KDE/Plasma share directories...${NC}"
    mkdir -p "$BACKUP_DIR/system_components/share"
    sudo cp -r "/usr/share/plasma" "$BACKUP_DIR/system_components/share/" 2>/dev/null
    sudo cp -r "/usr/share/kde4" "$BACKUP_DIR/system_components/share/" 2>/dev/null
    sudo cp -r "/usr/share/kservices5" "$BACKUP_DIR/system_components/share/" 2>/dev/null
    sudo cp -r "/usr/share/knotifications5" "$BACKUP_DIR/system_components/share/" 2>/dev/null
    sudo cp -r "/usr/share/kservicetypes5" "$BACKUP_DIR/system_components/share/" 2>/dev/null

    # Add additional files to backup
    if [ ${#ADDITIONAL_FILES[@]} -gt 0 ]; then
        echo -e "${BLUE}Adding additional files to backup...${NC}"
        mkdir -p "$BACKUP_DIR/additional_files"
        
        for file in "${ADDITIONAL_FILES[@]}"; do
            if [ -e "$file" ]; then
                local basename=$(basename "$file")
                cp -r "$file" "$BACKUP_DIR/additional_files/$basename" 2>/dev/null
                echo -e "${GREEN}Added: $file${NC}"
            fi
        done
    fi

    # Create backup info file
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
Plasma Desktop Environment Backup
Created on: $(date)
System: $(uname -a)
Distribution: $(cat /etc/*-release | grep -E "^NAME=" | head -n 1 | cut -d= -f2- | tr -d '"')
Plasma Version: $(plasmashell --version 2>/dev/null || echo "Unknown")
KDE Frameworks Version: $(kf5-config --version 2>/dev/null || echo "Unknown")
EOF

    # Create tarball if creating package
    if [ "$CREATE_PACKAGE" = "true" ]; then
        echo -e "${BLUE}Creating backup tarball...${NC}"
        tar -czf "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
        echo -e "${GREEN}Backup tarball created: ${NC}${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
    fi
    
    echo -e "${GREEN}Backup completed successfully!${NC}"
}

#
# Function to create .deb package
create_deb_package() {
    echo -e "${BLUE}Creating .deb package...${NC}"
    
    # Check if required tools are installed
    if ! command_exists dpkg-deb || ! command_exists fakeroot; then
        echo -e "${YELLOW}Required packaging tools not found. Installing...${NC}"
        sudo apt-get update
        sudo apt-get install -y build-essential debhelper devscripts fakeroot
    fi
    
    # Create directory structure for the .deb package
    PKG_DIR="${PACKAGE_NAME}-${PACKAGE_VERSION}"
    mkdir -p "$PKG_DIR/DEBIAN"
    mkdir -p "$PKG_DIR/usr"
    mkdir -p "$PKG_DIR/etc"
    mkdir -p "$PKG_DIR/home/USER_TO_REPLACE"
    
    # Create control file
    cat > "$PKG_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: $PACKAGE_MAINTAINER
Description: $PACKAGE_DESCRIPTION
 This package contains a backup of Plasma desktop environment
 including configuration files, themes, and binaries.
EOF

    # Create postinst script to handle installation
    cat > "$PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Determine current user (the one who ran sudo)
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(logname 2>/dev/null || echo "$USER")
fi

# Replace placeholder with actual username in paths
if [ -d "/home/USER_TO_REPLACE" ]; then
    # Only process if the placeholder directory exists
    if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ] && [ -d "/home/$REAL_USER" ]; then
        echo "Installing user configurations for $REAL_USER..."
        
        # Create target directories
        mkdir -p "/home/$REAL_USER/.config"
        mkdir -p "/home/$REAL_USER/.local/share"
        mkdir -p "/home/$REAL_USER/.cache"
        mkdir -p "/home/$REAL_USER/Wallpapers"
        
        # Copy user configs
        if [ -d "/home/USER_TO_REPLACE/.config" ]; then
            cp -rf "/home/USER_TO_REPLACE/.config/"* "/home/$REAL_USER/.config/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.config/"
        fi
        
        if [ -d "/home/USER_TO_REPLACE/.local" ]; then
            cp -rf "/home/USER_TO_REPLACE/.local/"* "/home/$REAL_USER/.local/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.local/"
        fi
        
        if [ -d "/home/USER_TO_REPLACE/.themes" ]; then
            cp -rf "/home/USER_TO_REPLACE/.themes" "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.themes"
        fi
        
        if [ -d "/home/USER_TO_REPLACE/.icons" ]; then
            cp -rf "/home/USER_TO_REPLACE/.icons" "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.icons"
        fi
        
        if [ -d "/home/USER_TO_REPLACE/.cache" ]; then
            cp -rf "/home/USER_TO_REPLACE/.cache/"* "/home/$REAL_USER/.cache/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.cache/"
        fi
        
        if [ -d "/home/USER_TO_REPLACE/Wallpapers" ]; then
            cp -rf "/home/USER_TO_REPLACE/Wallpapers/"* "/home/$REAL_USER/Wallpapers/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/Wallpapers/"
        fi
        
        # Handle any additional files
        if [ -d "/home/USER_TO_REPLACE/additional_files" ]; then
            echo "Installing additional files..."
            cp -rf "/home/USER_TO_REPLACE/additional_files/"* "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/"
        fi
    else
        echo "Warning: Could not determine the real user or home directory does not exist."
        echo "You may need to manually copy configurations from /home/USER_TO_REPLACE/ to your home directory."
    fi
fi

# Update system cache if necessary
if command -v update-icon-caches >/dev/null; then
    update-icon-caches /usr/share/icons/* >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null; then
    update-desktop-database -q || true
fi

echo "Plasma configuration installed. You may need to log out and log back in for all changes to take effect."
exit 0
EOF

    # Make the script executable
    chmod 755 "$PKG_DIR/DEBIAN/postinst"
    
    # Copy system components
    echo -e "${BLUE}Copying system components to package...${NC}"
    for dir in bin lib share; do
        if [ -d "$BACKUP_DIR/system_components/$dir" ]; then
            mkdir -p "$PKG_DIR/usr/$dir"
            cp -r "$BACKUP_DIR/system_components/$dir"/* "$PKG_DIR/usr/$dir/" 2>/dev/null || true
        fi
    done
    
    if [ -d "$BACKUP_DIR/system_themes_icons" ]; then
        mkdir -p "$PKG_DIR/usr/share"
        cp -r "$BACKUP_DIR/system_themes_icons"/* "$PKG_DIR/usr/share/" 2>/dev/null || true
    fi
    
    # Copy user configurations
    echo -e "${BLUE}Copying user configurations to package...${NC}"
    if [ -d "$BACKUP_DIR/home_configs" ]; then
        # Create necessary directory structure
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.config"
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share"
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.cache"
        
        # Copy config files
        for dir in "$BACKUP_DIR/home_configs"/*; do
            if [ -d "$dir" ]; then
                base_dir=$(basename "$dir")
                case "$base_dir" in
                    "cache")
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.cache/" 2>/dev/null || true
                        ;;
                    "local_icons")
                        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share/icons"
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.local/share/icons/" 2>/dev/null || true
                        ;;
                    "local_themes")
                        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share/themes"
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.local/share/themes/" 2>/dev/null || true
                        ;;
                    "aurorae"|"color-schemes"|"wallpapers")
                        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share/$base_dir"
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.local/share/$base_dir/" 2>/dev/null || true
                        ;;
                    *)
                        if [[ "$base_dir" == "plasma"* || "$base_dir" == "kde"* || "$base_dir" == "KDE"* || "$base_dir" == "Plasma"* ]]; then
                            cp -r "$dir" "$PKG_DIR/home/USER_TO_REPLACE/.config/" 2>/dev/null || true
                        fi
                        ;;
                esac
            fi
        done
        
        # Copy .themes and .icons directories
        if [ -d "$BACKUP_DIR/home_configs/.themes" ]; then
            cp -r "$BACKUP_DIR/home_configs/.themes" "$PKG_DIR/home/USER_TO_REPLACE/" 2>/dev/null || true
        fi
        
        if [ -d "$BACKUP_DIR/home_configs/.icons" ]; then
            cp -r "$BACKUP_DIR/home_configs/.icons" "$PKG_DIR/home/USER_TO_REPLACE/" 2>/dev/null || true
        fi
        
        if [ -d "$BACKUP_DIR/home_configs/Wallpapers" ]; then
            cp -r "$BACKUP_DIR/home_configs/Wallpapers" "$PKG_DIR/home/USER_TO_REPLACE/" 2>/dev/null || true
        fi
    fi
    
    # Add additional files to the package
    if [ -d "$BACKUP_DIR/additional_files" ]; then
        echo -e "${BLUE}Adding additional files to package...${NC}"
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/additional_files"
        cp -r "$BACKUP_DIR/additional_files/"* "$PKG_DIR/home/USER_TO_REPLACE/additional_files/" 2>/dev/null || true
    fi
    
    # Build the package
    echo -e "${BLUE}Building .deb package...${NC}"
    fakeroot dpkg-deb --build "$PKG_DIR"
    
    # Rename the package file if necessary
    if [ -f "${PKG_DIR}.deb" ]; then
        mv "${PKG_DIR}.deb" "${PACKAGE_NAME}_${PACKAGE_VERSION}_all.deb"
        echo -e "${GREEN}Package created: ${NC}${PACKAGE_NAME}_${PACKAGE_VERSION}_all.deb"
    else
        echo -e "${RED}Failed to create .deb package${NC}"
        exit 1
    fi
    
    # Cleanup
    if [ "$REMOVEPKGDIR" = "true" ]; then
    rm -rf "$PKG_DIR"
    fi
}

# Function to create .deb package
create_deb_package() {
    echo -e "${BLUE}Creating .deb package...${NC}"

    # Check if required tools are installed
    if ! command_exists dpkg-deb || ! command_exists fakeroot; then
        echo -e "${YELLOW}Required packaging tools not found. Installing...${NC}"
        sudo apt-get update
        sudo apt-get install -y build-essential debhelper devscripts fakeroot
    fi

    # Create directory structure for the .deb package
    PKG_DIR="${PACKAGE_NAME}-${PACKAGE_VERSION}"
    mkdir -p "$PKG_DIR/DEBIAN"
    mkdir -p "$PKG_DIR/usr"
    mkdir -p "$PKG_DIR/etc"
    mkdir -p "$PKG_DIR/home/USER_TO_REPLACE"

    # Create control file
    cat > "$PKG_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: $PACKAGE_MAINTAINER
Description: $PACKAGE_DESCRIPTION
 This package contains a backup of Plasma desktop environment
 including configuration files, themes, and binaries.
EOF

    # Create postinst script to handle installation
    cat > "$PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Determine current user (the one who ran sudo)
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(logname 2>/dev/null || echo "$USER")
fi

# Replace placeholder with actual username in paths
if [ -d "/home/USER_TO_REPLACE" ]; then
    # Only process if the placeholder directory exists
    if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ] && [ -d "/home/$REAL_USER" ]; then
        echo "Installing user configurations for $REAL_USER..."

        # Copy user configs
        if [ -d "/home/USER_TO_REPLACE/.config" ]; then
            cp -rf "/home/USER_TO_REPLACE/.config/"* "/home/$REAL_USER/.config/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.config/"
        fi

        if [ -d "/home/USER_TO_REPLACE/.local" ]; then
            cp -rf "/home/USER_TO_REPLACE/.local/"* "/home/$REAL_USER/.local/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.local/"
        fi

        if [ -d "/home/USER_TO_REPLACE/.themes" ]; then
            cp -rf "/home/USER_TO_REPLACE/.themes" "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.themes"
        fi

        if [ -d "/home/USER_TO_REPLACE/.icons" ]; then
            cp -rf "/home/USER_TO_REPLACE/.icons" "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.icons"
        fi

        if [ -d "/home/USER_TO_REPLACE/.cache" ]; then
            cp -rf "/home/USER_TO_REPLACE/.cache/"* "/home/$REAL_USER/.cache/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.cache/"
        fi
    else
        echo "Warning: Could not determine the real user or home directory does not exist."
        echo "You may need to manually copy configurations from /home/USER_TO_REPLACE/ to your home directory."
    fi
fi

# Update system cache if necessary
if command -v update-icon-caches >/dev/null; then
    update-icon-caches /usr/share/icons/* >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null; then
    update-desktop-database -q || true
fi

echo "Plasma configuration installed. You may need to log out and log back in for all changes to take effect."
exit 0
EOF

    # Make the script executable
    chmod 755 "$PKG_DIR/DEBIAN/postinst"

    # Copy system components
    echo -e "${BLUE}Copying system components to package...${NC}"
    if [ -d "$BACKUP_DIR/system_components/bin" ]; then
        cp -r "$BACKUP_DIR/system_components/bin"/* "$PKG_DIR/usr/bin/" 2>/dev/null || mkdir -p "$PKG_DIR/usr/bin"
    fi

    if [ -d "$BACKUP_DIR/system_components/lib" ]; then
        cp -r "$BACKUP_DIR/system_components/lib"/* "$PKG_DIR/usr/lib/" 2>/dev/null || mkdir -p "$PKG_DIR/usr/lib"
    fi

    if [ -d "$BACKUP_DIR/system_components/share" ]; then
        cp -r "$BACKUP_DIR/system_components/share"/* "$PKG_DIR/usr/share/" 2>/dev/null || mkdir -p "$PKG_DIR/usr/share"
    fi

    if [ -d "$BACKUP_DIR/system_themes_icons" ]; then
        cp -r "$BACKUP_DIR/system_themes_icons"/* "$PKG_DIR/usr/share/" 2>/dev/null
    fi

    # Copy user configurations
    echo -e "${BLUE}Copying user configurations to package...${NC}"
    if [ -d "$BACKUP_DIR/home_configs" ]; then
        # Create necessary directory structure
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.config"
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share"
        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.cache"

        # Copy config files
        for dir in "$BACKUP_DIR/home_configs"/*; do
            if [ -d "$dir" ]; then
                base_dir=$(basename "$dir")
                case "$base_dir" in
                    "cache")
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.cache/" 2>/dev/null
                        ;;
                    "local_icons")
                        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share/icons"
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.local/share/icons/" 2>/dev/null
                        ;;
                    "local_themes")
                        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share/themes"
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.local/share/themes/" 2>/dev/null
                        ;;
                    "aurorae"|"color-schemes"|"wallpapers")
                        mkdir -p "$PKG_DIR/home/USER_TO_REPLACE/.local/share/$base_dir"
                        cp -r "$dir"/* "$PKG_DIR/home/USER_TO_REPLACE/.local/share/$base_dir/" 2>/dev/null
                        ;;
                    *)
                        if [[ "$base_dir" == "plasma"* || "$base_dir" == "kde"* || "$base_dir" == "KDE"* || "$base_dir" == "Plasma"* ]]; then
                            cp -r "$dir" "$PKG_DIR/home/USER_TO_REPLACE/.config/" 2>/dev/null
                        fi
                        ;;
                esac
            fi
        done

        # Copy .themes and .icons directories
        if [ -d "$BACKUP_DIR/home_configs/.themes" ]; then
            cp -r "$BACKUP_DIR/home_configs/.themes" "$PKG_DIR/home/USER_TO_REPLACE/" 2>/dev/null
        fi

        if [ -d "$BACKUP_DIR/home_configs/.icons" ]; then
            cp -r "$BACKUP_DIR/home_configs/.icons" "$PKG_DIR/home/USER_TO_REPLACE/" 2>/dev/null
        fi
    fi

    # Build the package
    echo -e "${BLUE}Building .deb package...${NC}"
    fakeroot dpkg-deb --build "$PKG_DIR"

    # Rename the package file if necessary
    if [ -f "${PKG_DIR}.deb" ]; then
        mv "${PKG_DIR}.deb" "${PACKAGE_NAME}_${PACKAGE_VERSION}_all.deb"
        echo -e "${GREEN}Package created: ${NC}${PACKAGE_NAME}_${PACKAGE_VERSION}_all.deb"
    else
        echo -e "${RED}Failed to create .deb package${NC}"
        exit 1
    fi

    # Cleanup
    if [ "$REMOVEPKGDIR" = "true" ]; then
    rm -rf "$PKG_DIR"
    fi
}

# Function to create .pkg package (Arch Linux)
create_pkg_package() {
    echo -e "${BLUE}Creating .pkg package (Arch Linux)...${NC}"
    
    # Check if required tools are installed
    if ! command_exists makepkg; then
        echo -e "${YELLOW}Required packaging tools not found. Installing...${NC}"
        sudo pacman -Sy --needed --noconfirm base-devel
    fi
    
    # Create PKGBUILD directory
    PKG_BUILD_DIR="${PACKAGE_NAME}-pkgbuild"
    mkdir -p "$PKG_BUILD_DIR"
    
    # Move tarball to build directory
    cp "${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz" "$PKG_BUILD_DIR/"
    
    # Create PKGBUILD file
    cat > "$PKG_BUILD_DIR/PKGBUILD" << EOF
# Maintainer: $PACKAGE_MAINTAINER

pkgname=$PACKAGE_NAME
pkgver=$PACKAGE_VERSION
pkgrel=1
pkgdesc="$PACKAGE_DESCRIPTION"
arch=('any')
license=('custom')
depends=('plasma-desktop')
install=\${pkgname}.install

source=("${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz")
sha256sums=('SKIP')

package() {
    local backup_dir="\$(find . -maxdepth 1 -type d -name "plasma_backup_*" | head -n 1)"
    
    if [ -z "\$backup_dir" ]; then
        echo "Error: Could not find backup directory"
        exit 1
    fi
    
    # Install system components
    for dir in bin lib share; do
        if [ -d "\$backup_dir/system_components/\$dir" ]; then
            install -d "\$pkgdir/usr/\$dir"
            cp -r "\$backup_dir/system_components/\$dir/"* "\$pkgdir/usr/\$dir/" 2>/dev/null || true
        fi
    done
    
    if [ -d "\$backup_dir/system_themes_icons" ]; then
        install -d "\$pkgdir/usr/share"
        cp -r "\$backup_dir/system_themes_icons/"* "\$pkgdir/usr/share/" 2>/dev/null || true
    fi
    
    # Install user configurations
    if [ -d "\$backup_dir/home_configs" ]; then
        install -d "\$pkgdir/etc/skel"
        
        # Process home config files
        for dir in "\$backup_dir/home_configs/"*; do
            if [ -d "\$dir" ]; then
                base_dir=\$(basename "\$dir")
                case "\$base_dir" in
                    "cache")
                        install -d "\$pkgdir/etc/skel/.cache"
                        cp -r "\$dir/"* "\$pkgdir/etc/skel/.cache/" 2>/dev/null || true
                        ;;
                    "local_icons")
                        install -d "\$pkgdir/etc/skel/.local/share/icons"
                        cp -r "\$dir/"* "\$pkgdir/etc/skel/.local/share/icons/" 2>/dev/null || true
                        ;;
                    "local_themes")
                        install -d "\$pkgdir/etc/skel/.local/share/themes"
                        cp -r "\$dir/"* "\$pkgdir/etc/skel/.local/share/themes/" 2>/dev/null || true
                        ;;
                    "aurorae"|"color-schemes"|"wallpapers")
                        install -d "\$pkgdir/etc/skel/.local/share/\$base_dir"
                        cp -r "\$dir/"* "\$pkgdir/etc/skel/.local/share/\$base_dir/" 2>/dev/null || true
                        ;;
                    *)
                        if [[ "\$base_dir" == "plasma"* || "\$base_dir" == "kde"* || "\$base_dir" == "KDE"* || "\$base_dir" == "Plasma"* ]]; then
                            install -d "\$pkgdir/etc/skel/.config"
                            cp -r "\$dir" "\$pkgdir/etc/skel/.config/" 2>/dev/null || true
                        fi
                        ;;
                esac
            fi
        done
        
        # Copy .themes and .icons directories
        if [ -d "\$backup_dir/home_configs/.themes" ]; then
            cp -r "\$backup_dir/home_configs/.themes" "\$pkgdir/etc/skel/" 2>/dev/null || true
        fi
        
        if [ -d "\$backup_dir/home_configs/.icons" ]; then
            cp -r "\$backup_dir/home_configs/.icons" "\$pkgdir/etc/skel/" 2>/dev/null || true
        fi
        
        if [ -d "\$backup_dir/home_configs/Wallpapers" ]; then
            cp -r "\$backup_dir/home_configs/Wallpapers" "\$pkgdir/etc/skel/" 2>/dev/null || true
        fi
    fi
    
    # Add additional files to the package
    if [ -d "\$backup_dir/additional_files" ]; then
        install -d "\$pkgdir/etc/skel/additional_files"
        cp -r "\$backup_dir/additional_files/"* "\$pkgdir/etc/skel/additional_files/" 2>/dev/null || true
    fi
    
    # Copy backup info
    if [ -f "\$backup_dir/backup_info.txt" ]; then
        install -d "\$pkgdir/usr/share/doc/\$pkgname"
        cp "\$backup_dir/backup_info.txt" "\$pkgdir/usr/share/doc/\$pkgname/" 2>/dev/null || true
    fi
}
EOF

    # Create install script
    cat > "$PKG_BUILD_DIR/${PACKAGE_NAME}.install" << 'EOF'
post_install() {
    echo "Plasma configuration installed."
    echo "To apply user configurations for existing users, run:"
    echo "  cp -r /etc/skel/.config/{plasma*,kde*,KDE*,Plasma*} ~/.config/ 2>/dev/null"
    echo "  cp -r /etc/skel/.local/share/{plasma*,kde*,KDE*,Plasma*} ~/.local/share/ 2>/dev/null"
    echo "  cp -r /etc/skel/.themes ~/.themes 2>/dev/null"
    echo "  cp -r /etc/skel/.icons ~/.icons 2>/dev/null"
    echo "You may need to log out and log back in for all changes to take effect."
}

post_upgrade() {
    post_install
}
EOF

    # Build the package
    echo -e "${BLUE}Building package...${NC}"
    cd "$PKG_BUILD_DIR"
    makepkg -sf

    # Check if package was created successfully
    if ls ./*.pkg.tar.zst 1> /dev/null 2>&1; then
        echo -e "${GREEN}Package created in ${PKG_BUILD_DIR}/${NC}"
        cp ./*.pkg.tar.zst ../
        echo -e "${GREEN}Package copied to: ${NC}$(ls ../*.pkg.tar.zst)"
    else
        echo -e "${RED}Failed to create package${NC}"
        exit 1
    fi

    # Return to original directory
    cd ..
}

# Function to create .rpm package
create_rpm_package() {
    echo -e "${BLUE}Creating .rpm package...${NC}"

    # Check if required tools are installed
    if ! command_exists rpmbuild; then
        echo -e "${YELLOW}Required packaging tools not found. Installing...${NC}"
        if command_exists dnf; then
            sudo dnf install -y rpm-build rpmdevtools
        elif command_exists yum; then
            sudo yum install -y rpm-build rpmdevtools
        else
            echo -e "${RED}Neither dnf nor yum found. Cannot install required tools.${NC}"
            exit 1
        fi
    fi

    # Create RPM build environment
    echo -e "${BLUE}Setting up RPM build environment...${NC}"
    RPM_BUILD_ROOT="$PWD/rpm-build"
    mkdir -p "$RPM_BUILD_ROOT"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    # Create tarball of the package content
    TARBALL_NAME="${PACKAGE_NAME}-${PACKAGE_VERSION}"
    mkdir -p "$TARBALL_NAME"

    # Create directory structure similar to the .deb package
    mkdir -p "$TARBALL_NAME/usr"
    mkdir -p "$TARBALL_NAME/etc"
    mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE"

    # Copy system components
    echo -e "${BLUE}Copying system components to package...${NC}"
    if [ -d "$BACKUP_DIR/system_components/bin" ]; then
        cp -r "$BACKUP_DIR/system_components/bin"/* "$TARBALL_NAME/usr/bin/" 2>/dev/null || mkdir -p "$TARBALL_NAME/usr/bin"
    fi

    if [ -d "$BACKUP_DIR/system_components/lib" ]; then
        cp -r "$BACKUP_DIR/system_components/lib"/* "$TARBALL_NAME/usr/lib/" 2>/dev/null || mkdir -p "$TARBALL_NAME/usr/lib"
    fi

    if [ -d "$BACKUP_DIR/system_components/share" ]; then
        cp -r "$BACKUP_DIR/system_components/share"/* "$TARBALL_NAME/usr/share/" 2>/dev/null || mkdir -p "$TARBALL_NAME/usr/share"
    fi

    if [ -d "$BACKUP_DIR/system_themes_icons" ]; then
        cp -r "$BACKUP_DIR/system_themes_icons"/* "$TARBALL_NAME/usr/share/" 2>/dev/null
    fi

    # Copy user configurations
    echo -e "${BLUE}Copying user configurations to package...${NC}"
    if [ -d "$BACKUP_DIR/home_configs" ]; then
        # Create necessary directory structure
        mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE/.config"
        mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share"
        mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE/.cache"

        # Copy config files
        for dir in "$BACKUP_DIR/home_configs"/*; do
            if [ -d "$dir" ]; then
                base_dir=$(basename "$dir")
                case "$base_dir" in
                    "cache")
                        cp -r "$dir"/* "$TARBALL_NAME/home/USER_TO_REPLACE/.cache/" 2>/dev/null
                        ;;
                    "local_icons")
                        mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share/icons"
                        cp -r "$dir"/* "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share/icons/" 2>/dev/null
                        ;;
                    "local_themes")
                        mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share/themes"
                        cp -r "$dir"/* "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share/themes/" 2>/dev/null
                        ;;
                    "aurorae"|"color-schemes"|"wallpapers")
                        mkdir -p "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share/$base_dir"
                        cp -r "$dir"/* "$TARBALL_NAME/home/USER_TO_REPLACE/.local/share/$base_dir/" 2>/dev/null
                        ;;
                    *)
                        if [[ "$base_dir" == "plasma"* || "$base_dir" == "kde"* || "$base_dir" == "KDE"* || "$base_dir" == "Plasma"* ]]; then
                            cp -r "$dir" "$TARBALL_NAME/home/USER_TO_REPLACE/.config/" 2>/dev/null
                        fi
                        ;;
                esac
            fi
        done

        # Copy .themes and .icons directories
        if [ -d "$BACKUP_DIR/home_configs/.themes" ]; then
            cp -r "$BACKUP_DIR/home_configs/.themes" "$TARBALL_NAME/home/USER_TO_REPLACE/" 2>/dev/null
        fi

        if [ -d "$BACKUP_DIR/home_configs/.icons" ]; then
            cp -r "$BACKUP_DIR/home_configs/.icons" "$TARBALL_NAME/home/USER_TO_REPLACE/" 2>/dev/null
        fi
    fi

    # Create post-install script
    mkdir -p "$TARBALL_NAME/scripts"
    cat > "$TARBALL_NAME/scripts/post-install.sh" << 'EOF'
#!/bin/bash
set -e

# Determine current user (the one who ran sudo)
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(logname 2>/dev/null || echo "$USER")
fi

# Replace placeholder with actual username in paths
if [ -d "/home/USER_TO_REPLACE" ]; then
    # Only process if the placeholder directory exists
    if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ] && [ -d "/home/$REAL_USER" ]; then
        echo "Installing user configurations for $REAL_USER..."

        # Copy user configs
        if [ -d "/home/USER_TO_REPLACE/.config" ]; then
            cp -rf "/home/USER_TO_REPLACE/.config/"* "/home/$REAL_USER/.config/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.config/"
        fi

        if [ -d "/home/USER_TO_REPLACE/.local" ]; then
            cp -rf "/home/USER_TO_REPLACE/.local/"* "/home/$REAL_USER/.local/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.local/"
        fi

        if [ -d "/home/USER_TO_REPLACE/.themes" ]; then
            cp -rf "/home/USER_TO_REPLACE/.themes" "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.themes"
        fi

        if [ -d "/home/USER_TO_REPLACE/.icons" ]; then
            cp -rf "/home/USER_TO_REPLACE/.icons" "/home/$REAL_USER/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.icons"
        fi

        if [ -d "/home/USER_TO_REPLACE/.cache" ]; then
            cp -rf "/home/USER_TO_REPLACE/.cache/"* "/home/$REAL_USER/.cache/" 2>/dev/null || true
            chown -R "$REAL_USER:$(id -gn $REAL_USER)" "/home/$REAL_USER/.cache/"
        fi
    else
        echo "Warning: Could not determine the real user or home directory does not exist."
        echo "You may need to manually copy configurations from /home/USER_TO_REPLACE/ to your home directory."
    fi
fi

# Update system cache if necessary
if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/* >/dev/null 2>&1 || true
fi

if command -v update-desktop-database >/dev/null; then
    update-desktop-database -q || true
fi

echo "Plasma configuration installed. You may need to log out and log back in for all changes to take effect."
exit 0
EOF

    # Make the script executable
    chmod 755 "$TARBALL_NAME/scripts/post-install.sh"

    # Create tarball
    tar -czvf "$RPM_BUILD_ROOT/SOURCES/${TARBALL_NAME}.tar.gz" "$TARBALL_NAME"

    # Create spec file
    cat > "$RPM_BUILD_ROOT/SPECS/${PACKAGE_NAME}.spec" << EOF
Name:           $PACKAGE_NAME
Version:        $PACKAGE_VERSION
Release:        1%{?dist}
Summary:        $PACKAGE_DESCRIPTION

License:        GPL
BuildArch:      noarch

%description
This package contains a backup of Plasma desktop environment
including configuration files, themes, and binaries.

%prep
%setup -q

%build
# Nothing to build

%install
mkdir -p %{buildroot}/
cp -r usr %{buildroot}/
cp -r etc %{buildroot}/
mkdir -p %{buildroot}/home
cp -r home/USER_TO_REPLACE %{buildroot}/home/
mkdir -p %{buildroot}%{_datadir}/plasma-backup-scripts/
cp scripts/post-install.sh %{buildroot}%{_datadir}/plasma-backup-scripts/

%files
/usr
/etc
/home/USER_TO_REPLACE
%{_datadir}/plasma-backup-scripts/post-install.sh

%post
bash %{_datadir}/plasma-backup-scripts/post-install.sh

%changelog
* $(date "+%a %b %d %Y") $PACKAGE_MAINTAINER $PACKAGE_VERSION-1
- Initial package
EOF

    # Build the RPM package
    echo -e "${BLUE}Building .rpm package...${NC}"
    rpmbuild --define "_topdir $RPM_BUILD_ROOT" -bb "$RPM_BUILD_ROOT/SPECS/${PACKAGE_NAME}.spec"

    # Find and move the built RPM
    BUILT_RPM=$(find "$RPM_BUILD_ROOT/RPMS" -name "*.rpm" -type f | head -1)
    if [ -n "$BUILT_RPM" ]; then
        cp "$BUILT_RPM" ./
        FINAL_RPM=$(basename "$BUILT_RPM")
        echo -e "${GREEN}Package created: ${NC}$FINAL_RPM"
    else
        echo -e "${RED}Failed to create .rpm package${NC}"
        exit 1
    fi

    # Cleanup
    if [ "$REMOVEPKGDIR" = "true" ]; then
    rm -rf "$RPM_BUILD_ROOT" "$TARBALL_NAME"
    rm -rf "$PKG_DIR"
    fi
}

# Main script execution
echo -e "${GREEN}Backup completed: ${NC}${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"

# Create package if requested
if [ "$CREATE_PACKAGE" = "true" ]; then
    case "$PACKAGE_TYPE" in
        "deb")
            create_deb_package
            ;;
        "pkg")
            create_pkg_package
            ;;
        "rpm")
            create_rpm_package
            ;;
        *)
            echo -e "${RED}Unknown package type: $PACKAGE_TYPE${NC}"
            exit 1
            ;;
    esac
fi

echo -e "${GREEN}All operations completed successfully!${NC}"
