#!/bin/bash

# Universal Wallpaper Dimming Script
# Automatically adjusts wallpaper brightness based on time of day
# Compatible with: KDE Plasma 5, KDE Plasma 6, MATE, GNOME, XFCE, Cinnamon, LXDE/LXQt, i3, Sway, and other desktop environments

# Enable error tracing
set -e
set -o pipefail

# Base image path - use your lightest version as the base
BASE_WALLPAPER="${HOME}/Wallpapers/System-Defaults/fruit.jpg"

# Output path for the generated wallpaper
OUTPUT_DIR="${HOME}/Wallpapers/System-Defaults"
OUTPUT_WALLPAPER="${OUTPUT_DIR}/current-wallpaper.jpg"

# Log file for debugging
LOG_FILE="/tmp/wallpaper-change.log"
echo "Starting wallpaper adjustment at $(date)" > "$LOG_FILE"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check if base wallpaper exists
if [ ! -f "$BASE_WALLPAPER" ]; then
    echo "ERROR: Base wallpaper not found at $BASE_WALLPAPER" | tee -a "$LOG_FILE"
    echo "Please specify a valid wallpaper path by editing BASE_WALLPAPER in this script."
    exit 1
fi

# Get current hour (24-hour format)
HOUR=$(date +%H)
echo "Current hour: $HOUR" >> "$LOG_FILE"

# Define brightness levels
declare -A brightness_levels
brightness_levels[0]=20   # 12am - darkest
brightness_levels[1]=30
brightness_levels[2]=35
brightness_levels[3]=40
brightness_levels[4]=45
brightness_levels[5]=50
brightness_levels[6]=60   # 6am - starting to get lighter
brightness_levels[7]=70
brightness_levels[8]=80
brightness_levels[9]=85
brightness_levels[10]=90
brightness_levels[11]=95
brightness_levels[12]=100  # 12pm - brightest
brightness_levels[13]=100
brightness_levels[14]=95
brightness_levels[15]=90
brightness_levels[16]=85
brightness_levels[17]=80   # 5pm - starting to get darker
brightness_levels[18]=70
brightness_levels[19]=60
brightness_levels[20]=50   # 8pm
brightness_levels[21]=40
brightness_levels[22]=30
brightness_levels[23]=25

# Get the brightness level for the current hour
BRIGHTNESS=${brightness_levels[$HOUR]}
echo "Selected brightness: $BRIGHTNESS%" >> "$LOG_FILE"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ERROR: ImageMagick not installed. Please install it with your package manager:" | tee -a "$LOG_FILE"
    echo "  - Debian/Ubuntu: sudo apt install imagemagick" | tee -a "$LOG_FILE"
    echo "  - Fedora: sudo dnf install imagemagick" | tee -a "$LOG_FILE"
    echo "  - Arch: sudo pacman -S imagemagick" | tee -a "$LOG_FILE"
    exit 1
fi

# Use ImageMagick to adjust the brightness
echo "Creating adjusted wallpaper..." >> "$LOG_FILE"
convert "$BASE_WALLPAPER" -modulate 100,$BRIGHTNESS,100 "$OUTPUT_WALLPAPER" 2>> "$LOG_FILE"

# Check if the adjusted wallpaper was created successfully
if [ ! -f "$OUTPUT_WALLPAPER" ]; then
    echo "ERROR: Failed to create adjusted wallpaper" | tee -a "$LOG_FILE"
    exit 1
else
    echo "Adjusted wallpaper created successfully at $OUTPUT_WALLPAPER" >> "$LOG_FILE"
fi

# Detect desktop environment
detect_desktop_environment() {
    # Check for common environment variables
    if [ "$XDG_CURRENT_DESKTOP" ]; then
        DE="$XDG_CURRENT_DESKTOP"
    elif [ "$DESKTOP_SESSION" ]; then
        DE="$DESKTOP_SESSION"
    elif [ "$GDMSESSION" ]; then
        DE="$GDMSESSION"
    else
        # Try to detect by running processes
        if pgrep -x "plasmashell" > /dev/null; then
            DE="KDE"
        elif pgrep -x "gnome-shell" > /dev/null; then
            DE="GNOME"
        elif pgrep -x "mate-session" > /dev/null; then
            DE="MATE"
        elif pgrep -x "xfce4-session" > /dev/null; then
            DE="XFCE"
        elif pgrep -x "cinnamon" > /dev/null; then
            DE="CINNAMON"
        elif pgrep -x "lxsession" > /dev/null; then
            DE="LXDE"
        elif pgrep -x "lxqt-session" > /dev/null; then
            DE="LXQT"
        elif pgrep -x "i3" > /dev/null; then
            DE="i3"
        elif pgrep -x "sway" > /dev/null; then
            DE="SWAY"
        else
            DE="UNKNOWN"
        fi
    fi
    echo $DE | tr '[:lower:]' '[:upper:]'
}

# Get the desktop environment
DESKTOP_ENV=$(detect_desktop_environment)
echo "Detected desktop environment: $DESKTOP_ENV" | tee -a "$LOG_FILE"

# Function to set wallpaper in KDE Plasma (works for both 5 and 6)
set_kde_wallpaper() {
    echo "Setting wallpaper for KDE Plasma..." >> "$LOG_FILE"

    # Try the DBus method first (works in both Plasma 5 and 6)
    if qdbus org.kde.plasmashell /PlasmaShell &>/dev/null; then
        # Create a JavaScript file for the Plasma script
        JS_FILE="/tmp/plasma-wallpaper-script.js"
        cat > "$JS_FILE" << EOL
var allDesktops = desktops();
print("Found " + allDesktops.length + " desktops");
for (i=0; i<allDesktops.length; i++) {
    d = allDesktops[i];
    print("Setting wallpaper for desktop " + i);
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
    d.writeConfig('Image', 'file://${OUTPUT_WALLPAPER}');
}
EOL
        echo "Executing Plasma script..." >> "$LOG_FILE"
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat $JS_FILE)" >> "$LOG_FILE" 2>&1
        KDE_SUCCESS=$?

        if [ $KDE_SUCCESS -eq 0 ]; then
            echo "Successfully set wallpaper using DBus method" >> "$LOG_FILE"
            return 0
        fi
    fi

    echo "DBus method failed, trying alternative methods..." >> "$LOG_FILE"

    # Try plasma-apply-wallpaperimage (available in Plasma 5.18+ and Plasma 6)
    if command -v plasma-apply-wallpaperimage &> /dev/null; then
        echo "Using plasma-apply-wallpaperimage..." >> "$LOG_FILE"
        plasma-apply-wallpaperimage "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            echo "Successfully set wallpaper using plasma-apply-wallpaperimage" >> "$LOG_FILE"
            return 0
        fi
    fi

    # Last resort: Manually update config files
    echo "Trying manual config update..." >> "$LOG_FILE"

    # Detect Plasma version
    PLASMA_VERSION=$(plasmashell --version 2>/dev/null | grep -oP 'plasmashell \K[0-9]+' || echo "5")
    echo "Detected Plasma version: $PLASMA_VERSION" >> "$LOG_FILE"

    if [ "$PLASMA_VERSION" -ge "6" ]; then
        CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    else
        CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    fi

    # Find active containments
    CONTAINMENTS=$(grep -l "lastScreen" "$CONFIG_FILE" | grep "Containments" | grep -o '[0-9]\+' | sort -u || echo "1")

    for CONTAINMENT in $CONTAINMENTS; do
        echo "Updating containment $CONTAINMENT..." >> "$LOG_FILE"
        if command -v kwriteconfig5 &> /dev/null; then
            kwriteconfig5 --file "$CONFIG_FILE" --group "Containments" --group "$CONTAINMENT" --group "Wallpaper" --group "org.kde.image" --group "General" --key "Image" "file://$OUTPUT_WALLPAPER"
        elif command -v kwriteconfig6 &> /dev/null; then
            kwriteconfig6 --file "$CONFIG_FILE" --group "Containments" --group "$CONTAINMENT" --group "Wallpaper" --group "org.kde.image" --group "General" --key "Image" "file://$OUTPUT_WALLPAPER"
        else
            # If kwriteconfig is not available, directly edit the file
            # This is risky but better than nothing
            sed -i "s|Image=file://.*|Image=file://$OUTPUT_WALLPAPER|g" "$CONFIG_FILE"
        fi
    done

    # Try to reload the desktop configuration
    if qdbus org.kde.plasmashell /PlasmaShell refreshCurrentDesktop &>> "$LOG_FILE"; then
        echo "Refreshed desktop configuration" >> "$LOG_FILE"
    fi

    if qdbus org.kde.KWin /KWin reconfigure &>> "$LOG_FILE"; then
        echo "Reconfigured KWin" >> "$LOG_FILE"
    fi

    echo "Manual config update completed" >> "$LOG_FILE"
    return 0
}

# Function to set wallpaper in MATE
set_mate_wallpaper() {
    echo "Setting wallpaper for MATE..." >> "$LOG_FILE"

    if command -v gsettings &> /dev/null; then
        gsettings set org.mate.background picture-filename "$OUTPUT_WALLPAPER"
        echo "Set wallpaper using gsettings" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set MATE wallpaper: gsettings not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in GNOME
set_gnome_wallpaper() {
    echo "Setting wallpaper for GNOME..." >> "$LOG_FILE"

    if command -v gsettings &> /dev/null; then
        # For GNOME 3.x and newer
        gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
        # For GNOME 42+ which uses dark mode
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$OUTPUT_WALLPAPER"
        echo "Set wallpaper using gsettings" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set GNOME wallpaper: gsettings not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in XFCE
set_xfce_wallpaper() {
    echo "Setting wallpaper for XFCE..." >> "$LOG_FILE"

    if command -v xfconf-query &> /dev/null; then
        PROPERTY="/backdrop/screen0/monitor0/workspace0/last-image"

        # Get monitors
        MONITORS=$(xfconf-query -c xfce4-desktop -l | grep last-image | cut -d/ -f4 | sort -u)
        if [ -z "$MONITORS" ]; then
            MONITORS="monitor0"
        fi

        # Get workspaces
        for MONITOR in $MONITORS; do
            WORKSPACES=$(xfconf-query -c xfce4-desktop -l | grep $MONITOR | grep workspace | cut -d/ -f5 | sort -u)
            if [ -z "$WORKSPACES" ]; then
                WORKSPACES="workspace0"
            fi

            for WORKSPACE in $WORKSPACES; do
                PROPERTY="/backdrop/screen0/$MONITOR/$WORKSPACE/last-image"
                echo "Setting property $PROPERTY" >> "$LOG_FILE"
                xfconf-query -c xfce4-desktop -p "$PROPERTY" -s "$OUTPUT_WALLPAPER"
            done
        done

        echo "Set wallpaper using xfconf-query" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set XFCE wallpaper: xfconf-query not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in Cinnamon
set_cinnamon_wallpaper() {
    echo "Setting wallpaper for Cinnamon..." >> "$LOG_FILE"

    if command -v gsettings &> /dev/null; then
        gsettings set org.cinnamon.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
        echo "Set wallpaper using gsettings" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set Cinnamon wallpaper: gsettings not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in LXDE
set_lxde_wallpaper() {
    echo "Setting wallpaper for LXDE..." >> "$LOG_FILE"

    if command -v pcmanfm &> /dev/null; then
        pcmanfm --set-wallpaper="$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using pcmanfm" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set LXDE wallpaper: pcmanfm not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in LXQt
set_lxqt_wallpaper() {
    echo "Setting wallpaper for LXQt..." >> "$LOG_FILE"

    if command -v pcmanfm-qt &> /dev/null; then
        pcmanfm-qt --set-wallpaper="$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using pcmanfm-qt" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set LXQt wallpaper: pcmanfm-qt not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in i3/sway
set_i3_sway_wallpaper() {
    echo "Setting wallpaper for i3/Sway..." >> "$LOG_FILE"

    # Try feh (common for i3)
    if command -v feh &> /dev/null; then
        feh --bg-fill "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using feh" >> "$LOG_FILE"
        return 0
    # Try swaybg (for Sway)
    elif command -v swaybg &> /dev/null; then
        # Kill any existing swaybg process
        pkill -x swaybg 2>/dev/null || true
        # Start swaybg in the background
        swaybg -i "$OUTPUT_WALLPAPER" -m fill >> "$LOG_FILE" 2>&1 &
        echo "Set wallpaper using swaybg" >> "$LOG_FILE"
        return 0
    # Try nitrogen as a fallback
    elif command -v nitrogen &> /dev/null; then
        nitrogen --set-zoom-fill --save "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using nitrogen" >> "$LOG_FILE"
        return 0
    else
        echo "Failed to set i3/Sway wallpaper: neither feh, swaybg, nor nitrogen found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function for generic desktop environments (fallback)
set_generic_wallpaper() {
    echo "Trying generic wallpaper setters..." >> "$LOG_FILE"

    # Try various wallpaper setters
    if command -v nitrogen &> /dev/null; then
        nitrogen --set-zoom-fill --save "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using nitrogen" >> "$LOG_FILE"
        return 0
    elif command -v feh &> /dev/null; then
        feh --bg-fill "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using feh" >> "$LOG_FILE"
        return 0
    elif command -v hsetroot &> /dev/null; then
        hsetroot -fill "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using hsetroot" >> "$LOG_FILE"
        return 0
    elif command -v xwallpaper &> /dev/null; then
        xwallpaper --zoom "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using xwallpaper" >> "$LOG_FILE"
        return 0
    elif command -v gsettings &> /dev/null; then
        # Try GNOME/GTK based method
        gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        echo "Set wallpaper using gsettings" >> "$LOG_FILE"
        return 0
    fi

    echo "Failed to set wallpaper using generic methods" | tee -a "$LOG_FILE"
    return 1
}

# Set wallpaper based on detected desktop environment
success=false

case "$DESKTOP_ENV" in
    *KDE*|*PLASMA*)
        set_kde_wallpaper && success=true
        ;;
    *MATE*)
        set_mate_wallpaper && success=true
        ;;
    *GNOME*)
        set_gnome_wallpaper && success=true
        ;;
    *XFCE*)
        set_xfce_wallpaper && success=true
        ;;
    *CINNAMON*)
        set_cinnamon_wallpaper && success=true
        ;;
    *LXDE*)
        set_lxde_wallpaper && success=true
        ;;
    *LXQT*)
        set_lxqt_wallpaper && success=true
        ;;
    *I3*|*SWAY*)
        set_i3_sway_wallpaper && success=true
        ;;
    *)
        echo "Unknown desktop environment. Trying generic methods..." | tee -a "$LOG_FILE"
        set_generic_wallpaper && success=true
        ;;
esac

# If all DE-specific methods failed, try generic methods
if [ "$success" != "true" ]; then
    echo "Desktop-specific method failed. Trying generic methods..." | tee -a "$LOG_FILE"
    set_generic_wallpaper && success=true
fi

if [ "$success" = "true" ]; then
    echo "Wallpaper brightness adjusted to $BRIGHTNESS% for hour $HOUR" | tee -a "$LOG_FILE"
    echo "Wallpaper set successfully!" | tee -a "$LOG_FILE"
else
    echo "Failed to set wallpaper on your desktop environment." | tee -a "$LOG_FILE"
    echo "Please check $LOG_FILE for detailed logs."
    exit 1
fi

echo "Check $LOG_FILE for detailed logs"
