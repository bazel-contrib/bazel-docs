# Setup: "Bazel Docs PR Commenter" GitHub App

This runbook sets up the dedicated GitHub App that posts docs-preview comments on
`bazelbuild/bazel` pull requests. It replaces the old `BAZELBUILD_BAZEL_PAT` personal
access token (see [#400](https://github.com/bazel-contrib/bazel-docs/issues/400)).

Why an App instead of a PAT: a PAT is tied to a single human's account and inherits all
of that human's access. A GitHub App is a first-class service account, scoped to exactly
the permissions and repositories it needs — the model security teams expect for
automation.

The App is **owned by the `bazel-contrib` org** but must be **installed on
`bazelbuild/bazel` by a Bazel org owner**. Those are two separate steps with two
different owners; the workflow degrades gracefully in between.

---

## Step 1 — Create the App (bazel-contrib org owner)

Settings → Developer settings → GitHub Apps → **New GitHub App**.

| Field | Value |
|---|---|
| **GitHub App name** | `Bazel Docs PR Commenter` |
| **Homepage URL** | `https://github.com/bazel-contrib/bazel-docs` |
| **Webhook** | **Uncheck "Active"** — this App is polled by Actions, it receives no webhooks |
| **Where can this App be installed?** | **Any account** — required so it can be installed on `bazelbuild`, a different org |

### Repository permissions (least privilege)

| Permission | Access | Why |
|---|---|---|
| **Issues** | **Read and write** | Post and update the preview comment. A PR conversation comment is created via the REST issue-comments endpoint (`POST /repos/{o}/{r}/issues/{n}/comments`), which GitHub's fine-grained permissions reference lists under **Issues** — not Pull requests. The `read` half lets the workflow find an existing comment to update. |
| Metadata | Read-only | Mandatory; auto-selected |

Nothing else. No `contents`, no `pull requests`, no org permissions, no account permissions.

> **Why not "Pull requests"?** The App token only ever calls the issue-comments
> endpoints. Every `/pulls/*` read in the workflow (list open PRs, read changed files,
> read PR state during cleanup) runs on the bazel-docs repo's own `GITHUB_TOKEN`, which
> can read any public repo — confirmed in production: the cron has been doing exactly
> these cross-repo reads with `github.token` since the PAT was retired. So the App needs
> no Pull-requests access at all.
>
> Note the asymmetry in GitHub's reference: *updating* or *listing* issue comments can
> use either Issues or Pull requests, but *creating* one is listed only under Issues. The
> first comment on a PR is a create, so `Issues: write` is the load-bearing permission.

Click **Create GitHub App**.

## Step 2 — Capture credentials (bazel-contrib org owner)

1. On the App's page, note the **App ID** (a number).
2. Scroll to **Private keys** → **Generate a private key**. A `.pem` downloads. Treat it
   like a password.

Add both as **repository secrets** on `bazel-contrib/bazel-docs`
(Settings → Secrets and variables → Actions → New repository secret):

| Secret name | Value |
|---|---|
| `BAZEL_PR_COMMENTER_APP_ID` | the App ID from step 1 |
| `BAZEL_PR_COMMENTER_PRIVATE_KEY` | the **entire** contents of the `.pem` file, including the `-----BEGIN/END-----` lines |

## Step 3 — Request installation on `bazelbuild/bazel` (Bazel org owner)

Because `bazel-contrib` maintainers are not owners of the `bazelbuild` org, a Bazel org
owner has to install (or approve the installation request for) the App on the
`bazelbuild/bazel` repository.

Either: from the App page → **Install App** → choose the `bazelbuild` org → **Only select
repositories** → `bazelbuild/bazel`. If you lack permission, GitHub files an approval
request to the org owners automatically.

Use the template in [Appendix A](#appendix-a--maintainer-request-template) to ask.

Confirm the install grants exactly **Issues: Read and write** on
**`bazelbuild/bazel` only**.

## Step 4 — Verify

1. Actions → **Preview Bazel docs PRs** → **Run workflow**, set `pr_number` to any open
   `bazelbuild/bazel` PR that touches `docs/`.
2. The `comment` job's **Mint upstream comment token** step should succeed (green). If it
   shows as failed-but-continued, the App is not yet installed on `bazelbuild/bazel` —
   the run will still build the preview and the comment step will log the URL it *would*
   have posted instead of erroring.
3. On success, a `<!-- bazel-docs-preview -->` comment appears on the upstream PR,
   authored by `bazel-docs-pr-commenter[bot]`.

## Step 5 — Decommission the PAT

Once a real comment posts from the App, delete the old `BAZELBUILD_BAZEL_PAT` repository
secret and revoke the underlying personal access token in the human owner's GitHub
settings. The workflow no longer references it.

---

## Appendix A — Maintainer request template

> **Subject:** Approve install of "Bazel Docs PR Commenter" GitHub App on bazelbuild/bazel
>
> Hi Bazel maintainers,
>
> bazel-contrib/bazel-docs runs the docs-preview bot that comments a rendered Mintlify
> preview link on `bazelbuild/bazel` PRs that touch `docs/`. It currently posts using a
> personal access token, which we want to retire in favor of a scoped service account.
>
> Could an org owner install our GitHub App **"Bazel Docs PR Commenter"** (owned by the
> `bazel-contrib` org) on **`bazelbuild/bazel` only**, with a single permission:
>
> - **Issues: Read and write** — post/update the preview comment (a PR conversation
>   comment is created via the issue-comments REST endpoint, which is governed by the
>   Issues permission).
>
> No contents, pull-requests, or org-level access. No webhooks. Install link: <App
> "Install" page URL>. Tracking issue: bazel-contrib/bazel-docs#400. Thanks!
