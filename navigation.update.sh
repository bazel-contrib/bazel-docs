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
ALL_VERSIONS=$(echo "$VERSIONS" | grep -v "^HEAD$" | sort -V || true)

# For major 6 and 7: keep only the most recent minor per major (e.g. 6.5.0 only, not 6.4.0, 6.3.0).
# For major 8 and 9+: keep all minors.
LATEST_6=$(echo "$ALL_VERSIONS" | grep "^6\." | tail -1 || true)
LATEST_7=$(echo "$ALL_VERSIONS" | grep "^7\." | tail -1 || true)
FILTERED=""
for v in $ALL_VERSIONS; do
  major="${v%%.*}"
  if [ "$major" = "6" ]; then
    [ "$v" = "$LATEST_6" ] && FILTERED="$FILTERED"$'\n'"$v"
  elif [ "$major" = "7" ]; then
    [ "$v" = "$LATEST_7" ] && FILTERED="$FILTERED"$'\n'"$v"
  else
    FILTERED="$FILTERED"$'\n'"$v"
  fi
done
# HEAD first, then versioned list newest-first (sort -Vr)
VERSIONS=$(echo "HEAD"; echo "$FILTERED" | grep -v '^$' | sort -Vr || true)

TABS_FILE="docs-tabs.json"
NAV_DIR="navigation"

# Only regenerate the HEAD nav; preserve existing versioned nav files so that
# Dependabot submodule bumps don't overwrite manual fixes (see #346).
rm -f "$NAV_DIR/HEAD.en.json"
mkdir -p "$NAV_DIR"

# Remove pages from a nav file whose .mdx/.md files don't exist on disk.
filter_missing_pages() {
    local nav_file="$1"
    local pages
    pages=$(jq -r '[.tabs | .. | .pages? // empty | .[] | select(type == "string")] | unique[]' "$nav_file")

    local missing=()
    while IFS= read -r page; do
        [ -z "$page" ] && continue
        if [ ! -f "${page}.mdx" ] && [ ! -f "${page}.md" ]; then
            missing+=("$page")
        fi
    done <<< "$pages"

    if [ ${#missing[@]} -gt 0 ]; then
        local remove_map
        remove_map=$(printf '%s\n' "${missing[@]}" | jq -R . | jq -sc 'reduce .[] as $p ({}; .[$p] = true)')
        local tmp
        tmp=$(jq --argjson rm "$remove_map" \
            'walk(if type == "array" then map(select((type != "string") or ($rm[.] | not))) else . end)' \
            "$nav_file")
        printf '%s\n' "$tmp" > "$nav_file"
    fi
}

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
        filter_missing_pages "$NAV_DIR/HEAD.en.json"
        REFS_JSON="$REFS_JSON{\"version\":\"HEAD\",\"languages\":[{\"\$ref\":\"./navigation/HEAD.en.json\"}]}"
    else
        DISPLAY_VERSION=$(echo "$version" | sed 's/\.[0-9]*$//')
        NAV_FILE="$NAV_DIR/$DISPLAY_VERSION.en.json"

        if [ -f "$NAV_FILE" ]; then
            echo "Keeping existing $DISPLAY_VERSION navigation"
            filter_missing_pages "$NAV_FILE"
        else
            echo "Creating new $DISPLAY_VERSION navigation"
            TABS_JSON=$(jq -c --arg version "$version" '
                map(.groups = (.groups | map(.pages = (.pages | map("versions/" + $version + "/" + .)))))
            ' "$TABS_FILE")
            jq -n --argjson tabs "$TABS_JSON" \
                '{"language":"en","tabs":$tabs}' \
                > "$NAV_FILE"
            filter_missing_pages "$NAV_FILE"
        fi

        REFS_JSON="$REFS_JSON{\"version\":\"$DISPLAY_VERSION\",\"languages\":[{\"\$ref\":\"./navigation/$DISPLAY_VERSION.en.json\"}]}"
    fi
done

REFS_JSON="$REFS_JSON]"

# Write navigation.json as an index of $ref entries
jq -n --argjson refs "$REFS_JSON" '{"versions": $refs}' > navigation.json

echo "Created navigation.json + $(echo "$VERSIONS" | wc -l | tr -d ' ') files in $NAV_DIR/"
