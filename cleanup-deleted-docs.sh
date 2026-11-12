#!/usr/bin/env bash

set -euo pipefail

# This script removes references to deleted documentation files from navigation.
# It's run after rsync deletes files to keep the search index in sync.

echo "Cleaning up deleted docs from navigation files..."

shopt -s nullglob
nav_files=(navigation/*.en.json)
if [[ ${#nav_files[@]} -eq 0 ]]; then
  echo "No navigation files found."
  exit 0
fi

# Extract all unique page references across all navigation files in a single jq invocation
pages=$(jq -r '.. | objects | select(has("pages")) | .pages[]? | select(type == "string")' "${nav_files[@]}" 2>/dev/null | sort -u || true)

declare -a deleted_files=()
while IFS= read -r page; do
  [[ -z "$page" ]] && continue
  if [[ ! -f "${page}.mdx" && ! -f "${page}.md" ]]; then
    deleted_files+=("$page")
  fi
done <<< "$pages"

if [[ ${#deleted_files[@]} -eq 0 ]]; then
  echo "No deleted files found in navigation."
  exit 0
fi

echo "Found ${#deleted_files[@]} deleted file(s) referenced in navigation:"
printf '  - %s\n' "${deleted_files[@]}"

# Build an O(1) lookup table of deleted page paths and strip them in one jq pass per file
remove_map=$(printf '%s\n' "${deleted_files[@]}" | jq -R . | jq -sc 'INDEX(.)')

for nav_file in "${nav_files[@]}"; do
  tmp=$(jq --argjson remove "$remove_map" '
    walk(
      if type == "array" then
        map(select((type == "string" and ($remove[.] != null)) | not))
      else
        .
      end
    )
  ' "$nav_file")
  printf '%s\n' "$tmp" > "$nav_file"
done

echo "Cleanup complete. Removed ${#deleted_files[@]} page reference(s) from navigation files."
