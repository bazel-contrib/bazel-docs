#!/usr/bin/env python3
import sys
import zipfile
import shutil
import re
from pathlib import Path
import markdownify

def strip_devsite_templates(html_text: str) -> str:
    """Remove DevSite template tags `{% … %}` and `{{ … }}` (multiline)."""
    html_text = re.sub(r"\{\%.*?\%\}", "", html_text, flags=re.DOTALL)
    html_text = re.sub(r"\{\{.*?\}\}", "", html_text)
    return html_text

def html_to_markdown(html_text: str) -> str:
    """Convert HTML to Markdown (approximate)."""
    return markdownify.markdownify(html_text, heading_style="ATX")

def sanitize_for_mdx(md_text: str) -> str:
    """
    Sanitize Markdown to MDX-safe:
    - Drop first heading (to avoid duplicate title)
    - Escape bad `{…}` expressions
    - Convert `<https://…>` to Markdown links
    - Rewrite .html → .mdx
    - Fix leading slash links
    - Strip styles, normalize IDs
    - Escape leftover tags / braces
    - Patch problematic sequences like `)><code>…()` in anchors
    """
    out_lines = []
    seen_ids = {}
    skip_first_heading = True

    for ln in md_text.splitlines():
        # Skip first top-level heading (if any)
        if skip_first_heading and re.match(r"^#\s+.+", ln):
            skip_first_heading = False
            continue

        # Remove leftover template constructs
        if "{%" in ln:
            ln = re.sub(r"\{\%.*?\%\}", "", ln)
        if "{{" in ln:
            ln = re.sub(r"\{\{.*?\}\}", "", ln)

        # **FIX: Clean up broken markdown link syntax with embedded HTML**
        # Pattern: [text](url>junk..., more text](final-url)
        # This happens when anchor tags are nested or malformed in original HTML
        # Strategy: If a markdown link URL contains '>' followed by junk and then another '](',
        # remove everything from '>' to the next '](' 
        
        # First pass: Remove complex broken link portions with multiple issues
        ln = re.sub(
            r'\]\(([^)>]+)>[^\]]*\]\(',
            r'](\1](', 
            ln
        )
        
        # Second pass: Clean up any remaining unescaped HTML tags within markdown links
        # This handles cases where <a>, <code>, etc. appear inside ](...) 
        def fix_markdown_link_html(match):
            url = match.group(1)
            # If URL contains unescaped < or HTML-like content, truncate at first >
            if '>' in url and '<' in url:
                url = url.split('>')[0]
            # Escape any remaining angle brackets
            url = url.replace('<', '\\<').replace('>', '\\>')
            return '](' + url + ')'
        
        ln = re.sub(r'\]\(([^)]+)\)', fix_markdown_link_html, ln)
        
        # **FIX: Escape problematic HTML sequences EARLY**
        # Pattern 1: stuff>\<code\>stuff()\</code\>\</a\>, <a href=
        ln = re.sub(
            r'>\\\<code\\\>([^<]+)\\\</code\\\>\\\</a\\\>,\s*\<a\s+href=',
            lambda m: r'>`' + m.group(1) + r'()`</a>, <a href=',
            ln
        )
        
        # Pattern 2: Any remaining >\<code\> patterns
        ln = re.sub(r'>\\\<code\\\>', r'>`<code>', ln)
        ln = re.sub(r'\\\</code\\\>\\\</a\\\>', r'</code>`</a>', ln)
        
        # Pattern 3: Bare href= without quotes (from malformed links)
        ln = re.sub(r'<a\s+href=\)', r'<a href="#">', ln)
        ln = re.sub(r'href=\s*\)', r'href="#">', ln)

        # Escape `{…}` with colon inside
        ln = re.sub(
            r"\{([^}]*?:[^}]*)\}",
            lambda m: r"\{" + m.group(1) + r"\}",
            ln,
        )

        # Escape unescaped `{` or `}`
        ln = re.sub(r"(?<!\\)\{", r"\{", ln)
        ln = re.sub(r"(?<!\\)\}", r"\}", ln)

        # Rewrite .html links to .mdx
        ln = re.sub(r"\(([^)]+)\.html\)", r"(\1.mdx)", ln)
        ln = re.sub(r'href="([^"]+)\.html"', r'href="\1.mdx"', ln)

        # Convert raw angle-bracket URLs into Markdown links
        ln = re.sub(r"<(https?://[^>]+)>", r"[\1](\1)", ln)

        # **FIX: Escape comparison operators that look like HTML tags**
        # Replace <= and >= with HTML entities or escaped versions
        # Do this BEFORE other tag escaping to avoid confusion
        ln = re.sub(r'<=', r'&lt;=', ln)
        ln = re.sub(r'>=', r'&gt;=', ln)
        
        # **FIX: Escape #include <header.h> patterns**
        # Pattern: #include <path/to/file.h> where the angle brackets look like HTML
        ln = re.sub(r'#include\s+<([^>]+)>', r'#include &lt;\1&gt;', ln)
        
        # **FIX: Handle escaped tags more carefully**
        # Only escape tags that aren't already in code blocks or properly formed
        # Skip escaping if we're in a code context
        if not ('`' in ln and ln.count('`') % 2 == 0):
            ln = re.sub(r"<([^ >]+)>", r"\<\1\>", ln)

        # Fix leading slash links: [text](/path) → relative
        ln = re.sub(r"\[([^\]]+)\]\(/([^)]+)\)", r"[\1](./\2)", ln)
        ln = re.sub(r'href="/([^"]+)"', r'href="./\1"', ln)

        # Strip inline style attributes
        ln = re.sub(r'style="[^"]*"', "", ln)

        # Normalize id="section-foo"
        ln = re.sub(r'id="section-([A-Za-z0-9_-]+)"', r'id="\1"', ln)

        # Escape known custom tags
        ln = re.sub(r"<(workspace|symlink_path|attribute_name)([^>]*)>", r"\<\1\2\>", ln)
        ln = re.sub(r"</(workspace|symlink_path|attribute_name)>", r"\</\1\>", ln)

        # **FIX: More careful handling of </code> - only escape if not in inline code**
        # Count backticks to see if we're in code context
        backtick_count = ln.count('`')
        if backtick_count % 2 == 1:  # Odd number means we're inside code
            pass  # Don't escape
        else:
            ln = ln.replace("</code>", r"\</code>")

        # **FIX: Patch problematic `)><code>` sequences inside anchor context**
        ln = re.sub(
            r"\)\>\<code\>([^<]+)\</code\>",
            lambda m: r") `<code>" + m.group(1) + r"</code>`",
            ln
        )
        # Also patch anchor boundary syntax
        ln = re.sub(r"</a>,\s*<a href=", r"\</a\>, \<a href=", ln)

        # **FIX: Clean up malformed href attributes**
        # Pattern: href=)/some/path - should be removed or fixed
        ln = re.sub(r'href=\)/[^"\s)]+', r'href="#"', ln)

        # Deduplicate heading IDs
        m = re.match(r'^(#+)\s*(.*)\s*\{#([A-Za-z0-9_-]+)\}', ln)
        if m:
            hashes, text, hid = m.groups()
            cnt = seen_ids.get(hid, 0)
            if cnt > 0:
                newhid = f"{hid}-{cnt+1}"
                ln = f"{hashes} {text} {{#{newhid}}}"
            seen_ids[hid] = cnt + 1

        out_lines.append(ln)

    return "\n".join(out_lines)

def make_frontmatter(title: str) -> str:
    safe = title.replace("'", "\\'")
    return f"---\ntitle: '{safe}'\n---\n\n"

def convert_html_file(html_path: Path, mdx_path: Path) -> None:
    html_text = html_path.read_text(encoding="utf-8", errors="ignore")
    cleaned = strip_devsite_templates(html_text)
    md = html_to_markdown(cleaned)
    sanitized = sanitize_for_mdx(md)
    title = html_path.stem
    front = make_frontmatter(title)
    mdx_path.parent.mkdir(parents=True, exist_ok=True)
    mdx_path.write_text(front + sanitized, encoding="utf-8")
    print(f"Wrote {mdx_path}")

def process_zip(zip_path: Path) -> None:
    tmp = Path("_tmp_unzip_convert")
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir()
    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(tmp)

    for html_path in tmp.rglob("*.html"):
        rel = html_path.relative_to(tmp)
        mdx_out = Path(rel).with_suffix(".mdx")
        convert_html_file(html_path, mdx_out)

    shutil.rmtree(tmp)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 converter.py <reference-docs.zip>")
        sys.exit(1)
    zipf = Path(sys.argv[1])
    if not zipf.is_file():
        print(f"Error: {zipf} not found")
        sys.exit(1)
    process_zip(zipf)
    print("Conversion done.")

if __name__ == "__main__":
    main()