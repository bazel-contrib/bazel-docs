---
name: bazel-docs-fix-worker
description: >-
  Fix a single bazel.build documentation migration issue: investigate root
  cause in bazel source, implement minimal fix, run bazel tests, open draft
  PR, trigger Mintlify preview, and run Playwright visual verification.
  Use when assigned one migration bug by a manager or when fixing issues
  like MDX style attributes, docs2mdx conversion, or broken doc anchors.
---

# Bazel docs fix — worker

## Scope

One GitHub issue → one branch → one draft PR → verified test plan.

## Repos and paths

| Repo | Paths |
|------|-------|
| `bazelbuild/bazel` | `docs/` (hand-authored MDX), `scripts/docs/docs2mdx.py` |
| `bazel-contrib/bazel-docs` (this repo) | Preview pipeline, `scripts/verify_mintlify_preview.mjs` |

## Workflow

```
- [ ] Branch: docs/fix-<short-name> from origin/master (bazel repo)
- [ ] Read issue + repro URL; confirm root cause (cite file:line)
- [ ] Minimal fix in bazelbuild/bazel
- [ ] Tests: bazel test //scripts/docs:docs2mdx_test //scripts/docs:rewriter_test
- [ ] Draft PR to bazelbuild/bazel with Fixes #NNNN, test plan
- [ ] Trigger/wait for Mintlify preview (this repo's workflow)
- [ ] Visual verification: node scripts/verify_mintlify_preview.mjs <PR#> --path <repro-page> [...]
- [ ] Post verification comment on upstream PR
```

## Testing rules

Use Bazel:

```bash
bazel test //scripts/docs:docs2mdx_test //scripts/docs:rewriter_test
```

You may also construct one-off verification scripts when needed.

## Visual verification

From **this repo** (bazel-docs), after preview bot comment (~10–15 min):

```bash
export PATH="$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node | tail -1)/bin:$PATH"
cd /tmp && npm init -y && npm install playwright && npx playwright install chromium
node scripts/verify_mintlify_preview.mjs <PR#> --path /path/from/issue [--path ...]
# Optional custom checks (local file; do not commit):
node scripts/verify_mintlify_preview.mjs <PR#> --checks-file /tmp/pr-<N>-checks.json
```

Pick paths from the issue repro or [reference.md](../bazel-docs-migration-manager/reference.md).
Example schema: `scripts/examples/mintlify-checks.example.json`.

Output: `/tmp/bazel-docs-screenshots/pr-<N>/`

Trigger preview if missing:

```bash
gh workflow run "Preview Bazel docs PRs" --repo bazel-contrib/bazel-docs -f pr_number=<N>
```

### Preview gotchas

- Root URL often **404**; script checks specific page paths.
- **Hand-authored MDX** fixes verify in preview immediately.
- **`docs2mdx.py` fixes** may show stale reference MDX until regen in sync pipeline.

## PR test plan template

```markdown
## Test plan

### Unit tests
- [x] `bazel test //scripts/docs:docs2mdx_test`
- [x] `bazel test //scripts/docs:rewriter_test`

### Mintlify preview
Preview: https://bazel-pr-<PR>.mintlify.app/

| Page | Check | Result |
|------|-------|--------|
| `/path` | <expected> | [ ] |

- [ ] Automated: `node scripts/verify_mintlify_preview.mjs <PR> --path <page>` (from bazel-docs repo)
```

See [../bazel-docs-migration-manager/reference.md](../bazel-docs-migration-manager/reference.md).
