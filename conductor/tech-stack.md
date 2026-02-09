# Technology Stack - Bazel Docs Pipeline

## Build & Automation
- **Bazel:** Used for building reference documentation and managing internal tools.
- **Shell Scripts (Bash):** Orchestrate the pipeline steps, synchronization, and git operations.

## Documentation & Rendering
- **MDX:** The primary format for documentation content, sourced directly from upstream.
- **Mintlify:** The platform used for rendering the documentation and hosting the live site and previews.

## Integration & Infrastructure
- **Git Submodules:** Used to track and pull documentation content directly from the upstream `bazelbuild/bazel` repository.
- **GitHub Actions:** Provides the CI/CD infrastructure for automated updates and PR preview workflows.
