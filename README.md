# Bazel Docs

Pipeline repository that generates Reference docs and deploys `.mdx` files to Mintlify.

## Motivation

This repository implements the improvements outlined in [Bazel Docs: Why It Might Be Time For A Refresh](https://alanmond.com/posts/bazel-documentation-improvements/).  The goal is to create a more developer friendly set of Bazel Docs.  Starting with [bazel.build/docs](https://bazel.build/docs)

## Live Demo

https://preview.bazel.build

## How it works

1. Clones .mdx files from `bazelbuild/bazel` repo using a git submodule.
2. Transforms Devsite frontmatter and directory layout into MDX format.
3. Deploys on Mintlify

### FUTURE WORK
All converted .mdx files (necessary for Mintlify to render) are now located in the `bazelbuild/bazel/docs` folder. 
The missing step is to copy the `docs/` folder, generate the reference docs via `bazel build` and deploy to Mintlify


## Usage

Send a PR to get a hosted preview of the changes.
(Very soon) you will see a comment on the `bazelbuild/bazel` PR with a link the Mintlify's deployment.
