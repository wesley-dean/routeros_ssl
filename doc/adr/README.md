# Architecture Decisions

This directory contains accepted Architecture Decision Records for
`routeros_ssl`.

## Current Decisions

### ADR-001: Adopt Shared Coding Standards

The repository commits the complete selected shared standards release beneath
`doc/standards/` and records its provenance in `.codingstandardrc`.
Applicable imported standards govern the project, while accepted local ADRs
and explicit policy may refine them.  Imported standards are not edited
locally.

See [ADR-001](ADR-001-adopt-shared-coding-standards.md).

### ADR-002: Adopt Make and bashdeps Dependency Boundary

Make is the repository-level interface for dependency, build, and documentation
operations, while a pinned bootstrap copy of bashdeps prepares ordinary
dependencies from `dependencies.txt`.  `vendor/` remains generated and ignored;
dependency convergence may use the network, while verification and prepared
build/documentation targets remain offline.  Bash built-ins are preferred over
avoidable helper processes when they keep the implementation clear.

See [ADR-002](ADR-002-adopt-make-and-bashdeps-boundary.md).

### ADR-003: Preserve Public Entry Point and Single-Artifact Distribution

The root `letsencrypt-routeros.bash` remains the public entry point for direct
execution, sourcing, raw download, and container use.  ADR-006 superseded the
source-layout portion, and ADR-007 now supersedes the former single-artifact
release contract.

See [ADR-003](ADR-003-preserve-entry-point-and-single-artifact-distribution.md).

### ADR-004: Generate Reference Documentation and ADR Inventory

The repository uses pinned bash-doxygen and adrctl artifacts through the
bashdeps boundary.  `make docs` validates maintained Bash documentation and
generates ignored Doxygen HTML beneath `doc/reference/`, while `make adr-index`
preserves curated current-decision summaries and regenerates only the inventory
below the ADR footer marker.  CI verifies both generated surfaces, while
behavior testing is governed separately by ADR-005.

See [ADR-004](ADR-004-generate-reference-documentation-and-adr-inventory.md).

### ADR-005: Use Bats Characterization Tests with TAP Output

Behavior tests use Bats, emit TAP, and replace live RouterOS transport with
deterministic PATH-injected fakes.  The same suite targets either the root
entry point or a generated artifact through `ROUTEROS_SSL_UNDER_TEST`, while
CI runs root and ordinary distribution coverage as separate TAP streams.
Corrected runtime behavior is protected as regression coverage under ADR-006.

See [ADR-005](ADR-005-use-bats-characterization-tests-with-tap-output.md).

### ADR-006: Embed bashlog and Harden Runtime Boundaries

Maintained application source lives under `src/`, while the historical root
path is a deterministic generated compatibility artifact.  SSH/SCP use argv
arrays, RouterOS-interpolated identifiers cross a conservative validation
boundary, reusable functions return status, and cleanup is explicit after
partial failures.  ADR-007 supersedes only its temporary single-artifact
packaging details.

See [ADR-006](ADR-006-embed-bashlog-and-harden-runtime-boundaries.md).

### ADR-007: Adopt Three-Flavor Distribution Artifacts

The build now produces documented development, comment-stripped ordinary, and
minified standalone Bash artifacts, each with an adjacent SHA-256 file.  The
three files form one development-to-ordinary-to-minified transformation chain,
and the root compatibility artifact corresponds to the ordinary flavor with
stable provenance.  Releases use a validate-then-publish boundary so privileged
publication consumes the exact six previously tested bytes.

See [ADR-007](ADR-007-adopt-three-flavor-distribution-artifacts.md).

### ADR-008: Publish Generated Reference Documentation Through GitHub Pages

Generated Doxygen HTML beneath `doc/reference/` is published through a dedicated
GitHub Pages workflow after dependencies are synchronized and verified through
the existing Make/bashdeps boundary.  The workflow invokes `make docs`, verifies
that generated documentation remains ignored and leaves the checkout clean, then
uploads only `doc/reference/` for deployment.  ADR-004 continues to govern
documentation generation; ADR-008 adds the public hosting contract it explicitly
deferred.

See [ADR-008](ADR-008-publish-generated-reference-documentation-through-github-pages.md).

<!-- adrctl-generated-footer -->

## Architecture Decision Records

* [ADR-001: Adopt Shared Coding Standards](ADR-001-adopt-shared-coding-standards.md)
* [ADR-002: Adopt Make and bashdeps Dependency Boundary](ADR-002-adopt-make-and-bashdeps-boundary.md)
* [ADR-003: Preserve Public Entry Point and Single-Artifact Distribution](ADR-003-preserve-entry-point-and-single-artifact-distribution.md)
* [ADR-004: Generate Reference Documentation and ADR Inventory](ADR-004-generate-reference-documentation-and-adr-inventory.md)
* [ADR-005: Use Bats Characterization Tests with TAP Output](ADR-005-use-bats-characterization-tests-with-tap-output.md)
* [ADR-006: Embed bashlog and Harden Runtime Boundaries](ADR-006-embed-bashlog-and-harden-runtime-boundaries.md)
* [ADR-007: Adopt Three-Flavor Distribution Artifacts](ADR-007-adopt-three-flavor-distribution-artifacts.md)
* [ADR-008: Publish Generated Reference Documentation Through GitHub Pages](ADR-008-publish-generated-reference-documentation-through-github-pages.md)
