#!/usr/bin/env bash
# Update docs-versions.json with a list of Bazel versions that are relevant to document.
set -euo pipefail

# Don't show documentation for versions that are no longer supported
OLDEST_LTS_MAJOR=5

echo "Fetching Bazel tags and finding latest patch versions..."

# Get all tags once and store in temporary file
TAGS_FILE=$(mktemp)
gh api repos/bazelbuild/bazel/tags --paginate | \
  jq -rs '.[] | .[] | .name' | \
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
  grep -v "rc" > "$TAGS_FILE"

# Extract unique minor versions (skip versions earlier than 5.4)
# For current major version, include all minor versions
# For older major versions, only include the latest minor
MINOR_VERSIONS=$(cat "$TAGS_FILE" | \
  sed 's/\.[0-9]*$//' | \
  sort -V | \
  awk -F. "\$1 >= $OLDEST_LTS_MAJOR" | \
  uniq)

# Find the highest major version (current major)
CURRENT_MAJOR=$(echo "$MINOR_VERSIONS" | cut -d. -f1 | sort -n | tail -1)

# Filter to only include latest minor for each major (except current major)
FILTERED_MINOR_VERSIONS=""
for minor in $MINOR_VERSIONS; do
  MAJOR=$(echo "$minor" | cut -d. -f1)
  if [ "$MAJOR" = "$CURRENT_MAJOR" ]; then
    # Include all minor versions for current major
    FILTERED_MINOR_VERSIONS="$FILTERED_MINOR_VERSIONS $minor"
  else
    # For older majors, only include if it's the latest minor for that major
    LATEST_FOR_MAJOR=$(echo "$MINOR_VERSIONS" | grep "^$MAJOR\." | sort -V | tail -1)
    if [ "$minor" = "$LATEST_FOR_MAJOR" ]; then
      FILTERED_MINOR_VERSIONS="$FILTERED_MINOR_VERSIONS $minor"
    fi
  fi
done

MINOR_VERSIONS="$FILTERED_MINOR_VERSIONS"

echo "Found minor versions: $MINOR_VERSIONS"

# Create temporary file for versions
TEMP_FILE=$(mktemp)

# For each minor version, find the latest patch from the cached tags
for minor in $MINOR_VERSIONS; do
  echo "Finding latest patch for $minor..."
  
  # Get the latest patch version for this minor version from cached data
  LATEST_PATCH=$(grep -E "^$minor\.[0-9]+$" "$TAGS_FILE" | \
    sort -V | \
    tail -1)
  
  if [ -n "$LATEST_PATCH" ]; then
    echo "$LATEST_PATCH" >> "$TEMP_FILE"
    echo "  → $LATEST_PATCH"
  else
    echo "  → No stable patch found for $minor"
  fi
done

# Clean up tags file
rm "$TAGS_FILE"

# Sort the versions in reverse order (newest first) and add HEAD at the end
echo "Writing versions to docs-versions.json..."
echo "HEAD" > temp_sorted.txt
sort -Vr "$TEMP_FILE" >> temp_sorted.txt

# Convert to JSON array
jq -R -s 'split("\n") | map(select(length > 0))' temp_sorted.txt > docs-versions.json

# Clean up
rm "$TEMP_FILE" temp_sorted.txt

echo "Updated docs-versions.json with $(jq length docs-versions.json) versions:"
jq -r '.[]' docs-versions.json
