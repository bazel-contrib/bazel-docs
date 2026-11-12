# Bazel Docs

![Bazel logo](/logo/light.svg)

This repository contains the source and automated preview generation pipeline
for the https://bazel.build/ website.

## Contributing

**Most changes to https://bazel.build/ should be made in the
[bazelbuild/bazel](https://github.com/bazelbuild/bazel) repository.**

See Bazel's [Docs contribution
workflow](https://bazel.build/contribute/docs-contribution-workflow) for more
information on how to make changes to Bazel's documentation site.

### Agent-assisted migration

Agent skills for fixing bazel.build migration bugs live in [`agent-skills/`](agent-skills/).
See [`AGENTS.md`](AGENTS.md) for manager/worker workflows and Mintlify preview verification.

### How to build the Bazel site locally

1. Clone the `bazel-docs` project:

   ```console
   git clone https://github.com/bazel-contrib/bazel-docs.git && cd bazel-docs
   ```

   > WARNING: Do not clone with `--recurse-submodules` or it will break the local
   > preview generation. If you accidentally initialize the upstream submodule, you
   > can deinitialize it with `git submodule deinit -f --all`.

2. If you haven't already, [install
   npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm#using-a-node-version-manager-to-install-nodejs-and-npm).

3. Launch a local preview server with the following command:

   ```console
   npx mint dev
   ```

   <details>

   <summary>Example output</summary>

   ```console
   $ npx mint dev
   Need to install the following packages:
   mint@4.2.679
   Ok to proceed? (y) y
   ✓ preview ready

     local   → http://localhost:3000
     network → http://192.168.1.4:3000

   press ctrl+c to exit the preview
   ```

   </details>

## How it works

Each branch with an active preview deployment in this repo is deployed by Mintlify at `https://bazel-<branch-name>.mintlify.app`.

Files listed in `.mintignore` (gitignore syntax) are excluded from Mintlify rendering. Add files there when they contain MDX syntax errors that block deployment.

### PR preview generation

The preview workflow (`preview-bazel-docs-pr.yml`) polls `bazelbuild/bazel` for recently-updated open PRs targeting `master`/`main`. For each PR that has doc-related changes, it:

1. Creates or updates a `pr-<N>` branch and PR in this repo with the PR's docs.
2. Mintlify deploys that branch at `https://bazel-pr-<N>.mintlify.app`.
3. Posts (or updates) a comment on the upstream PR with the preview link.

The preview workflow can be triggered manually from the GitHub Actions UI via `workflow_dispatch` without waiting for the scheduled cron.

### Updates to the live Bazel website

1. The `upstream` Git submodule tracks `bazelbuild/bazel`.
2. Dependabot (`dependabot.yml`) checks `bazelbuild/bazel` daily for new commits on `master` and opens a submodule update PR, which triggers `dependabot-automerge.yml`.
3. The reusable sync workflow (`pull-from-bazel-build.yml`):
   - Copies `.mdx` files from `upstream/docs/` directly into this repo (propagating deletions via `rsync --delete-after`).
   - Builds reference documentation (Starlark/Java API docs) via `bazel build //src/main/java/com/google/devtools/build/lib:gen_mdx_reference_docs`, which produces clean MDX directly via `docs2mdx.py`.
   - Updates versioned navigation (`navigation.update.sh` and `cleanup-deleted-docs.sh`), commits the result, and pushes to the branch before `dependabot-automerge.yml` squash-merges the PR.
4. Mintlify picks up the merged changes on `main` and deploys the updated docs site at https://bazel.build/.
   - Files listed in `.mintignore` are excluded from Mintlify rendering. These are files with MDX syntax that cannot yet be auto-fixed (see [#226](https://github.com/bazel-contrib/bazel-docs/issues/226)).
