#!/usr/bin/env python3
"""Generate Bazel's llms.txt family (curated, abridged, compressed, full, sections)."""

from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Sequence, TypeVar


BASE_URL_DEFAULT = "https://bazel.build"
HEAD_VERSION = "HEAD"
MEDIUM_DOCS_PER_SECTION = 6
MEDIUM_PARAGRAPH_LIMIT = 3
MEDIUM_CHAR_LIMIT = 4000
SMALL_DOCS_PER_SECTION = 3
SMALL_SUMMARY_CHARS = 220
SEMVER_RE = re.compile(r"^\d+\.\d+(?:\.\d+)?$")
SLUG_TOKEN_RE = re.compile(r"[^a-z0-9]+")
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
FORMATTING_RE = re.compile(r"[*_`]")
WHITESPACE_RE = re.compile(r"\s+")
SKIP_DIR_NAMES = {
    ".context",
    ".git",
    ".github",
    "html2md_converter",
    "images",
    "legacy_devsite_to_hugo_converter",
    "logo",
    "scripts",
    "upstream",
}
ROOT_LEVEL_CONTENT = {"help.mdx", "index.mdx"}
T = TypeVar("T")


@dataclass
class Document:
    slug: str
    path: Path
    title: str
    description: str | None
    body: str

    def url(self, base_url: str) -> str:
        slug = self.slug.strip("/")
        if slug:
            return f"{base_url.rstrip('/')}/{slug}"
        return base_url.rstrip("/") + "/"

    def short_slug(self) -> str:
        return f"/{self.slug}" if self.slug else "/"


@dataclass
class NavigationGroup:
    title: str
    documents: List[Document]


@dataclass
class NavigationSection:
    title: str
    slug: str
    groups: List[NavigationGroup]

    @property
    def document_count(self) -> int:
        return sum(len(g.documents) for g in self.groups)

    def iter_documents(self) -> Iterator[Document]:
        seen: set[str] = set()
        for group in self.groups:
            for doc in group.documents:
                if doc.slug in seen:
                    continue
                seen.add(doc.slug)
                yield doc


@dataclass
class BuildContext:
    base_url: str
    version_label: str
    timestamp: str
    documents: Dict[str, Document]
    sections: List[NavigationSection]
    version_dirs: Sequence[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate llms*.txt snapshots for the Bazel documentation site."
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("LLMS_BASE_URL", BASE_URL_DEFAULT),
        help="Canonical base URL for the published docs (default: %(default)s).",
    )
    parser.add_argument(
        "--version",
        default=os.environ.get("LLMS_DOCS_VERSION", HEAD_VERSION),
        help="Navigation version to use from docs.json (default: %(default)s).",
    )
    parser.add_argument(
        "--sections-only",
        nargs="*",
        help=(
            "Limit section-specific outputs to these slugs (default: generate all). "
            "Slugs map to the `llms-section-<slug>.txt` filenames printed in llms.txt."
        ),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S %Z")

    documents = collect_documents(repo_root)
    navigation_tabs = load_navigation(repo_root, args.version)
    sections = build_sections(navigation_tabs, documents)
    version_dirs = list_version_dirs(repo_root)

    context = BuildContext(
        base_url=args.base_url,
        version_label=args.version,
        timestamp=timestamp,
        documents=documents,
        sections=sections,
        version_dirs=version_dirs,
    )

    section_filter = set(args.sections_only or [])
    outputs = build_outputs(context, section_filter=section_filter)
    for rel_path, contents in outputs:
        destination = repo_root / rel_path
        destination.write_text(contents, encoding="utf-8")


def collect_documents(repo_root: Path) -> Dict[str, Document]:
    documents: Dict[str, Document] = {}
    patterns = ("*.mdx", "*.md")
    for pattern in patterns:
        for path in sorted(repo_root.rglob(pattern)):
            if not is_content_path(repo_root, path):
                continue
            slug = slug_from_path(repo_root, path)
            meta, body = split_front_matter(path.read_text(encoding="utf-8"))
            title = meta.get("title") or derive_title_from_slug(slug or path.stem)
            documents[slug] = Document(
                slug=slug,
                path=path.relative_to(repo_root),
                title=title,
                description=meta.get("description"),
                body=body.strip(),
            )
    return documents


def is_content_path(repo_root: Path, path: Path) -> bool:
    rel_parts = path.relative_to(repo_root).parts
    if any(part in SKIP_DIR_NAMES for part in rel_parts):
        return False
    if any(SEMVER_RE.match(part) for part in rel_parts):
        return False
    if len(rel_parts) == 1 and rel_parts[0] not in ROOT_LEVEL_CONTENT:
        return False
    return True


def slug_from_path(repo_root: Path, path: Path) -> str:
    rel = path.relative_to(repo_root)
    no_suffix = rel.with_suffix("")
    parts = list(no_suffix.parts)
    if parts and parts[-1] == "index":
        parts = parts[:-1]
    return "/".join(parts)


def split_front_matter(raw: str) -> tuple[Dict[str, str], str]:
    if not raw.startswith("---"):
        return {}, raw
    parts = raw.split("---", 2)
    if len(parts) < 3:
        return {}, raw
    block = parts[1].strip("\n")
    body = parts[2].lstrip("\n")
    meta: Dict[str, str] = {}
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        meta[key.strip()] = value.strip().strip("\"'")
    return meta, body


def derive_title_from_slug(slug: str) -> str:
    cleaned = slug.strip("/").split("/")[-1]
    if not cleaned:
        return "Overview"
    return cleaned.replace("-", " ").title()


def load_navigation(repo_root: Path, version_label: str) -> Sequence[dict]:
    data = json.loads((repo_root / "docs.json").read_text(encoding="utf-8"))
    versions = data.get("navigation", {}).get("versions", [])
    version = next((v for v in versions if v.get("version") == version_label), None)
    if version is None:
        if not versions:
            raise RuntimeError("docs.json navigation is empty.")
        version = versions[0]
    languages = version.get("languages", [])
    if not languages:
        raise RuntimeError("No languages found under navigation.")
    return languages[0].get("tabs", [])


def build_sections(
    navigation_tabs: Sequence[dict],
    documents: Dict[str, Document],
) -> List[NavigationSection]:
    sections: List[NavigationSection] = []
    used_slugs: Dict[str, int] = {}
    for tab in navigation_tabs:
        tab_name = tab.get("tab", "Untitled section")
        groups: List[NavigationGroup] = []
        for group in tab.get("groups", []):
            group_name = group.get("group", "Ungrouped")
            docs = [documents[slug] for slug in group.get("pages", []) if slug in documents]
            if docs:
                groups.append(NavigationGroup(group_name, docs))
        if not groups:
            continue
        slug = slugify(tab_name, used_slugs)
        sections.append(NavigationSection(tab_name, slug, groups))
    return sections


def slugify(label: str, used: Dict[str, int]) -> str:
    slug = SLUG_TOKEN_RE.sub("-", label.lower()).strip("-") or "section"
    if slug not in used:
        used[slug] = 1
        return slug
    used[slug] += 1
    return f"{slug}-{used[slug]}"


def list_version_dirs(repo_root: Path) -> List[str]:
    names = []
    for child in repo_root.iterdir():
        if child.is_dir() and SEMVER_RE.match(child.name):
            names.append(child.name)
    return sorted(names, reverse=True)


def build_outputs(
    context: BuildContext,
    *,
    section_filter: set[str],
) -> List[tuple[str, str]]:
    outputs: List[tuple[str, str]] = []
    section_paths = {
        section.slug: f"llms-section-{section.slug}.txt" for section in context.sections
    }

    variant_paths = {
        "curated": "llms.txt",
        "medium": "llms-medium.txt",
        "small": "llms-small.txt",
        "full": "llms-full.txt",
        "sections": section_paths,
    }

    outputs.append(
        (variant_paths["curated"], render_curated_index(context, variant_paths))
    )
    outputs.append((variant_paths["medium"], render_medium_digest(context)))
    outputs.append((variant_paths["small"], render_small_digest(context)))
    outputs.append((variant_paths["full"], render_full_corpus(context)))

    for section in context.sections:
        if section_filter and section.slug not in section_filter:
            continue
        rel_path = section_paths[section.slug]
        outputs.append((rel_path, render_section_corpus(context, section)))

    return outputs


def render_curated_index(
    context: BuildContext,
    variant_paths: Dict[str, object],
) -> str:
    lines: List[str] = []
    lines.append("# Bazel documentation for LLMs")
    lines.append(
        "> Bazel is a fast, hermetic build system. Use this file to choose the right "
        "documentation snapshot for your LLM session."
    )
    lines.append("")
    lines.append("## Documentation sets")
    lines.append(
        f"- [Abridged documentation]({variant_paths['medium']}): "
        "High-signal narrative with short excerpts for every major section."
    )
    lines.append(
        f"- [Compressed documentation]({variant_paths['small']}): "
        "Strictly limited summaries for low-token contexts."
    )
    lines.append(
        f"- [Complete documentation]({variant_paths['full']}): "
        "Entire Markdown corpus mirrors all MDX sources."
    )
    lines.append("")
    lines.append("## Section snapshots")
    for section in context.sections:
        rel_path = variant_paths["sections"][section.slug]
        summary = section_summary(section)
        lines.append(
            f"- [{section.title}]({rel_path}) — {section.document_count} pages. {summary}"
        )
    lines.append("")
    if context.version_dirs:
        lines.append("## Archived versions")
        for name in context.version_dirs:
            lines.append(
                f"- Bazel {name}: {context.base_url.rstrip('/')}/{name}/ (snapshot only)"
            )
        lines.append("")
    lines.append("## Notes")
    lines.append(f"- Canonical domain: {context.base_url.rstrip('/')}/")
    lines.append(f"- Docs snapshot: {context.version_label}")
    lines.append(f"- Generated: {context.timestamp}")
    lines.append("- Source repo: https://github.com/bazel-contrib/bazel-docs")
    lines.append(
        "- Preview locally: run `mint dev` then open http://localhost:3000/llms.txt"
    )
    lines.append("")
    return "\n".join(lines).strip() + "\n"


def render_medium_digest(context: BuildContext) -> str:
    lines: List[str] = []
    lines.append(
        "<SYSTEM>This is the abridged Bazel developer documentation. "
        "Use it when you need balanced coverage without the full corpus.</SYSTEM>"
    )
    lines.append("")
    lines.append("# Bazel documentation (abridged)")
    lines.append(
        f"_Generated {context.timestamp} from {context.base_url.rstrip('/')} — version {context.version_label}_"
    )
    lines.append("")

    for section in context.sections:
        docs = list(take(section.iter_documents(), MEDIUM_DOCS_PER_SECTION))
        if not docs:
            continue
        lines.append(f"## {section.title}")
        lines.append("")
        for doc in docs:
            lines.append(f"### {doc.title}")
            lines.append(f"- URL: {doc.url(context.base_url)}")
            lines.append(f"- From: {doc.short_slug()}")
            summary = summarize_doc(doc, max_chars=400)
            if summary:
                lines.append("")
                lines.append(summary)
            excerpt = excerpt_body(doc.body, MEDIUM_PARAGRAPH_LIMIT, MEDIUM_CHAR_LIMIT)
            if excerpt:
                lines.append("")
                lines.append(excerpt)
            lines.append("")
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def render_small_digest(context: BuildContext) -> str:
    lines: List[str] = []
    lines.append(
        "<SYSTEM>This is the compressed Bazel quick-reference. "
        "Prioritize actionable answers over prose. "
        "If more context is required, escalate to llms-medium.txt.</SYSTEM>"
    )
    lines.append("")
    lines.append("# Bazel quick-reference (compressed)")
    lines.append(
        "- Default to Bazel 8 semantics unless the prompt specifies otherwise.\n"
        "- Keep answers scoped to the referenced docs; link back to the canonical URL."
    )
    lines.append("")

    for section in context.sections:
        docs = list(take(section.iter_documents(), SMALL_DOCS_PER_SECTION))
        if not docs:
            continue
        lines.append(f"## {section.title}")
        summary = section_summary(section)
        if summary:
            lines.append(f"> {summary}")
        lines.append("")
        for doc in docs:
            lines.append(
                f"- **{doc.title}** — {summarize_doc(doc, max_chars=SMALL_SUMMARY_CHARS)}"
                f" ({doc.url(context.base_url)})"
            )
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def render_full_corpus(context: BuildContext) -> str:
    lines: List[str] = []
    lines.append("# Bazel Documentation – llms-full.txt")
    lines.append(
        "> Complete Markdown snapshot of the Bazel documentation tree. "
        "Each section is canonicalized to the published URL for easier ingestion."
    )
    lines.append("")
    lines.append(f"- Canonical domain: {context.base_url.rstrip('/')}/")
    lines.append(f"- Docs snapshot: {context.version_label}")
    lines.append(f"- Generated: {context.timestamp}")
    lines.append("- Source repo: https://github.com/bazel-contrib/bazel-docs")
    lines.append("")
    lines.append("---")
    lines.append("")

    for slug in sorted(context.documents):
        doc = context.documents[slug]
        lines.append(f"## {doc.title}")
        lines.append(f"- URL: {doc.url(context.base_url)}")
        lines.append(f"- Source: {doc.path}")
        lines.append(f"- Slug: {doc.short_slug()}")
        if doc.description:
            lines.append(f"- Summary: {doc.description}")
        lines.append("")
        lines.append(doc.body)
        lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines).strip() + "\n"


def render_section_corpus(context: BuildContext, section: NavigationSection) -> str:
    lines: List[str] = []
    lines.append(
        f"<SYSTEM>This is the Bazel '{section.title}' documentation subset. "
        "Use it when you only need this portion of the corpus.</SYSTEM>"
    )
    lines.append("")
    lines.append(f"# {section.title}")
    lines.append(f"- Docs snapshot: {context.version_label}")
    lines.append(f"- Generated: {context.timestamp}")
    lines.append("")
    for group in section.groups:
        lines.append(f"## {group.title}")
        lines.append("")
        for doc in group.documents:
            lines.append(f"### {doc.title}")
            lines.append(f"- URL: {doc.url(context.base_url)}")
            lines.append(f"- Source: {doc.path}")
            if doc.description:
                lines.append(f"- Summary: {doc.description}")
            lines.append("")
            lines.append(doc.body)
            lines.append("")
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def summarize_doc(doc: Document, max_chars: int = 220) -> str:
    text = doc.description or first_paragraph(doc.body)
    text = LINK_RE.sub(r"\1", text)
    text = FORMATTING_RE.sub("", text)
    text = WHITESPACE_RE.sub(" ", text).strip()
    if len(text) <= max_chars:
        return text
    truncated = text[:max_chars].rsplit(" ", 1)[0].rstrip(" ,.;:")
    return f"{truncated}…"


def first_paragraph(body: str) -> str:
    for block in body.split("\n\n"):
        cleaned = block.strip()
        if cleaned:
            return cleaned
    return ""


def excerpt_body(body: str, paragraph_limit: int, char_limit: int) -> str:
    paragraphs = [p.strip() for p in body.split("\n\n") if p.strip()]
    excerpt = "\n\n".join(paragraphs[:paragraph_limit])
    if len(excerpt) <= char_limit:
        return excerpt
    truncated = excerpt[:char_limit].rsplit(" ", 1)[0].rstrip(" ,.;:")
    return f"{truncated}…"


def section_summary(section: NavigationSection) -> str:
    for doc in section.iter_documents():
        summary = summarize_doc(doc, max_chars=200)
        if summary:
            return summary
    return ""


def take(iterable: Iterable[T], limit: int) -> Iterator[T]:
    count = 0
    for item in iterable:
        if count >= limit:
            break
        yield item
        count += 1


if __name__ == "__main__":
    main()
