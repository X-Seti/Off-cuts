#!/bin/bash
#Better wallpaper, night time and weather wallpaper changer - X-Seti
set -e
set -o pipefail

# Configuration
WALLPAPER_DIR="${HOME}/Wallpaper/System-Defaults"
OUTPUT_DIR="${HOME}/Wallpaper/System-Defaults"
OUTPUT_WALLPAPER="${OUTPUT_DIR}/current-wallpaper.jpg"
LOG_FILE="/tmp/system-theme-change.log"

echo "Starting system theme adjustment at $(date)" > "$LOG_FILE"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Get current hour (24-hour format)
HOUR=$(date +%H)
echo "Current hour: $HOUR" >> "$LOG_FILE"

# Get wallpaper for current hour
get_hourly_wallpaper() {
    # First try to find an exact hour match
    HOURLY_WALLPAPER="${WALLPAPER_DIR}/wallpaper-${HOUR}.jpg"
    
    # Check for variations of file extensions
    if [ ! -f "$HOURLY_WALLPAPER" ]; then
        HOURLY_WALLPAPER="${WALLPAPER_DIR}/wallpaper-${HOUR}.png"
    fi
    
    if [ ! -f "$HOURLY_WALLPAPER" ]; then
        HOURLY_WALLPAPER="${WALLPAPER_DIR}/wallpaper-${HOUR}.jpeg"
    fi
    
    # If no exact match, use a fallback wallpaper
    if [ ! -f "$HOURLY_WALLPAPER" ]; then
        # Try to find any wallpaper in the directory
        FALLBACK=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | sort | head -n 1)
        
        if [ -n "$FALLBACK" ]; then
            HOURLY_WALLPAPER="$FALLBACK"
        else
            echo "ERROR: No wallpapers found in $WALLPAPER_DIR" | tee -a "$LOG_FILE"
            exit 1
        fi
    fi
    
    echo "$HOURLY_WALLPAPER"
}

# Define brightness levels, color temperature, and time periods
declare -A brightness_levels
brightness_levels[0]=30   # 12am - darkest
brightness_levels[1]=30
brightness_levels[2]=35
brightness_levels[3]=40
brightness_levels[4]=45
brightness_levels[5]=50
brightness_levels[6]=60   # 6am - starting to get lighter
brightness_levels[7]=70
brightness_levels[8]=80
brightness_levels[9]=90
brightness_levels[10]=95
brightness_levels[11]=100
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
brightness_levels[22]=35
brightness_levels[23]=30

# Define time periods for theming
is_daytime() {
    if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 19 ]; then
        return 0  # True - it's daytime (7am-7pm)
    else
        return 1  # False - it's nighttime
    fi
}

# Define color temperature levels (for blue light reduction)
get_color_temp() {
    if [ "$HOUR" -ge 19 ] || [ "$HOUR" -lt 6 ]; then
        echo "93"  # Significant blue reduction
    elif [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 8 ]; then
        echo "97"  # Slight blue reduction
    elif [ "$HOUR" -ge 17 ] && [ "$HOUR" -lt 19 ]; then
        echo "97"  # Slight blue reduction
    else
        echo "100"  # No color temperature adjustment
    fi
}

# Get theme settings based on time
get_theme_settings() {
    if is_daytime; then
        echo "light:#1e88e5"  # Light theme with blue accent
    else
        echo "dark:#ff7043"   # Dark theme with orange accent
    fi
}

# Get the selected wallpaper for the current hour
HOURLY_WALLPAPER=$(get_hourly_wallpaper)
echo "Selected wallpaper: $HOURLY_WALLPAPER" >> "$LOG_FILE"

# Get the brightness level for the current hour
BRIGHTNESS=${brightness_levels[$HOUR]}
# Get the color temperature (hue adjustment)
COLOR_TEMP=$(get_color_temp)
# Get theme settings
THEME_SETTINGS=$(get_theme_settings)
THEME_MODE=$(echo $THEME_SETTINGS | cut -d':' -f1)
ACCENT_COLOR=$(echo $THEME_SETTINGS | cut -d':' -f2)

echo "Selected brightness: $BRIGHTNESS%" >> "$LOG_FILE"
echo "Selected color temperature: $COLOR_TEMP%" >> "$LOG_FILE"
echo "Theme mode: $THEME_MODE" >> "$LOG_FILE"
echo "Accent color: $ACCENT_COLOR" >> "$LOG_FILE"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ERROR: ImageMagick not installed. Please install it with your package manager:" | tee -a "$LOG_FILE"
    echo "  - Debian/Ubuntu: sudo apt install imagemagick" | tee -a "$LOG_FILE"
    echo "  - Fedora: sudo dnf install imagemagick" | tee -a "$LOG_FILE"
    echo "  - Arch: sudo pacman -S imagemagick" | tee -a "$LOG_FILE"
    exit 1
fi

# Use ImageMagick to adjust the brightness and color temperature
echo "Creating adjusted wallpaper..." >> "$LOG_FILE"
convert "$HOURLY_WALLPAPER" -modulate $BRIGHTNESS,100,$COLOR_TEMP "$OUTPUT_WALLPAPER" 2>> "$LOG_FILE"

# Check if the adjusted wallpaper was created successfully
if [ ! -f "$OUTPUT_WALLPAPER" ]; then
    echo "ERROR: Failed to create adjusted wallpaper" | tee -a "$LOG_FILE"
    exit 1
else
    echo "Adjusted wallpaper created successfully at $OUTPUT_WALLPAPER" >> "$LOG_FILE"
fi

# Weather effect (new feature)
apply_weather_effect() {
    # Check if we can get weather data
    if command -v curl &> /dev/null; then
        echo "Checking for weather conditions..." >> "$LOG_FILE"
        
        # Try to get weather data - using wttr.in for simple text-based weather
        WEATHER_DATA=$(curl -s "wttr.in/?format=%C" 2>/dev/null || echo "Unknown")
        echo "Current weather: $WEATHER_DATA" >> "$LOG_FILE"
        
        # Apply effects based on weather
        case "$WEATHER_DATA" in
            *[Rr]ain*|*[Dd]rizzle*|*[Ss]hower*)
                echo "Applying rain effect..." >> "$LOG_FILE"
                # Add rain droplet effect
                convert "$OUTPUT_WALLPAPER" \
                    \( -size 200x200 -fill white -draw "circle 100,100 100,90" -blur 0x3 -level 0%,50% \) \
                    -gravity northwest -compose screen -composite \
                    \( -size 200x200 -fill white -draw "circle 150,150 150,140" -blur 0x2 -level 0%,50% \) \
                    -gravity northeast -compose screen -composite \
                    \( -size 200x200 -fill white -draw "circle 180,120 180,110" -blur 0x3 -level 0%,40% \) \
                    -gravity southeast -compose screen -composite \
                    \( -size 200x200 -fill white -draw "circle 120,180 120,170" -blur 0x2 -level 0%,40% \) \
                    -gravity southwest -compose screen -composite \
                    -fill "#0000003f" -colorize 10% \
                    "$OUTPUT_WALLPAPER"
                ;;
            *[Ss]now*)
                echo "Applying snow effect..." >> "$LOG_FILE"
                # Add snow effect
                convert "$OUTPUT_WALLPAPER" \
                    \( -size 400x400 -fill white -draw "point 100,100 point 200,200 point 300,150 point 250,300 point 150,250 point 350,350 point 120,310 point 280,120 point 50,180 point 330,80 point 170,40 point 390,220" -blur 0x1 \) \
                    -gravity center -compose screen -composite \
                    -brightness-contrast 5x5 \
                    "$OUTPUT_WALLPAPER"
                ;;
            *[Cc]loud*|*[Oo]vercast*)
                echo "Applying cloudy effect..." >> "$LOG_FILE"
                # Add cloudy effect - slightly desaturate and add vignette
                convert "$OUTPUT_WALLPAPER" \
                    -modulate 100,90,100 \
                    \( +clone -fill "#00000025" -colorize 100% -draw "circle 50%,50% 0,50%" -blur 0x30 \) \
                    -compose multiply -composite \
                    "$OUTPUT_WALLPAPER"
                ;;
            *[Cc]lear*|*[Ss]unny*)
                echo "Applying sunny effect..." >> "$LOG_FILE"
                # Add sunny effect - increase saturation and add sun flare
                convert "$OUTPUT_WALLPAPER" \
                    -modulate 100,110,100 \
                    \( -size 400x400 -fill "#ffffff60" -draw "circle 200,200 200,100" -blur 0x30 \) \
                    -gravity northeast -compose screen -composite \
                    "$OUTPUT_WALLPAPER"
                ;;
            *[Ff]og*|*[Mm]ist*)
                echo "Applying foggy effect..." >> "$LOG_FILE"
                # Add fog effect - overlay white transparent layer and reduce contrast
                convert "$OUTPUT_WALLPAPER" \
                    \( -clone 0 -fill white -colorize 30% -blur 0x2 \) \
                    -compose overlay -composite \
                    -brightness-contrast 0x-10 \
                    "$OUTPUT_WALLPAPER"
                ;;
        esac
    else
        echo "Weather effects skipped - curl not installed" >> "$LOG_FILE"
    fi
}

# Apply weather effect if the user has enabled it
APPLY_WEATHER=true  # Set to false to disable weather effects
if [ "$APPLY_WEATHER" = true ]; then
    apply_weather_effect
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

# Function to set theme in KDE Plasma
set_kde_theme() {
    echo "Setting theme for KDE Plasma..." >> "$LOG_FILE"

    if [ "$THEME_MODE" = "dark" ]; then
        PLASMA_THEME="breeze-dark"
        COLOR_SCHEME="BreezeDark"
    else
        PLASMA_THEME="breeze-light"
        COLOR_SCHEME="BreezeLight"
    fi

    if command -v lookandfeeltool &> /dev/null; then
        if [ "$THEME_MODE" = "dark" ]; then
            lookandfeeltool -a org.kde.breezedark.desktop >> "$LOG_FILE" 2>&1
        else
            lookandfeeltool -a org.kde.breeze.desktop >> "$LOG_FILE" 2>&1
        fi
    fi

    if command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file kdeglobals --group General --key ColorScheme "$COLOR_SCHEME"
        kwriteconfig5 --file kdeglobals --group General --key AccentColor "$ACCENT_COLOR"
    elif command -v kwriteconfig6 &> /dev/null; then
        kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$COLOR_SCHEME"
        kwriteconfig6 --file kdeglobals --group General --key AccentColor "$ACCENT_COLOR"
    fi

    if command -v qdbus &> /dev/null; then
        qdbus org.kde.KWin /KWin reconfigure >> "$LOG_FILE" 2>&1
        qdbus org.kde.plasmashell /PlasmaShell refreshCurrentDesktop >> "$LOG_FILE" 2>&1
    fi

    return 0
}

# Function to set theme in GNOME
set_gnome_theme() {
    echo "Setting theme for GNOME..." >> "$LOG_FILE"

    if command -v gsettings &> /dev/null; then
        if [ "$THEME_MODE" = "dark" ]; then
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
            gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
        else
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
            gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
        fi

        if gsettings list-keys org.gnome.desktop.interface | grep -q 'accent-color'; then
            GNOME_ACCENT="${ACCENT_COLOR/#\#/}"
            gsettings set org.gnome.desktop.interface accent-color "'$GNOME_ACCENT'"
        fi

        return 0
    else
        echo "Failed to set GNOME theme: gsettings not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set theme in XFCE
set_xfce_theme() {
    echo "Setting theme for XFCE..." >> "$LOG_FILE"

    if command -v xfconf-query &> /dev/null; then
        if [ "$THEME_MODE" = "dark" ]; then
            xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
            xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita-dark"
        else
            xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita"
            xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita"
        fi
        return 0
    else
        echo "Failed to set XFCE theme: xfconf-query not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set theme in Cinnamon
set_cinnamon_theme() {
    echo "Setting theme for Cinnamon..." >> "$LOG_FILE"

    if command -v gsettings &> /dev/null; then
        if [ "$THEME_MODE" = "dark" ]; then
            gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y-Dark'
            gsettings set org.cinnamon.desktop.wm.preferences theme 'Mint-Y-Dark'
            gsettings set org.cinnamon.theme name 'Mint-Y-Dark'
        else
            gsettings set org.cinnamon.desktop.interface gtk-theme 'Mint-Y'
            gsettings set org.cinnamon.desktop.wm.preferences theme 'Mint-Y'
            gsettings set org.cinnamon.theme name 'Mint-Y'
        fi
        return 0
    else
        echo "Failed to set Cinnamon theme: gsettings not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in KDE Plasma (works for both 5 and 6)
set_kde_wallpaper() {
    echo "Setting wallpaper for KDE Plasma..." >> "$LOG_FILE"

    if qdbus org.kde.plasmashell /PlasmaShell &>/dev/null; then
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
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat $JS_FILE)" >> "$LOG_FILE" 2>&1
        KDE_SUCCESS=$?

        if [ $KDE_SUCCESS -eq 0 ]; then
            return 0
        fi
    fi

    if command -v plasma-apply-wallpaperimage &> /dev/null; then
        plasma-apply-wallpaperimage "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi

    PLASMA_VERSION=$(plasmashell --version 2>/dev/null | grep -oP 'plasmashell \K[0-9]+' || echo "5")
    
    if [ "$PLASMA_VERSION" -ge "6" ]; then
        CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    else
        CONFIG_FILE="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    fi

    CONTAINMENTS=$(grep -l "lastScreen" "$CONFIG_FILE" | grep "Containments" | grep -o '[0-9]\+' | sort -u || echo "1")

    for CONTAINMENT in $CONTAINMENTS; do
        if command -v kwriteconfig5 &> /dev/null; then
            kwriteconfig5 --file "$CONFIG_FILE" --group "Containments" --group "$CONTAINMENT" --group "Wallpaper" --group "org.kde.image" --group "General" --key "Image" "file://$OUTPUT_WALLPAPER"
        elif command -v kwriteconfig6 &> /dev/null; then
            kwriteconfig6 --file "$CONFIG_FILE" --group "Containments" --group "$CONTAINMENT" --group "Wallpaper" --group "org.kde.image" --group "General" --key "Image" "file://$OUTPUT_WALLPAPER"
        else
            sed -i "s|Image=file://.*|Image=file://$OUTPUT_WALLPAPER|g" "$CONFIG_FILE"
        fi
    done

    if qdbus org.kde.plasmashell /PlasmaShell refreshCurrentDesktop &>> "$LOG_FILE"; then
        echo "Refreshed desktop configuration" >> "$LOG_FILE"
    fi

    if qdbus org.kde.KWin /KWin reconfigure &>> "$LOG_FILE"; then
        echo "Reconfigured KWin" >> "$LOG_FILE"
    fi

    return 0
}

# Function to set wallpaper in MATE
set_mate_wallpaper() {
    echo "Setting wallpaper for MATE..." >> "$LOG_FILE"

    if command -v gsettings &> /dev/null; then
        gsettings set org.mate.background picture-filename "$OUTPUT_WALLPAPER"
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
        gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$OUTPUT_WALLPAPER"
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

        MONITORS=$(xfconf-query -c xfce4-desktop -l | grep last-image | cut -d/ -f4 | sort -u)
        if [ -z "$MONITORS" ]; then
            MONITORS="monitor0"
        fi

        for MONITOR in $MONITORS; do
            WORKSPACES=$(xfconf-query -c xfce4-desktop -l | grep $MONITOR | grep workspace | cut -d/ -f5 | sort -u)
            if [ -z "$WORKSPACES" ]; then
                WORKSPACES="workspace0"
            fi

            for WORKSPACE in $WORKSPACES; do
                PROPERTY="/backdrop/screen0/$MONITOR/$WORKSPACE/last-image"
                xfconf-query -c xfce4-desktop -p "$PROPERTY" -s "$OUTPUT_WALLPAPER"
            done
        done

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
        return 0
    else
        echo "Failed to set LXQt wallpaper: pcmanfm-qt not found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to set wallpaper in i3/sway
set_i3_sway_wallpaper() {
    echo "Setting wallpaper for i3/Sway..." >> "$LOG_FILE"

    if command -v feh &> /dev/null; then
        feh --bg-fill "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    elif command -v swaybg &> /dev/null; then
        pkill -x swaybg 2>/dev/null || true
        swaybg -i "$OUTPUT_WALLPAPER" -m fill >> "$LOG_FILE" 2>&1 &
        return 0
    elif command -v nitrogen &> /dev/null; then
        nitrogen --set-zoom-fill --save "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    else
        echo "Failed to set i3/Sway wallpaper: neither feh, swaybg, nor nitrogen found" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function for generic desktop environments (fallback)
set_generic_wallpaper() {
    echo "Trying generic wallpaper setters..." >> "$LOG_FILE"

    if command -v nitrogen &> /dev/null; then
        nitrogen --set-zoom-fill --save "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    elif command -v feh &> /dev/null; then
        feh --bg-fill "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    elif command -v hsetroot &> /dev/null; then
        hsetroot -fill "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    elif command -v xwallpaper &> /dev/null; then
        xwallpaper --zoom "$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    elif command -v gsettings &> /dev/null; then
        gsettings set org.gnome.desktop.background picture-uri "file://$OUTPUT_WALLPAPER" >> "$LOG_FILE" 2>&1
        return 0
    fi

    echo "Failed to set wallpaper using generic methods" | tee -a "$LOG_FILE"
    return 1
}

# Apply wallpaper based on detected desktop environment
wallpaper_success=false

case "$DESKTOP_ENV" in
    *KDE*|*PLASMA*)
        set_kde_wallpaper && wallpaper_success=true
        ;;
    *MATE*)
        set_mate_wallpaper && wallpaper_success=true
        ;;
    *GNOME*)
        set_gnome_wallpaper && wallpaper_success=true
        ;;
    *XFCE*)
        set_xfce_wallpaper && wallpaper_success=true
        ;;
    *CINNAMON*)
        set_cinnamon_wallpaper && wallpaper_success=true
        ;;
    *LXDE*)
        set_lxde_wallpaper && wallpaper_success=true
        ;;
    *LXQT*)
        set_lxqt_wallpaper && wallpaper_success=true
        ;;
    *I3*|*SWAY*)
        set_i3_sway_wallpaper && wallpaper_success=true
        ;;
    *)
        echo "Unknown desktop environment. Trying generic wallpaper methods..." | tee -a "$LOG_FILE"
        set_generic_wallpaper && wallpaper_success=true
        ;;
esac

# If all DE-specific methods failed, try generic methods
if [ "$wallpaper_success" != "true" ]; then
    echo "Desktop-specific wallpaper method failed. Trying generic methods..." | tee -a "$LOG_FILE"
    set_generic_wallpaper && wallpaper_success=true
fi

# Apply theme based on detected desktop environment
theme_success=false

case "$DESKTOP_ENV" in
    *KDE*|*PLASMA*)
        set_kde_theme && theme_success=true
        ;;
    *GNOME*)
        set_gnome_theme && theme_success=true
        ;;
    *XFCE*)
        set_xfce_theme && theme_success=true
        ;;
    *CINNAMON*)
        set_cinnamon_theme && theme_success=true
        ;;
    *)
        echo "Theme switching not implemented for $DESKTOP_ENV" | tee -a "$LOG_FILE"
        theme_success=false
        ;;
esac

# Report success
echo "Summary of changes:" | tee -a "$LOG_FILE"
echo "-------------------" | tee -a "$LOG_FILE"

if [ "$wallpaper_success" = "true" ]; then
    echo "✓ Wallpaper for hour $HOUR applied: $(basename "$HOURLY_WALLPAPER")" | tee -a "$LOG_FILE"
    echo "✓ Brightness adjusted to $BRIGHTNESS%" | tee -a "$LOG_FILE"
    echo "✓ Blue light reduction set to $COLOR_TEMP%" | tee -a "$LOG_FILE"
    if [ "$APPLY_WEATHER" = true ]; then
        echo "✓ Weather effects applied based on current conditions" | tee -a "$LOG_FILE"
    fi
else
    echo "✗ Failed to set wallpaper on your desktop environment" | tee -a "$LOG_FILE"
fi

if [ "$theme_success" = "true" ]; then
    echo "✓ System theme set to $THEME_MODE mode with $ACCENT_COLOR accent" | tee -a "$LOG_FILE"
else
    echo "✗ Theme switching not supported for your desktop environment" | tee -a "$LOG_FILE"
fi

echo "Check $LOG_FILE for detailed logs"
