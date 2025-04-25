#!/bin/bash

# HDMI Input Recording and Display Script for Orange Pi 5 Plus

# Set variables for recording
OUTPUT_FILE="hdmi_recording_$(date +%Y%m%d_%H%M%S).mp4"
DURATION=60  # Recording duration in seconds, set to 0 for unlimited
DEVICE="/dev/video-enc0"  # This might need to be changed depending on your setup
RESOLUTION="1920x1080"  # Change to match your input source resolution
FRAMERATE="30"  # Frames per second
WINDOW_TITLE="HDMI Input Preview"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg is not installed. Installing now..."
    apt-get update && apt-get install -y ffmpeg
fi

# Check if the video device exists
if [ ! -e "$DEVICE" ]; then
    echo "Video device $DEVICE not found. Available devices:"
    ls -la /dev/video*
    exit 1
fi

# List available formats
echo "Available formats for $DEVICE:"
v4l2-ctl --device=$DEVICE --list-formats-ext

# Function to clean up processes on exit
cleanup() {
    echo "Cleaning up processes..."
    [ -n "$FFPLAY_PID" ] && kill $FFPLAY_PID 2>/dev/null
    [ -n "$FFMPEG_PID" ] && kill $FFMPEG_PID 2>/dev/null
    exit 0
}

# Set trap for cleanup on Ctrl+C
trap cleanup SIGINT SIGTERM

# Start display window in background
echo "Opening preview window..."
ffplay -f v4l2 -framerate $FRAMERATE -video_size $RESOLUTION -window_title "$WINDOW_TITLE" $DEVICE &
FFPLAY_PID=$!

# Give ffplay a moment to initialize
sleep 1

# Start recording
echo "Starting HDMI recording to $OUTPUT_FILE..."
if [ "$DURATION" -eq 0 ]; then
    # Record until manually stopped (Ctrl+C)
    ffmpeg -f v4l2 -framerate $FRAMERATE -video_size $RESOLUTION -i $DEVICE -c:v libx264 -preset ultrafast -qp 0 "$OUTPUT_FILE" &
    FFMPEG_PID=$!
    
    # Wait for user to stop recording
    echo "Press Ctrl+C to stop recording"
    wait $FFMPEG_PID
else
    # Record for specified duration
    ffmpeg -f v4l2 -framerate $FRAMERATE -video_size $RESOLUTION -i $DEVICE -c:v libx264 -preset ultrafast -qp 0 -t $DURATION "$OUTPUT_FILE" &
    FFMPEG_PID=$!
    
    # Wait for recording to complete
    wait $FFMPEG_PID
    kill $FFPLAY_PID 2>/dev/null
fi

echo "Recording complete. Saved to $OUTPUT_FILE"
