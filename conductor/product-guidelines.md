# Product Guidelines - Bazel Docs Pipeline

## Technical Fidelity
- **Sync Integrity:** The pipeline must ensure that the MDX files and site structure in the preview exactly mirror the state of the upstream `bazelbuild/bazel` docs for the specific commit being previewed.
- **Automated Reference Generation:** Every build must trigger the upstream Bazel target responsible for reference documentation. The resulting artifacts must be integrated into the final site without manual intervention.
- **Reference Doc Propagation:** Generated reference documentation (from Starlark/Java sources) must be correctly integrated into the Mintlify layout, ensuring that the navigation and cross-links remain functional.

## PR Integration Guidelines
- **Minimalist Feedback:** Automated comments on upstream PRs should be concise. They must provide a direct link to the preview and clear status information (e.g., "Updated for commit `hash`").
- **Error Transparency:** If a transformation fails, the error message posted to the PR must be actionable for a Bazel contributor, even if they are not familiar with the internal workings of this pipeline.

## Performance & Freshness
- **Low Latency:** Previews should be generated and updated as quickly as possible after an upstream PR update to minimize friction in the review process.
- **Submodule Management:** The `upstream` submodule must always point to a stable reference point in the main branch, except during active PR preview builds.
