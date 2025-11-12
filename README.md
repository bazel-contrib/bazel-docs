# Bazel Docs

Host Bazel’s Devsite docs on a Mintlify site for easy modification.

## Motivation

This tool implements the improvements outlined in [Bazel Docs: Why It Might Be Time For A Refresh](https://alanmond.com/posts/bazel-documentation-improvements/).  The goal is to create a more developer friendly set of Bazel Docs.  Starting with [bazel.build/docs](https://bazel.build/docs)

## Live Demo

https://bazel.online

## How it works

1. Clones the Devsite source from `bazel.build/docs` using a git submodule.
2. Transforms Devsite frontmatter and directory layout into MDX format.
3. Hosted on Mintlify

## Usage

Clone the submodule: `git submodule update --init -- upstream`

Run the converter tool: TODO

Install the Mintlify dev tool: `npm install -g mint`

Then run `mint dev` to get a locally-running site.

Send a PR to get a hosted preview of the changes.

## LLM-friendly snapshots

The repository now ships a family of machine-readable files at the site root:

- `llms.txt` – curated index linking out to every other variant.
- `llms-medium.txt` – abridged narrative with limited excerpts.
- `llms-small.txt` – compressed quick-reference for low-token contexts.
- `llms-full.txt` – the entire Markdown/MDX corpus in one file.
- `llms-section-<slug>.txt` – section-scoped corpora (for example `llms-section-user-guide.txt`).

Regenerate all variants after editing docs:

```bash
python3 scripts/generate_llms.py
```

Hints:

- Set `LLMS_BASE_URL` if you need to point to a preview/staging domain.
- Use `--sections-only about-bazel user-guide` to regenerate just the per-section files you touched.
- Run `mint dev` and visit `http://localhost:3000/llms.txt` (or `/llms-medium.txt`, etc.) to preview locally.
