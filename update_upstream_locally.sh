#!/usr/bin/env bash
set -euo pipefail

# Reproduce the steps from .github/workflows/pull-from-bazel-build.yml locally.
#
# Usage:
#   ./run-pull-from-bazel-build.sh [--reference-zip PATH]
#
# Options:
#   --reference-zip PATH   Path to the upstream reference docs archive (default
#                          upstream/bazel-bin/src/main/java/com/google/devtools/build/lib/reference-docs.zip).
#   -h, --help             Show this help text.

REFERENCE_ZIP="upstream/bazel-bin/src/main/java/com/google/devtools/build/lib/reference-docs.zip"

function usage() {
  sed -n 's/^# //p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reference-zip)
      if [[ $# -lt 2 ]]; then
        echo "Error: --reference-zip requires an argument" >&2
        exit 1
      fi
      REFERENCE_ZIP="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

function run() {
  echo "+ $*"
  "$@"
}

if [[ ! -f .github/workflows/pull-from-bazel-build.yml ]]; then
  echo "Please run this script from the repository root." >&2
  exit 1
fi

run git submodule update --init -- upstream

if [[ ! -f "$REFERENCE_ZIP" ]]; then
  echo "Error: reference docs archive not found at $REFERENCE_ZIP" >&2
  echo "Provide the archive with --reference-zip if it lives elsewhere." >&2
  exit 1
fi

run ./cleanup-mdx.sh

run ./run-in-go-docker.sh "$REFERENCE_ZIP"
  

run ./copy-upstream-docs.sh
run ./docs.json.update.sh

rm -rf "reference-docs-temp"
echo "Workflow reproduction completed successfully."