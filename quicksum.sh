#!/bin/bash

# X-Seti - July26 2025 - Quick Checksum Generator - Version: 1.0

# Quick checksum generator for file verification
# Creates individual .txt checksum files for each archive AND a master list

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_FILE="checksums_master_$(date +%Y%m%d_%H%M%S).txt"

echo "🔍 Generating checksums for files in: $SCRIPT_DIR"
echo

# Initialize master file
{
    echo "# Master Checksum Verification File"
    echo "# Generated: $(date)"
    echo "# Directory: $SCRIPT_DIR"
    echo "# =================================="
    echo
} > "$SCRIPT_DIR/$MASTER_FILE"

# Find all files (excluding hidden files and the script itself)
file_count=0

for file in "$SCRIPT_DIR"/*; do
    # Skip if not a regular file, or if it's this script, or hidden files, or existing .txt files
    if [[ ! -f "$file" ]] || [[ "$(basename "$file")" == "$(basename "$0")" ]] || [[ "$(basename "$file")" == .* ]] || [[ "$file" == *.txt ]]; then
        continue
    fi
    
    filename=$(basename "$file")
    filesize=$(stat -c%s "$file" 2>/dev/null || echo "0")
    checksum_file="${file}.txt"
    sha256_hash=$(sha256sum "$file" | cut -d' ' -f1)
    md5_hash=$(md5sum "$file" | cut -d' ' -f1)
    
    # Create individual checksum file
    {
        echo "# Checksum Verification for: $filename"
        echo "# Generated: $(date)"
        echo "# =================================="
        echo
        echo "File: $filename"
        echo "Size: $filesize bytes ($(numfmt --to=iec-i --suffix=B "$filesize" 2>/dev/null || echo "$filesize bytes"))"
        echo "SHA256: $sha256_hash"
        echo "MD5: $md5_hash"
        echo "Modified: $(stat -c%y "$file" 2>/dev/null || echo "Unknown")"
    } > "$checksum_file"
    
    # Add to master file
    {
        echo "File: $filename"
        echo "Size: $filesize bytes ($(numfmt --to=iec-i --suffix=B "$filesize" 2>/dev/null || echo "$filesize bytes"))"
        echo "SHA256: $sha256_hash"
        echo "MD5: $md5_hash"
        echo "Modified: $(stat -c%y "$file" 2>/dev/null || echo "Unknown")"
        echo "---"
    } >> "$SCRIPT_DIR/$MASTER_FILE"
    
    ((file_count++))
    echo "✅ $filename → $(basename "$checksum_file")"
done

if [[ $file_count -eq 0 ]]; then
    echo "❌ No files found to checksum"
    exit 1
else
    echo
    echo "✅ Generated $file_count checksum files"
    echo "💡 Each archive now has its own .txt checksum file"
    echo "📤 Upload both the archive and its .txt file to verify integrity"
fi
