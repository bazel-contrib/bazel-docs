# Bazel Docs

Pipeline repository that syncs pre-converted MDX documentation from `bazelbuild/bazel` and deploys it to Mintlify.

## Live Site

https://preview.bazel.build

## How it works

1. The `upstream` git submodule tracks `bazelbuild/bazel`.
2. On every push to `bazelbuild/bazel`'s main branch, a `repository_dispatch` event triggers this repo to sync the latest docs.
3. The sync workflow (`pull-from-bazel-build.yml`):
   - Copies pre-converted MDX files from `upstream/docs/` directly into this repo.
   - Builds reference documentation (Starlark/Java API docs) via `bazel build` and unzips the generated artifact.
   - Commits the result and pushes to the appropriate branch.
4. Mintlify picks up the changes and deploys the updated docs site.

## PR Previews

When a contributor opens or updates a PR in `bazelbuild/bazel` that touches the `docs/` folder (or reference-doc source files), a Mintlify preview is automatically generated and a comment is posted on the upstream PR linking to it.

The preview workflow (`preview-bazel-docs-pr.yml`) polls `bazelbuild/bazel` every 30 minutes for recently-updated open PRs. For each PR that has doc-related changes, it:

1. Creates or updates a `pr-<N>` branch in this repo with the PR's docs.
2. Mintlify deploys that branch at `https://bazel-pr-<N>.mintlify.app`.
3. Posts (or updates) a comment on the upstream PR with the preview link.

## Setup

### Required GitHub Actions Secrets

| Secret | Description | Scope |
|---|---|---|
| `GH_APP_ID` | GitHub App ID used to push branches to this repo | `bazel-contrib/bazel-docs` |
| `GH_APP_PRIVATE_KEY` | Private key for the GitHub App above | `bazel-contrib/bazel-docs` |
| `BAZELBUILD_BAZEL_PAT` | Personal Access Token with `pull_requests: write` permission | `bazelbuild/bazel` |
| `BUILDBUDDY_ORG_API_KEY` | BuildBuddy API key for remote caching during `bazel build` | BuildBuddy org |

### Mintlify Configuration

Each branch pushed to this repo is automatically deployed by Mintlify at `https://bazel-<branch-name>.mintlify.app`. No additional configuration is required for preview deployments — the branch name determines the subdomain.

## Manual Trigger

The preview workflow can be triggered manually from the GitHub Actions UI via `workflow_dispatch` without waiting for the 30-minute cron.
