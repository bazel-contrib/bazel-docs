# Implementation Plan - Simplify Pipeline

## Phase 1: Cleanup
- [~] Task: Remove Go converter and related files
- [ ] Task: Remove obsolete shell scripts (`cleanup-mdx.sh`, `copy-upstream-docs.sh`, etc.)

## Phase 2: Workflow Refactoring
- [ ] Task: Update `pull-from-bazel-build.yml` to remove conversion steps
- [ ] Task: Update `preview-bazel-docs-pr.yml` for direct sync

## Phase 3: PR Integration
- [ ] Task: Finalize PR commenting logic
- [ ] Task: Verify upstream connection and document required GitHub App/PAT permissions
