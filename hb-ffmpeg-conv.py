#!/usr/bin/env python3

import os
import sys
import json
import argparse
import subprocess
import shutil
import platform
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional

# Script version
SCRIPT_VERSION = "0.8"

# Default media extensions
MEDIA_EXTENSIONS = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "ts"]


def show_usage():
    """Display usage information and exit"""
    print(f"Usage: {sys.argv[0]} [input_json_file] [options]")
    print("Options:")
    print("  -r, --recursive    Process media files recursively in subdirectories")
    print("  -e, --execute      Execute the generated ffmpeg commands")
    print("  -d, --dry-run      Show what would be done without actually doing it")
    print("  -p, --show-preset  Show only the ffmpeg equivalent of the preset")
    print("  -i, --input-dir    Specify input directory (default: same as JSON file)")
    print("  -o, --output-dir   Specify output directory (default: input_dir/converted)")
    print("  -m, --force-m4v    Force output extension to .m4v regardless of container")
    print("  -u, --no-underscore-replace  Don't replace underscores with spaces in output filenames")
    print("  --ignore-flag=X    Set custom ignore flag file (default: .noconvert)")
    print("  --verbose          Show verbose output and ffmpeg logs")
    print("  -v, --version      Show version:", SCRIPT_VERSION)
    print("  -l, --log=FILE     Send output to log file (default: script_output.log)")
    print("  -h, --help         Show this help message")
    print("")
    print("Special Features:")
    print("  - Files will be skipped if a '.noconvert' file exists in the same directory")
    print("  - Use -m/--force-m4v to output all files with .m4v extension")
    print("  - By default, underscores in filenames are replaced with spaces")
    sys.exit(1)


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('json_file', nargs='?', help='Input JSON file')
    parser.add_argument('-r', '--recursive', action='store_true', help='Process media files recursively')
    parser.add_argument('-e', '--execute', action='store_true', help='Execute the generated ffmpeg commands')
    parser.add_argument('-d', '--dry-run', action='store_true', help='Show what would be done without actually doing it')
    parser.add_argument('-p', '--show-preset', action='store_true', help='Show only the ffmpeg equivalent of the preset')
    parser.add_argument('-m', '--force-m4v', action='store_true', help='Force output extension to .m4v')
    parser.add_argument('-u', '--no-underscore-replace', action='store_true', help='Don\'t replace underscores with spaces')
    parser.add_argument('--verbose', action='store_true', help='Show verbose output and ffmpeg logs')
    parser.add_argument('-i', '--input-dir', help='Specify input directory')
    parser.add_argument('-o', '--output-dir', help='Specify output directory')
    parser.add_argument('--ignore-flag', default='.noconvert', help='Set custom ignore flag file')
    parser.add_argument('-v', '--version', action='store_true', help='Show version')
    parser.add_argument('-l', '--log', help='Send output to log file')
    parser.add_argument('-h', '--help', action='store_true', help='Show this help message')

    args = parser.parse_args()

    if args.help:
        show_usage()

    if args.version:
        print(f"Script Version={SCRIPT_VERSION}")
        sys.exit(0)

    if not args.json_file:
        show_usage()

    return args


def load_json_preset(json_file: str) -> Dict[str, Any]:
    """Load and parse the JSON preset file"""
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
        return data
    except FileNotFoundError:
        print(f"Error: JSON file '{json_file}' does not exist.", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Failed to parse '{json_file}' as valid JSON.", file=sys.stderr)
        sys.exit(1)


def extract_preset_settings(preset_data: Dict[str, Any]) -> Dict[str, Any]:
    """Extract relevant settings from the preset data"""
    preset = preset_data.get('PresetList', [{}])[0]

    # Extract audio settings from first audio track (if available)
    audio_list = preset.get('AudioList', [{}])
    audio_settings = audio_list[0] if audio_list else {}

    # Return extracted settings
    return {
        'preset_name': preset.get('PresetName', ''),
        'video_encoder': preset.get('VideoEncoder', ''),
        'video_bitrate': preset.get('VideoAvgBitrate', ''),
        'video_preset': preset.get('VideoPreset', ''),
        'video_profile': preset.get('VideoProfile', ''),
        'video_framerate': preset.get('VideoFramerate', ''),
        'video_quality': preset.get('VideoQualitySlider', ''),
        'video_quality_type': preset.get('VideoQualityType', ''),
        'video_multipass': preset.get('VideoMultiPass', False),
        'picture_width': preset.get('PictureWidth', ''),
        'picture_height': preset.get('PictureHeight', ''),
        'audio_encoder': audio_settings.get('AudioEncoder', ''),
        'audio_bitrate': audio_settings.get('AudioBitrate', ''),
        'audio_mixdown': audio_settings.get('AudioMixdown', ''),
        'container': preset.get('FileFormat', '')
    }


def convert_to_ffmpeg_params(settings: Dict[str, Any]) -> Dict[str, Any]:
    """Convert Handbrake settings to FFmpeg parameters"""
    result = {}

    # Convert video encoder
    if settings['video_encoder'] == 'x265':
        result['vcodec'] = 'libx265'
    elif settings['video_encoder'] == 'x264':
        result['vcodec'] = 'libx264'
    else:
        result['vcodec'] = settings['video_encoder']

    # Convert audio encoder
    if settings['audio_encoder'].startswith('copy:'):
        audio_codec = settings['audio_encoder'].split(':', 1)[1]
        result['acodec'] = '-c:a copy'
    else:
        result['acodec'] = f"-c:a aac -b:a {settings['audio_bitrate']}k"

    # Handle audio mixdown
    if settings['audio_mixdown'] == '5point1':
        result['audio_channels'] = '-ac 6'
    elif settings['audio_mixdown'] == 'stereo':
        result['audio_channels'] = '-ac 2'
    elif settings['audio_mixdown'] == 'mono':
        result['audio_channels'] = '-ac 1'
    else:
        result['audio_channels'] = ''

    # Video quality settings
    if settings['video_quality_type'] == '2':
        # CRF mode
        result['quality'] = f"-crf {settings['video_quality']}"
    else:
        # Bitrate mode
        result['quality'] = f"-b:v {settings['video_bitrate']}k"

    # Convert container format
    if settings['container'] == 'av_mkv':
        result['format'] = 'mkv'
    elif settings['container'] == 'av_mp4':
        result['format'] = 'mp4'
    else:
        result['format'] = 'mkv'  # Default to MKV

    result['preset'] = settings['video_preset']
    result['profile'] = settings['video_profile']
    result['framerate'] = settings['video_framerate']
    result['resolution'] = f"{settings['picture_width']}x{settings['picture_height']}"
    result['multipass'] = settings['video_multipass']

    return result


def show_preset(ffmpeg_params: Dict[str, Any], output_format: str, analyze_duration: int, probe_size: int):
    """Display the FFmpeg equivalent of the preset"""
    print("============================================")
    print(f"Handbrake Preset: {ffmpeg_params.get('preset_name', '')}")
    print("FFmpeg Equivalent Parameters:")
    print("============================================")
    print(f"Video codec:      -c:v {ffmpeg_params['vcodec']}")
    print(f"Quality:          {ffmpeg_params['quality']}")
    print(f"Preset:           -preset {ffmpeg_params['preset']}")

    if ffmpeg_params['framerate'] != "auto" and ffmpeg_params['framerate']:
        print(f"Framerate:        -r {ffmpeg_params['framerate']}")

    print(f"Resolution:       -s {ffmpeg_params['resolution']}")
    print(f"Audio:            {ffmpeg_params['acodec']} {ffmpeg_params['audio_channels']}")

    if ffmpeg_params['profile'] != "auto" and ffmpeg_params['profile']:
        print(f"Profile:          -profile:v {ffmpeg_params['profile']}")

    print(f"Output format:    {output_format}")

    if ffmpeg_params['multipass'] and ffmpeg_params.get('video_quality_type') != '2':
        print("Multipass:        Enabled (two-pass encoding)")
    else:
        print("Multipass:        Disabled (single-pass encoding)")

    print(f"Analyze duration: {analyze_duration}")
    print(f"Probe size:       {probe_size}")
    print("============================================")
    print("Example usage:")
    print(f"ffmpeg -analyzeduration {analyze_duration} -probesize {probe_size} -i input.mp4 "
          f"-c:v {ffmpeg_params['vcodec']} {ffmpeg_params['quality']} -preset {ffmpeg_params['preset']} "
          f"-s {ffmpeg_params['resolution']} {ffmpeg_params['acodec']} {ffmpeg_params['audio_channels']} "
          f"output.{output_format}")
    print("============================================")


def should_ignore_file(file_path: str, ignore_flag: str) -> bool:
    """Check if a file should be ignored based on ignore flag"""
    dir_path = os.path.dirname(file_path)
    if os.path.isfile(os.path.join(dir_path, ignore_flag)):
        return True
    return False


def format_filename(basename: str, replace_underscores: bool) -> str:
    """Format filename (replace underscores with spaces if enabled)"""
    if replace_underscores:
        return basename.replace('_', ' ')
    return basename


def check_file_access(file_path: str) -> bool:
    """Check if a file exists and is writable"""
    dir_path = os.path.dirname(file_path)

    if not os.path.isdir(dir_path):
        print(f"Error: Output directory '{dir_path}' does not exist.")
        return False

    if os.path.isfile(file_path) and not os.access(file_path, os.W_OK):
        print(f"Error: Output file '{file_path}' exists but is not writable.")
        return False

    if not os.access(dir_path, os.W_OK):
        print(f"Error: Output directory '{dir_path}' is not writable.")
        return False

    return True


def get_null_device() -> str:
    """Get the appropriate null device for the current platform"""
    if platform.system() == 'Windows':
        return 'NUL'
    return '/dev/null'


def build_ffmpeg_command(input_file: str, output_file: str, ffmpeg_params: Dict[str, Any],
                         analyze_duration: int, probe_size: int, verbose: bool) -> List[str]:
    """Build FFmpeg command with proper parameter handling"""
    # Base command with proper escaping and extended analysis parameters
    cmd = [
        "ffmpeg",
        "-analyzeduration", str(analyze_duration),
        "-probesize", str(probe_size),
        "-i", input_file,
        "-c:v", ffmpeg_params['vcodec'],
    ]

    # Add quality parameter (split to handle multiple arguments)
    quality_parts = ffmpeg_params['quality'].split()
    cmd.extend(quality_parts)

    # Add preset
    cmd.extend(["-preset", ffmpeg_params['preset']])

    # Add framerate if specified
    if ffmpeg_params['framerate'] != "auto" and ffmpeg_params['framerate']:
        cmd.extend(["-r", ffmpeg_params['framerate']])

    # Add resolution
    cmd.extend(["-s", ffmpeg_params['resolution']])

    # Add audio settings (split to handle multiple arguments)
    audio_parts = ffmpeg_params['acodec'].split()
    cmd.extend(audio_parts)

    if ffmpeg_params['audio_channels']:
        audio_channel_parts = ffmpeg_params['audio_channels'].split()
        cmd.extend(audio_channel_parts)

    # Add profile if specified
    if ffmpeg_params['profile'] != "auto" and ffmpeg_params['profile']:
        cmd.extend(["-profile:v", ffmpeg_params['profile']])

    # Add verbosity level
    if not verbose:
        cmd.extend(["-v", "error", "-stats"])

    # Always copy all streams from input
    cmd.extend(["-map", "0"])

    # Add output file
    cmd.append(output_file)

    return cmd


def build_multipass_commands(input_file: str, output_file: str, ffmpeg_params: Dict[str, Any],
                           analyze_duration: int, probe_size: int, verbose: bool) -> List[List[str]]:
    """Build FFmpeg commands for two-pass encoding"""
    # Get appropriate null device
    null_device = get_null_device()

    # First pass command - write to null device with specified format
    pass1_cmd = build_ffmpeg_command(input_file, null_device, ffmpeg_params,
                                     analyze_duration, probe_size, verbose)

    # Need to fix the first pass command:
    # For first pass, replace the output file with -f null to explicitly specify the format
    # and avoid the need for a valid output file extension
    pass1_cmd = pass1_cmd[:-1]  # Remove the last element (output file)
    pass1_cmd.extend(["-pass", "1", "-f", "null", null_device])

    # Second pass command
    pass2_cmd = build_ffmpeg_command(input_file, output_file, ffmpeg_params,
                                    analyze_duration, probe_size, verbose)
    pass2_cmd.extend(["-pass", "2"])

    return [pass1_cmd, pass2_cmd]


def rename_to_m4v(file_path: str, dry_run: bool) -> bool:
    """Rename a file from original format to m4v"""
    m4v_path = os.path.splitext(file_path)[0] + ".m4v"

    if dry_run:
        print(f"[DRY RUN] Would rename {file_path} to {m4v_path}")
        return True

    print(f"Renaming {file_path} to {m4v_path}")
    if os.path.isfile(file_path):
        try:
            os.rename(file_path, m4v_path)
            return True
        except OSError as e:
            print(f"Error renaming file to .m4v: {e}")
            return False
    else:
        print(f"Error: File {file_path} not found for renaming")
        return False


def get_file_info(file_path: str):
    """Get file information using ffprobe"""
    print(f"File information for {file_path}:")
    cmd = ["ffprobe", "-hide_banner", "-v", "error", "-show_format", "-show_streams", file_path]
    subprocess.run(cmd)


def find_media_files(directory: str, recursive: bool, extensions: List[str]) -> List[str]:
    """Find media files in the specified directory"""
    result = []

    if recursive:
        for root, _, files in os.walk(directory):
            for file in files:
                if any(file.lower().endswith(f".{ext}") for ext in extensions):
                    result.append(os.path.join(root, file))
    else:
        for item in os.listdir(directory):
            full_path = os.path.join(directory, item)
            if os.path.isfile(full_path) and any(item.lower().endswith(f".{ext}") for ext in extensions):
                result.append(full_path)

    return result


def process_file(
    input_file: str,
    media_dir: str,
    output_dir: str,
    ffmpeg_params: Dict[str, Any],
    original_format: str,
    output_format: str,
    force_m4v: bool,
    execute: bool,
    dry_run: bool,
    replace_underscores: bool,
    analyze_duration: int,
    probe_size: int,
    verbose: bool
) -> int:
    """Process a media file"""
    # Calculate relative path to preserve directory structure
    rel_path = os.path.relpath(input_file, media_dir)

    # Ensure output subdirectory path is properly constructed
    dir_part = os.path.dirname(rel_path)
    output_subdir = output_dir

    if dir_part != ".":
        output_subdir = os.path.join(output_dir, dir_part)

    filename = os.path.basename(input_file)
    basename = os.path.splitext(filename)[0]

    # Format basename (replace underscores with spaces if enabled)
    formatted_basename = format_filename(basename, replace_underscores)

    # Determine the correct output format for initial conversion
    actual_format = output_format
    if force_m4v and execute:
        # When executing with force_m4v, use original format first
        actual_format = original_format

    output_file = os.path.join(output_subdir, f"{formatted_basename}.{actual_format}")

    # Create output subdirectory if needed
    if not os.path.isdir(output_subdir):
        if not dry_run:
            print(f"Creating output directory: {output_subdir}")
            try:
                os.makedirs(output_subdir, exist_ok=True)
            except OSError as e:
                print(f"Error creating directory: {output_subdir}: {e}")
                return 1
        else:
            print(f"[DRY RUN] Would create directory: {output_subdir}")

    # Check if output file location is valid and writable
    if not dry_run and execute:
        if not check_file_access(output_file):
            print(f"Skipping {input_file} due to output file access issues.")
            return 1

    # Determine if multipass is needed
    is_multipass = ffmpeg_params['multipass'] and ffmpeg_params.get('video_quality_type') != '2'

    # Build ffmpeg command(s)
    if is_multipass:
        ffmpeg_cmds = build_multipass_commands(
            input_file, output_file, ffmpeg_params, analyze_duration, probe_size, verbose
        )
        ffmpeg_cmd_str = " && ".join([" ".join(map(lambda x: f'"{x}"' if ' ' in str(x) else str(x), cmd)) for cmd in ffmpeg_cmds])
    else:
        ffmpeg_cmd = build_ffmpeg_command(
            input_file, output_file, ffmpeg_params, analyze_duration, probe_size, verbose
        )
        ffmpeg_cmd_str = " ".join(map(lambda x: f'"{x}"' if ' ' in str(x) else str(x), ffmpeg_cmd))

    if dry_run:
        print(f"[DRY RUN] Would execute:")
        print(ffmpeg_cmd_str)
        if force_m4v:
            m4v_output = os.path.splitext(output_file)[0] + ".m4v"
            print(f"[DRY RUN] Would rename {output_file} to {m4v_output}")
    elif execute:
        print(f"Processing: {input_file}")
        print(f"Output: {output_file}")
        print(f"Command: {ffmpeg_cmd_str}")

        # Execute ffmpeg command(s)
        try:
            if is_multipass:
                # For multipass, run commands sequentially
                for i, cmd in enumerate(ffmpeg_cmds, 1):
                    print(f"Running pass {i} of {len(ffmpeg_cmds)}...")
                    result = subprocess.run(cmd, check=True)
            else:
                # For single pass
                result = subprocess.run(ffmpeg_cmd, check=True)

            print("Conversion successful")

            # If successful and force_m4v is enabled, rename to .m4v
            if force_m4v:
                if not rename_to_m4v(output_file, dry_run):
                    print("Warning: Failed to rename file to .m4v")

            return 0

        except subprocess.CalledProcessError as e:
            print(f"Error: FFmpeg command failed with return code {e.returncode}")
            print("Checking input file...")
            get_file_info(input_file)
            return 1
    else:
        print(f"Generated command for {input_file}:")
        print(ffmpeg_cmd_str)
        if force_m4v:
            print(f"Note: If executed, the file will be converted to {actual_format} then renamed to .m4v")

    return 0


def main():
    # Parse command line arguments
    args = parse_arguments()

    # Check if required tools are installed
    if not shutil.which('ffmpeg'):
        print("Error: ffmpeg is required but not installed. Please install ffmpeg.")
        sys.exit(1)

    if not shutil.which('ffprobe'):
        print("Error: ffprobe is required but not installed. Please install ffprobe.")
        sys.exit(1)

    # Load and parse JSON preset
    preset_data = load_json_preset(args.json_file)

    # Extract settings from the preset
    settings = extract_preset_settings(preset_data)

    # Convert to FFmpeg parameters
    ffmpeg_params = convert_to_ffmpeg_params(settings)
    ffmpeg_params['preset_name'] = settings['preset_name']  # Add preset name for display

    # Default FFmpeg extended settings
    analyze_duration = 100000000  # 100MB
    probe_size = 100000000        # 100MB

    # Determine output format
    output_format = ffmpeg_params['format']
    original_format = output_format  # Store original before potentially overriding

    # Override output format if force m4v is enabled
    if args.force_m4v and not args.execute:
        output_format = "m4v"
        print("Forcing output extension to .m4v")
    elif args.force_m4v:
        print(f"Force m4v is enabled. Files will be converted to {original_format} first, then renamed to .m4v")

    # Show preset only if requested
    if args.show_preset:
        show_preset(ffmpeg_params, output_format, analyze_duration, probe_size)
        sys.exit(0)

    # Set media directory if not specified
    if not args.input_dir:
        args.input_dir = os.path.dirname(os.path.abspath(args.json_file))
        print(f"Using media directory: {args.input_dir}")

    # Set output directory if not specified
    if not args.output_dir:
        args.output_dir = os.path.join(args.input_dir, "converted")
        print(f"Using output directory: {args.output_dir}")

    # Make sure output directory doesn't contain duplicate "converted" subdirectories
    args.output_dir = args.output_dir.replace('/converted/converted', '/converted')
    args.output_dir = args.output_dir.replace('\\converted\\converted', '\\converted')

    # Create output directory if it doesn't exist and not in dry run mode
    if not os.path.isdir(args.output_dir) and not args.dry_run:
        print(f"Creating output directory: {args.output_dir}")
        os.makedirs(args.output_dir, exist_ok=True)

    # Find and process media files
    print(f"Searching for media files in {args.input_dir}")
    print(f"Files with the '{args.ignore_flag}' file in their directory will be skipped")
    print(f"Output directory set to: {args.output_dir}")
    print(f"Using analyzeduration: {analyze_duration}, probesize: {probe_size}")

    if not args.no_underscore_replace:
        print("Underscores in filenames will be replaced with spaces in output files")
    else:
        print("Output filenames will maintain the same format as input filenames")

    if args.recursive:
        print("Recursive search enabled")
    else:
        print("Non-recursive search")

    if args.verbose:
        print("Verbose output enabled")

    # Find media files
    media_files = find_media_files(args.input_dir, args.recursive, MEDIA_EXTENSIONS)

    # Process each file
    file_count = 0
    skipped_count = 0
    error_count = 0

    for file in media_files:
        # Skip JSON file itself
        if os.path.abspath(file) == os.path.abspath(args.json_file):
            continue

        # Check if file should be ignored
        if should_ignore_file(file, args.ignore_flag):
            print(f"Skipping: {file} (ignore flag found)")
            skipped_count += 1
            continue

        # Process the file
        result = process_file(
            file,
            args.input_dir,
            args.output_dir,
            ffmpeg_params,
            original_format,
            output_format,
            args.force_m4v,
            args.execute,
            args.dry_run,
            not args.no_underscore_replace,
            analyze_duration,
            probe_size,
            args.verbose
        )

        if result == 0:
            file_count += 1
        else:
            error_count += 1
            print(f"Failed to process: {file}")

    # Display summary
    print("Processing complete:")
    print(f"  - Successfully processed: {file_count} files")
    print(f"  - Skipped: {skipped_count} files")
    print(f"  - Failed: {error_count} files")

    if file_count == 0 and skipped_count == 0 and error_count == 0:
        print("No media files found in the specified directory.")

    # Return non-zero status if errors occurred
    if error_count > 0:
        print("Warning: Some files failed to process. Check output for details.")
        # Don't exit with error to allow processing to continue
        # sys.exit(1)


if __name__ == "__main__":
    main()
