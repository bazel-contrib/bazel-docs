#!/usr/bin/awk -f
# Transform script for converting Bazel docs to Mintlify MDX format
# Usage: awk -f transform-docs.awk input.md > output.mdx

# Trim leading/trailing whitespace
function trim(str,    s) {
    s = str
    gsub(/^[ \t\r\n]+/, "", s)
    gsub(/[ \t\r\n]+$/, "", s)
    return s
}

# Decode common HTML entities
function html_decode(text,    t) {
    t = text
    gsub(/&amp;/, "&", t)
    gsub(/&lt;/, "<", t)
    gsub(/&gt;/, ">", t)
    gsub(/&quot;/, "\"", t)
    gsub(/&#39;/, "'", t)
    gsub(/&nbsp;/, " ", t)
    return t
}

# Convert inline HTML tags to Markdown/MDX-friendly syntax
function inline_to_md(text,    tmp) {
    tmp = text
    gsub(/<code>/, "`", tmp)
    gsub(/<\/code>/, "`", tmp)
    gsub(/<strong>/, "**", tmp)
    gsub(/<\/strong>/, "**", tmp)
    gsub(/<em>/, "*", tmp)
    gsub(/<\/em>/, "*", tmp)
    gsub(/<p>/, "", tmp)
    gsub(/<\/p>/, "", tmp)
    tmp = html_decode(tmp)
    return trim(tmp)
}

# Map PrettyPrint language labels to code fence languages
function map_lang(lang) {
    lang = tolower(lang)
    if (lang == "py" || lang == "python") return "python"
    if (lang == "shell" || lang == "sh" || lang == "bash") return "bash"
    if (lang == "java" || lang == "lang-java") return "java"
    if (lang == "lang") return ""
    return lang
}

# Emit a Mintlify Callout component
function emit_callout(type, title, body) {
    print "<Callout type=\"" type "\" title=\"" title "\">"
    print body
    print "</Callout>"
    print ""
}

# Convert navigation tables into simple Markdown links
function emit_navigation(text,    sanitized, count, hrefs, labels, match_str, href_val, label, prev_label, next_label, output_line, i) {
    sanitized = text
    gsub(/\n/, " ", sanitized)
    gsub(/<span[^>]*>[^<]*<\/span>/, "", sanitized)
    gsub(/<\/?(tr|td|table)>/, "", sanitized)
    gsub(/class="[^"]*"/, "", sanitized)

    count = 0
    while (match(sanitized, /<a[^>]*href="[^"]*"[^>]*>[^<]*<\/a>/)) {
        match_str = substr(sanitized, RSTART, RLENGTH)
        sanitized = substr(sanitized, RSTART + RLENGTH)

        href_val = ""
        if (match(match_str, /href="[^"]*"/)) {
            href_val = substr(match_str, RSTART + 6, RLENGTH - 7)
        }

        label = match_str
        sub(/^[^>]*>/, "", label)
        sub(/<\/a>.*$/, "", label)
        gsub(/[[:space:]]+/, " ", label)
        label = trim(label)
        gsub(/arrow_forward/, "", label)
        gsub(/arrow_back/, "", label)

        count++
        hrefs[count] = href_val
        labels[count] = label
    }

    if (count == 0) {
        return
    }

    prev_label = trim(labels[1])
    if (prev_label !~ /←/) {
        prev_label = "← " prev_label
    }

    output_line = "[" prev_label "](" hrefs[1] ")"

    if (count > 1 && hrefs[2] != "") {
        next_label = trim(labels[2])
        if (next_label !~ /→/) {
            next_label = next_label " →"
        }
        output_line = output_line " · [" next_label "](" hrefs[2] ")"
    }

    print ""
    print output_line
    print ""

    for (i in hrefs) { delete hrefs[i] }
    for (i in labels) { delete labels[i] }
}
# Convert compare paragraphs into Mintlify Callouts
function handle_compare(text,    type, title_segment, title, body_segment, content) {
    type = (index(text, "compare-better") > 0) ? "success" : "warning"

    title_segment = text
    sub(/^<p><span class="compare-[^"]*">/, "", title_segment)
    sub(/<\/span>.*/, "", title_segment)
    title = inline_to_md(title_segment)

    body_segment = text
    sub(/^<p><span class="compare-[^"]*">[^<]*<\/span>/, "", body_segment)
    sub(/<\/p>[[:space:]]*$/, "", body_segment)
    gsub(/\n[ \t]*/, " ", body_segment)
    sub(/^[[:space:]]*(—|--|-)?[[:space:]]*/, "", body_segment)
    content = inline_to_md(body_segment)

    emit_callout(type, title, content)
}

BEGIN {
    in_frontmatter = 0
    first_h1_found = 0
    frontmatter_printed = 0
    before_first_h1 = 1
    in_code_block = 0
    in_pre_block = 0
    meta_index = 0
    capture_compare = 0
    compare_buffer = ""
    capture_nav_table = 0
    nav_buffer = ""
}

# Skip Jekyll front-matter lines
/^Project: \/_project\.yaml$/ { next }
/^Book: \/_book\.yaml$/ { next }

# Skip Starlark lint directives embedded as comments
/^\{#.*#\}$/ { next }

# Stash metadata lines before the first H1 so we can emit them as frontmatter
before_first_h1 && /^[A-Za-z0-9_-]+: / {
    meta_lines[meta_index++] = $0
    next
}

# Remove lines that contain only '{% include "_buttons.html" %}'
/^{% include "_buttons\.html" %}$/ { next }

# Remove lines containing '{% dynamic setvar'
/{% dynamic setvar/ { next }

# Remove any lines that start with '{%'
/^{%/ { next }

# Convert <pre> blocks (with optional classes) into fenced code blocks
/^[ \t]*<pre/ {
    line = $0
    lang = ""
    if (match(line, /lang-[A-Za-z0-9_-]+/)) {
        lang_token = substr(line, RSTART, RLENGTH)
        lang = map_lang(substr(lang_token, 6))
    } else if (match(line, /language-[A-Za-z0-9_-]+/)) {
        lang_token = substr(line, RSTART, RLENGTH)
        lang = map_lang(substr(lang_token, 10))
    }
    if (line ~ /<pre[^>]*>.*<\/pre>/) {
        content = line
        sub(/^[ \t]*<pre[^>]*>/, "", content)
        sub(/<\/pre>[ \t]*$/, "", content)
        gsub(/<\/?span[^>]*>/, "", content)
        gsub(/<\/?div[^>]*>/, "", content)
        gsub(/<\/?code[^>]*>/, "", content)
        content = html_decode(content)
        print "```" lang
        print content
        print "```"
        next
    }
    print "```" lang
    in_pre_block = 1
    next
}

in_pre_block && /<\/pre>/ {
    print "```"
    in_pre_block = 0
    next
}

in_pre_block {
    line = $0
    gsub(/<\/?span[^>]*>/, "", line)
    gsub(/<\/?div[^>]*>/, "", line)
    gsub(/<\/?code[^>]*>/, "", line)
    line = html_decode(line)
    print line
    next
}

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

# Convert navigation tables into inline Markdown
capture_nav_table == 1 {
    nav_buffer = nav_buffer "\n" $0
    if ($0 ~ /<\/table>/) {
        emit_navigation(nav_buffer)
        nav_buffer = ""
        capture_nav_table = 0
    }
    next
}

/^<table class="columns">/ {
    capture_nav_table = 1
    nav_buffer = $0
    next
}

# Convert compare callouts (Wrong/Correct) to Mintlify Callout components
capture_compare == 1 {
    compare_buffer = compare_buffer "\n" $0
    if ($0 ~ /<\/p>/) {
        handle_compare(compare_buffer)
        compare_buffer = ""
        capture_compare = 0
    }
    next
}

/^<p><span class="compare-(better|worse)">/ {
    compare_buffer = $0
    if ($0 ~ /<\/p>/) {
        handle_compare(compare_buffer)
        compare_buffer = ""
    } else {
        capture_compare = 1
    }
    next
}

# Handle inline compare badges inside lists
/^[ \t]*[-*][ \t]*<span class="compare-(better|worse)">/ {
    line = $0
    icon = (index(line, "compare-better") > 0) ? "✅" : "⚠️"
    label_segment = line
    sub(/^[ \t]*[-*][ \t]*<span class="compare-[^"]*">/, "", label_segment)
    sub(/<\/span>.*/, "", label_segment)
    label = inline_to_md(label_segment)
    rest_segment = line
    sub(/^.*<\/span>:[[:space:]]*/, "", rest_segment)
    rest = inline_to_md(rest_segment)
    print "- " icon " **" label "**: " rest
    next
}

# Promote **Note:** style callouts to Mintlify Callout components
/^\*\*Note\*\*:/ {
    line = $0
    sub(/^\*\*Note\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("info", "Note", body)
    next
}

/^[ \t]*<div style=/ { next }
/^[ \t]*<\/div>[ \t]*$/ { next }

# Convert styled horizontal rules to Markdown
/^<hr/ {
    print "---"
    next
}

/^\*\*WARNING\*\*:/ {
    line = $0
    sub(/^\*\*WARNING\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("warning", "Warning", body)
    next
}

/^\*\*Warning\*\*:/ {
    line = $0
    sub(/^\*\*Warning\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("warning", "Warning", body)
    next
}

/^\*\*Important\*\*:/ {
    line = $0
    sub(/^\*\*Important\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("info", "Important", body)
    next
}

/^\*\*IMPORTANT\*\*:/ {
    line = $0
    sub(/^\*\*IMPORTANT\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("warning", "Important", body)
    next
}

/^\*\*Tip\*\*:/ {
    line = $0
    sub(/^\*\*Tip\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("success", "Tip", body)
    next
}

/^\*\*TIP\*\*:/ {
    line = $0
    sub(/^\*\*TIP\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("success", "Tip", body)
    next
}

/^\*\*Caution\*\*:/ {
    line = $0
    sub(/^\*\*Caution\*\*:[ \t]*/, "", line)
    body = inline_to_md(line)
    emit_callout("warning", "Caution", body)
    next
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
/<td[^>]*>[[:space:]]*[^<[:space:]]+[[:space:]]*$/ {
    # Only add closing tag if there isn't already one
    if ($0 !~ /<\/td>$/) {
        $0 = $0 "</td>"
    }
}

# Be more careful with <th> - don't match <thead>
/^[^<]*<th[^e]/ && /<th[^>]*>[[:space:]]*[^<[:space:]]+[[:space:]]*$/ {
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
    for (i = 0; i < meta_index; i++) {
        print meta_lines[i]
    }
    print "---"
    print ""
    first_h1_found = 1
    before_first_h1 = 0
    next
}

{
    gsub(/ class="/, " className=\"", $0)
    gsub(/ style="[^"]*"/, "", $0)
    gsub(/<([A-Za-z0-9]+)  /, "<\\1 ", $0)
    gsub(/  (href|target|rel|aria|data)/, " \\1", $0)
    gsub(/[ \t]+>/, ">", $0)
}

{
    gsub(/<span className="material-icons"[^>]*>arrow_back<\/span>/, "←", $0)
    gsub(/<span className="material-icons"[^>]*>arrow_forward<\/span>/, "→", $0)
    gsub(/<span className="material-icons"[^>]*>arrow_forward_ios<\/span>/, "→", $0)
}

{
    gsub(/ className="[^"]*"/, "", $0)
    gsub(/<\/?span[^>]*>/, "", $0)
}

{
    $0 = html_decode($0)
    print
}
