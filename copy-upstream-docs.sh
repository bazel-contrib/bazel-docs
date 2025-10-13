#!/bin/bash

# Script to copy all .md files from upstream/site/en to destination with .mdx extension
# Usage: ./copy-upstream-docs.sh [destination_directory]
# If no destination is provided, defaults to current working directory

set -o errexit -o nounset -o pipefail

# Primary upstream directory
UPSTREAM_SITE="upstream/site/en"

# Reference docs directory
REFERENCE_DOCS="reference-docs-temp"

# Destination directory (default to current directory)
DEST_DIR="${1:-.}"

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
reference/command-line-reference.mdx
reference/be/be-nav.mdx
reference/be/functions.mdx
reference/be/platforms-and-toolchains.mdx
release/rolling.mdx
remote/ci.mdx
remote/dynamic.mdx
rules/language.mdx
rules/windows.mdx
run/build.mdx
start/go.mdx
tutorials/ccp-toolchain-config.mdx
"

# Verify that at least one source exists
if [ ! -d "$UPSTREAM_SITE" ] && [ ! -d "$REFERENCE_DOCS" ]; then
    echo "Error: neither source directory exists: '$UPSTREAM_SITE' or '$REFERENCE_DOCS'"
    exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

echo "Will search in '$UPSTREAM_SITE' and '$REFERENCE_DOCS' (if exists) to copy .md → .mdx to $DEST_DIR"

transform_docs() {
    local SOURCE_DIR="$1"
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Warning: source directory '$SOURCE_DIR' not found, skipping"
        return
    fi

    find "$SOURCE_DIR" -name "*.md" -type f | while read -r source_file; do
        # Derive the relative path inside the source tree
        relative_path="${source_file#$SOURCE_DIR/}"
        target_file="${relative_path%.md}.mdx"
        target_dir=$(dirname "$DEST_DIR/$target_file")

        mkdir -p "$target_dir"

    # Check if this file is in the BROKEN_FILES list
        if echo "$BROKEN_FILES" | grep -q "^$target_file$"; then
            echo "Skipping broken file: $target_file"
            continue
        fi

    # Transform and copy the file
    echo "Transforming and copying $source_file to $DEST_DIR/$target_file"
    awk -f transform-docs.awk "$source_file" > "$DEST_DIR/$target_file"
    done
}

# Copy from both sources
transform_docs "$UPSTREAM_SITE"
transform_docs "$REFERENCE_DOCS"

echo "Converting community YAML files to MDX..."
./convert-community-to-mdx.sh "$DEST_DIR/community/experts"
./convert-community-to-mdx.sh "$DEST_DIR/community/partners"

echo "Copying community images..."
mkdir -p "$DEST_DIR/community/images"
cp upstream/site/en/community/images/* "$DEST_DIR/community/images/"

echo "Done copying docs."
