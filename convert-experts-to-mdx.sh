#!/bin/bash

# Script to convert community YAML files to MDX using yq
# Usage: ./convert-community-to-mdx.sh [experts|partners]

set -e

# Default to experts if no argument provided
TYPE=${1:-experts}

if [ "$TYPE" = "experts" ]; then
    INPUT_FILE="upstream/site/en/community/experts/_index.yaml"
    OUTPUT_FILE="community/experts.mdx"
elif [ "$TYPE" = "partners" ]; then
    INPUT_FILE="upstream/site/en/community/partners/_index.yaml"
    OUTPUT_FILE="community/partners.mdx"
else
    echo "Error: Invalid type '$TYPE'. Must be 'experts' or 'partners'"
    exit 1
fi

# Extract metadata
TITLE=$(yq eval '.landing_page.rows[0].heading' "$INPUT_FILE")
DESCRIPTION=$(yq eval '.landing_page.rows[0].description' "$INPUT_FILE")

# Create the MDX file
cat > "$OUTPUT_FILE" << EOF
---
title: '$TITLE'
---

$DESCRIPTION

---

EOF

# Process each expert item
yq eval '.landing_page.rows[0].items[]' "$INPUT_FILE" -o json | jq -r '
"## " + .heading + "\n\n" +
"![" + .heading + "](" + .image_path + ")\n\n" +
.description + "\n\n" +
(if .buttons then (.buttons | map("- [" + .label + "](" + .path + ")") | join("\n")) + "\n\n" else "" end) +
"---\n"
' >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE"
