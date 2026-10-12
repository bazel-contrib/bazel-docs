#!/usr/bin/env bash

set -euo pipefail

# This script removes references to deleted documentation files from navigation.
# It's run after rsync deletes files to keep the search index in sync.

# Find all page references in navigation files that don't have corresponding source files
# and remove them from the navigation structure.

echo "Cleaning up deleted docs from navigation files..."

# Get list of deleted files by finding all referenced pages that don't exist
declare -a deleted_files
deleted_files=()

for nav_file in navigation/*.en.json; do
  if [[ ! -f "$nav_file" ]]; then
    continue
  fi

  # Extract all page references from the navigation file
  pages=$(jq -r '.. | objects | select(has("pages")) | .pages[]?' "$nav_file" 2>/dev/null || true)

  while IFS= read -r page; do
    [[ -z "$page" ]] && continue

    # Check if the .mdx or .md file exists
    if [[ ! -f "${page}.mdx" && ! -f "${page}.md" ]]; then
      # Check if this is not already in our deleted list
      if [[ ! " ${deleted_files[@]:-} " =~ " ${page} " ]]; then
        deleted_files+=("$page")
      fi
    fi
  done <<< "$pages"
done

if [[ ${#deleted_files[@]} -eq 0 ]]; then
  echo "No deleted files found in navigation."
  exit 0
fi

echo "Found ${#deleted_files[@]} deleted file(s) referenced in navigation:"
printf '  - %s\n' "${deleted_files[@]}"

# Remove the deleted files from all navigation files
for nav_file in navigation/*.en.json; do
  if [[ ! -f "$nav_file" ]]; then
    continue
  fi

  for deleted_page in "${deleted_files[@]}"; do
    # Use jq to remove the page from the pages array
    tmp=$(jq --arg p "$deleted_page" '
      walk(
        if type == "array" then
          map(select(. != $p))
        else
          .
        end
      )
    ' "$nav_file")
    echo "$tmp" > "$nav_file"
  done
done

echo "Cleanup complete. Removed ${#deleted_files[@]} page reference(s) from navigation files."
