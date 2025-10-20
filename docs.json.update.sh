#!/usr/bin/env bash
# Create docs.json with versioned navigation

set -euo pipefail

# Read the versions and tabs
VERSIONS=$(jq -r '.[]' docs-versions.json)
TABS_FILE="docs-tabs.json"
OUTPUT_FILE="docs.json"
INPUT_FILE="docs-no-versions.json"

# Start with the base structure
cp "$INPUT_FILE" "$OUTPUT_FILE"

# Create versions array - HEAD first, then others
VERSIONS_JSON="["
FIRST=true

# Process HEAD first if it exists
if echo "$VERSIONS" | grep -q "^HEAD$"; then
    TABS_JSON=$(jq -c . "$TABS_FILE")
    VERSIONS_JSON="$VERSIONS_JSON{\"version\":\"HEAD\",\"languages\":[{\"language\":\"en\",\"tabs\":$TABS_JSON}]}"
    FIRST=false
fi

# Process other versions
for version in $VERSIONS; do
    if [ "$version" = "HEAD" ]; then
        continue  # Already processed
    fi
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        VERSIONS_JSON="$VERSIONS_JSON,"
    fi
    
    # For other versions, add version prefix to paths and strip patch version
    TABS_JSON=$(jq -c --arg version "$version" '
        map(.groups = (.groups | map(.pages = (.pages | map($version + "/" + .)))))
    ' "$TABS_FILE")
    DISPLAY_VERSION=$(echo "$version" | sed 's/\.[0-9]*$//')
    
    VERSIONS_JSON="$VERSIONS_JSON{\"version\":\"$DISPLAY_VERSION\",\"languages\":[{\"language\":\"en\",\"tabs\":$TABS_JSON}]}"
done

VERSIONS_JSON="$VERSIONS_JSON]"

# Update the navigation.versions field
jq --argjson versions "$VERSIONS_JSON" '.navigation.versions = $versions' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo "Created $OUTPUT_FILE with $(echo "$VERSIONS" | wc -l) versions"
