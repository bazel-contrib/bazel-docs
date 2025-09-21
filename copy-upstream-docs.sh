#!/bin/bash

# Script to copy all .md files from upstream/site/en to root with .mdx extension
# Usage: ./copy-upstream-docs.sh

set -e

SOURCE_DIR="upstream/site/en"
# Files that live in this repo, not fetched from upstream
LOCAL_FILES="
    index.mdx
"

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found"
    exit 1
fi

echo "Finding all .md files in $SOURCE_DIR..."

# Find all .md files and copy them
find "$SOURCE_DIR" -name "*.md" -type f | while read -r source_file; do
    # Get relative path from upstream/site/en
    relative_path="${source_file#$SOURCE_DIR/}"
    
    # Convert .md to .mdx
    target_file="${relative_path%.md}.mdx"
    
    # Create target directory if it doesn't exist
    target_dir=$(dirname "$target_file")
    if [ "$target_dir" != "." ]; then
        mkdir -p "$target_dir"
    fi
    
    # Transform and copy the file
    echo "Transforming and copying $source_file to $target_file"
    awk -f transform-docs.awk "$source_file" > "$target_file"
done

echo "Successfully copied all .md files to .mdx files in root"
echo "You can now modify the files as needed."
