#!/usr/bin/env bash
set -euo pipefail

# HTML to Markdown Converter Script
# 
# This script converts HTML files to Markdown using a Go-based converter in Docker.
# 
# Usage:
#   ./script.sh                    # Uses default reference-docs.zip
#   ./script.sh path/to/file.zip   # Uses specified zip file
#
# The script will:
# 1. Check if the zip file exists
# 2. Inspect the zip contents to detect nested zip files
# 3. If nested zips are found, extract them automatically
# 4. Run the HTML-to-Markdown conversion using Docker
# 5. Output converted files to generated_reference_docs/

GO_IMAGE="golang:1.25.3"
WORKDIR="/app/html2md_converter"
MODULE="html-to-md-converter"
PKG="github.com/JohannesKaufmann/html-to-markdown"
REFERENCE_DIR="reference-docs-temp"

# Use first argument as zip file, or default to reference-docs.zip
ZIP_FILE="${1:-reference-docs.zip}"
TEMP_EXTRACT="temp_html_files"

mkdir -p "$REFERENCE_DIR"

# Check if zip file exists
if [[ ! -f "$ZIP_FILE" ]]; then
    echo "Error: $ZIP_FILE not found"
    exit 1
fi

# Check contents of the zip file
echo "Checking contents of $ZIP_FILE..."
unzip -l "$ZIP_FILE" | head -20

# Check if zip contains another zip file (nested zip)
if unzip -l "$ZIP_FILE" | grep -q '\.zip$'; then
    echo ""
    echo "Found nested zip file(s). Extracting..."
    mkdir -p "$TEMP_EXTRACT"
    unzip -q "$ZIP_FILE" -d "$TEMP_EXTRACT"
    
    # Find the nested zip file(s) and use the first one
    NESTED_ZIP=$(find "$TEMP_EXTRACT" -name "*.zip" -type f | head -1)
    
    if [[ -n "$NESTED_ZIP" ]]; then
        echo "Using nested zip: $NESTED_ZIP"
        # Convert to container path
        INPUT_PATH="/app/${NESTED_ZIP}"
    else
        echo "Error: Expected nested zip file but none found"
        rm -rf "$TEMP_EXTRACT"
        exit 1
    fi
else
    echo "No nested zip files found. Using zip directly..."
    INPUT_PATH="/app/$ZIP_FILE"
fi

# Run the conversion in Docker container
docker run --rm -it \
  -v "$PWD":/app \
  -w "$WORKDIR" \
  "$GO_IMAGE" \
  bash -lc '
    set -euo pipefail
    export PATH="/usr/local/go/bin:$PATH"

    echo "==> Initializing Go module (if needed)…"
    [[ -f go.mod ]] || go mod init html-to-md-converter

    echo "==> Ensuring dependency…"
    go get github.com/JohannesKaufmann/html-to-markdown
    go mod tidy

    echo "==> Building converter…"
    go build -o html-to-md main.go

    echo "==> Running converter…"
    ./html-to-md -zip "$1" -output "/app/'"$REFERENCE_DIR"'"
  ' -- "$INPUT_PATH"

# Cleanup temporary extraction directory if it exists
[[ -d "$TEMP_EXTRACT" ]] && rm -rf "$TEMP_EXTRACT"
rm -rf "htlm2md_converter/" # Clean up Go module files
