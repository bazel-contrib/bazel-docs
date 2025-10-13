#!/bin/bash

# Local test script for HTML to Markdown converter
# This runs the converter in a Go Docker container

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Testing HTML to Markdown Converter with Docker ===${NC}\n"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if zip file exists
ZIP_FILE="${1:-reference-docs.zip}"
if [ ! -f "$ZIP_FILE" ]; then
    echo -e "${RED}Error: Zip file '$ZIP_FILE' not found${NC}"
    echo "Usage: $0 [path-to-zip-file]"
    echo "Example: $0 upstream/bazel-bin/src/main/java/com/google/devtools/build/lib/reference-docs.zip"
    exit 1
fi

# Get absolute path to zip file
ZIP_FILE_ABS=$(cd "$(dirname "$ZIP_FILE")" && pwd)/$(basename "$ZIP_FILE")

echo -e "${GREEN}✓${NC} Found zip file: $ZIP_FILE_ABS"

# Create output directory
OUTPUT_DIR="reference-docs-temp"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}✓${NC} Created output directory: $OUTPUT_DIR"

# Run converter in Docker container
echo -e "\n${BLUE}Running converter in Go Docker container...${NC}\n"

docker run --rm \
  -v "$(pwd)/html2md_converter:/app" \
  -v "$ZIP_FILE_ABS:/input/reference-docs.zip:ro" \
  -v "$(pwd)/$OUTPUT_DIR:/output" \
  -w /app \
  golang:1.21 \
  bash -c "
    echo '==> Initializing Go module...'
    go mod init html-to-md-converter
    go get github.com/JohannesKaufmann/html-to-markdown
    
    echo '==> Building converter...'
    go build -o html-to-md main.go
    
    echo '==> Running conversion...'
    ./html-to-md -zip /input/reference-docs.zip -output /output
    
    echo '==> Done!'
  "

echo -e "\n${GREEN}✓${NC} Conversion complete!"

# Show results
echo -e "\n${BLUE}=== Results ===${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Directory structure:"
tree -L 3 "$OUTPUT_DIR" 2>/dev/null || find "$OUTPUT_DIR" -type f | head -20

echo -e "\n${BLUE}=== Sample converted file (before AWK) ===${NC}"
SAMPLE_FILE=$(find "$OUTPUT_DIR" -name "*.md" -type f | head -1)
if [ -n "$SAMPLE_FILE" ]; then
    echo "File: $SAMPLE_FILE"
    echo "---"
    head -30 "$SAMPLE_FILE"
    echo "..."
else
    echo "No markdown files found"
fi

# Run AWK transformation
echo -e "\n${BLUE}=== Running AWK transformation (MD -> MDX) ===${NC}"

if [ ! -f "transform-docs.awk" ]; then
    echo -e "${RED}Error: transform-docs.awk not found in current directory${NC}"
    echo "Skipping AWK transformation step"
else
    echo "Transforming to root-level reference/ and rules/ directories..."
    echo "(This matches the GitHub workflow output structure)"
    echo ""
    
    # Clean up any existing output directories
    rm -rf reference rules
    
    echo "Transforming reference/ directory..."
    find "$OUTPUT_DIR/reference" -name "*.md" -type f 2>/dev/null | while read -r file; do
        # Extract path relative to reference-docs-temp/
        rel_path="${file#$OUTPUT_DIR/}"
        output_file="$rel_path"
        output_file="${output_file%.md}.mdx"
        
        # Create directory structure
        mkdir -p "$(dirname "$output_file")"
        
        # Transform file
        awk -f transform-docs.awk "$file" > "$output_file"
        echo "  ✓ $rel_path -> $output_file"
    done
    
    # Copy YAML files from reference/
    find "$OUTPUT_DIR/reference" -name "*.yaml" -type f 2>/dev/null | while read -r file; do
        rel_path="${file#$OUTPUT_DIR/}"
        output_file="$rel_path"
        mkdir -p "$(dirname "$output_file")"
        cp "$file" "$output_file"
        echo "  ✓ Copied $rel_path"
    done
    
    echo ""
    echo "Transforming rules/ directory..."
    find "$OUTPUT_DIR/rules" -name "*.md" -type f 2>/dev/null | while read -r file; do
        # Extract path relative to reference-docs-temp/
        rel_path="${file#$OUTPUT_DIR/}"
        output_file="$rel_path"
        output_file="${output_file%.md}.mdx"
        
        mkdir -p "$(dirname "$output_file")"
        awk -f transform-docs.awk "$file" > "$output_file"
        echo "  ✓ $rel_path -> $output_file"
    done
    
    # Copy YAML files from rules/
    find "$OUTPUT_DIR/rules" -name "*.yaml" -type f 2>/dev/null | while read -r file; do
        rel_path="${file#$OUTPUT_DIR/}"
        output_file="$rel_path"
        mkdir -p "$(dirname "$output_file")"
        cp "$file" "$output_file"
        echo "  ✓ Copied $rel_path"
    done
    
    echo -e "\n${GREEN}✓${NC} AWK transformation complete!"
    
    # Show MDX output
    echo -e "\n${BLUE}=== MDX Output Directories (Root Level) ===${NC}"
    echo "Output directories:"
    echo "  - reference/"
    echo "  - rules/"
    echo ""
    echo "Directory structure:"
    echo ""
    echo "reference/:"
    tree -L 3 reference 2>/dev/null || find reference -type f | head -20
    echo ""
    echo "rules/:"
    tree -L 3 rules 2>/dev/null || find rules -type f | head -20
    
    echo -e "\n${BLUE}=== Sample MDX file (after AWK) ===${NC}"
    SAMPLE_MDX=$(find reference -name "*.mdx" -type f 2>/dev/null | head -1)
    if [ -z "$SAMPLE_MDX" ]; then
        SAMPLE_MDX=$(find rules -name "*.mdx" -type f 2>/dev/null | head -1)
    fi
    if [ -n "$SAMPLE_MDX" ]; then
        echo "File: $SAMPLE_MDX"
        echo "---"
        head -40 "$SAMPLE_MDX"
        echo "..."
    fi
fi

echo -e "\n${GREEN}✓${NC} Test complete!"
echo -e "\nOutput directories:"
echo "  - Markdown (HTML->MD): $OUTPUT_DIR"
if [ -d "reference" ] && [ -d "rules" ]; then
    echo "  - MDX (MD->MDX):       reference/ and rules/ (at repo root)"
fi