# Bazel Docs — Agent Guide

This repository hosts the Mintlify pipeline for https://bazel.build/. Most doc
content lives in [bazelbuild/bazel](https://github.com/bazelbuild/bazel); this
repo syncs and deploys it.

## Documentation migration (agent skills)

For bazel.build migration bugs (tracking issue
[bazelbuild/bazel#30598](https://github.com/bazelbuild/bazel/issues/30598)):

| Role | Skill path |
|------|------------|
| Manager (orchestrate sub-agents) | [agent-skills/bazel-docs-migration-manager/SKILL.md](agent-skills/bazel-docs-migration-manager/SKILL.md) |
| Worker (one issue → one PR) | [agent-skills/bazel-docs-fix-worker/SKILL.md](agent-skills/bazel-docs-fix-worker/SKILL.md) |
| Issue taxonomy | [agent-skills/bazel-docs-migration-manager/reference.md](agent-skills/bazel-docs-migration-manager/reference.md) |

### Visual verification

After a bazelbuild/bazel doc PR gets a Mintlify preview comment:

```bash
export PATH="$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node | tail -1)/bin:$PATH"
cd /tmp && npm init -y && npm install playwright && npx playwright install chromium
node scripts/verify_mintlify_preview.mjs <bazel PR number> --path /path/to/check [--path ...]
# Optional: --checks-file with schema from scripts/examples/mintlify-checks.example.json
```

Trigger preview manually:

```bash
gh workflow run "Preview Bazel docs PRs" --repo bazel-contrib/bazel-docs -f pr_number=<N>
```

### Tool discovery

| Tool | Discovery path |
|------|----------------|
| Cursor | `.cursor/skills/` (symlinks to `agent-skills/`) |
| Claude Code | `.claude/skills/` (symlinks) + [CLAUDE.md](CLAUDE.md) |
| Codex / Gemini | This file (`AGENTS.md`) |

## Where to make changes

| Change type | Repository |
|-------------|------------|
| Doc content, MDX, `docs2mdx.py` | `bazelbuild/bazel` |
| Preview pipeline, Mintlify config | This repo (`bazel-contrib/bazel-docs`) |

See [README.md](README.md) and [CLAUDE.md](CLAUDE.md) for pipeline details.

## Upstream bazel agent guide

For building/testing Bazel itself, see `upstream/AGENTS.md` after initializing
the submodule.
