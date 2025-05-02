#!/bin/bash

# GTA Model Converter Script
# For ARM64 systems
# Converts between GTA III, Vice City, and San Andreas model files (DFF, TXD, COL)

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Program name
PROGRAM_NAME="gta_model_converter"

# Show banner
echo -e "${BLUE}╔═════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        GTA Model Converter for ARM64        ║${NC}"
echo -e "${BLUE}║  Supports GTA III, Vice City, San Andreas   ║${NC}"
echo -e "${BLUE}║    Converts DFF, TXD, and COL files         ║${NC}"
echo -e "${BLUE}╚═════════════════════════════════════════════╝${NC}"

# Check if converter exists and compile if needed
if [ ! -f "./$PROGRAM_NAME" ]; then
    echo -e "${YELLOW}Model converter not found. Compiling from source...${NC}"

    # Check if gcc is installed
    if ! command -v gcc &> /dev/null; then
        echo -e "${RED}Error: GCC compiler not found. Please install gcc.${NC}"
        exit 1
    fi

    # Check if source file exists
    if [ ! -f "${PROGRAM_NAME}.c" ]; then
        echo -e "${RED}Error: Source file ${PROGRAM_NAME}.c not found.${NC}"
        exit 1
    }

    # Compile the converter
    echo -e "${YELLOW}Compiling model converter...${NC}"
    gcc -o $PROGRAM_NAME ${PROGRAM_NAME}.c

    if [ $? -ne 0 ]; then
        echo -e "${RED}Compilation failed. Please check the source code.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Compilation successful.${NC}"
fi

# Make sure the converter is executable
chmod +x ./$PROGRAM_NAME

# Function to show usage
show_usage() {
    echo -e "Usage: $0 [options] <files>"
    echo -e "Options:"
    echo -e "  -g <game>   Target game: 3 (GTA III), vc (Vice City), sa (San Andreas)"
    echo -e "  -v          Verbose output"
    echo -e "  -h          Show this help message"
    echo -e "  -o <dir>    Output directory (default: 'converted')"
    echo -e "\nExamples:"
    echo -e "  $0 -g sa *.dff                # Convert all DFF files to SA format"
    echo -e "  $0 -g vc -v building.dff      # Convert building.dff to VC with verbose output"
    echo -e "  $0 -g 3 -o gta3_models *.dff  # Convert all DFF files to GTA III format"
}

# Default values
TARGET_GAME="sa"
VERBOSE=""
OUTPUT_DIR="converted"

# Parse command line options
while getopts "g:o:vh" opt; do
    case $opt in
        g)
            TARGET_GAME="$OPTARG"
            ;;
        v)
            VERBOSE="-v"
            ;;
        o)
            OUTPUT_DIR="$OPTARG"
            ;;
        h)
            show_usage
            exit 0
            ;;
        \?)
            echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
            show_usage
            exit 1
            ;;
        :)
            echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Validate target game
if [ "$TARGET_GAME" != "3" ] && [ "$TARGET_GAME" != "vc" ] && [ "$TARGET_GAME" != "sa" ]; then
    echo -e "${RED}Invalid target game: $TARGET_GAME${NC}"
    echo -e "${YELLOW}Valid options are: 3 (GTA III), vc (Vice City), sa (San Andreas)${NC}"
    exit 1
fi

# Shift options to get file arguments
shift $((OPTIND-1))

# Check if files were provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No input files specified.${NC}"
    show_usage
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Process each input file
converted_count=0
failed_count=0

for file in "$@"; do
    # Skip if not a file
    if [ ! -f "$file" ]; then
        echo -e "${RED}Skipping $file (not a file)${NC}"
        continue
    fi

    # Get file extension
    filename=$(basename "$file")
    extension="${filename##*.}"
    base_name="${filename%.*}"

    # Convert extension to lowercase for comparison
    extension_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

    # Check if it's a supported file type
    if [[ "$extension_lower" != "dff" && "$extension_lower" != "txd" && "$extension_lower" != "col" ]]; then
        echo -e "${RED}Skipping $file (not a supported file type)${NC}"
        continue
    fi

    # Construct output filename with target game suffix
    case "$TARGET_GAME" in
        3)
            output_file="$OUTPUT_DIR/${base_name}_gta3.$extension_lower"
            game_name="GTA III"
            ;;
        vc)
            output_file="$OUTPUT_DIR/${base_name}_vc.$extension_lower"
            game_name="Vice City"
            ;;
        sa)
            output_file="$OUTPUT_DIR/${base_name}_sa.$extension_lower"
            game_name="San Andreas"
            ;;
    esac

    # Convert the file
    echo -e "${YELLOW}Converting $file to $game_name format...${NC}"
    ./$PROGRAM_NAME -g $TARGET_GAME $VERBOSE "$file" "$output_file"

    # Check if conversion was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully converted $file to $output_file${NC}"
        ((converted_count++))
    else
        echo -e "${RED}Failed to convert $file${NC}"
        ((failed_count++))
    fi
done

# Summary
echo "------------------------------------"
echo -e "${GREEN}Conversion complete!${NC}"
echo "Files converted: $converted_count"
echo "Files failed: $failed_count"
echo "Output directory: $OUTPUT_DIR"
echo "------------------------------------"
