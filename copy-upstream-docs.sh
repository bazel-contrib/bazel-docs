#!/bin/bash

# Script to copy docs from upstream into a destination directory.
# For Bazel < 9: copies .md from upstream/site/en, transforms to .mdx.
# For Bazel 9+: copies .mdx (and .md) from upstream/docs as-is (no translation).
# Usage: ./copy-upstream-docs.sh [destination_directory] [bazel_version]
# If no destination is provided, defaults to current working directory.
# If bazel_version is provided and is 9.0.0 or later, uses upstream/docs/ and skips translation.

set -o errexit -o nounset -o pipefail

# Destination directory (default to current directory)
DEST_DIR="${1:-.}"
# Optional: Bazel version (e.g. 9.0.0) — when >= 9, use upstream/docs/ and skip translation
BAZEL_VERSION="${2:-}"

# Primary upstream directory (Bazel < 9)
UPSTREAM_SITE="upstream/site/en"
# Bazel 9+ upstream has pre-built .mdx in docs/
UPSTREAM_DOCS="upstream/docs"

# Reference docs directory
REFERENCE_DOCS="reference-docs-temp"

# Files that live in this repo, not fetched from upstream
LOCAL_FILES="
    index.mdx
"

# Files that are not valid MDX syntax
# This output pasted from a CI job - we should burn it down to zero
BROKEN_FILES="
community/roadmaps-configurability.mdx
concepts/build-files.mdx
concepts/dependencies.mdx
concepts/labels.mdx
contribute/docs-style-guide.mdx
contribute/search.mdx
docs/cc-toolchain-config-reference.mdx
docs/user-manual.mdx
extending/config.mdx
external/mod-command.mdx
external/registry.mdx
external/migration_tool.mdx
query/language.mdx
reference/be/functions.mdx
reference/be/platforms-and-toolchains.mdx
reference/command-line-reference.mdx
reference/flag-cheatsheet.mdx
reference/test-encyclopedia.mdx
remote/dynamic.mdx
rules/lib/globals/bzl.mdx
rules/lib/repo/cache.mdx
rules/lib/repo/git.mdx
rules/lib/repo/http.mdx
rules/lib/repo/local.mdx
rules/lib/repo/utils.mdx
rules/lib/globals/module.mdx
run/build.mdx
"

# Verify that at least one source exists
if [[ -n "$BAZEL_VERSION" ]]; then
  MAJOR="${BAZEL_VERSION%%.*}"
  if [[ "$MAJOR" -ge 9 ]]; then
    if [ ! -d "$UPSTREAM_DOCS" ]; then
      echo "Error: upstream/docs not found (required for Bazel 9+)"
      exit 1
    fi
  else
    if [ ! -d "$UPSTREAM_SITE" ] && [ ! -d "$REFERENCE_DOCS" ]; then
      echo "Error: neither source directory exists: '$UPSTREAM_SITE' or '$REFERENCE_DOCS'"
      exit 1
    fi
  fi
else
  if [ ! -d "$UPSTREAM_SITE" ] && [ ! -d "$REFERENCE_DOCS" ]; then
    echo "Error: neither source directory exists: '$UPSTREAM_SITE' or '$REFERENCE_DOCS'"
    exit 1
  fi
fi

if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# Bazel 9+ has pre-built .mdx in upstream/docs/ — copy as-is, no translation
if [[ -n "$BAZEL_VERSION" ]]; then
  MAJOR="${BAZEL_VERSION%%.*}"
  if [[ "$MAJOR" -ge 9 ]]; then
    if [ ! -d "$UPSTREAM_DOCS" ]; then
      echo "Error: upstream/docs not found (expected for Bazel 9+)"
      exit 1
    fi
    echo "Bazel $BAZEL_VERSION: copying from $UPSTREAM_DOCS to $DEST_DIR (no translation)"
    rsync -a --include='*/' --include='*.mdx' --include='*.md' --exclude='*' "$UPSTREAM_DOCS/" "$DEST_DIR/"
    echo "Done copying docs."
    exit 0
  fi
fi

echo "Will search in '$UPSTREAM_SITE' and '$REFERENCE_DOCS' (if exists) to copy .md → .mdx to $DEST_DIR"

transform_docs() {
    local SOURCE_DIR="$1"
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Warning: source directory '$SOURCE_DIR' not found, skipping"
        return
    fi

    find "$SOURCE_DIR" -name "*.md" -type f | while read -r source_file; do
        # Derive the relative path inside the source tree
        relative_path="${source_file#$SOURCE_DIR/}"
        target_file="${relative_path%.md}.mdx"
        target_dir=$(dirname "$DEST_DIR/$target_file")

        mkdir -p "$target_dir"

        # Check if this file is in the BROKEN_FILES list
        if echo "$BROKEN_FILES" | grep -q "^$target_file$"; then
            echo "Skipping broken file: $target_file"
            continue
        fi

    # Transform and copy the file
    echo "Transforming and copying $source_file to $DEST_DIR/$target_file"
    awk -f transform-docs.awk "$source_file" > "$DEST_DIR/$target_file"
    done
}

# Copy from both sources
transform_docs "$UPSTREAM_SITE"
transform_docs "$REFERENCE_DOCS"

echo "Converting community YAML files to MDX..."
for subdir in community/experts community/partners; do
  if [ -f "upstream/site/en/${subdir}/_index.yaml" ]; then
    ./convert-community-to-mdx.sh "$subdir"
  fi
done
if [ "$DEST_DIR" != "." ]; then
  mkdir -p "$DEST_DIR/community"
  for f in community/experts.mdx community/partners.mdx; do
    [ -f "$f" ] && mv "$f" "$DEST_DIR/community/"
  done
fi

echo "Copying community images..."
mkdir -p "$DEST_DIR/community/images"
cp upstream/site/en/community/images/* "$DEST_DIR/community/images/"

echo "Done copying docs."
