#!/usr/bin/env bash
# Regenerate MDX reference docs for untrusted (fork) upstream PRs.
#
# Builds HTML inputs from a trusted base commit, then runs docs2mdx.py from the
# PR head via Python (not Bazel on fork BUILD files).
#
# Usage (from bazel-docs repo root):
#   ./scripts/regen_reference_docs_split_trust.sh <base_sha> <head_sha>
#
# Writes: upstream/bazel-bin/src/main/java/com/google/devtools/build/lib/mdx-reference-docs.zip

set -euo pipefail

BASE_SHA="${1:?base commit required}"
HEAD_SHA="${2:?head commit required}"
UPSTREAM_DIR="${UPSTREAM_DIR:-upstream}"
OUTPUT_ZIP="${UPSTREAM_DIR}/bazel-bin/src/main/java/com/google/devtools/build/lib/mdx-reference-docs.zip"

HTML_TARGETS=(
  "//src/main/java/com/google/devtools/build/lib:build-encyclopedia.zip"
  "//src/main/java/com/google/devtools/build/lib:command-line-reference.html"
  "//src/main/java/com/google/devtools/build/lib:skylark-library.zip"
  "//tools/build_defs/repo:doc"
)

run_bazel() {
  if [[ -n "${BAZEL_EXTRA_RCFILE:-}" ]]; then
    bazel --bazelrc="${BAZEL_EXTRA_RCFILE}" "$@"
  else
    bazel "$@"
  fi
}

assemble_html_dir() {
  local html_dir="$1"
  local bin
  bin="$(run_bazel info bazel-bin)"

  local repo_doc="${bin}/tools/build_defs/repo/doc.tar"
  if [[ ! -f "${repo_doc}" ]]; then
    repo_doc="$(run_bazel cquery --config=docs --output=files //tools/build_defs/repo:doc 2>/dev/null | head -1)"
  fi
  if [[ -z "${repo_doc}" || ! -f "${repo_doc}" ]]; then
    echo "ERROR: could not locate //tools/build_defs/repo:doc output" >&2
    exit 1
  fi

  mkdir -p "${html_dir}/reference/be" "${html_dir}/rules/lib/repo"
  cp "${bin}/src/main/java/com/google/devtools/build/lib/command-line-reference.html" \
    "${html_dir}/reference/"
  unzip -q -o -d "${html_dir}/reference/be/" \
    "${bin}/src/main/java/com/google/devtools/build/lib/build-encyclopedia.zip"
  unzip -q -o -d "${html_dir}/rules/lib/" \
    "${bin}/src/main/java/com/google/devtools/build/lib/skylark-library.zip"
  tar -xf "${repo_doc}" -C "${html_dir}/rules/lib/repo/"
}

cd "${UPSTREAM_DIR}"

ORIG_SHA="$(git rev-parse HEAD)"
if [[ "${ORIG_SHA}" != "${HEAD_SHA}" ]]; then
  echo "ERROR: expected upstream at head ${HEAD_SHA}, got ${ORIG_SHA}" >&2
  exit 1
fi

echo "Building reference HTML inputs from trusted base ${BASE_SHA}..."
git checkout "${BASE_SHA}"

run_bazel build \
  --config=docs \
  --build_metadata=ROLE=DOCS \
  --bes_results_url=https://app.buildbuddy.io/invocation/ \
  --bes_backend=grpcs://remote.buildbuddy.io \
  --remote_cache=grpcs://remote.buildbuddy.io \
  --remote_timeout=10m \
  "${HTML_TARGETS[@]}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT
HTML_DIR="${WORKDIR}/html_for_mdx"
MDX_DIR="${WORKDIR}/mdx_docs"
mkdir -p "${MDX_DIR}"
assemble_html_dir "${HTML_DIR}"

echo "Checking out PR head ${HEAD_SHA} and running docs2mdx.py..."
git checkout "${HEAD_SHA}"

python3 -m pip install --quiet absl-py markdownify
python3 scripts/docs/docs2mdx.py --in_dir "${HTML_DIR}" --out_dir "${MDX_DIR}"

mkdir -p "$(dirname "${OUTPUT_ZIP}")"
rm -f "${OUTPUT_ZIP}"
(cd "${MDX_DIR}" && zip -qr "${OUTPUT_ZIP}" .)

echo "Wrote ${OUTPUT_ZIP}"
