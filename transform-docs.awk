#!/usr/bin/awk -f

# Transform script for converting Bazel docs to Mintlify format
# Usage: awk -f transform-docs.awk input.md > output.mdx

BEGIN {
    in_frontmatter = 0
    first_h1_found = 0
    frontmatter_printed = 0
    before_first_h1 = 1
    in_html_table = 0
    in_pre_in_table = 0
    buffer = ""
    in_multiline_tag = 0
    tag_buffer = ""
    tag_name = ""
}

# Skip Jekyll front-matter lines
/^Project: \/_project\.yaml$/ { next }
/^Book: \/_book\.yaml$/ { next }

# Remove HTML document structure tags
/^<html[^>]*>$/ { next }
/^<head>$/ { next }
/^<\/head>$/ { next }
/^<body>$/ { next }
/^<\/body>$/ { next }
/^<\/html>$/ { next }
/<meta name="project_path"/ { next }
/<meta name="book_path"/ { next }

# Remove Jinja/Nunjucks style comments (can be anywhere in line)
{
    gsub(/\{# [^}]* #\}/, "", $0)
}

# Remove lines that contain only '{% include "_buttons.html" %}'
/^{% include "_buttons\.html" %}$/ { next }

# Remove lines containing '{% dynamic setvar'
/{% dynamic setvar/ { next }

# Remove {% dynamic if %} and {% dynamic endif %} lines
/^{% dynamic if .*%}$/ { next }
/^{% dynamic endif %}$/ { next }

# Remove any lines that start with '{%'
/^{%/ { next }

# Skip <style> blocks entirely
/<style>/ {
    while (getline > 0 && $0 !~ /<\/style>/) { }
    next
}

# Escape angle brackets in URLs that look like HTML tags
# Match <http or <https URLs and escape them
{
    gsub(/<(https?:\/\/[^>]+)>/, "\\&lt;\\1\\&gt;", $0)
}

# Handle multi-line HTML tags by buffering incomplete tags
# If line contains an opening tag but doesn't close it on the same line
/<img[^>]*$/ && !/\/>/ {
    tag_buffer = $0
    in_multiline_tag = 1
    tag_name = "img"
    next
}

# Match <a> tags that don't have closing </a> on the same line
/<a [^>]*>/ && !/<\/a>/ {
    tag_buffer = $0
    in_multiline_tag = 1
    tag_name = "a"
    next
}

# Match <a> tags that don't have closing > on the same line (incomplete opening tag)
# Match lines with <a  followed by space (attributes) but no closing > for the <a> tag
/<a / && !/<a [^>]*>/ {
    tag_buffer = $0
    in_multiline_tag = 1
    tag_name = "a_incomplete"
    next
}

# Match <code> tags that don't have closing > on the same line (incomplete opening tag)
# Match lines with <code followed by space (attributes) but no closing > for the <code> tag
/<code / && !/<code [^>]*>/ {
    tag_buffer = $0
    in_multiline_tag = 1
    tag_name = "code"
    next
}

# Continue buffering if we're in a multi-line tag
in_multiline_tag == 1 {
    tag_buffer = tag_buffer " " $0
    # Check if this line completes the tag
    if (tag_name == "img" && /\/>/) {
        # Process the complete img tag
        gsub(/\n/, " ", tag_buffer)
        # Make sure it's self-closing
        if (!/<img[^>]*\/>/) {
            gsub(/>/, " />", tag_buffer)
        }
        $0 = tag_buffer
        in_multiline_tag = 0
        tag_buffer = ""
        tag_name = ""
        # Fall through to normal processing
    } else if (tag_name == "a" && /<\/a>/) {
        # Process the complete anchor tag - collapse to single line
        gsub(/\n/, " ", tag_buffer)
        gsub(/[ \t]+/, " ", tag_buffer)  # Collapse multiple spaces
        $0 = tag_buffer
        in_multiline_tag = 0
        tag_buffer = ""
        tag_name = ""
        # Fall through to normal processing
    } else if (tag_name == "a_incomplete" && />/) {
        # Opening tag is now complete, check if closing tag is also present
        if (/<\/a>/) {
            # Complete anchor tag on multiple lines - collapse to single line
            gsub(/\n/, " ", tag_buffer)
            gsub(/[ \t]+/, " ", tag_buffer)  # Collapse multiple spaces
            $0 = tag_buffer
            in_multiline_tag = 0
            tag_buffer = ""
            tag_name = ""
            # Fall through to normal processing
        } else {
            # Opening tag complete but still need closing tag
            tag_name = "a"
            # Continue buffering
            next
        }
    } else if (tag_name == "code" && />/) {
        # Opening tag is now complete, check if closing tag is also present
        if (/<\/code>/) {
            # Complete code tag on multiple lines - collapse to single line
            gsub(/\n/, " ", tag_buffer)
            gsub(/[ \t]+/, " ", tag_buffer)  # Collapse multiple spaces
            $0 = tag_buffer
            in_multiline_tag = 0
            tag_buffer = ""
            tag_name = ""
            # Fall through to normal processing
        } else {
            # Opening tag complete but still need closing tag - switch to waiting for closing
            tag_name = "code_waiting_close"
            # Continue buffering
            next
        }
    } else if (tag_name == "code_waiting_close" && /<\/code>/) {
        # Complete code tag - collapse to single line
        gsub(/\n/, " ", tag_buffer)
        gsub(/[ \t]+/, " ", tag_buffer)  # Collapse multiple spaces
        $0 = tag_buffer
        in_multiline_tag = 0
        tag_buffer = ""
        tag_name = ""
        # Fall through to normal processing
    } else {
        # Still building the tag
        next
    }
}

# Skip multi-line HTML comments (opening tag)
/^<!--/ {
    # If it's a single-line comment, handle it normally
    if (/-->$/) {
        gsub(/^<!-- /, "// ", $0)
        gsub(/ -->$/, "", $0)
        # Skip TOC comments
        if ($0 == "// [TOC]") {
            next
        }
        print
        next
    }
    # Otherwise skip the multi-line comment entirely
    while (getline > 0 && $0 !~ /-->/) { }
    next
}

# Convert <pre> tags to markdown code blocks (but not inside tables)
/^<pre>/ && in_html_table == 0 {
    gsub(/^<pre>/, "```")
    gsub(/<\/pre>$/, "```")
    print
    next
}

# Remove </pre> tags that appear at the end of lines (but not inside tables)
/<\/pre>$/ && in_html_table == 0 {
    gsub(/<\/pre>$/, "```", $0)
}

# Remove orphaned </pre> tags (closing tags without opening)
/^<\/pre>$/ {
    next
}

# Inside tables, keep <pre> as HTML but wrap content in <code> tags
/<pre/ && in_html_table == 1 {
    # Keep <pre> as-is but ensure it's plain HTML
    gsub(/<pre[^>]*>/, "<pre><code>", $0)
    in_pre_in_table = 1
    print
    next
}

/<\/pre>/ && in_html_table == 1 {
    gsub(/<\/pre>/, "</code></pre>", $0)
    in_pre_in_table = 0
    print
    next
}

# Escape import/export keywords and curly braces in pre blocks inside tables to prevent MDX JSX parsing
in_pre_in_table == 1 {
    # Use HTML entity for first letter to break JSX parsing
    # Only replace the first occurrence on the line
    # Note: & is special in AWK replacement, need to escape it
    if (/^[[:space:]]*import[[:space:]]/) {
        sub(/import/, "\\&#105;mport", $0)
    }
    if (/^[[:space:]]*export[[:space:]]/) {
        sub(/export/, "\\&#101;xport", $0)
    }
    # Escape curly braces to prevent MDX from treating them as JSX expressions
    gsub(/\{/, "\\&#123;", $0)
    gsub(/\}/, "\\&#125;", $0)
}

# Remove anchor parts from headings (e.g., ## Title {:#anchor})
/^#+ .* \{:#[^}]*\}$/ {
    # Extract the heading text without the anchor
    heading = $0
    # Apply template variable conversion first
    gsub(/\{\{ ?"<var>" ?\}\}/, "<var>", heading)
    gsub(/\{\{ ?"<\/var>" ?\}\}/, "</var>", heading)
    # Remove the anchor
    gsub(/\s*\{:#[^}]*\}$/, "", heading)
    # Trim trailing whitespace
    gsub(/[ \t]+$/, "", heading)
    print heading
    next
}

# Remove inline anchor references like {:flag--name} or {:.class-name}
{
    gsub(/\{:[^}]+\}/, "", $0)
}

# Remove standalone {: that appears at end of line (multi-line attribute)
/\{:\s*$/ {
    gsub(/\{:\s*$/, "", $0)
}

# Remove lines that are just attribute continuations like .external}
/^\s*\.[a-z-]+\}\s*$/ {
    next
}

# Escape curly braces that contain backtick-quoted strings (dictionary notation)
# Pattern: {`word`:`word`} should become &#123;`word`:`word`&#125;
{
    if (match($0, /\{`[^`]+`:`[^`]+`\}/)) {
        gsub(/\{(`[^`]+`:`[^`]+`)\}/, "\\&#123;\\1\\&#125;", $0)
    }
}

# Remove lines that contain only '{: .external}'
/^\s*\{\s*:\s*\.external\s*\}\s*$/ { next }

# Remove '{: .external}' anywhere it appears (with optional spaces/newlines)
{
    gsub(/\{\s*:\s*\.external\s*\}/, "", $0)
}

# Convert template variable syntax {{ "<var>" }}text{{ "</var>" }} or {{ '<var>' }}
{
    gsub(/\{\{ ?["']<var>["'] ?\}\}/, "<var>", $0)
    gsub(/\{\{ ?["']<\/var>["'] ?\}\}/, "</var>", $0)
}

# Handle comparison spans - convert to Mintlify callouts or styled text
/<p><span class="compare-worse">/ {
    gsub(/<p><span class="compare-worse">/, "**❌ ", $0)
    gsub(/<\/span>/, "**", $0)
    gsub(/<\/p>/, "", $0)
}

/<p><span class="compare-better">/ {
    gsub(/<p><span class="compare-better">/, "**✅ ", $0)
    gsub(/<\/span>/, "**", $0)
    gsub(/<\/p>/, "", $0)
}

# Remove standalone <p> tags
/^<p>$/ { next }
/^<\/p>$/ { next }

# Handle <p class="lead"> specially - convert to bold or just remove
/<p class="lead">/ {
    gsub(/<p class="lead">/, "**", $0)
    # If there's a closing </p> on the same line, replace it
    if (/<\/p>/) {
        gsub(/<\/p>/, "**", $0)
    } else {
        # If not, the next line will need the closing **
        # For now, just add it at the end of this line
        $0 = $0 "**"
    }
}

# Convert simple inline <p> tags to just text
{
    gsub(/^<p>/, "", $0)
    gsub(/<\/p>$/, "", $0)
}

# Handle unclosed <p> tags at start of line - remove them
/^<p>$/ {
    # Standalone <p>, just skip it
    next
}

# If a line starts with <p and doesn't end with </p>, close it
/^<p[^>]*>/ && !/<\/p>/ {
    # Remove the <p> tag and any closing </p> will be handled later
    gsub(/^<p[^>]*>/, "", $0)
}

# Convert <code> tags - keep them as they're valid in MDX
# But remove class attributes
{
    gsub(/<code class="[^"]*">/, "<code>", $0)
}

# Convert <pre> tags with class to plain code blocks
/<pre class="[^"]*">/ {
    gsub(/<pre class="[^"]*">/, "```", $0)
}

# Make <br> tags self-closing
{
    gsub(/<br>/, "<br />", $0)
    gsub(/<br\/>/, "<br />", $0)
}

# Handle <strong> and <b> tags - convert to markdown bold
{
    gsub(/<strong>/, "**", $0)
    gsub(/<\/strong>/, "**", $0)
    gsub(/<b>/, "**", $0)
    gsub(/<\/b>/, "**", $0)
}

# Handle <em> and <i> tags - convert to markdown italic
{
    gsub(/<em>/, "_", $0)
    gsub(/<\/em>/, "_", $0)
    gsub(/<i>/, "_", $0)
    gsub(/<\/i>/, "_", $0)
}

# Remove &nbsp; entities
{
    gsub(/&nbsp;/, " ", $0)
}

# Handle figures - keep them but ensure they're closed properly
# In tables, figures need proper closing
/<\/figure>/ {
    # Make sure we also close the </td> if we're in a table
    print "      </figure>"
    next
}

/<figcaption>/ {
    gsub(/<figcaption>/, "_", $0)
    gsub(/<\/figcaption>/, "_", $0)
}

# Clean up img tags - remove extra attributes that might cause issues
/<img / {
    # Simply remove problematic attributes
    gsub(/ width="[^"]*"/, "", $0)
    gsub(/ height="[^"]*"/, "", $0)
    # Ensure img tags end with />
    # First, handle tags that end with just >
    if (/<img [^>]*>/ && !/<img [^>]*\/>/) {
        gsub(/>/, " />", $0)
    }
}

# Remove class and style attributes from remaining HTML tags
{
    gsub(/ class="[^"]*"/, "", $0)
    gsub(/ style="[^"]*"/, "", $0)
}

# Add quotes to unquoted HTML attributes (align, width, height, etc.)
{
    gsub(/ align=([a-z]+)/, " align=\"\\1\"", $0)
    gsub(/ width=([0-9]+)/, " width=\"\\1\"", $0)
    gsub(/ height=([0-9]+)/, " height=\"\\1\"", $0)
    gsub(/ border=([0-9]+)/, " border=\"\\1\"", $0)
}

# Handle HTML tables - for now, keep them but remove problematic attributes
/<table/ {
    gsub(/<table[^>]*>/, "<table>", $0)
    in_html_table = 1
}

/<\/table>/ {
    in_html_table = 0
}

# Clean up table structure tags - be careful with order
# Handle <thead> and <tbody> before <th> and <td>
/<thead/ {
    gsub(/<thead[^>]*>/, "<thead>", $0)
}

/<tbody/ {
    gsub(/<tbody[^>]*>/, "<tbody>", $0)
}

# Clean up table rows
/<tr/ {
    gsub(/<tr[^>]*>/, "<tr>", $0)
}

# Now handle <th> (but not <thead>)
/<th[^e]/ || /<th>/ {
    gsub(/<th[^>]*>/, "<th>", $0)
}

/<td/ {
    gsub(/<td[^>]*>/, "<td>", $0)
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
