# Bazel Docs — Claude Context

## What this repo is

Pipeline that syncs pre-converted MDX docs from `bazelbuild/bazel` and deploys them via Mintlify at `https://preview.bazel.build`. It also auto-generates PR previews for upstream doc changes and comments on those PRs.

## Tech stack

- **GitHub Actions** — CI/CD orchestration
- **Bazel** — builds reference docs (Starlark/Java API)
- **MDX** — doc format, sourced directly from `upstream/docs/`
- **Mintlify** — renders and hosts the docs; each branch deploys to `https://bazel-<branch>.mintlify.app`
- **Git submodule** (`upstream/`) — tracks `bazelbuild/bazel`
- **Go** (`html2md_converter/`) — converts HTML reference docs from `reference-docs.zip` to intermediate `.md`
- **AWK** (`transform-docs.awk`) — post-processes `.md` → valid MDX (strips Devsite tags, fixes JSX syntax)

## Key files

| File | Purpose |
|---|---|
| `.github/workflows/pull-from-bazel-build.yml` | Reusable sync workflow (MDX + reference docs → commit) |
| `.github/workflows/preview-bazel-docs-pr.yml` | Cron: polls upstream PRs, builds previews, posts comments |
| `.github/workflows/trigger-from-bazel-repo.yml` | Syncs on upstream main-branch push |
| `.github/workflows/generate-docs.yml` | Syncs on PRs to this repo |
| `docs.json.update.sh` | Regenerates versioned Mintlify nav (`docs.json`) |
| `html2md_converter/main.go` | Go tool: HTML zip → `.md` files |
| `transform-docs.awk` | AWK: `.md` → MDX-safe `.mdx` (fixes Devsite/JSX issues) |
| `.mintignore` | Files excluded from Mintlify rendering (broken MDX syntax) |

## Sync pipeline (pull-from-bazel-build.yml)

1. Checkout repo + `upstream` submodule
2. Optionally checkout specific Bazel commit
3. Detect upstream doc changes (if `detect_upstream_docs_changes` is set)
4. `bazel build //src/main/java/com/google/devtools/build/lib:gen_reference_docs` → `reference-docs.zip`
5. `rsync upstream/docs/ .` — copies pre-converted MDX files
6. Go converter + awk: `reference-docs.zip` → `.mdx` reference docs
7. `docs.json.update.sh` — regenerates nav
8. Strip `.mintignore` entries from `docs.json` navigation
9. Commit + push with `[skip ci]` to prevent re-trigger loop

## Broken MDX files

Files with MDX syntax errors that Mintlify cannot parse are listed in `.mintignore` (gitignore syntax). Mintlify skips them at deploy time. They still exist in the repo for reference. See issue #226 for fixing them properly.

- Wildcard patterns supported: e.g. `rules/lib/repo/*.mdx`
- The nav step also removes these from `docs.json` so they don't appear as broken nav links
- Versioned nav entries (e.g. `8.4.2/query/language`) are NOT cleaned up — left as a known TODO

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
