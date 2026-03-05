#!/usr/bin/env bash
# Create docs.json with versioned navigation
# Version list is derived from upstream/docs/versions/ (subdirectory names).

set -euo pipefail

# Get versions: HEAD first, then subdirs of upstream/docs/versions/ (or versions/ after rsync).
# All versioned page paths use a "versions/VERSION/" prefix (e.g. versions/7.6.2/basics).
if [ -d "upstream/docs/versions" ]; then
  VERSION_DIRS="upstream/docs/versions"
elif [ -d "versions" ]; then
  VERSION_DIRS="versions"
else
  echo "Error: neither upstream/docs/versions nor versions/ found. Need upstream checkout or synced docs."
  exit 1
fi
VERSIONS="HEAD"
for d in "$VERSION_DIRS"/*/; do
  [ -d "$d" ] && VERSIONS="$VERSIONS"$'\n'"$(basename "$d")"
done
ALL_VERSIONS=$(echo "$VERSIONS" | grep -v "^HEAD$" | sort -V)

# For major 6 and 7: keep only the most recent minor per major (e.g. 6.5.0 only, not 6.4.0, 6.3.0).
# For major 8 and 9+: keep all minors.
FILTERED=""
for v in $ALL_VERSIONS; do
  major="${v%%.*}"
  if [ "$major" = "6" ] || [ "$major" = "7" ]; then
    latest_for_major=$(echo "$ALL_VERSIONS" | grep "^${major}\." | sort -V | tail -1)
    [ "$v" = "$latest_for_major" ] && FILTERED="$FILTERED"$'\n'"$v"
  else
    FILTERED="$FILTERED"$'\n'"$v"
  fi
done
# HEAD first, then versioned list newest-first (sort -Vr)
VERSIONS=$(echo "HEAD"; echo "$FILTERED" | grep -v '^$' | sort -Vr)

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
    
    # For other versions, add versions/VERSION prefix to paths and strip patch version
    TABS_JSON=$(jq -c --arg version "$version" '
        map(.groups = (.groups | map(.pages = (.pages | map("versions/" + $version + "/" + .)))))
    ' "$TABS_FILE")
    DISPLAY_VERSION=$(echo "$version" | sed 's/\.[0-9]*$//')
    
    VERSIONS_JSON="$VERSIONS_JSON{\"version\":\"$DISPLAY_VERSION\",\"languages\":[{\"language\":\"en\",\"tabs\":$TABS_JSON}]}"
done

VERSIONS_JSON="$VERSIONS_JSON]"

# Update the navigation.versions field
jq --argjson versions "$VERSIONS_JSON" '.navigation.versions = $versions' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo "Created $OUTPUT_FILE with $(echo "$VERSIONS" | wc -l) versions"
