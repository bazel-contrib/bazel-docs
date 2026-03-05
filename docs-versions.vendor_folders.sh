#!/usr/bin/env bash
# Create or update versioned subfolders for docs of all Bazel releases.
#
# This script does the following:
# Reads docs-versions.json to get all available versions
# Checks which version folders are missing
# For each missing version, resets the upstream/ submodule to that tag
# Runs the ./copy-upstream-docs.sh script to copy the docs to the version directory

set -euo pipefail

echo "Checking for missing version folders..."

# Get all versions from docs-versions.json, excluding HEAD
VERSIONS=$(jq -r '.[] | select(. != "HEAD")' docs-versions.json)

mkdir -p versions

# Check which folders are missing and create them
for VERSION in $VERSIONS; do
    VERSION_DIR="versions/$VERSION"
    if [ ! -d "$VERSION_DIR" ]; then
        echo "Creating missing folder for version: $VERSION_DIR"
        
        # Change to upstream directory and reset to the specific tag
        cd upstream
        echo "Resetting submodule to tag: $VERSION"
        git fetch origin "refs/tags/$VERSION:refs/tags/$VERSION"
        git reset --hard "$VERSION"
        
        # Go back to the root directory
        cd ..
        
        # Run the copy-upstream-docs.sh script with the version directory and version
        echo "Copying docs to directory: $VERSION_DIR"
        ./copy-upstream-docs.sh "$VERSION_DIR" "$VERSION"
        
        echo "Successfully created docs for version $VERSION"
    else
        echo "Folder $VERSION_DIR already exists, skipping"
    fi
done

echo "All version folders are now up to date!"