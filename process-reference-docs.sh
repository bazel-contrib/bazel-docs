#!/bin/bash

# Script to process Bazel reference documentation from reference-docs.zip
# Usage: ./process-reference-docs.sh <path-to-reference-docs.zip>
# Requirements: pandoc must be installed (brew install pandoc or apt-get install pandoc)

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

# Check if pandoc is installed
if ! command -v pandoc &> /dev/null; then
    echo "Error: pandoc is not installed"
    echo "Please install it first:"
    echo "  - macOS: brew install pandoc"
    echo "  - Ubuntu/Debian: sudo apt-get install pandoc"
    echo "  - Other: https://pandoc.org/installing.html"
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

# Function to convert HTML to MDX using pandoc
html_to_mdx() {
    local input_file="$1"
    local output_file="$2"
    
    # Extract title from HTML
    local title=$(grep -oP '<title>\K[^<]+' "$input_file" 2>/dev/null || echo "$(basename "${input_file%.html}")")
    title=$(echo "$title" | sed "s/'/'\\\''/g")
    
    # Create temporary markdown file
    local temp_md=$(mktemp)
    
    # Convert HTML to Markdown using pandoc
    # Options:
    #   -f html: input format is HTML
    #   -t gfm: output format is GitHub Flavored Markdown
    #   --wrap=preserve: preserve line wrapping
    #   --extract-media=.: extract images to current directory (if any)
    pandoc -f html -t gfm --wrap=preserve "$input_file" -o "$temp_md" 2>/dev/null || {
        echo "Warning: pandoc conversion failed for $(basename "$input_file"), using fallback"
        # Fallback: just copy the HTML content
        cat "$input_file" > "$temp_md"
    }
    
    # Write MDX file with frontmatter
    {
        echo "---"
        echo "title: '$title'"
        echo "---"
        echo ""
        cat "$temp_md"
    } > "$output_file"
    
    rm "$temp_md"
}

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
            html_to_mdx "$html_file" "$mdx_file"
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
    
    echo "  Converting command-line-reference.html to MDX..."
    html_to_mdx "$TEMP_DIR/reference/command-line-reference.html" "reference/command-line-reference.mdx"
    echo "  Created reference/command-line-reference.mdx"
else
    echo "Warning: command-line-reference.html not found in zip"
fi

# Process Starlark library docs
echo "Processing Starlark library documentation..."
if [ -d "$TEMP_DIR/rules/lib" ]; then
    mkdir -p rules/lib

    # Convert HTML files to MDX
    file_count=0
    find "$TEMP_DIR/rules/lib" -name "*.html" -type f | while read -r html_file; do
        relative_path="${html_file#$TEMP_DIR/rules/lib/}"
        mdx_file="rules/lib/${relative_path%.html}.mdx"

        # Create directory structure
        mkdir -p "$(dirname "$mdx_file")"

        html_to_mdx "$html_file" "$mdx_file"
        file_count=$((file_count + 1))
    done
    
    echo "  Converted Starlark library documentation"
else
    echo "Warning: No rules/lib/ directory found in zip"
fi

echo ""
echo "Reference documentation processing complete!"
echo ""
echo "Summary:"
echo "  - Build Encyclopedia: reference/be/*.mdx"
echo "  - Command-Line Reference: reference/command-line-reference.mdx"
echo "  - Starlark Library: rules/lib/**/*.mdx"
echo ""
echo "All files have been converted from HTML to Markdown format."