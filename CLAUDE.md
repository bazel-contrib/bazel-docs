# Bazel Docs — Claude Context

## What this repo is

Pipeline that syncs pre-converted MDX docs from `bazelbuild/bazel` and deploys them via Mintlify at `https://bazel.build`. It also auto-generates PR previews for upstream doc changes and comments on those PRs.

## Tech stack

- **GitHub Actions** — CI/CD orchestration
- **Bazel** — builds reference docs (Starlark/Java API)
- **MDX** — doc format, sourced directly from `upstream/docs/`
- **Mintlify** — renders and hosts the docs; each preview deploys to `https://bazel-<branch>.mintlify.app`
- **Git submodule** (`upstream/`) — tracks `bazelbuild/bazel`
- **Python** (`docs2mdx.py` in `bazelbuild/bazel`) — converts Starlark/Java API docs; upstream builds reference docs via `gen_mdx_reference_docs` Bazel target

## Key files

| File | Purpose |
|---|---|
| `.github/workflows/pull-from-bazel-build.yml` | Reusable sync workflow (MDX + reference docs → commit) |
| `.github/workflows/dependabot-automerge.yml` | Auto-syncs docs on Dependabot submodule bumps and squash-merges |
| `.github/workflows/preview-bazel-docs-pr.yml` | Cron/manual: polls upstream `master`/`main` PRs, builds previews, posts comments |
| `.github/workflows/generate-docs.yml` | Syncs when internal PRs to this repo update `upstream` |
| `navigation.update.sh` | Regenerates versioned Mintlify nav (`navigation.json` + `navigation/*.en.json`); version list from `upstream/docs/versions/` |
| `cleanup-deleted-docs.sh` | Removes deleted page references from `navigation/*.en.json` |
| `.mintignore` | Files excluded from Mintlify rendering (broken MDX syntax) |

## Sync pipeline (pull-from-bazel-build.yml)

1. Checkout repo + `upstream` submodule
2. Optionally checkout specific Bazel commit
3. Detect upstream doc / reference-docgen changes (if `detect_upstream_docs_changes` is set)
4. `bazel build //src/main/java/com/google/devtools/build/lib:gen_mdx_reference_docs` → `mdx-reference-docs.zip` (when reference doc inputs changed or on full sync)
5. `rsync --delete-after upstream/docs/ .` — copies pre-converted MDX files (including `versions/` from `upstream/docs/versions/`)
6. Apply local documentation patches (`patches/query-language-table-width.patch`)
7. Unzip `mdx-reference-docs.zip` — extracts Starlark/Java API reference docs
8. `navigation.update.sh` + `cleanup-deleted-docs.sh` — regenerates nav (`navigation.json` + `navigation/*.en.json`) and prunes deleted pages
9. Strip `.mintignore` entries from `navigation/*.json`
10. Commit + push changes

## generate-docs.yml (PRs to this repo)

Only runs the sync pipeline when an internal PR targeting `main`/`master` modifies the `upstream` submodule pointer. PRs that only touch pipeline files or docs skip the sync to keep the PR diff clean.

## Broken MDX files

Files with MDX syntax errors that Mintlify cannot parse are listed in `.mintignore` (gitignore syntax). Mintlify skips them at deploy time. They still exist in the repo for reference. See issue #226 for fixing them properly.

- Wildcard patterns supported: e.g. `rules/lib/repo/*.mdx`
- The nav step also removes these from `navigation/*.json` so they don't appear as broken nav links
- Versioned nav entries (e.g. `versions/8.4.2/query/language`) are NOT cleaned up — left as a known TODO

## Required secrets

| Secret | Used for |
|---|---|
| `GH_APP_ID` + `GH_APP_PRIVATE_KEY` | Push branches and manage PRs in this repo |
| `BAZEL_PR_COMMENTER_APP_ID` + `BAZEL_PR_COMMENTER_PRIVATE_KEY` | Comment on `bazelbuild/bazel` PRs (`Bazel Docs PR Commenter` GitHub App) |
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
   - See `navigation.update.sh` lines 25-39 for implementation

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
