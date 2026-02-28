# Bazel Docs — Claude Context

## What this repo is

Pipeline that syncs pre-converted MDX docs from `bazelbuild/bazel` and deploys them via Mintlify at `https://preview.bazel.build`. It also auto-generates PR previews for upstream doc changes and comments on those PRs.

## Tech stack

- **GitHub Actions** — CI/CD orchestration
- **Bazel** — builds reference docs (Starlark/Java API)
- **MDX** — doc format, sourced directly from `upstream/docs/`
- **Mintlify** — renders and hosts the docs; each branch deploys to `https://bazel-<branch>.mintlify.app`
- **Git submodule** (`upstream/`) — tracks `bazelbuild/bazel`

## Key files

| File | Purpose |
|---|---|
| `.github/workflows/pull-from-bazel-build.yml` | Reusable sync workflow (MDX + reference docs → commit) |
| `.github/workflows/preview-bazel-docs-pr.yml` | Cron: polls upstream PRs, builds previews, posts comments |
| `.github/workflows/trigger-from-bazel-repo.yml` | Syncs on upstream main-branch push |
| `.github/workflows/generate-docs.yml` | Syncs on PRs to this repo |
| `docs.json.update.sh` | Regenerates versioned Mintlify nav (`docs.json`) |

## Required secrets

| Secret | Used for |
|---|---|
| `GH_APP_ID` + `GH_APP_PRIVATE_KEY` | Push branches to this repo |
| `BAZELBUILD_BAZEL_PAT` | Comment on `bazelbuild/bazel` PRs (`pull_requests: write`) |
| `BUILDBUDDY_ORG_API_KEY` | Remote cache for `bazel build` |

## Commit conventions

```
<type>(<scope>): <short description>
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`. Keep messages succinct.

## Working norms

- Always ask before editing the PR description.
- Read files before suggesting changes to them.
- Do not commit the `upstream` submodule pointer unless explicitly updating the pinned ref.
