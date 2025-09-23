#!/usr/bin/awk -f

# Transform script for converting Bazel docs to Mintlify format
# Usage: awk -f transform-docs.awk input.md > output.mdx

BEGIN {
    in_frontmatter = 0
    first_h1_found = 0
    frontmatter_printed = 0
    before_first_h1 = 1
}

# Skip Jekyll front-matter lines
/^Project: \/_project\.yaml$/ { next }
/^Book: \/_book\.yaml$/ { next }

# Remove lines that contain only '{% include "_buttons.html" %}'
/^{% include "_buttons\.html" %}$/ { next }

# Remove lines containing '{% dynamic setvar'
/{% dynamic setvar/ { next }

# Remove any lines that start with '{%'
/^{%/ { next }

# Convert HTML comments to MDX comments
/^<!-- .* -->$/ {
    gsub(/^<!-- /, "// ", $0)
    gsub(/ -->$/, "", $0)
    # Skip TOC comments
    if ($0 == "// [TOC]") {
        next
    }
    print
    next
}

# Convert <pre> tags to markdown code blocks
/^<pre>/ {
    gsub(/^<pre>/, "```")
    gsub(/<\/pre>$/, "```")
    print
    next
}

# Remove </pre> tags that appear at the end of lines
{
    gsub(/<\/pre>$/, "```", $0)
}

# Remove anchor parts from headings (e.g., ## Title {:#anchor})
/^#+ .* \{:#[^}]*\}$/ {
    # Extract the heading text without the anchor
    heading = $0
    gsub(/\s*\{:#[^}]*\}$/, "", heading)
    # Trim trailing whitespace
    gsub(/[ \t]+$/, "", heading)
    print heading
    next
}

# Remove lines that contain only '{: .external}'
/^\s*\{\s*:\s*\.external\s*\}\s*$/ { next }

# Remove '{: .external}' anywhere it appears
{
    gsub(/\{: \.external\}/, "", $0)
}

# Skip blank lines before first H1
/^[ \t]*$/ && before_first_h1 == 1 { next }

# Convert first H1 to front-matter
/^# / && first_h1_found == 0 {
    title = substr($0, 3)  # Remove "# " prefix
    gsub(/^[ \t]+|[ \t]+$/, "", title)  # Trim whitespace
    print "---"
    print "title: '" title "'"
    print "---"
    print ""
    first_h1_found = 1
    before_first_h1 = 0
    next
}

# Print all other lines
{
    print
}
