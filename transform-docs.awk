#!/usr/bin/awk -f

# Transform script for converting Bazel docs to Mintlify format
# Usage: awk -f transform-docs.awk input.md > output.mdx

BEGIN {
    in_frontmatter = 0
    first_h1_found = 0
    frontmatter_printed = 0
}

# Skip Jekyll front-matter lines
/^Project: \/_project\.yaml$/ { next }
/^Book: \/_book\.yaml$/ { next }

# Remove lines that contain only '{% include "_buttons.html" %}'
/^{% include "_buttons\.html" %}$/ { next }

# Convert first H1 to front-matter
/^# / && first_h1_found == 0 {
    title = substr($0, 3)  # Remove "# " prefix
    gsub(/^[ \t]+|[ \t]+$/, "", title)  # Trim whitespace
    print "---"
    print "title: '" title "'"
    print "---"
    print ""
    first_h1_found = 1
    next
}

# Print all other lines
{
    print
}
