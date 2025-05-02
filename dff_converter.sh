#!/bin/bash

# Script to convert GTA Vice City DFF files to San Andreas format
# For ARM64 systems - X-Seti

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if dff_converter is installed
if [ ! -f "./dff_converter" ]; then
    echo -e "${YELLOW}DFF Converter not found. Compiling from source...${NC}"

    # Check if gcc is installed
    if ! command -v gcc &> /dev/null; then
        echo -e "${RED}Error: GCC compiler not found. Please install gcc.${NC}"
        exit 1
    fi

    # Compile the converter
    echo -e "${YELLOW}Compiling DFF converter...${NC}"
    gcc -o dff_converter dff_converter.c

    if [ $? -ne 0 ]; then
        echo -e "${RED}Compilation failed. Please check the source code.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Compilation successful.${NC}"
fi

# Make sure the converter is executable
chmod +x ./dff_converter

# Function to convert a single DFF file
convert_dff() {
    local input_file="$1"
    local output_file="${input_file%.dff}_SA.dff"

    echo -e "${YELLOW}Converting: $input_file to $output_file${NC}"

    # Run our custom converter
    ./dff_converter -v "$input_file" "$output_file"

    # Check if conversion was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully converted $input_file${NC}"
    else
        echo -e "${RED}Failed to convert $input_file${NC}"
    fi
}

# Function to convert TXD files if needed
convert_txd() {
    local input_file="$1"
    local output_file="${input_file%.txd}_SA.txd"

    echo -e "${YELLOW}Note: TXD conversion not implemented yet.${NC}"
    echo -e "${YELLOW}You may need to convert $input_file manually.${NC}"
}

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 [DFF/TXD file(s)]"
    echo "Example: $0 *.dff    # Convert all DFF files in current directory"
    echo "Example: $0 car.dff building.dff    # Convert specific files"
    exit 1
fi

# Create output directory
output_dir="converted_models"
mkdir -p "$output_dir"

# Process each input file
converted_count=0
failed_count=0

for file in "$@"; do
    # Check file extension
    if [[ "$file" == *.dff ]]; then
        # Get just the filename without path
        filename=$(basename "$file")
        output_file="$output_dir/${filename%.dff}_SA.dff"

        ./dff_converter -v "$file" "$output_file"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully converted $file to $output_file${NC}"
            ((converted_count++))
        else
            echo -e "${RED}Failed to convert $file${NC}"
            ((failed_count++))
        fi
    elif [[ "$file" == *.txd ]]; then
        echo -e "${YELLOW}TXD conversion not implemented yet: $file${NC}"
    else
        echo -e "${RED}Skipping $file (not a DFF or TXD file)${NC}"
    fi
done

# Summary
echo "------------------------------------"
echo -e "${GREEN}Conversion complete!${NC}"
echo "Files converted: $converted_count"
echo "Files failed: $failed_count"
echo "------------------------------------"
