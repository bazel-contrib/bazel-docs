---
name: bazel-docs-migration-manager
description: >-
  Orchestrate bazel.build documentation migration fixes across GitHub issues:
  triage tracking issues, delegate to sub-agents, open draft PRs to
  bazelbuild/bazel, trigger Mintlify previews, run visual verification, and
  report status. Use when fixing bazel.build migration bugs, coordinating a
  docs team, or continuing work on bazel-contrib/bazel-docs / docs2mdx issues.
---

# Bazel docs migration — manager

## When to use

User gives a list of GitHub issues and wants draft PRs with minimal maintainer attention.

## Architecture

Use **both** this manager skill and the worker skill [`bazel-docs-fix-worker`](../bazel-docs-fix-worker/SKILL.md):

| Role | Skill | Responsibility |
|------|-------|----------------|
| Manager (you) | This skill | Triage, delegate, dedupe PRs, stacking notes, preview triggers, final report |
| Sub-agents | Worker skill | One issue → one branch → tests → draft PR → visual verification |

Do **not** duplicate worker steps in manager prompts; paste the worker checklist and add issue-specific context only.

## Repos

| Repo | Role |
|------|------|
| `bazelbuild/bazel` | Source of truth; PRs land here under `docs/` and `scripts/docs/` |
| `bazel-contrib/bazel-docs` (this repo) | Mintlify site; previews at `https://bazel-pr-<N>.mintlify.app/` |

Clone with submodule:
```bash
git clone --recurse-submodules https://github.com/bazel-contrib/bazel-docs.git
```

## Agent skill locations (this repo)

| Tool | Path |
|------|------|
| Canonical | `agent-skills/` |
| Cursor | `.cursor/skills/` → symlinks to `agent-skills/` |
| Claude Code | `.claude/skills/` → symlinks to `agent-skills/` |
| Codex / Gemini | Read `AGENTS.md` at repo root |

Verification scripts: `scripts/verify_mintlify_preview.mjs`, `scripts/screenshot_mintlify_preview.sh`

## Triage rules

**Straightforward (delegate immediately):**
- Hand-authored MDX fixes (`style="..."` → JSX) — merges without regen
- `docs2mdx.py` converter fixes — unit tests + post-merge regen note

**Split tracking issues** (#30598) into individual tasks before delegating.

**Skip or note closed:** #30604 (GPG key, often already fixed upstream).

**Investigation-only (don't promise PRs):** performance (#30671), search (#30672), missing release docs (#30618).

**Stacking:** PRs touching `scripts/docs/docs2mdx.py` conflict. Merge order: anchors → table cells → code entities → flag links.

## Manager workflow

```
- [ ] Read tracking issue comments for repro URLs
- [ ] Classify issues: hand-authored MDX vs docs2mdx vs infra
- [ ] Launch 3–5 sub-agents (Task tool); each follows bazel-docs-fix-worker
- [ ] Push to fork if upstream push denied; draft PR to bazelbuild/bazel
- [ ] Close duplicate PRs when agents overlap
- [ ] Trigger previews: gh workflow run "Preview Bazel docs PRs" --repo bazel-contrib/bazel-docs -f pr_number=<N>
- [ ] After ~10–15 min: node scripts/verify_mintlify_preview.mjs <N> --path <repro-page> [...]
- [ ] Ensure agents have performed visual verification of changes using Mintlify preview
- [ ] Post verification comments on upstream PRs; update test plan checkboxes
```

## Sub-agent prompt template

```
Follow skill: agent-skills/bazel-docs-fix-worker/SKILL.md (in bazel-docs repo)

Issue: bazelbuild/bazel#<NUMBER> — <title>
Root cause hint: <1–2 sentences + file paths>
Branch: docs/fix-<short-name>
Draft PR to bazelbuild/bazel; push to fork if needed.
Return: PR URL, test results, preview verification status.
```

## Preview infrastructure caveats

1. Preview **root** often 404s; check **page paths** (e.g. `/configure/attributes`).
2. **Hand-authored MDX PRs** verify fully in Mintlify preview.
3. **`docs2mdx.py` PRs** may show stale reference MDX in preview until regen runs in sync pipeline.

## Additional resources

- Worker skill: [../bazel-docs-fix-worker/SKILL.md](../bazel-docs-fix-worker/SKILL.md)
- Issue taxonomy: [reference.md](reference.md)
