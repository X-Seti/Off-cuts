#!/bin/bash

# X-Seti - Jan11 2018 - deepsearch: Search file names and contents in a folder,
# usable via Dolphin or terminal

# --- Configurable ---
DEFAULT_EDITOR="kate"  # Options: kate, kwrite, code

# --- Parse CLI Args ---
search_term=""
target_dir="."
ignore_case=false
editor_open=false
output_file=""
include_old=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case) ignore_case=true ;;
        -o|--output) output_file="$2"; shift ;;
        -e|--editor) editor_open=true ;;
        -d|--dir) target_dir="$2"; shift ;;
        --include-old) include_old=true ;;
        --help) 
            echo "Usage: deepsearch [options] <search_term>"
            echo "Options:"
            echo "  -i, --ignore-case     Case-insensitive search"
            echo "  -o, --output <file>   Save results to file"
            echo "  -e, --editor          Enable editor clickable output"
            echo "  -d, --dir <folder>    Target directory (default: current)"
            echo "  --include-old         Include old/ folders (default: excluded)"
            exit 0
            ;;
        *) 
            if [[ -z "$search_term" && "$1" != -* ]]; then
                search_term="$1"
            elif [[ -d "$1" ]]; then
                target_dir="$1"
            fi
            ;;
    esac
    shift
done

# --- GUI fallback if invoked from Dolphin ---
if [[ -z "$search_term" && -n "$target_dir" && "$target_dir" != "." ]]; then
    search_term=$(kdialog --inputbox "Enter search term:" "Deep Search")
    [[ -z "$search_term" ]] && exit 1
fi

# --- Ensure search term exists ---
if [[ -z "$search_term" ]]; then
    echo "Usage: deepsearch [options] <search_term>"
    echo "Options:"
    echo "  -i, --ignore-case     Case-insensitive search"
    echo "  -o, --output <file>   Save results to file"
    echo "  -e, --editor          Enable editor clickable output (e.g., open with Kate)"
    echo "  -d, --dir <folder>    Target directory (default: current)"
    echo "  --include-old         Include old/ folders (default: excluded)"
    exit 1
fi

# --- Build exclude directories ---
exclude_dirs=".git,__pycache__,.vscode,.idea,node_modules"
if ! $include_old; then
    exclude_dirs+=",old"
fi

# --- Build grep flags ---
grep_flags="-rn"
$ignore_case && grep_flags+="i"

# --- Perform Search ---
result=$(mktemp)

{
    echo "🔍 Searching for: \"$search_term\" in $target_dir"
    if ! $include_old; then
        echo "📁 Excluding: old/ folders (use --include-old to include)"
    fi
    echo

    echo "📁 Files with name containing \"$search_term\":"
    if $include_old; then
        find "$target_dir" -type f -iname "*$search_term*" 2>/dev/null || echo "None"
    else
        find "$target_dir" -type f -iname "*$search_term*" -not -path "*/old/*" 2>/dev/null || echo "None"
    fi
    echo

    echo "📄 Files with contents containing \"$search_term\":"
    if $include_old; then
        grep $grep_flags --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} "$search_term" "$target_dir" 2>/dev/null || echo "None"
    else
        grep $grep_flags --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} "$search_term" "$target_dir" 2>/dev/null | grep -v "/old/" || echo "None"
    fi
} | tee "$result"

# --- Save to file if requested ---
if [[ -n "$output_file" ]]; then
    cp "$result" "$output_file"
    echo -e "\n💾 Saved to: $output_file"
fi

# --- Editor clickable lines ---
if $editor_open; then
    echo -e "\n🖱 Opening matches in $DEFAULT_EDITOR..."
    if $include_old; then
        grep $grep_flags --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} "$search_term" "$target_dir" 2>/dev/null | while IFS=: read -r file line _; do
            [[ -f "$file" && "$line" =~ ^[0-9]+$ ]] && "$DEFAULT_EDITOR" "$file" -l "$line" &
        done
    else
        grep $grep_flags --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} "$search_term" "$target_dir" 2>/dev/null | grep -v "/old/" | while IFS=: read -r file line _; do
            [[ -f "$file" && "$line" =~ ^[0-9]+$ ]] && "$DEFAULT_EDITOR" "$file" -l "$line" &
        done
    fi
fi

# --- GUI output if Dolphin (kdialog) mode ---
if [[ "$target_dir" != "." && -n "$DISPLAY" && -n "$(which kdialog)" ]]; then
    kdialog --textbox "$result" 800 600
fi

rm -f "$result"
