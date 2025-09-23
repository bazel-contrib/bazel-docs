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
"<Card title=\"" + .heading + "\" img=\"" + (.image_path) + "\"" +
(if .buttons then " cta=\"" + .buttons[0].label + "\" href=\"" + .buttons[0].path + "\"" else "" end) +
">" + "\n" +
.description + "\n" +
"</Card>" + "\n\n"
' >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE"
