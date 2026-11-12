# Bazel Docs — Claude Context

## What this repo is

Pipeline that syncs pre-converted MDX docs from `bazelbuild/bazel` and deploys them via Mintlify at `https://bazel.build`. It also auto-generates PR previews for upstream doc changes targeting `master`/`main` and comments on those PRs.

## Tech stack

- **GitHub Actions** — CI/CD orchestration
- **Bazel** — builds reference docs (Starlark/Java API)
- **MDX** — doc format, sourced directly from `upstream/docs/`
- **Mintlify** — renders and hosts the docs; each branch deploys to `https://bazel-<branch>.mintlify.app`
- **Git submodule** (`upstream/`) — tracks `bazelbuild/bazel`
- **Python** (`docs2mdx.py` in `bazelbuild/bazel`) — converts Starlark/Java API docs; upstream builds reference docs via `gen_mdx_reference_docs` Bazel target

## Key files

| File | Purpose |
|---|---|
| `.github/workflows/pull-from-bazel-build.yml` | Reusable sync workflow (MDX + reference docs → commit) |
| `.github/workflows/dependabot-automerge.yml` | Syncs docs on Dependabot `upstream` bumps and auto-merges Dependabot PRs |
| `.github/workflows/preview-bazel-docs-pr.yml` | Cron: polls upstream `master`/`main` PRs, builds previews, posts comments |
| `.github/workflows/generate-docs.yml` | Syncs docs on internal PRs to `main`/`master` that update `upstream` |
| `navigation.update.sh` | Regenerates versioned Mintlify nav (`navigation.json` + `navigation/*.en.json`); version list from `upstream/docs/versions/` |
| `cleanup-deleted-docs.sh` | Removes deleted page references from `navigation/*.en.json` |
| `.mintignore` | Files excluded from Mintlify rendering (broken MDX syntax) |

## Sync pipeline (pull-from-bazel-build.yml)

1. Checkout repo + `upstream` submodule
2. Optionally checkout specific Bazel commit (for upstream PR previews targeting `master`/`main`)
3. Detect upstream doc / reference-doc input changes (if `detect_upstream_docs_changes` is set)
4. `bazel build //src/main/java/com/google/devtools/build/lib:gen_mdx_reference_docs` → `mdx-reference-docs.zip` (when reference-doc inputs changed and upstream code is trusted)
5. `rsync --delete-after upstream/docs/ .` — copies pre-converted MDX files and propagates deletions (including `versions/` from `upstream/docs/versions/`)
6. Apply local patches (`patches/query-language-table-width.patch`) and unzip `mdx-reference-docs.zip`
7. `navigation.update.sh` + `cleanup-deleted-docs.sh` — regenerates nav (`navigation.json` + `navigation/*.en.json`) and prunes deleted pages
8. Commit + push (`[skip ci]` on sync PRs to avoid re-trigger loops; omitted on `pr-<N>` preview branches so Mintlify deploys previews)

## generate-docs.yml & dependabot-automerge.yml (PRs to this repo)

- `dependabot-automerge.yml` handles Dependabot PRs targeting `main`/`master`: runs the doc sync pipeline only for `submodules` updates (skipping it for `github_actions` bumps), then approves and enables squash auto-merge.
- `generate-docs.yml` triggers only on internal non-Dependabot PRs targeting `main`/`master` that modify the `upstream` submodule path. PRs that only touch pipeline or local doc files skip the sync.

## Broken MDX files

Files with MDX syntax errors that Mintlify cannot parse are listed in `.mintignore` (gitignore syntax). Mintlify skips them at deploy time. They still exist in the repo for reference. See issue #226 for fixing them properly.

- Wildcard patterns supported: e.g. `rules/lib/repo/*.mdx`

## Required secrets

| Secret | Used for |
|---|---|
| `GH_APP_ID` + `GH_APP_PRIVATE_KEY` | Push branches and manage PRs in this repo |
| `BAZEL_PR_COMMENTER_APP_ID` + `BAZEL_PR_COMMENTER_PRIVATE_KEY` | Comment on `bazelbuild/bazel` PRs |
| `BUILDBUDDY_ORG_API_KEY` | Remote cache for `bazel build` |

## Commit conventions

```
<type>(<scope>): <short description>
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`. Keep messages succinct.

## Release & versioning

When a new Bazel version is released with docs, the following happens automatically via the sync pipeline:

1. **Upstream docs synced:** `bazelbuild/bazel/docs/versions/VERSION/` → `versions/VERSION/`
2. **Navigation regenerated:** `./navigation.update.sh` creates `navigation/VERSION.en.json`
3. **Version filtering applied:**
   - Major 6 & 7: keeps only latest minor (e.g., 6.5.0, not 6.4.0)
   - Major 8+: keeps all minors (so 8.7, 8.8, 9.0, 9.1, etc.)
   - See `navigation.update.sh` lines 25-38 for implementation

**Manual step required for EOL versions:**
When deprecating old versions (e.g., removing 6.x support), manually delete the corresponding navigation file:
```bash
git rm navigation/6.x.en.json  # Remove EOL version file
./navigation.update.sh          # Regenerate to remove from version index
```

This ensures old versions don't appear in version switcher menus.

## Agent skills (docs migration)

For bazel.build migration work (issue #30598 and related):

- **Manager:** `agent-skills/bazel-docs-migration-manager/SKILL.md`
- **Worker:** `agent-skills/bazel-docs-fix-worker/SKILL.md`
- **Verification:** `scripts/verify_mintlify_preview.mjs`

Symlinks: `.claude/skills/` and `.cursor/skills/` → `agent-skills/`. See also `AGENTS.md`.

## Working norms

- Always ask before editing the PR description.
- Read files before suggesting changes to them.
- Do not commit the `upstream` submodule pointer unless explicitly updating the pinned ref.
