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
concepts/build-files.mdx
concepts/dependencies.mdx
concepts/labels.mdx
configure/integrate-cpp.mdx
contribute/docs-style-guide.mdx
contribute/search.mdx
docs/cc-toolchain-config-reference.mdx
docs/user-manual.mdx
extending/config.mdx
external/mod-command.mdx
external/registry.mdx
external/migration_tool.mdx
query/language.mdx
query/quickstart.mdx
reference/be/functions.mdx
reference/be/platforms-and-toolchains.mdx
reference/command-line-reference.mdx
reference/flag-cheatsheet.mdx
reference/test-encyclopedia.mdx
remote/dynamic.mdx
rules/lib/globals/bzl.mdx
rules/lib/providers/DebugPackageInfo.mdx
rules/lib/toplevel/java_common.mdx
rules/lib/repo/cache.mdx
rules/lib/repo/git.mdx
rules/lib/repo/http.mdx
rules/lib/repo/local.mdx
rules/lib/repo/utils.mdx
rules/lib/globals/module.mdx
rules/windows.mdx
run/build.mdx
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

# --- Community Page Conversion Logic ---

function convert_community_page() {
    local topic="$1" # e.g., "experts" or "partners"
    local source_yaml="upstream/site/en/community/${topic}/_index.yaml"
    local output_mdx="${DEST_DIR}/community/${topic}.mdx"

    if [ ! -f "$source_yaml" ]; then
        echo "Skipping ${topic} conversion (source YAML not found)."
        return
    fi

    echo "Converting ${topic} YAML to MDX..."

    local title=$(yq eval '.landing_page.rows[0].heading' "$source_yaml")
    local description=$(yq eval '.landing_page.rows[0].description' "$source_yaml")

    # Ensure destination directory exists
    mkdir -p "$(dirname "$output_mdx")"

    # Create the MDX file
    cat > "$output_mdx" << EOF
---
title: '$title'
---

$description

---

EOF

    # Process each item and group into pairs, appending to the new file
    yq eval '.landing_page.rows[0].items[]' "$source_yaml" -o json | jq -r '
    "<Card title=\"" + .heading + "\" img=\"" + (.image_path) + "\"" +
    (if .buttons then " cta=\"" + .buttons[0].label + "\" href=\"" + .buttons[0].path + "\"" else "" end) +
    ">" + "\n" +
    .description + "\n" +
    "</Card>"
    ' | awk '
    BEGIN { 
        count = 0
        card_buffer = ""
    }
    /^<Card/ {
        if (count % 2 == 0) {
            print "<Columns cols={2}>"
        }
        card_buffer = $0
        next
    }
    {
        card_buffer = card_buffer "\n" $0
    }
    /^<\/Card>/ {
        print card_buffer
        count++
        if (count % 2 == 0) {
            print "</Columns>"
            print ""
        }
        card_buffer = ""
    }
    END {
        if (count % 2 == 1) {
            print "</Columns>"
            print ""
        }
    }' >> "$output_mdx"

    echo "Generated $output_mdx"
}

# Run conversion for community pages and copy images
if [ -d "upstream/site/en/community" ]; then
    convert_community_page "experts"
    convert_community_page "partners"

    if [ -d "upstream/site/en/community/images" ]; then
        echo "Copying community images..."
        mkdir -p "$DEST_DIR/community/images"
        cp upstream/site/en/community/images/* "$DEST_DIR/community/images/"
    fi
else
    echo "Skipping community conversion (directory not found)."
fi


echo "Done copying docs."
