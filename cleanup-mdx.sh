#!/bin/bash

# Script to delete all .mdx files except those in LOCAL_FILES
# Usage: ./cleanup-mdx.sh

set -e

# Files that should be kept (from copy-upstream-docs.sh) - exact paths
LOCAL_FILES="
    ./index.mdx
"

echo "Cleaning up .mdx files..."

# Find all .mdx files in the repo, excluding versioned directories
# This excludes any directory starting with a digit (e.g., 6.5.0, 7.6.1, 8.0.1)
find . -name "*.mdx" -type f \
  -not -path "./[0-9]*/*" \
  -not -path "./.github/*" | while read -r mdx_file; do
    
    # Check if this exact file path is in LOCAL_FILES
    if echo "$LOCAL_FILES" | grep -q "^\s*$mdx_file\s*$"; then
        echo "Keeping: $mdx_file (in LOCAL_FILES)"
    else
        echo "Deleting: $mdx_file"
        rm "$mdx_file"
    fi
done

echo "Cleanup complete!"
