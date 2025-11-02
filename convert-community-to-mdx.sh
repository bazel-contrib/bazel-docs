#!/bin/bash

# Script to convert community YAML files to MDX using yq
# Usage: ./convert-community-to-mdx.sh [experts|partners]

set -e

# $1 is the source topic (e.g., "community/experts")
# $2 is the destination base path (e.g., "my-docs/community/experts")
SOURCE_TOPIC=${1}
DEST_BASE_PATH=${2}

INPUT_FILE="upstream/site/en/${SOURCE_TOPIC}/_index.yaml"
TITLE=$(yq eval '.landing_page.rows[0].heading' "$INPUT_FILE")
DESCRIPTION=$(yq eval '.landing_page.rows[0].description' "$INPUT_FILE")

OUTPUT_FILE="${DEST_BASE_PATH}.mdx"
# Create the MDX file
cat > "$OUTPUT_FILE" << EOF
---
title: '$TITLE'
---

$DESCRIPTION

---

EOF

# Process each expert item and group into pairs
yq eval '.landing_page.rows[0].items[]' "$INPUT_FILE" -o json | jq -r '
"<Card title=\"" + .heading + "\" img=\"" + (.image_path) + "\"" +
(if .buttons then " cta=\"" + .buttons[0].label + "\" href=\"" + .buttons[0].path + "\"" else "" end) +
">" + "\n" +
.description + "\n" +
"</Card>"
' | awk '
BEGIN { 
    count = 0
    card_buffer = ""
}
/^<Card/ {
    if (count % 2 == 0) {
        print "<Columns cols={2}>"
    }
    card_buffer = $0
    next
}
{
    card_buffer = card_buffer "\n" $0
}
/^<\/Card>/ {
    print card_buffer
    count++
    if (count % 2 == 0) {
        print "</Columns>"
        print ""
    }
    card_buffer = ""
}
END {
    if (count % 2 == 1) {
        print "</Columns>"
        print ""
    }
}' >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE"
