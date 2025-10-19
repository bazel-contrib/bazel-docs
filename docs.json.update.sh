#!/usr/bin/env bash
# Create docs.json with versioned navigation

set -euo pipefail

# Read the versions and tabs
VERSIONS_FILE="docs-versions.json"
TABS_FILE="docs-tabs.json"
OUTPUT_FILE="docs.json"
INPUT_FILE="docs-no-versions.json"

# Start with the base structure
cp "$INPUT_FILE" "$OUTPUT_FILE"

if [ ! -s "$VERSIONS_FILE" ]; then
    echo "No versions found in $VERSIONS_FILE" >&2
    exit 1
fi

# Build the versions array using jq to avoid manual string building
VERSIONS_JSON=$(jq -n --slurpfile tabs "$TABS_FILE" --slurpfile versions "$VERSIONS_FILE" '
    ($tabs[0] // []) as $tabs_data |
    def prefix_tabs($version):
        $tabs_data
        | map(
            if has("groups") then
                .groups |= map(
                    if has("pages") then
                        .pages |= map($version + "/" + .)
                    else
                        .
                    end
                )
            else
                .
            end
        );

    def version_label($version):
        if $version == "HEAD" then
            "HEAD"
        else
            $version | sub("\\.[0-9]+$"; "")
        end;

    def build_entry($version):
        {
            version: version_label($version),
            languages: [
                {
                    language: "en",
                    tabs: (if $version == "HEAD" then $tabs_data else prefix_tabs($version) end)
                }
            ]
        };

    ($versions[0] // []) as $all_versions |
    ([$all_versions[] | select(. == "HEAD")]) as $head |
    ([$all_versions[] | select(. != "HEAD")]) as $others |
    ($head | map(build_entry(.))) + ($others | map(build_entry(.)))
')

# Update the navigation.versions field
jq --argjson versions "$VERSIONS_JSON" '.navigation.versions = $versions' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

count=$(jq 'length' "$VERSIONS_FILE")
echo "Created $OUTPUT_FILE with $count versions" 
