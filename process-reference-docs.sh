#!/bin/bash

# Script to process Bazel reference documentation from reference-docs.zip
# Usage: ./process-reference-docs.sh <path-to-reference-docs.zip>

set -o errexit -o nounset -o pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path-to-reference-docs.zip>"
    exit 1
fi

ZIP_FILE="$1"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File '$ZIP_FILE' not found"
    exit 1
fi

echo "Processing reference documentation from $ZIP_FILE..."

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Extract the zip file
echo "Extracting reference-docs.zip..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Check for nested zip files
nested_zips=$(find "$TEMP_DIR" -maxdepth 1 -name "*.zip" -type f)

if [ -n "$nested_zips" ]; then
    echo ""
    echo "Error: The zip file contains another zip file inside it:"
    for nested_zip in $nested_zips; do
        echo "  - $(basename "$nested_zip")"
    done
    echo ""
    echo "Please extract the contents properly before running this script."
    echo "The zip should contain the documentation files directly, not another zip."
    exit 1
fi

# Process reference/be/ HTML files and convert to MDX
echo "Processing Build Encyclopedia (reference/be/) files..."
if [ -d "$TEMP_DIR/reference/be" ]; then
    mkdir -p reference/be

    # Convert HTML files to MDX
    for html_file in "$TEMP_DIR/reference/be"/*.html; do
        if [ -f "$html_file" ]; then
            basename_file=$(basename "$html_file")
            mdx_file="reference/be/${basename_file%.html}.mdx"

            echo "  Converting $(basename "$html_file") to MDX..."

            # Extract title from HTML and create basic MDX structure
            # This is a simple conversion - may need refinement
            title=$(grep -oP '<title>\K[^<]+' "$html_file" 2>/dev/null || echo "$(basename "${html_file%.html}")")

            # Create MDX file with frontmatter
            # Clean up the title to avoid issues with quotes
            title=$(echo "$title" | sed "s/'/'\\\''/g")

            {
                echo "---"
                echo "title: '$title'"
                echo "---"
                echo ""
                # For now, we'll keep the HTML content as-is
                # The transform-docs.awk can be enhanced later for HTML->MDX conversion
                cat "$html_file"
            } > "$mdx_file"

            echo "  Created $mdx_file"
        fi
    done
else
    echo "Warning: No reference/be/ directory found in zip"
fi

# Process command-line reference
echo "Processing command-line reference..."
if [ -f "$TEMP_DIR/reference/command-line-reference.html" ]; then
    mkdir -p reference

    title=$(grep -oP '<title>\K[^<]+' "$TEMP_DIR/reference/command-line-reference.html" 2>/dev/null || echo "Command-Line Reference")
    title=$(echo "$title" | sed "s/'/'\\\''/g")

    {
        echo "---"
        echo "title: '$title'"
        echo "---"
        echo ""
        cat "$TEMP_DIR/reference/command-line-reference.html"
    } > "reference/command-line-reference.mdx"

    echo "  Created reference/command-line-reference.mdx"
else
    echo "Warning: command-line-reference.html not found in zip"
fi

# Process Starlark library docs
echo "Processing Starlark library documentation..."
if [ -d "$TEMP_DIR/rules/lib" ]; then
    mkdir -p rules/lib

    # Copy HTML files and convert to MDX
    find "$TEMP_DIR/rules/lib" -name "*.html" -type f | while read -r html_file; do
        relative_path="${html_file#$TEMP_DIR/rules/lib/}"
        mdx_file="rules/lib/${relative_path%.html}.mdx"

        # Create directory structure
        mkdir -p "$(dirname "$mdx_file")"

        title=$(grep -oP '<title>\K[^<]+' "$html_file" 2>/dev/null || echo "$(basename "${html_file%.html}")")
        title=$(echo "$title" | sed "s/'/'\\\''/g")

        {
            echo "---"
            echo "title: '$title'"
            echo "---"
            echo ""
            cat "$html_file"
        } > "$mdx_file"

        echo "  Created $mdx_file"
    done
else
    echo "Warning: No rules/lib/ directory found in zip"
fi

echo "Reference documentation processing complete!"
echo ""
echo "Summary:"
echo "  - Build Encyclopedia: reference/be/*.mdx"
echo "  - Command-Line Reference: reference/command-line-reference.mdx"
echo "  - Starlark Library: rules/lib/**/*.mdx"