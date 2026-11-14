#!/usr/bin/env bash

set -euo pipefail

# This script removes references to deleted documentation files from navigation.
# It's run after rsync deletes files to keep the search index in sync.

echo "Cleaning up deleted docs from navigation files..."

total_removed=0

for nav_file in navigation/*.en.json; do
  if [[ ! -f "$nav_file" ]]; then
    continue
  fi

  # Extract unique string page references in this navigation file
  pages=$(jq -r '[.. | objects | select(has("pages")) | .pages[]? | select(type == "string")] | unique[]' "$nav_file" 2>/dev/null || true)
  [[ -z "$pages" ]] && continue

  missing=()
  while IFS= read -r page; do
    [[ -z "$page" ]] && continue
    if [[ ! -f "${page}.mdx" && ! -f "${page}.md" ]]; then
      missing+=("$page")
    fi
  done <<< "$pages"

  if [[ ${#missing[@]} -eq 0 ]]; then
    continue
  fi

  echo "Removing ${#missing[@]} deleted page reference(s) from ${nav_file}:"
  printf '  - %s\n' "${missing[@]}"

  remove_map=$(printf '%s\n' "${missing[@]}" | jq -R . | jq -sc 'reduce .[] as $p ({}; .[$p] = true)')
  tmp=$(jq --argjson rm "$remove_map" '
    walk(
      if type == "array" then
        map(select((type != "string") or ($rm[.] | not)))
      else
        .
      end
    )
  ' "$nav_file")
  printf '%s\n' "$tmp" > "$nav_file"
  total_removed=$((total_removed + ${#missing[@]}))
done

if [[ "$total_removed" -eq 0 ]]; then
  echo "No deleted files found in navigation."
else
  echo "Cleanup complete. Removed ${total_removed} page reference(s) across navigation files."
fi
