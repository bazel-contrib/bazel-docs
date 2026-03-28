#!/usr/bin/env bash
# Create navigation.json and per-version language files under navigation/.
# docs.json references navigation.json via "$ref": "./navigation.json".
# navigation.json references each version's language file via "$ref": "./navigation/VERSION.en.json".
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
NAV_DIR="navigation"

# Clean and recreate the per-version directory
rm -f "$NAV_DIR"/*.json
mkdir -p "$NAV_DIR"

# Build the $ref list for navigation.json as we write each file
REFS_JSON="["
FIRST=true

for version in $VERSIONS; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        REFS_JSON="$REFS_JSON,"
    fi

    if [ "$version" = "HEAD" ]; then
        TABS_JSON=$(jq -c . "$TABS_FILE")
        jq -n --argjson tabs "$TABS_JSON" \
            '{"language":"en","tabs":$tabs}' \
            > "$NAV_DIR/HEAD.en.json"
        REFS_JSON="$REFS_JSON{\"version\":\"HEAD\",\"languages\":[{\"\$ref\":\"./navigation/HEAD.en.json\"}]}"
    else
        DISPLAY_VERSION=$(echo "$version" | sed 's/\.[0-9]*$//')
        TABS_JSON=$(jq -c --arg version "$version" '
            map(.groups = (.groups | map(.pages = (.pages | map("versions/" + $version + "/" + .)))))
        ' "$TABS_FILE")
        jq -n --argjson tabs "$TABS_JSON" \
            '{"language":"en","tabs":$tabs}' \
            > "$NAV_DIR/$DISPLAY_VERSION.en.json"
        REFS_JSON="$REFS_JSON{\"version\":\"$DISPLAY_VERSION\",\"languages\":[{\"\$ref\":\"./navigation/$DISPLAY_VERSION.en.json\"}]}"
    fi
done

REFS_JSON="$REFS_JSON]"

# Write navigation.json as an index of $ref entries
jq -n --argjson refs "$REFS_JSON" '{"versions": $refs}' > navigation.json

echo "Created navigation.json + $(echo "$VERSIONS" | wc -l | tr -d ' ') files in $NAV_DIR/"
