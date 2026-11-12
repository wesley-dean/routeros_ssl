# Architectural Decisions

This is a maintained summary of the project's Accepted ADRs. The complete
ADRs remain authoritative and should be read before changing consequential
interfaces, security boundaries, build/release contracts, or compatibility.

## ADR-001: Adopt Shared Coding Standards

The repository uses a complete externally released shared standards snapshot
under `doc/standards/`. The root `.codingstandardrc` records the current
concrete version and archive digest. Applicable standards govern unless
Accepted local ADRs or explicit policy refine them, and imported files are
not locally modified.

See [ADR-001](adr/ADR-001-adopt-shared-coding-standards.md).

## ADR-002: Adopt Make and bashdeps Dependency Boundary

GNU Make is the canonical development interface, and pinned bashdeps
synchronizes ordinary repository dependencies. Dependencies in `vendor/`
remain generated and are not checked in. The build and documentation paths
consume prepared dependencies without silently using the network.

See [ADR-002](adr/ADR-002-adopt-make-and-bashdeps-boundary.md).

## ADR-003: Preserve Public Entry Point and Single-Artifact Distribution

The root `letsencrypt-routeros.bash` remains a supported public entry
point for sourcing, direct execution, downloads, and container use.
ADR-006 subsequently superseded the source-layout contract, and ADR-007
superseded its single-artifact release model. The preserved compatibility
path remains separate from maintained implementation source.

See [ADR-003](adr/ADR-003-preserve-entry-point-and-single-artifact-distribution.md).

## ADR-004: Generate Reference Documentation and ADR Inventory

Pinned bash-doxygen and adrctl dependencies provide documentation
validation and maintained ADR navigation. The generated Doxygen HTML is
ignored derivative output, and the curated ADR digest remains maintained
above the index marker. The generated ADR footer is produced by the pinned
adrctl release rather than treated as editorial content.

See [ADR-004](adr/ADR-004-generate-reference-documentation-and-adr-inventory.md).

## ADR-005: Use Bats Characterization Tests with TAP Output

The repository uses Bats for deterministic behavior testing instead of
contacting a live RouterOS device. The suite covers root and generated
artifacts through an explicit artifact-under-test selector. TAP remains
the canonical test stream, with the derivative report model governed
separately by ADR-009.

See [ADR-005](adr/ADR-005-use-bats-characterization-tests-with-tap-output.md).

## ADR-006: Embed bashlog and Harden Runtime Boundaries

Application source lives beneath `src/`, and the root compatibility
script is generated deterministically. SSH/SCP argument arrays, validated
RouterOS identifiers, consistent cleanup, and structured error records
define the runtime safety boundary. ADR-007 supersedes only the
temporary single-artifact packaging details.

See [ADR-006](adr/ADR-006-embed-bashlog-and-harden-runtime-boundaries.md).

## ADR-007: Adopt Three-Flavor Distribution Artifacts

Builds produce development, ordinary, and minified standalone Bash
artifacts with one SHA-256 companion each. The public root compatibility
script corresponds to the ordinary artifact with stable provenance.
Releases validate the exact six distributed files before a separately
authorized publication job uploads those bytes.

See [ADR-007](adr/ADR-007-adopt-three-flavor-distribution-artifacts.md).

## ADR-008: Publish Generated Reference Documentation Through GitHub Pages

Generated Doxygen reference material is published through a dedicated
least-privilege GitHub Pages workflow. Documentation is rebuilt using
prepared dependencies and must remain ignored derivative state.
The hosting workflow does not change runtime or release artifacts.

See [ADR-008](adr/ADR-008-publish-generated-reference-documentation-through-github-pages.md).

## ADR-009: Publish Derivative JUnit Test Reports While Preserving TAP

Bats continues to emit TAP while producing derivative JUnit reports
for CI visibility. Validation jobs remain read-only and upload reports
and trusted event metadata through separated steps. A separate
`workflow_run` publisher has narrowly scoped authority to publish
checks and comments without executing untrusted pull-request code.

See [ADR-009](adr/ADR-009-publish-derivative-junit-test-reports-while-preserving-tap.md).

## ADR-010: Consolidate GitHub Actions Dependabot Version Updates

Routine GitHub Actions version updates remain weekly with a new
seven-day cooldown and a wildcard major/minor/patch group. Security
updates remain independent, and major-containing groups stay outside
the existing non-major-only auto-merge route. The change preserves
RouterOS runtime, artifact, and CI trust boundaries and does not
automatically close existing Dependabot PRs.

See [ADR-010](adr/ADR-010-consolidate-github-actions-dependabot-maintenance.md).
