# ADR-007: Adopt Three-Flavor Distribution Artifacts

Date: 2026-09-23

## Status

Accepted

## Context

The repository now has maintained source under `src/`, a generated root
compatibility artifact, pinned bashlog bytes, and a TAP regression suite that
can target arbitrary generated artifacts.  Issue #113 is therefore the planned
point to replace the temporary single-artifact distribution contract from
ADR-003 and ADR-006 with the three-flavor model used by related Bash tools.

## Decision

This decision supersedes ADR-003's single-artifact release contract and the
artifact-shape portions of ADR-006.  ADR-006's runtime-hardening decisions
remain governing.

The build SHALL produce exactly these six files beneath ignored `dist/`:

- `letsencrypt-routeros.dev.bash`
- `letsencrypt-routeros.dev.bash.sha256`
- `letsencrypt-routeros.bash`
- `letsencrypt-routeros.bash.sha256`
- `letsencrypt-routeros.min.bash`
- `letsencrypt-routeros.min.bash.sha256`

The transformation chain SHALL be:

`maintained source -> development -> ordinary -> minified`

The development artifact SHALL contain generated provenance, executable
provenance variables, the documented `bashlog.dev.bash` dependency, and the
maintained application source.

The ordinary artifact SHALL be derived only from the development artifact and
remove full-line comments while preserving the shebang and executable
behavior.

The minified artifact SHALL be derived only from the ordinary artifact using a
pinned Bash-Minifier dependency.

The dependency manifest SHALL pin Bash-Minifier commit
`9c824e20815a5bca2153ec25ecc02a4edea1430e` with SHA-256
`93cb422360db4cc410d19b068eb074da020a4a743f0eebc9c442d1e5acd90e9b`.

The committed root `letsencrypt-routeros.bash` SHALL remain the historical
public executable/sourceable path and SHALL correspond to the ordinary flavor
with stable compatibility provenance values.  CI SHALL rebuild it and require
a clean Git diff.

Every executable flavor SHALL pass `bash -n` and the same Bats regression
suite.  Bats output SHALL remain TAP through `bats --tap`.

Each executable artifact SHALL have an adjacent standard `sha256sum`-format
checksum using only the artifact basename.

Release publication SHALL use a validate-then-publish boundary.  A read-only
validation job SHALL calculate the candidate semantic version, prepare
dependencies, build the exact six release files, run behavior tests, verify the
file set and checksums, and upload those exact bytes as a workflow artifact.
A separate job with release-write authority SHALL download and re-verify those
bytes, then create the tag/release and attach the six files without rebuilding
them.

The old post-release rebuild workflow is superseded and SHALL be removed.

## Alternatives Considered

### Build all three flavors independently

Rejected because independent assembly paths can drift.  One transformation
chain keeps provenance and behavior auditable.

### Keep bashlog.bash in the development flavor

Rejected because the development flavor is explicitly review-oriented and
should preserve the documented dependency representation.  The ordinary
transformation removes full-line comments for consumer use.

### Commit dist/

Rejected because all six files are deterministic derivative products.

### Rebuild inside the privileged release job

Rejected because release-write authority should operate only on bytes already
validated without release privileges.

## Consequences

Developers must prepare the additional pinned minifier dependency before
building.  `make build` remains network-free after dependency preparation.

`make test` now exercises the root compatibility artifact and all three
generated flavors as separate TAP streams.

Release consumers gain documented, ordinary, and minified choices while the
historical root path and container input remain compatible.

## Related Decisions

- ADR-003: Preserve Public Entry Point and Single-Artifact Distribution
- ADR-005: Use Bats Characterization Tests with TAP Output
- ADR-006: Embed bashlog and Harden Runtime Boundaries

## Related Issues

- #113: Adopt three-flavor distribution artifacts
