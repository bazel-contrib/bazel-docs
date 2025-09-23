#!/bin/bash

# Script to convert community YAML files to MDX using yq
# Usage: ./convert-community-to-mdx.sh [experts|partners]

set -e

FILE=${1}
INPUT_FILE="upstream/site/en/${FILE}/_index.yaml"
TITLE=$(yq eval '.landing_page.rows[0].heading' "$INPUT_FILE")
DESCRIPTION=$(yq eval '.landing_page.rows[0].description' "$INPUT_FILE")

OUTPUT_FILE="${FILE}.mdx"
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
"![" + .heading + "](" + (.image_path | gsub("^/community/images/"; "/upstream/site/en/community/images/")) + ")\n\n" +
.description + "\n\n" +
(if .buttons then (.buttons | map("- [" + .label + "](" + .path + ")") | join("\n")) + "\n\n" else "" end) +
"---\n"
' >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE"
