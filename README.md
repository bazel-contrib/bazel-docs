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

### Build the Bazel site locally

If you haven't already, [install
npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm#using-a-node-version-manager-to-install-nodejs-and-npm).

To build the Bazel site and launch a local preview, run the following command
from the root of this repository:

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

Each branch pushed to this repo is automatically deployed by Mintlify at `https://bazel-<branch-name>.mintlify.app`. No additional configuration is required for preview deployments — the branch name determines the subdomain.

Files listed in `.mintignore` (gitignore syntax) are excluded from Mintlify rendering. Add files there when they contain MDX syntax errors that block deployment.

### PR preview generation

The preview workflow (`preview-bazel-docs-pr.yml`) polls `bazelbuild/bazel` every 30 minutes for recently-updated open PRs. For each PR that has doc-related changes, it:

1. Creates or updates a `pr-<N>` branch in this repo with the PR's docs.
2. Mintlify deploys that branch at `https://bazel-pr-<N>.mintlify.app`.
3. Posts (or updates) a comment on the upstream PR with the preview link.

The preview workflow can be triggered manually from the GitHub Actions UI via `workflow_dispatch` without waiting for the 30-minute cron.

### Updates to the live Bazel website

1. The `upstream` Git submodule tracks `bazelbuild/bazel`.
2. On every push to `bazelbuild/bazel`'s main branch, a `repository_dispatch` event triggers this repo to sync the latest docs.
3. The sync workflow (`pull-from-bazel-build.yml`):
   - Copies `.mdx` files from `upstream/docs/` directly into this repo.
   - Builds reference documentation (Starlark/Java API docs) via `bazel build //...gen_mdx_reference_docs`, which produces clean MDX directly via `docs2mdx.py`, and commits the result.
   - Commits the result and pushes to the appropriate branch.
4. Mintlify picks up the changes and deploys the updated docs site.
   - Files listed in `.mintignore` are excluded from Mintlify rendering. These are files with MDX syntax that cannot yet be auto-fixed (see [#226](https://github.com/bazel-contrib/bazel-docs/issues/226)).
