#!/usr/bin/env bash
# Ask Bazel to dump the flags as a binary protobuf, and save in our repo for later rendering.
set -o errexit -o nounset -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ -z "${USE_BAZEL_VERSION:-}" ]; then
  export USE_BAZEL_VERSION=rolling
  OUTPUT_FILE=flags.mdx
else
  OUTPUT_FILE=${USE_BAZEL_VERSION}/flags.mdx
fi
bazel help flags-as-proto | node flags_to_markdown_converter/convert.js > ${OUTPUT_FILE}
