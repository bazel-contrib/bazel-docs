#!/bin/bash

# Script to copy all .md files from upstream/site/en to root with .mdx extension
# Usage: ./copy-upstream-docs.sh

set -o errexit -o nounset -o pipefail

SOURCE_DIR="upstream/site/en"
# Files that live in this repo, not fetched from upstream
LOCAL_FILES="
    index.mdx
"

# Files that are not valid MDX syntax
# This output pasted from a CI job - we should burn it down to zero
BROKEN_FILES="
community/roadmaps-configurability.mdx
community/users.mdx
concepts/build-files.mdx
concepts/dependencies.mdx
concepts/labels.mdx
configure/integrate-cpp.mdx
configure/windows.mdx
contribute/search.mdx
docs/cc-toolchain-config-reference.mdx
docs/mobile-install.mdx
docs/user-manual.mdx
extending/config.mdx
extending/legacy-macros.mdx
extending/macros.mdx
external/extension.mdx
external/faq.mdx
external/migration.mdx
external/mod-command.mdx
external/overview.mdx
external/registry.mdx
external/vendor.mdx
install/windows.mdx
query/guide.mdx
query/language.mdx
query/quickstart.mdx
reference/flag-cheatsheet.mdx
reference/test-encyclopedia.mdx
release/rolling.mdx
remote/ci.mdx
remote/dynamic.mdx
rules/language.mdx
rules/windows.mdx
run/build.mdx
start/go.mdx
tutorials/ccp-toolchain-config.mdx
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
    
    # Check if this file is in the BROKEN_FILES list
    if echo "$BROKEN_FILES" | grep -q "^$target_file$"; then
        echo "Skipping broken file: $target_file"
        continue
    fi
    
    # Transform and copy the file
    echo "Transforming and copying $source_file to $target_file"
    awk -f transform-docs.awk "$source_file" > "$target_file"
done

echo "Successfully copied all .md files to .mdx files in root"
echo "You can now modify the files as needed."
