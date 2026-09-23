# ADR-003: Preserve Public Entry Point and Single-Artifact Distribution

Date: 2026-09-23

## Status

Accepted

## Context

`letsencrypt-routeros.bash` is both the repository's maintained implementation
and its historical public entry point.  Existing users may execute it directly,
source its functions, download it from the raw GitHub path, or consume the
container image that copies the root file.  Issue #110 also requires release
artifacts to carry build provenance and an adjacent SHA-256 checksum.

A later backlog item, issue #113, will consider the documented/ordinary/minified
three-flavor distribution model used by related Bash tools.  Introducing that
model now would collapse two intentionally separate review stages and make the
baseline build contract harder to characterize before behavior tests exist.

## Decision

The root `letsencrypt-routeros.bash` file SHALL remain the maintained and public
sourceable/executable entry point during this modernization stage.  The
container image SHALL continue to consume that root path.

`dist/` SHALL be generated, ignored derivative state.  `make build` SHALL
produce:

- `dist/letsencrypt-routeros.bash`; and
- `dist/letsencrypt-routeros.bash.sha256`.

The generated executable SHALL be derived from the root script without changing
its maintained executable body.  The build SHALL preserve the shebang, insert
a generated provenance header and executable provenance variables, then copy
the remainder of the maintained file in order.  At minimum, provenance SHALL
record project name, version, build date, and source commit identifier.

For reproducibility, the default build date SHALL be the source commit timestamp
rather than the wall-clock time at which Make happens to run.  Both build date
and commit identifier MAY be overridden explicitly by controlled build
environments.  The default development version is `0.0.0-dev`; release
automation SHALL pass the release version explicitly.

The generated artifact SHALL pass `bash -n` before replacing any prior artifact.
The adjacent checksum SHALL use standard `sha256sum` format and name only
`letsencrypt-routeros.bash`, making verification independent of the checkout
path.

Published releases SHALL attach those exact two files from `dist/`.  Release
attachment occurs after the release is published and does not replace the
existing container publication workflow.

## Alternatives Considered

### Move maintained source beneath src/ now

Rejected for this stage because it would add a source-layout migration before
the characterization suite in issue #111 exists.  The root path is already a
public compatibility surface and can remain the maintained source until a
later decision has stronger reasons to split maintained and generated forms.

### Commit dist/

Rejected because the artifact is deterministic derivative output with embedded
build provenance.  Committing it would duplicate maintained source and create
avoidable source-scanning noise.

### Adopt three flavors immediately

Rejected because issue #113 intentionally follows behavior characterization
and runtime hardening.  The ordinary single-artifact contract provides a
smaller baseline that can be tested before being transformed further.

### Use wall-clock build time

Rejected as the default because identical source/version inputs would then
produce different bytes on every build.  Using the source revision timestamp
retains meaningful provenance while making repeated builds reproducible.

## Consequences

`make all` becomes the clean-checkout path that prepares dependencies and
produces the ordinary release artifact.  Existing raw-download, sourced-script,
and container consumers continue to use the root file without migration.

Issue #113 may later supersede the distribution portions of this decision while
preserving the public-entry-point compatibility requirement.  Until then, only
the ordinary artifact and its checksum belong to the release contract.

## Related Decisions

- ADR-002: Adopt Make and bashdeps Dependency Boundary

## Related Issues

- #110: Modernize repository governance, documentation, and build tooling
- #111: Add Bats characterization tests for current behavior
- #113: Adopt three-flavor distribution artifacts
