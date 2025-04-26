#!/bin/bash

# Handbrake preset JSON to ffmpeg convertion - X-Seti (Mooheda)
# Usage: ./hb-ffmpeg-conv.sh [input_json_file] [options]
# ./hbpreset.json -r [-r option will search and convert any media file(s)]
#

set -e

SCRVERS=0.8
# Default values
RECURSIVE=false
EXECUTE=false
MEDIA_EXTENSIONS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "ts")
DRY_RUN=false
SHOW_PRESET_ONLY=false
MEDIA_DIR=""
OUTPUT_DIR=""
IGNORE_FLAG=".noconvert"
FORCE_M4V=false
REPLACE_UNDERSCORES=true
FFMPEG_ANALYZEDURATION=100000000  # 100MB
FFMPEG_PROBESIZE=100000000        # 100MB
VERBOSE=false

# Function to display usage
show_usage() {
    echo "Usage: $0 [input_json_file] [options]" >&2
    echo "Options:" >&2
    echo "  -r, --recursive    Process media files recursively in subdirectories" >&2
    echo "  -e, --execute      Execute the generated ffmpeg commands" >&2
    echo "  -d, --dry-run      Show what would be done without actually doing it" >&2
    echo "  -p, --show-preset  Show only the ffmpeg equivalent of the preset" >&2
    echo "  -i, --input-dir    Specify input directory (default: same as JSON file)" >&2
    echo "  -o, --output-dir   Specify output directory (default: input_dir/converted)" >&2
    echo "  -m, --force-m4v    Force output extension to .m4v regardless of container" >&2
    echo "  -u, --no-underscore-replace  Replace underscores with spaces in output filenames" >&2
    echo "  --ignore-flag=X    Set custom ignore flag file (default: .noconvert)" >&2
    echo "  --verbose          Show verbose output and ffmpeg logs" >&2
    echo "  -v, --version      Show version: "$SCRVERS >&2
    echo "  -h, --help         Show this help message" >&2
    echo "" >&2
    echo "Special Features:" >&2
    echo "  - Files will be skipped if a '$IGNORE_FLAG' file exists in the same directory" >&2
    echo "  - Use -m/--force-m4v to output all files with .m4v extension" >&2
    echo "  - By default, underscores in filenames are replaced with spaces" >&2
    exit 1
}

# Parse command line arguments
if [ $# -lt 1 ]; then
    show_usage
fi

# First argument should be the JSON file
JSON_FILE="$1"
shift

# Check for options
while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--recursive) RECURSIVE=true ;;
        -e|--execute) EXECUTE=true ;;
        -d|--dry-run) DRY_RUN=true ;;
        -p|--show-preset) SHOW_PRESET_ONLY=true ;;
        -m|--force-m4v) FORCE_M4V=true ;;
        -u|--no-underscore-replace) REPLACE_UNDERSCORES=false ;;
        --verbose) VERBOSE=true ;;
        -i|--input-dir)
            shift
            MEDIA_DIR="$1" ;;
        -o|--output-dir)
            shift
            OUTPUT_DIR="$1" ;;
        --ignore-flag=*)
            IGNORE_FLAG="${1#*=}" ;;
        -v|--version) VERSION=true ;;
        -h|--help) show_usage ;;
        *) echo "Unknown option: $1" >&2; show_usage ;;
    esac
    shift
done

if [ "$VERSION" = "true" ]; then
    echo "Script Version=$SCRVERS"
    exit 0
fi

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: JSON file '$JSON_FILE' does not exist." >&2
    exit 1
fi

# Set default directory paths if not specified
if [ -z "$MEDIA_DIR" ]; then
    MEDIA_DIR=$(dirname "$(realpath "$JSON_FILE")")
    echo "Using media directory: $MEDIA_DIR"
fi

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$MEDIA_DIR/converted"
    echo "Using output directory: $OUTPUT_DIR"
fi

# Make sure output directory doesn't contain duplicate "converted" subdirectories
OUTPUT_DIR=$(echo "$OUTPUT_DIR" | sed 's|/converted/converted|/converted|g')

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq." >&2
    exit 1
fi

# Extract relevant settings from JSON
PRESET_NAME=$(jq -r '.PresetList[0].PresetName' "$JSON_FILE")
VIDEO_ENCODER=$(jq -r '.PresetList[0].VideoEncoder' "$JSON_FILE")
VIDEO_BITRATE=$(jq -r '.PresetList[0].VideoAvgBitrate' "$JSON_FILE")
VIDEO_PRESET=$(jq -r '.PresetList[0].VideoPreset' "$JSON_FILE")
VIDEO_PROFILE=$(jq -r '.PresetList[0].VideoProfile' "$JSON_FILE")
VIDEO_FRAMERATE=$(jq -r '.PresetList[0].VideoFramerate' "$JSON_FILE")
VIDEO_QUALITY=$(jq -r '.PresetList[0].VideoQualitySlider' "$JSON_FILE")
VIDEO_QUALITY_TYPE=$(jq -r '.PresetList[0].VideoQualityType' "$JSON_FILE")
VIDEO_MULTIPASS=$(jq -r '.PresetList[0].VideoMultiPass' "$JSON_FILE" 2>/dev/null || echo "false")
PICTURE_WIDTH=$(jq -r '.PresetList[0].PictureWidth' "$JSON_FILE")
PICTURE_HEIGHT=$(jq -r '.PresetList[0].PictureHeight' "$JSON_FILE")
AUDIO_ENCODER=$(jq -r '.PresetList[0].AudioList[0].AudioEncoder' "$JSON_FILE")
AUDIO_BITRATE=$(jq -r '.PresetList[0].AudioList[0].AudioBitrate' "$JSON_FILE")
AUDIO_MIXDOWN=$(jq -r '.PresetList[0].AudioList[0].AudioMixdown' "$JSON_FILE")
CONTAINER=$(jq -r '.PresetList[0].FileFormat' "$JSON_FILE")

# Convert video encoder name
if [ "$VIDEO_ENCODER" = "x265" ]; then
    FFMPEG_VCODEC="libx265"
elif [ "$VIDEO_ENCODER" = "x264" ]; then
    FFMPEG_VCODEC="libx264"
else
    FFMPEG_VCODEC="$VIDEO_ENCODER"
fi

# Convert audio encoder name
if [[ "$AUDIO_ENCODER" == "copy:"* ]]; then
    AUDIO_CODEC=$(echo "$AUDIO_ENCODER" | cut -d':' -f2)
    FFMPEG_ACODEC="-c:a copy"
else
    FFMPEG_ACODEC="-c:a aac -b:a ${AUDIO_BITRATE}k"
fi

# Handle audio mixdown
if [ "$AUDIO_MIXDOWN" = "5point1" ]; then
    FFMPEG_AUDIO_CHANNELS="-ac 6"
elif [ "$AUDIO_MIXDOWN" = "stereo" ]; then
    FFMPEG_AUDIO_CHANNELS="-ac 2"
elif [ "$AUDIO_MIXDOWN" = "mono" ]; then
    FFMPEG_AUDIO_CHANNELS="-ac 1"
else
    FFMPEG_AUDIO_CHANNELS=""
fi

# Video quality settings
if [ "$VIDEO_QUALITY_TYPE" = "2" ]; then
    # Convert Handbrake CRF value to ffmpeg
    FFMPEG_QUALITY="-crf $VIDEO_QUALITY"
else
    FFMPEG_QUALITY="-b:v ${VIDEO_BITRATE}k"
fi

# Convert container format
if [ "$CONTAINER" = "av_mkv" ]; then
    OUTPUT_FORMAT="mkv"
elif [ "$CONTAINER" = "av_mp4" ]; then
    OUTPUT_FORMAT="mp4"
else
    OUTPUT_FORMAT="mkv"  # Default to MKV
fi

# Store original format before potentially overriding with force-m4v
ORIGINAL_FORMAT="$OUTPUT_FORMAT"

# Override output format if force m4v is enabled (we'll handle this specially now)
if [ "$FORCE_M4V" = "true" ] && [ "$EXECUTE" = "true" ]; then
    echo "Force m4v is enabled. Files will be converted to $ORIGINAL_FORMAT first, then renamed to .m4v"
elif [ "$FORCE_M4V" = "true" ]; then
    OUTPUT_FORMAT="m4v"
    echo "Forcing output extension to .m4v"
fi

# Function to show the preset's FFmpeg equivalent
show_preset() {
    echo "============================================"
    echo "Handbrake Preset: $PRESET_NAME"
    echo "FFmpeg Equivalent Parameters:"
    echo "============================================"
    echo "Video codec:      -c:v $FFMPEG_VCODEC"
    echo "Quality:          $FFMPEG_QUALITY"
    echo "Preset:           -preset $VIDEO_PRESET"

    if [ "$VIDEO_FRAMERATE" != "auto" ] && [ -n "$VIDEO_FRAMERATE" ]; then
        echo "Framerate:        -r $VIDEO_FRAMERATE"
    fi

    echo "Resolution:       -s ${PICTURE_WIDTH}x${PICTURE_HEIGHT}"
    echo "Audio:            $FFMPEG_ACODEC $FFMPEG_AUDIO_CHANNELS"

    if [ "$VIDEO_PROFILE" != "auto" ] && [ -n "$VIDEO_PROFILE" ]; then
        echo "Profile:          -profile:v $VIDEO_PROFILE"
    fi

    echo "Output format:    $OUTPUT_FORMAT"

    if [ "$VIDEO_MULTIPASS" = "true" ] && [ "$VIDEO_QUALITY_TYPE" != "2" ]; then
        echo "Multipass:        Enabled (two-pass encoding)"
    else
        echo "Multipass:        Disabled (single-pass encoding)"
    fi
    echo "Analyze duration: $FFMPEG_ANALYZEDURATION"
    echo "Probe size:       $FFMPEG_PROBESIZE"
    echo "============================================"
    echo "Example usage:"
    echo "ffmpeg -analyzeduration $FFMPEG_ANALYZEDURATION -probesize $FFMPEG_PROBESIZE -i input.mp4 -c:v $FFMPEG_VCODEC $FFMPEG_QUALITY -preset $VIDEO_PRESET -s ${PICTURE_WIDTH}x${PICTURE_HEIGHT} $FFMPEG_ACODEC $FFMPEG_AUDIO_CHANNELS output.$OUTPUT_FORMAT"
    echo "============================================"
}

# Show preset only if requested
if [ "$SHOW_PRESET_ONLY" = "true" ]; then
    show_preset
    exit 0
fi

# Create output directory if it doesn't exist and not in dry run mode
if [ ! -d "$OUTPUT_DIR" ] && [ "$DRY_RUN" = "false" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Function to check if a file should be ignored
should_ignore_file() {
    local dir_path=$(dirname "$1")
    if [ -f "$dir_path/$IGNORE_FLAG" ]; then
        return 0  # True, should ignore
    fi
    return 1  # False, should not ignore
}

# Function to format filename (replace underscores with spaces if enabled)
format_filename() {
    local basename="$1"
    if [ "$REPLACE_UNDERSCORES" = "true" ]; then
        basename="${basename//_/ }"
    fi
    echo "$basename"
}

# Function to check if a file exists and is writable
check_file_access() {
    local file_path="$1"
    local dir_path=$(dirname "$file_path")

    if [ ! -d "$dir_path" ]; then
        echo "Error: Output directory '$dir_path' does not exist."
        return 1
    fi

    if [ -f "$file_path" ] && [ ! -w "$file_path" ]; then
        echo "Error: Output file '$file_path' exists but is not writable."
        return 1
    fi

    if [ ! -w "$dir_path" ]; then
        echo "Error: Output directory '$dir_path' is not writable."
        return 1
    fi

    return 0
}

# Function to safely handle paths and filenames with spaces and special characters
build_ffmpeg_command() {
    local input_file="$1"
    local output_file="$2"

    # Base command with proper escaping and extended analysis parameters
    local cmd="ffmpeg -analyzeduration $FFMPEG_ANALYZEDURATION -probesize $FFMPEG_PROBESIZE -i \"$input_file\" -c:v $FFMPEG_VCODEC $FFMPEG_QUALITY -preset $VIDEO_PRESET"

    # Add framerate if specified
    if [ "$VIDEO_FRAMERATE" != "auto" ] && [ -n "$VIDEO_FRAMERATE" ]; then
        cmd="$cmd -r $VIDEO_FRAMERATE"
    fi

    # Add resolution
    cmd="$cmd -s ${PICTURE_WIDTH}x${PICTURE_HEIGHT}"

    # Add audio settings
    cmd="$cmd $FFMPEG_ACODEC $FFMPEG_AUDIO_CHANNELS"

    # Add profile if specified
    if [ "$VIDEO_PROFILE" != "auto" ] && [ -n "$VIDEO_PROFILE" ]; then
        cmd="$cmd -profile:v $VIDEO_PROFILE"
    fi

    # Add verbosity level
    if [ "$VERBOSE" = "false" ]; then
        cmd="$cmd -v error -stats"
    fi

    # Always copy all streams from input
    cmd="$cmd -map 0"

    # Add multipass settings
    if [ "$VIDEO_MULTIPASS" = "true" ] && [ "$VIDEO_QUALITY_TYPE" != "2" ]; then
        # First pass
        local pass1="$cmd -pass 1 -f null /dev/null"
        # Second pass
        local pass2="$cmd -pass 2 \"$output_file\""

        # Combine commands
        cmd="$pass1 && $pass2"
    else
        cmd="$cmd \"$output_file\""
    fi

    echo "$cmd"
}

# Function to rename a file from original format to m4v
rename_to_m4v() {
    local file_path="$1"
    local m4v_path="${file_path%.*}.m4v"

    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would rename $file_path to $m4v_path"
    else
        echo "Renaming $file_path to $m4v_path"
        if [ -f "$file_path" ]; then
            mv "$file_path" "$m4v_path"
            if [ $? -ne 0 ]; then
                echo "Error renaming file to .m4v"
                return 1
            fi
        else
            echo "Error: File $file_path not found for renaming"
            return 1
        fi
    fi
    return 0
}

# Function to get file information
get_file_info() {
    local file_path="$1"
    echo "File information for $file_path:"
    ffprobe -hide_banner -v error -show_format -show_streams "$file_path"
}

# Function to process a media file
process_file() {
    local input_file="$1"
    local rel_path="${input_file#$MEDIA_DIR/}"

    # Ensure output subdirectory path is properly constructed
    local output_subdir="$OUTPUT_DIR"
    local dir_part=$(dirname "$rel_path")

    if [ "$dir_part" != "." ]; then
        output_subdir="$OUTPUT_DIR/$dir_part"
    fi

    local filename=$(basename "$input_file")
    local basename="${filename%.*}"

    # Format basename (replace underscores with spaces if enabled)
    local formatted_basename=$(format_filename "$basename")

    # Determine the correct output format for initial conversion
    local actual_format="$OUTPUT_FORMAT"
    if [ "$FORCE_M4V" = "true" ] && [ "$EXECUTE" = "true" ]; then
        # When executing with force_m4v, use original format first
        actual_format="$ORIGINAL_FORMAT"
    fi

    local output_file="$output_subdir/$formatted_basename.$actual_format"

    # Skip processing the JSON file itself
    if [ "$input_file" = "$(realpath "$JSON_FILE")" ]; then
        return
    fi

    # Check if file should be ignored
    if should_ignore_file "$input_file"; then
        echo "Skipping: $input_file (ignore flag found)"
        return
    fi

    # Create output subdirectory if needed
    if [ ! -d "$output_subdir" ]; then
        if [ "$DRY_RUN" = "false" ]; then
            echo "Creating output directory: $output_subdir"
            mkdir -p "$output_subdir"
            if [ $? -ne 0 ]; then
                echo "Error creating directory: $output_subdir"
                return 1
            fi
        else
            echo "[DRY RUN] Would create directory: $output_subdir"
        fi
    fi

    # Check if output file location is valid and writable
    if [ "$DRY_RUN" = "false" ] && [ "$EXECUTE" = "true" ]; then
        check_file_access "$output_file"
        if [ $? -ne 0 ]; then
            echo "Skipping $input_file due to output file access issues."
            return 1
        fi
    fi

    # Build ffmpeg command
    local ffmpeg_cmd=$(build_ffmpeg_command "$input_file" "$output_file")

    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would execute:"
        echo "$ffmpeg_cmd"
        if [ "$FORCE_M4V" = "true" ]; then
            echo "[DRY RUN] Would rename $output_file to ${output_file%.*}.m4v"
        fi
    elif [ "$EXECUTE" = "true" ]; then
        echo "Processing: $input_file"
        echo "Output: $output_file"
        echo "Command: $ffmpeg_cmd"

        # Execute ffmpeg and capture exit status
        set +e  # Temporarily disable exit on error
        eval "$ffmpeg_cmd"
        local ffmpeg_status=$?
        set -e  # Re-enable exit on error

        if [ $ffmpeg_status -ne 0 ]; then
            echo "Error: FFmpeg command failed with status $ffmpeg_status"
            echo "Checking input file..."
            get_file_info "$input_file"
            return 1
        else
            echo "Conversion successful"

            # If successful and force_m4v is enabled, rename to .m4v
            if [ "$FORCE_M4V" = "true" ]; then
                rename_to_m4v "$output_file"
                if [ $? -ne 0 ]; then
                    echo "Warning: Failed to rename file to .m4v"
                fi
            fi
        fi
    else
        echo "Generated command for $input_file:"
        echo "$ffmpeg_cmd"
        if [ "$FORCE_M4V" = "true" ]; then
            echo "Note: If executed, the file will be converted to $actual_format then renamed to .m4v"
        fi
    fi
}

# Function to safely find media files with proper handling of spaces and special characters
find_media_files() {
    local directory="$1"
    local recursive="$2"
    local result=()
    local max_depth=""

    if [ "$recursive" = "false" ]; then
        max_depth="-maxdepth 1"
    fi

    # Build the find command with proper handling of file extensions
    local find_cmd="find \"$directory\" $max_depth -type f \( "
    local first=true

    for ext in "${MEDIA_EXTENSIONS[@]}"; do
        if [ "$first" = "true" ]; then
            find_cmd="$find_cmd -name \"*.$ext\""
            first=false
        else
            find_cmd="$find_cmd -o -name \"*.$ext\""
        fi
    done

    find_cmd="$find_cmd \) -print0"

    # Use a null-delimiter to handle filenames with spaces and special characters
    while IFS= read -r -d $'\0' file; do
        echo "$file"
    done < <(eval "$find_cmd")
}

# Find and process media files
echo "Searching for media files in $MEDIA_DIR"
echo "Files with the '$IGNORE_FLAG' file in their directory will be skipped"
echo "Output directory set to: $OUTPUT_DIR"
echo "Using analyzeduration: $FFMPEG_ANALYZEDURATION, probesize: $FFMPEG_PROBESIZE"

if [ "$REPLACE_UNDERSCORES" = "true" ]; then
    echo "Underscores in filenames will be replaced with spaces in output files"
else
    echo "Output filenames will maintain the same format as input filenames"
fi

if [ "$RECURSIVE" = "true" ]; then
    echo "Recursive search enabled"
else
    echo "Non-recursive search"
fi

if [ "$VERBOSE" = "true" ]; then
    echo "Verbose output enabled"
fi

# Process each file
file_count=0
skipped_count=0
error_count=0

# Use null-delimiter to safely handle filenames with spaces and special characters
while IFS= read -r file; do
    process_status=0  # Initialize the variable outside the function scope
    if should_ignore_file "$file"; then
        echo "Skipping: $file (ignore flag found)"
        skipped_count=$((skipped_count + 1))
    else
        set +e  # Temporarily disable exit on error
        process_file "$file"
        process_status=$?  # Capture return status without 'local'
        set -e  # Re-enable exit on error

        if [ $process_status -eq 0 ]; then
            file_count=$((file_count + 1))
        else
            error_count=$((error_count + 1))
            echo "Failed to process: $file"
        fi
    fi
done < <(find_media_files "$MEDIA_DIR" "$RECURSIVE")

echo "Processing complete:"
echo "  - Successfully processed: $file_count files"
echo "  - Skipped: $skipped_count files"
echo "  - Failed: $error_count files"

if [ "$file_count" -eq 0 ] && [ "$skipped_count" -eq 0 ] && [ "$error_count" -eq 0 ]; then
    echo "No media files found in the specified directory."
fi

# Return non-zero status if errors occurred
if [ "$error_count" -gt 0 ]; then
    echo "Warning: Some files failed to process. Check output for details."
    # Don't exit with error to allow processing to continue
    # exit 1
fi
