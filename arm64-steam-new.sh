#!/bin/bash
#Original Script by Vennstone - https://interfacinglinux.com/
#Modified bash format; - X-Seti / Mooheda
#This is a modified script that can be run from bash.
#This allows Steam to be installed from any Arm64 debian/Armbian based linux.

# Check if script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
   echo "This script needs to be run with sudo privileges for system modifications."
   echo "Please run: sudo $0"
   exit 1
fi

echo "=== Installing Steam on ARM64 with Box86/Box64 ==="

# Function for error handling
handle_error() {
    echo "ERROR: $1"
    exit 1
}

echo "=== Adding Box86/64 repositories ==="
# BOX86 REPOSITORY
if wget -q https://ryanfortner.github.io/box86-debs/box86.list -O /etc/apt/sources.list.d/box86.list; then
    if wget -qO- https://ryanfortner.github.io/box86-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box86-debs-archive-keyring.gpg; then
        echo "✓ Box86 repository and key added successfully."
    else
        handle_error "Failed to add Box86 key."
    fi
else
    handle_error "Failed to download Box86 repository list."
fi

# BOX64 REPOSITORY
if wget -q https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list; then
    if wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg; then
        echo "✓ Box64 repository and key added successfully."
    else
        handle_error "Failed to add Box64 key."
    fi
else
    handle_error "Failed to download Box64 repository list."
fi

echo "=== Adding ARMHF architecture ==="
dpkg --add-architecture armhf || handle_error "Failed to add ARMHF architecture."
apt update || handle_error "Failed to update package lists."

echo "=== Installing Box86/64 and dependencies ==="
# INSTALLING BOX86/64 AND DEPENDENCIES
apt install -y box86-rk3588 box64-rk3588 \
    libfaudio0 libc6:armhf libsdl2-2.0-0:armhf libsdl2-image-2.0-0:armhf \
    libsdl2-mixer-2.0-0:armhf libsdl2-ttf-2.0-0:armhf libopenal1:armhf \
    libpng16-16t64:armhf libfontconfig1:armhf libxcomposite1:armhf libbz2-1.0:armhf \
    libxtst6:armhf libsm6:armhf libice6:armhf libgl1:armhf libxinerama1:armhf \
    libxdamage1:armhf libncurses6:armhf libgl1-mesa-dri:armhf curl:armhf \
    mesa-vulkan-drivers ppa-purge || handle_error "Failed to install dependencies."

echo "=== Installing Steam ==="
# INSTALLING STEAM
mkdir -p ~/steam && mkdir -p ~/steam/tmp
cd ~/steam/tmp || handle_error "Failed to create or access steam directory."

echo "Downloading Steam..."
wget https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb || handle_error "Failed to download Steam."

echo "Extracting Steam package..."
ar x steam.deb || handle_error "Failed to extract Steam deb package."
tar xf data.tar.xz || handle_error "Failed to extract Steam data."
rm ./*.tar.xz ./steam.deb
mv ./usr/* ../
cd ../ || handle_error "Failed to navigate directories."
rm -rf ./tmp/

echo "Creating Steam launcher script..."
cat > /usr/local/bin/steam << 'EOF'
#!/bin/bash
export STEAMOS=1
export STEAM_RUNTIME=1
export DBUS_FATAL_WARNINGS=0
export PAN_MESA_DEBUG=gofaster,gl3
box64 ~/steam/bin/steam "$@"
EOF

chmod +x /usr/local/bin/steam || handle_error "Failed to make Steam launcher executable."

echo "=== Installing latest Mesa drivers ==="
# MESA DRIVERS - MODIFIED TO ADD WITHOUT REMOVING KISAK REPO FIRST
add-apt-repository -y ppa:oibaf/graphics-drivers || echo "Warning: Failed to add Mesa graphics PPA. Continuing..."

# Function to detect architecture and install the appropriate Box64 package
detect_and_install_box64() {
    # Get basic system information
    ARCH=$(uname -m)

    # Check if we're on ARM64/aarch64
    if [[ "$ARCH" != "aarch64" ]]; then
        echo "Error: Not running on ARM64 architecture. Box64 requires ARM64."
        exit 1
    fi

    # Try to determine the specific hardware
    if grep -q "Raspberry Pi 5" /proc/device-tree/model 2>/dev/null; then
        # Check page size for Pi 5
        PAGE_SIZE=$(getconf PAGE_SIZE)
        if [[ "$PAGE_SIZE" -eq 16384 ]]; then
            PKG="box64-rpi5arm64ps16k box86-rpi5arm64ps16k"
        else
            PKG="box64-rpi5arm64 box86-rpi5arm64"
        fi
    elif grep -q "Raspberry Pi 4" /proc/device-tree/model 2>/dev/null; then
        PKG="box64-rpi4arm64 box86-rpi4arm64"
    elif grep -q "Raspberry Pi 3" /proc/device-tree/model 2>/dev/null; then
        PKG="box64-rpi3arm64 box86-rpi3arm64"
    elif grep -q "Tegra X1" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-tegrax1 box86-tegrax1"
    elif grep -q "Tegra194" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-tegra-t194 box86-tegra-t194"
    elif grep -q "rockchip,rk3399" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-rk3399 box86-rk3399"
    elif grep -q "rockchip,rk3588" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-rk3588 box86-rk3588"
    elif grep -q "apple,m1" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-m1 box86-m1"
    elif grep -q "lx2160a" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-lx2160a box86-lx2160a"
    # Check for Snapdragon processors
    elif grep -q "Snapdragon 888" /proc/cpuinfo 2>/dev/null || grep -q "SM8350" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-sd888 box86-sd888"
    elif grep -q "Snapdragon X Elite" /proc/cpuinfo 2>/dev/null || grep -q "X1E" /proc/device-tree/compatible 2>/dev/null; then
        PKG="box64-sdoryon1 box86-sdoryon1"
    # Check if running on Android
    elif [[ -d "/system/app" && -d "/system/priv-app" ]]; then
        PKG="box64-android box86-android"
    else
        # Default to generic ARM64 if specific hardware not identified
        PKG="box64 box86"
    fi

    echo "Detected system requires: $PKG"
    echo "Installing $PKG..."
    sudo apt install -y $PKG

    # Check if installation was successful
    if [[ $? -eq 0 ]]; then
        echo "$PKG successfully installed!"
    else
        echo "Installation failed. You may need to add the Box64 repository first."
        echo "Visit https://github.com/ptitSeb/box64 for more information."
    fi
}

# Run the detection and installation function
detect_and_install_box64

echo "=== Installation Complete ==="
echo "Run 'steam' to launch Steam."
echo "Note: First run may require additional setup."
