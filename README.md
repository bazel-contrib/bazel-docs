# Bazel Docs

Host Bazel’s Devsite docs on a Mintlify site for easy modification.

## Motivation

This tool implements the improvements outlined in [Bazel Docs: Why It Might Be Time For A Refresh](https://alanmond.com/posts/bazel-documentation-improvements/).  The goal is to create a more developer friendly set of Bazel Docs.  Starting with [bazel.build/docs](https://bazel.build/docs)

## Live Demo

https://bazel.online

## Repository Structure

- **Root directory**: Contains the latest (HEAD) documentation
- **versions/ directory**: Contains version-specific documentation (e.g., `versions/8.4.2/`, `versions/7.7.0/`)
- **upstream/**: Git submodule containing the source Bazel repository

## How it works

1. Clones the Devsite source from `bazel.build/docs` using a git submodule (`upstream/`).
2. Transforms Devsite frontmatter and directory layout into MDX format.
3. Version-specific docs are organized in the `versions/` directory.
4. Hosted on Mintlify at https://bazel.online

## Usage

Clone the submodule: `git submodule update --init -- upstream`

Run the converter tool: TODO

Install the Mintlify dev tool: `npm install -g mint`

Then run `mint dev` to get a locally-running site.

Send a PR to get a hosted preview of the changes.
