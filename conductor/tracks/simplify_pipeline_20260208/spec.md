# Specification - Simplify Pipeline

## Overview
The upstream `bazelbuild/bazel` repository now handles the conversion of documentation to MDX. This pipeline should be simplified to act as a synchronization and deployment bridge.

## Scope
- Remove Go-based transformation tools.
- Remove shell scripts for HTML to MDX conversion.
- Update GitHub Actions to sync and deploy directly from upstream.
