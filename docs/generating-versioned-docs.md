# Generating a Versioned Docset

Generate and publish the versioned documentation snapshot for a new Bazel release, for example, `9.1.0`.

## Overview

There are two repos involved:

| Repo | Purpose |
|---|---|
| `bazelbuild/bazel` | Source of truth for docs. Versioned snapshots live in `docs/versions/X.Y.Z/`. |
| `bazel-contrib/bazel-docs` | Pipeline and hosting. Syncs docs through git submodule; deploys with Mintlify. |

The high-level flow is:
1. Build the release docs from the `release-X.Y.Z` branch of `bazelbuild/bazel`.
2. Convert to MDX and validate locally.
3. Fix any MDX syntax errors.
4. Open a PR against `bazelbuild/bazel` master with the new `docs/versions/X.Y.Z/` folder.
5. Open a navigation PR against `bazel-contrib/bazel-docs`.

---

## Two build paths

The process differs depending on whether the release branch contains the MDX
build tooling. Check first, then follow the matching path:

```bash
git show origin/release-X.Y.Z:scripts/docs/BUILD | grep "gen_mdx"
```

| Result | Build target | Output | Path |
|---|---|---|---|
| Prints a target name | `gen_mdx_release_docs` | MDX files directly in a zip | **Path A** |
| Prints nothing | `gen_release_docs --config=docs` + `docs2mdx.py` | Markdown/HTML → converted to MDX | **Path B** |

The MDX tooling is added to release branches over time, so which path applies
will change as new releases are made. Always run the check above rather than
assuming based on version number.

---

## Prerequisites

Install these once if you haven't already.

```bash
# Bazel (via Bazelisk — reads .bazelversion automatically)
brew install bazelisk

# GNU grep — required by get_workspace_status.sh on macOS
# macOS ships BSD grep which doesn't support the -P flag the script needs
brew install grep

# Mintlify CLI — for validating MDX locally
npm install -g mintlify

# GitHub CLI — for opening PRs from the terminal
brew install gh
gh auth login

# Python deps for docs2mdx.py (Path B only)
pip3 install absl-py markdownify
```

---

## Step 1: Set up the build environment

Work inside your local clone of `bazelbuild/bazel`.

```bash
cd ~/path/to/bazel

# On macOS: put GNU grep first in PATH so get_workspace_status.sh works
export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
```

### Path A: Cherry-pick MDX tooling, then check out release branch

The release branch doesn't include the MDX build tooling from `main`.
Cherry-pick the required commits — ask the docs maintainer for the right hashes
for your release. For reference, the 9.1.0 docs required these:

```bash
git checkout release-X.Y.Z
git cherry-pick bc436e3 a4e5d84 8ca49ef 4c6b39b 8f80aea 1c114e3 e602c70
```

Then verify the version stamp before building:

```bash
bash tools/workspace_status_writer/get_workspace_status.sh
```

It should print `BUILD_SCM_REVISION X.Y.Z`. If it shows `UNSAFE_release-X.Y.Z`
instead, either GNU grep isn't in PATH or your local tags are stale — run
`git fetch --tags` and re-check.

### Path B: Check out release branch directly

No cherry-picks needed. Just check out and verify:

```bash
git checkout release-X.Y.Z

# Verify the version stamp
export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
bash scripts/docs/get_workspace_status.sh
```

---

## Step 2: Build the release docs

### Path A

```bash
bazel build //scripts/docs:gen_mdx_release_docs
```

This produces `bazel-bin/scripts/docs/mdx_release_docs.zip`.
The zip's internal structure already contains `versions/X.Y.Z/` with `.mdx` files.

### Path B

```bash
bazel build //scripts/docs:gen_release_docs --config=docs
```

This produces `bazel-bin/scripts/docs/release_docs.zip` with `.md` and `.html`
files — not yet MDX. Conversion happens in the next step.

---

## Step 3: Extract and convert to MDX

### Path A: Extract the zip

**Important**: Extract from the `bazel-docs` repo root, not into a subdirectory.
The zip already has `versions/X.Y.Z/` inside it.

```bash
cd ~/path/to/bazel-docs
unzip ~/path/to/bazel/bazel-bin/scripts/docs/mdx_release_docs.zip
```

<Tip>
**Double-nested paths**: If you run `unzip ... -d versions/X.Y.Z/`, you'll get
`versions/X.Y.Z/versions/X.Y.Z/`. Always unzip from the `bazel-docs` root.
</Tip>

### Path B: Extract, then run docs2mdx.py

Get `docs2mdx.py` from `main` (it doesn't exist on older release branches):

```bash
cd ~/path/to/bazel
git show origin/master:scripts/docs/docs2mdx.py > /tmp/docs2mdx.py
```

Extract the zip to a temp directory and convert:

```bash
mkdir -p /tmp/bazel-X.Y.Z-raw
unzip bazel-bin/scripts/docs/release_docs.zip -d /tmp/bazel-X.Y.Z-raw

mkdir -p /tmp/bazel-X.Y.Z-mdx
python3 /tmp/docs2mdx.py \
  --in_dir=/tmp/bazel-X.Y.Z-raw/versions/X.Y.Z \
  --out_dir=/tmp/bazel-X.Y.Z-mdx
```

Then copy the MDX output into `bazel-docs`:

```bash
cp -r /tmp/bazel-X.Y.Z-mdx ~/path/to/bazel-docs/versions/X.Y.Z
```

---

## Step 4: Validate with Mintlify

```bash
# Must be run from the bazel-docs root (where docs.json lives)
cd ~/path/to/bazel-docs
mint validate
```

<Tip>
**Validate in the correct directory**: Running `mint validate` from inside `versions/X.Y.Z/`
gives "must be run in a directory where a docs.json file exists". Always run
it from the repo root.
</Tip>

Docs produced by Path A typically have more errors on first run.
Docs produced by Path B (via `docs2mdx.py`) often pass `mint validate`
immediately, but still need the fixes in Step 5.

---

## Step 5: Fix MDX syntax errors

Run this checklist to find all known error categories:

```bash
cd ~/path/to/bazel-docs

echo "Jekyll anchors {:#}:";    grep -rl "{:#" versions/X.Y.Z/ | wc -l
echo "{: .external}:";          grep -rl "{: .external}" versions/X.Y.Z/ | wc -l
echo "Jinja-escaped tags:";     grep -rl "{{ '<" versions/X.Y.Z/ | wc -l
echo "DevSite keywords:";       grep -rl "^keywords:" versions/X.Y.Z/ | wc -l
echo "Non-self-closing <img>:"; grep -rl "<img [^>]*[^/]>" versions/X.Y.Z/ | wc -l
echo "Non-self-closing <col>:"; grep -rl "<col [^>]*[^/]>" versions/X.Y.Z/ | wc -l
```

All should be `0` before opening the PR. Apply whichever fixes are needed:

### a. Jekyll heading anchors → MDX format

Jekyll: `## My Heading {:#my-heading}`
MDX:    `## My Heading {#my-heading}`

```bash
grep -rl "{:#" versions/X.Y.Z/ | xargs sed -i '' 's/{:#/{#/g'
```

### b. `{: .external}` link attributes

```bash
grep -rl "{: .external}" versions/X.Y.Z/ | xargs sed -i '' 's/{: \.external}//g'
```

### c. Jinja-escaped HTML tags

The build sometimes escapes HTML tags as Jinja templates:
`{{ '<var>' }}text{{ '</var>' }}` → should be `<var>text</var>`

```bash
grep -rl "{{ '<" versions/X.Y.Z/ | xargs perl -i -pe "s/\{\{ '(<\/?\w+>)' \}\}/\$1/g"
```

Then check for stragglers with unusual spacing (no space before `}}`):

```bash
grep -rn "{{ '<" versions/X.Y.Z/
```

Fix those manually by replacing the full `{{ '</tag> '}}` with `</tag>`.

### d. DevSite metadata before frontmatter

Some files have `keywords:` lines or Jinja `{# ... #}` comments before the
YAML frontmatter `---`. Mintlify expects the file to start with `---`.

```bash
grep -rl "^keywords:" versions/X.Y.Z/
```

For each file, remove everything above the first `---`:

```python
# python3 fix_devsite_meta.py path/to/file.mdx
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
idx = content.find('---\n')
if idx > 0:
    with open(path, 'w') as f:
        f.write(content[idx:])
```

### e. Non-self-closing void HTML tags

JSX requires `<img>` and `<col>` to be self-closing.

```bash
grep -rl "<img [^>]*[^/]>" versions/X.Y.Z/ | xargs perl -i -pe 's/<img ([^>]*[^\/\s])>/<img $1 \/>/g'
grep -rl "<col [^>]*[^/]>" versions/X.Y.Z/ | xargs perl -i -pe 's/<col ([^>]*[^\/\s])>/<col $1 \/>/g'
```

Re-run `mint validate` to confirm zero errors before continuing.

---

## Step 6: Fix errors with AI assistance

For errors that are hard to catch with grep — subtle rendering issues,
broken table syntax, malformed HTML blocks — use an AI tool with the
following prompt. Paste it along with any specific files or error output
you want fixed.

---

**AI prompt for MDX syntax fixes:**

> You are helping fix MDX syntax errors in Bazel documentation files that were
> converted from an older Markdown/HTML format to MDX for the Mintlify platform.
>
> Please fix the following known error categories in any files I share:
>
> 1. **Jekyll heading anchors**: `{:#anchor-id}` → `{#anchor-id}` (remove the colon)
> 2. **External link attributes**: remove `{: .external}` entirely from links
> 3. **Jinja-escaped HTML tags**: `{{ '<var>' }}text{{ '</var>' }}` → `<var>text</var>`
>    (also handles `<sub>`, `<sup>`, and other tags; watch for unusual spacing like `{{ '</var> '}}`)
> 4. **DevSite metadata**: remove any lines before the opening `---` frontmatter block,
>    including `keywords:` lines and `{# ... #}` Jinja comments
> 5. **Non-self-closing void elements**: `<img ...>` → `<img ... />` and `<col ...>` → `<col ... />`
> 6. **Unescaped `<` and `>` in prose**: characters like `<==` or `<workspace-name>` that
>    appear outside of code blocks must be escaped as `&lt;` and `&gt;` so JSX doesn't
>    try to parse them as tags
> 7. **HTML `<pre>` blocks containing variables or special characters**: convert to
>    fenced code blocks (``` ``` ```) since `<pre>` content is parsed as JSX
>
> Rules:
> - Only change what is listed above. Do not reword, restructure, or improve content.
> - Preserve all code blocks exactly. Do not alter anything inside ``` fences or `inline code`.
> - After fixing, the file must pass `mint validate` with zero errors.
> - Do not add `Co-Authored-By` lines to any commit messages.

---

## Step 7: Restore heading anchor IDs

The conversion strips all custom heading anchor IDs, for example, `{#my-anchor}`,
which are needed for stable deep links. Restore them by copying from a
snapshot that already has correct MDX-format anchors.

**Choosing the anchor source:**

Use the most recent versioned snapshot in `bazel-docs/versions/` that already
has heading anchors (lines matching `## ... {#anchor-id}`). To find it:

```bash
# Find the most recent snapshot with anchors
for v in $(ls versions/ | sort -V -r); do
  count=$(grep -rl " {#" versions/$v/ 2>/dev/null | wc -l | tr -d ' ')
  echo "$v: $count files with anchors"
  [ "$count" -gt 0 ] && break
done
```

Use that version as your source. Older snapshots produced before the MDX
migration have no anchors and yield 0 results.

Use the script `copy_anchors_SOURCE_to_TARGET.py` at the `bazel-docs` root.
Adapt it for your versions by changing the `SOURCE_DIR` and `TARGET_DIR`
variables at the top, then run:

```bash
python3 copy_anchors_9_0_to_9_1.py
# Output: "957 anchors added across 98 files" (numbers vary by release)
```

Then re-run `mint validate` to confirm it's still clean.

---

## Step 8: Open the PR in bazelbuild/bazel

The PR goes against **master**, not the release branch.

```bash
cd ~/path/to/bazel

git checkout master
git pull origin master
git checkout -b add-X.Y.Z-release-docs

# Copy the validated docs from bazel-docs into the bazel repo
cp -r ~/path/to/bazel-docs/versions/X.Y.Z docs/versions/X.Y.Z

git add docs/versions/X.Y.Z/
git commit -m "docs: Add X.Y.Z release docs."

# Push to your fork (not origin — that's bazelbuild/bazel directly)
git push fork add-X.Y.Z-release-docs
```

Open a PR at `https://github.com/YOUR_USERNAME/bazel/pull/new/add-X.Y.Z-release-docs`.
Set the base to **`bazelbuild/bazel` master**.

**Gotchas:**
- Do not include `Co-Authored-By: Claude ...` or any AI tool lines in commits as these cause the Google CLA bot to fail.
- Always target `master`, not `release-X.Y.Z`. Branching off the release branch pulls in hundreds of unrelated commits.
- Do not add or restore `docs/reference/command-line-reference.mdx`. This file does not exist on master and its presence causes presubmit failures.

---

## Step 9: Open the navigation PR in bazel-contrib/bazel-docs

The Mintlify navigation needs to be updated to include the new version in the
version selector. This is a separate PR against `bazel-contrib/bazel-docs`.

```bash
cd ~/path/to/bazel-docs

# The navigation files to update:
# - navigation.json
# - navigation/X.Y.en.json  (new file)
```

Check with the maintainers whether the navigation update happens automatically
through the sync pipeline or needs a manual PR.

---

## Checklist

- [ ] Determined correct build path (Path A or Path B)
- [ ] GNU grep in PATH before building (macOS)
- [ ] `BUILD_SCM_REVISION` shows `X.Y.Z` (not `UNSAFE_...`)
- [ ] MDX files extracted/converted into `bazel-docs/versions/X.Y.Z/`
- [ ] `mint validate` shows 0 errors
- [ ] All MDX error categories fixed and verified with grep checklist in Step 5
- [ ] Heading anchors restored from appropriate source version
- [ ] `mint validate` still passes after anchor restoration
- [ ] PR targets `bazelbuild/bazel` master (not the release branch)
- [ ] No `command-line-reference.mdx` outside `docs/versions/X.Y.Z/`
- [ ] No `Co-Authored-By` AI tool lines in commits
- [ ] Navigation PR opened in `bazel-contrib/bazel-docs`
