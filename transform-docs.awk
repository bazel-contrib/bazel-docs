#!/usr/bin/awk -f
# Transform script for converting Bazel docs to Mintlify MDX format
# Usage: awk -f transform-docs.awk input.md > output.mdx

BEGIN {
    in_frontmatter = 0
    first_h1_found = 0
    frontmatter_printed = 0
    before_first_h1 = 1
    in_code_block = 0
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

# Track code blocks to avoid processing their content
/^```/ {
    in_code_block = !in_code_block
    print
    next
}

# Don't process lines inside code blocks
in_code_block {
    print
    next
}

# Convert HTML comments to MDX comments
/<!-- / {
    # Multi-line comment handling
    if (/<!-- .* -->/) {
        # Single line comment
        gsub(/<!--/, "{/*", $0)
        gsub(/-->/, "*/}", $0)
        print
        next
    } else {
        # Start of multi-line comment
        gsub(/<!--/, "{/*", $0)
        print
        next
    }
}

# End of multi-line comment
/--> *$/ {
    gsub(/-->/, "*/}", $0)
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

# Fix <pre> tags that don't close properly
/<pre[^>]*>/ {
    # If it has content after the tag and ends with ```, it's malformed
    if (/<pre[^>]*>[^<]*```$/) {
        # Replace <pre...>content``` with just content (already has ```)
        gsub(/<pre[^>]*>/, "", $0)
        print
        next
    }
    # If it has content after the tag, it's likely malformed
    if (/<pre[^>]*>[^<]*$/) {
        gsub(/<pre[^>]*>/, "```", $0)
    }
}

# Remove </pre> tags that appear at the end of lines
{
    gsub(/<\/pre>$/, "```", $0)
}

# Remove anchor parts from headings (e.g., ## Title {:#anchor})
/^#+ .* \{:#[^}]*\}$/ {
    heading = $0
    gsub(/\s*\{:#[^}]*\}$/, "", heading)
    gsub(/[ \t]+$/, "", heading)
    print heading
    next
}

# Remove anchor syntax like {:flag--deleted_packages} or {: .external}
{
    gsub(/\{:[^}]*\}/, "", $0)
}

# Fix common Jekyll/Kramdown patterns that break MDX
{
    # Remove {# ... #} Jekyll comments - be more aggressive
    while (match($0, /\{#[^}]*#\}/)) {
        gsub(/\{#[^}]*#\}/, "", $0)
    }
}

# Fix problematic {{ "<var>" }} and {{ '</var>' }} patterns
{
    # These double curly braces with quotes break acorn parser
    gsub(/\{\{ *"<var>" *\}\}/, "<var>", $0)
    gsub(/\{\{ *"<\/var>" *\}\}/, "</var>", $0)
    gsub(/\{\{ *'<var>' *\}\}/, "<var>", $0)
    gsub(/\{\{ *'<\/var>' *\}\}/, "</var>", $0)
}

# Fix &lt; and &gt; that should be escaped differently in MDX
{
    # In attribute values, convert &lt; and &gt; to actual < >
    # This is safer in JSX/MDX
    while (match($0, /="[^"]*&[lg]t;[^"]*"/)) {
        gsub(/&lt;/, "<", $0)
        gsub(/&gt;/, ">", $0)
    }
}

# Fix empty thead tags - <thead></th> should be <thead>
{
    # Multiple variations of broken thead
    gsub(/<thead><\/th>/, "<thead>", $0)
    gsub(/<thead><\/thead>/, "<thead>", $0)
    
    # Also fix lines that are ONLY </th> after a thead
    if ($0 ~ /^<\/th>$/ || $0 ~ /^[ \t]*<\/th>[ \t]*$/) {
        next  # Skip this line entirely
    }
}

# Fix malformed <img> tags with align attribute without quotes
{
    # align=right should be align="right"
    gsub(/align=right/, "align=\"right\"", $0)
    gsub(/align=left/, "align=\"left\"", $0)
    gsub(/align=center/, "align=\"center\"", $0)
}

# Fix malformed <col> tags - CORRECTED VERSION
{
    # First, handle <col> with no attributes
    gsub(/<col>/, "<col />", $0)
    
    # Then handle <col ...> with attributes but no self-closing slash
    # We need to find <col followed by attributes followed by > (not />)
    while (match($0, /<col [^>\/]*>/)) {
        # Get the matched string
        pre = substr($0, 1, RSTART - 1)
        matched = substr($0, RSTART, RLENGTH)
        post = substr($0, RSTART + RLENGTH)
        
        # Remove the trailing > and add />
        matched = substr(matched, 1, length(matched) - 1) " />"
        $0 = pre matched post
    }
}

# Close other self-closing HTML tags properly
{
    # Fix <br> tags
    gsub(/<br>/, "<br />", $0)
    
    # Fix <img> tags - ensure they're self-closing
    while (match($0, /<img[^>]*[^\/]>/)) {
        pre = substr($0, 1, RSTART - 1)
        tag = substr($0, RSTART, RLENGTH)
        post = substr($0, RSTART + RLENGTH)
        # Remove the trailing > and add />
        tag = substr(tag, 1, length(tag) - 1) " />"
        $0 = pre tag post
    }
    
    # Fix <hr> tags
    gsub(/<hr>/, "<hr />", $0)
}

# Fix unclosed <p> tags
{
    # If we have <p> but no closing tag on the same line, and line ends with text
    if (/<p[^>]*>/ && !/<\/p>/ && $0 !~ /<\/(div|table|ul|ol|blockquote)>$/) {
        # Check if it's just a <p> with content and no closing
        if ($0 ~ /<p[^>]*>[^<]+$/) {
            $0 = $0 "</p>"
        }
    }
}

# Fix unclosed <code> tags in <code class="..."> patterns
{
    # Fix escaped underscores in code tags like \_ 
    # These appear in patterns like noimplicit\_deps
    if (/<code>.*\\_.*<\/code>/) {
        gsub(/\\_/, "_", $0)
    }
    
    # If we have opening <code> but line doesn't end with </code>
    if (/<code[^>]*>/ && !/<\/code>/) {
        # Look for the pattern and close it properly
        if ($0 ~ /<code[^>]*>[^<]*$/) {
            $0 = $0 "</code>"
        }
    }
}

# Fix unclosed <td> and <th> tags at end of lines (common in tables)
/<td[^>]*>[^<]*$/ {
    # Only add closing tag if there isn't already one
    if ($0 !~ /<\/td>$/) {
        $0 = $0 "</td>"
    }
}

# Be more careful with <th> - don't match <thead>
/^[^<]*<th[^e]/ && /<th[^>]*>[^<]*$/ {
    if ($0 !~ /<\/th>$/) {
        $0 = $0 "</th>"
    }
}

# Fix malformed <a> tags
{
    # Ensure href has quotes
    while (match($0, /<a ([^>]*)href=([^"'][^ >]+)/)) {
        pre = substr($0, 1, RSTART - 1)
        match_str = substr($0, RSTART, RLENGTH)
        post = substr($0, RSTART + RLENGTH)
        gsub(/href=([^"'][^ >]+)/, "href=\"\\1\"", match_str)
        $0 = pre match_str post
    }
    
    # Fix broken <a href="\1" pattern - remove the \1
    gsub(/<a href="\\1"/, "<a href=\"#\"", $0)
}

# Fix special characters in text that break JSX parsing
{
    # Escape curly braces in code examples like select({ ... })
    # But only if they're NOT in backticks
    if ($0 ~ /\{['"]/ && $0 ~ /['"]\}/ && $0 !~ /`[^`]*\{[^`]*\}[^`]*`/) {
        # Escape curly braces in dictionary/object literals like {'cpu': 'ppc'}
        # outside of code blocks
        gsub(/\{'/, "\\{'", $0)
        gsub(/'\}/, "'\\}", $0)
        gsub(/\{"/, "\\{\"", $0)
        gsub(/"\}/, "\"\\}", $0)
    }
}

# Escape angle brackets in specific contexts (like #include <foo>)
{
    # Escape angle brackets in text that looks like C++ includes
    # Pattern: #include <something.h> or e.g. #include <foo/bar.h>
    if ($0 ~ /#include </) {
        gsub(/#include </, "#include \\&lt;", $0)
        # Find the closing > and escape it too
        gsub(/\.h>/, ".h\\&gt;", $0)
    }
}

# Skip blank lines before first H1
/^[ \t]*$/ && before_first_h1 == 1 { next }

# Convert first H1 to front-matter
/^# / && first_h1_found == 0 {
    title = substr($0, 3)  # Remove "# " prefix
    gsub(/^[ \t]+|[ \t]+$/, "", title)  # Trim whitespace
    # Escape single quotes in title by doubling them for YAML
    gsub(/'/, "''", title)
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