#!/usr/bin/env bash
# Capture screenshots of Mintlify preview pages for bazelbuild/bazel PRs.
#
# Usage (from bazel-docs repo root):
#   ./scripts/screenshot_mintlify_preview.sh <pr_number> <page_path> [<page_path>...]
#
# Example:
#   ./scripts/screenshot_mintlify_preview.sh 12345 /configure/attributes /release/rolling
#
# Requires: node/npm + npx playwright

set -euo pipefail

PR="${1:?PR number required}"
shift || true

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <pr_number> <page_path> [<page_path>...]" >&2
  echo "Example: $0 12345 /configure/attributes /reference/be/common-definitions" >&2
  exit 1
fi

BASE_URL="https://bazel-pr-${PR}.mintlify.app"
OUT_DIR="/tmp/bazel-docs-screenshots/pr-${PR}"
mkdir -p "${OUT_DIR}"

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx not found. Install Node.js/npm first." >&2
  exit 1
fi

# Root often 404s; probe first requested page path
PROBE="${1%%#*}"
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}${PROBE}")"
if [[ "${code}" != "200" ]]; then
  echo "ERROR: Preview page not ready at ${BASE_URL}${PROBE} (HTTP ${code})" >&2
  exit 1
fi

for path in "$@"; do
  nav_path="${path%%#*}"
  fragment=""
  [[ "${path}" == *"#"* ]] && fragment="${path#*#}"
  slug="$(echo "${nav_path}" | tr '/:' '-' | sed 's/^-//')"
  outfile="${OUT_DIR}/screenshot-${slug}.png"
  url="${BASE_URL}${nav_path}"
  [[ -n "${fragment}" ]] && url="${url}#${fragment}"
  echo "Capturing ${url} -> ${outfile}"
  npx --yes playwright screenshot --full-page --wait-for-timeout 3000 "${url}" "${outfile}"
done

echo "Screenshots saved to ${OUT_DIR}"
