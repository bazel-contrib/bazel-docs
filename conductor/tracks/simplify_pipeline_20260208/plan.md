# Implementation Plan - Simplify Pipeline

## Phase 1: Cleanup
- [x] Task: Remove Go converter and related files 852c370
- [x] Task: Remove obsolete shell scripts (`cleanup-mdx.sh`, `copy-upstream-docs.sh`, etc.) 852c370

## Phase 2: Workflow Refactoring
- [x] Task: Update `pull-from-bazel-build.yml` to remove conversion steps a2040f7
- [x] Task: Update `preview-bazel-docs-pr.yml` for direct sync 8a8f86a

## Phase 3: PR Integration
- [x] Task: Finalize PR commenting logic 8bd8df4
- [ ] Task: Verify upstream connection and document required GitHub App/PAT permissions
