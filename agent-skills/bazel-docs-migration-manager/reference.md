# Bazel docs migration — reference

## Issue → fix location map

| Issue | Symptom | Fix location | Preview verifies? |
|-------|---------|--------------|-------------------|
| #30658, #30668 | HTTP 500 / excluded pages with `style="..."` | Hand-authored `docs/**/*.mdx` → JSX `style={{...}}` | Yes |
| #30617 | Broken `#anchor` on reference headings | `scripts/docs/docs2mdx.py` — preserve `{#id}` | After regen |
| #30614, #30616, #30615 | Lists/tables squished in table cells | `docs2mdx.py` — raw HTML in complex cells | After regen |
| #30669 | `&lt;` `&lcub;` in code blocks | `docs2mdx.py` — skip entity escape in code/pre | Partial (narrative pages) |
| #30670 | Flag URLs not copyable | `docs2mdx.py` — move links out of `<code>` | After regen |
| #30604 | GPG key 404 | `docs/install/*.mdx` — use `releases.bazel.build` URL | N/A |
| #30618 | Missing version docs | Release branch + `gen_release_docs` | N/A |

## Fix patterns

### JSX inline styles (from PR #30657)

```jsx
// Before (breaks MDX)
<tr style="background: #E9E9E9; font-weight: bold">

// After
<tr style={{background: "#E9E9E9", fontWeight: "bold"}}>
```

### docs2mdx tests (run in bazel repo)

```bash
bazel test //scripts/docs:docs2mdx_test //scripts/docs:rewriter_test
```

### Mintlify preview verification (run in this repo)

```bash
export PATH="$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node | tail -1)/bin:$PATH"
cd /tmp && npm init -y && npm install playwright && npx playwright install chromium
node scripts/verify_mintlify_preview.mjs <bazelbuild/bazel PR number>
```

## Verification pages by PR type

| Fix type | Pages to check |
|----------|----------------|
| Inline styles | `/configure/attributes`, `/release/rolling`, `/external/mod-command` |
| Heading anchors | `/reference/be/common-definitions#common-attributes` |
| Table cells | `/reference/be/common-definitions` (aspect_hints, tags, size rows) |
| Code entities | `/remote/output-directories` |
| Flag links | `/reference/command-line-reference` — `a[href*="flag--"]` |
