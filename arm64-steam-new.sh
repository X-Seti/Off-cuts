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
    libpng16-16:armhf libfontconfig1:armhf libxcomposite1:armhf libbz2-1.0:armhf \
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

echo "=== Installation Complete ==="
echo "Run 'steam' to launch Steam."
echo "Note: First run may require additional setup."
