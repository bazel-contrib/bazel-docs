#!/usr/bin/env python3
"""Generate llms.txt and llms-full.txt snapshots for bazel.build documentation."""

from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Sequence


BASE_URL_DEFAULT = "https://bazel.build"
HEAD_VERSION = "HEAD"
MAX_PAGES_PER_GROUP = 6
SEMVER_RE = re.compile(r"^\d+\.\d+(?:\.\d+)?$")
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
FORMATTING_RE = re.compile(r"[*_`]")
SKIP_DIR_NAMES = {
    ".context",
    ".git",
    ".github",
    "html2md_converter",
    "images",
    "legacy_devsite_to_hugo_converter",
    "logo",
    "upstream",
}
ROOT_LEVEL_CONTENT = {"help.mdx", "index.mdx"}


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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate llms.txt + llms-full.txt from the Mintlify docs sources."
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
        "--max-pages",
        type=int,
        default=MAX_PAGES_PER_GROUP,
        help="Maximum curated links per navigation group (default: %(default)s).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S %Z")

    documents = collect_documents(repo_root)
    navigation = load_navigation(repo_root, args.version)
    version_dirs = list_version_dirs(repo_root)

    curated = build_curated_index(
        documents=documents,
        navigation=navigation,
        base_url=args.base_url,
        timestamp=timestamp,
        version_label=args.version,
        version_dirs=version_dirs,
        max_pages=args.max_pages,
    )
    full = build_full_corpus(
        documents=documents,
        base_url=args.base_url,
        timestamp=timestamp,
        version_label=args.version,
    )

    (repo_root / "llms.txt").write_text(curated, encoding="utf-8")
    (repo_root / "llms-full.txt").write_text(full, encoding="utf-8")


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


def list_version_dirs(repo_root: Path) -> List[str]:
    names = []
    for child in repo_root.iterdir():
        if child.is_dir() and SEMVER_RE.match(child.name):
            names.append(child.name)
    return sorted(names, reverse=True)


def build_curated_index(
    *,
    documents: Dict[str, Document],
    navigation: Sequence[dict],
    base_url: str,
    timestamp: str,
    version_label: str,
    version_dirs: Sequence[str],
    max_pages: int,
) -> str:
    lines: List[str] = []
    lines.append("# Bazel Documentation – llms.txt")
    lines.append(
        "> High-signal navigation cues for the Bazel build system docs. "
        "Use this before fetching the full corpus to understand layout and priority content."
    )
    lines.append("")
    lines.append(f"- Canonical domain: {base_url.rstrip('/')}/")
    lines.append(f"- Docs snapshot: {version_label}")
    lines.append(f"- Generated: {timestamp}")
    lines.append("- Full corpus: /llms-full.txt")
    lines.append("- Source repo: https://github.com/bazel-contrib/bazel-docs")
    lines.append("")
    lines.append("## Navigation highlights")

    for tab in navigation:
        tab_name = tab.get("tab", "Untitled tab")
        lines.append(f"### {tab_name}")
        for group in tab.get("groups", []):
            group_name = group.get("group", "Ungrouped")
            pages = [documents[p] for p in group.get("pages", []) if p in documents]
            if not pages:
                continue
            lines.append(f"- **{group_name}** ({len(pages)} pages)")
            for doc in pages[:max_pages]:
                summary = summarize_doc(doc)
                lines.append(f"  - [{doc.title}]({doc.url(base_url)}) — {summary}")
            remaining = len(pages) - max_pages
            if remaining > 0:
                lines.append(f"  - … {remaining} more pages in this group")
        lines.append("")

    if version_dirs:
        lines.append("## Versioned archives")
        for name in version_dirs:
            lines.append(
                f"- Bazel {name} docs: {base_url.rstrip('/')}/{name}/ (snapshot content)"
            )
        lines.append("")

    lines.append("## Machine-readable artifacts")
    lines.append("- Curated summary: /llms.txt (this document)")
    lines.append("- Full corpus: /llms-full.txt")
    lines.append("- Generator: scripts/generate_llms.py")
    lines.append("")
    lines.append(
        "> Tip: Fetch llms-full.txt only after skimming this curated file; "
        "the corpus is large (~many MB) and mirrors all MDX sources."
    )
    lines.append("")
    return "\n".join(lines).strip() + "\n"


def summarize_doc(doc: Document, max_chars: int = 220) -> str:
    text = doc.description or first_paragraph(doc.body)
    text = LINK_RE.sub(r"\1", text)
    text = FORMATTING_RE.sub("", text)
    text = re.sub(r"\\s+", " ", text).strip()
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


def build_full_corpus(
    *,
    documents: Dict[str, Document],
    base_url: str,
    timestamp: str,
    version_label: str,
) -> str:
    lines: List[str] = []
    lines.append("# Bazel Documentation – llms-full.txt")
    lines.append(
        "> Complete Markdown snapshot of the Bazel documentation tree. "
        "Each section is canonicalized to the published URL for easier ingestion."
    )
    lines.append("")
    lines.append(f"- Canonical domain: {base_url.rstrip('/')}/")
    lines.append(f"- Docs snapshot: {version_label}")
    lines.append(f"- Generated: {timestamp}")
    lines.append("- Source repo: https://github.com/bazel-contrib/bazel-docs")
    lines.append("")
    lines.append("---")
    lines.append("")

    for slug in sorted(documents):
        doc = documents[slug]
        lines.append(f"## {doc.title}")
        lines.append(f"- URL: {doc.url(base_url)}")
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


if __name__ == "__main__":
    main()
