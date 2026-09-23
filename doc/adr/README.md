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

The root `letsencrypt-routeros.bash` remains the maintained public entry point
for direct execution, sourcing, raw download, and container use.  The build
adds reproducible provenance to a generated ordinary artifact beneath `dist/`
and creates an adjacent SHA-256 companion, while releases attach only those two
generated files.  The later three-flavor backlog item may supersede the
distribution portion of this decision without breaking the root path.

See [ADR-003](ADR-003-preserve-entry-point-and-single-artifact-distribution.md).

### ADR-004: Generate Reference Documentation and ADR Inventory

The repository uses pinned bash-doxygen and adrctl artifacts through the
bashdeps boundary.  `make docs` validates maintained Bash documentation and
generates ignored Doxygen HTML beneath `doc/reference/`, while `make adr-index`
preserves curated current-decision summaries and regenerates only the inventory
below the ADR footer marker.  CI verifies both generated surfaces without
introducing the Bats behavior suite reserved for the next modernization stage.

See [ADR-004](ADR-004-generate-reference-documentation-and-adr-inventory.md).

<!-- adrctl-generated-footer -->

## Architecture Decision Records

* [ADR-001: Adopt Shared Coding Standards](ADR-001-adopt-shared-coding-standards.md)
* [ADR-002: Adopt Make and bashdeps Dependency Boundary](ADR-002-adopt-make-and-bashdeps-boundary.md)
* [ADR-003: Preserve Public Entry Point and Single-Artifact Distribution](ADR-003-preserve-entry-point-and-single-artifact-distribution.md)
* [ADR-004: Generate Reference Documentation and ADR Inventory](ADR-004-generate-reference-documentation-and-adr-inventory.md)
