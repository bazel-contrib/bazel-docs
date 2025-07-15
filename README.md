# Bazel Docs

Convert Bazel’s Devsite docs into a Hugo/Docsy site for easy modification.

## Motivation

This tool implements the improvements outlined in [Bazel Docs: Why It Might Be Time For A Refresh](https://alanmond.com/posts/bazel-documentation-improvements/).  The goal is to create a more developer friendly set of Bazel Docs.  Starting with [bazel.build/docs](https://bazel.build/docs)

## Live Demo

https\://bazel-docs-68tmf.ondigitalocean.app/

## How it works

1. Clones the Devsite source from `bazel.build/docs`.
2. Transforms Devsite frontmatter and directory layout into Hugo/Docsy format.
3. Converts CSS/SCSS for Docsy theme compatibility.

## Usage

Run the latest build locally:

```bash
docker run -it -p 1313:1313 alan707/bazel-docs:latest
```

Build a new image:

```bash
docker build . -t bazel_docs:latest
```

