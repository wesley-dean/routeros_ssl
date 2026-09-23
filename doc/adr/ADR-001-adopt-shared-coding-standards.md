# ADR-001: Adopt Shared Coding Standards

Date: 2026-09-23

## Status

Accepted

## Context

The repository predates the shared coding-standards library used by related
Bash projects and currently has no repository-local governance layer that
declares those standards authoritative.  Issue #110 begins a modernization
sequence that will add build tooling, documentation generation, behavior
tests, bug fixes, and a later multi-artifact distribution model.  Those
changes need one explicit and reviewable baseline for coding, documentation,
workflow, release, and ADR practices.

The canonical standards are released from
`https://github.com/wesley-dean/coding_standards.git`.  Release `v1.0.11` is
the stable release selected for this adoption.  Its released
`coding_standards.tar.gz` artifact has SHA-256
`d4f931a089782e3b7c6c8ee09fcb0ca999c42f3dc99353f38243bb1565af8138`
and the release tag resolves to commit
`ef7e670f1de3d9912011bd8398181630c2d446f2`.

## Decision

The repository SHALL adopt the complete `coding_standards@v1.0.11` release
snapshot beneath `doc/standards/`.  `.codingstandardrc` SHALL record the
canonical upstream source, concrete release, verified release-archive digest,
and managed destination.

Applicable imported standards are repository governance.  They SHALL NOT be
edited locally.  Repository-specific exceptions, refinements, or
supersessions SHALL be expressed through accepted local ADRs or other
explicit repository policy.

The imported standards SHALL remain a committed readable snapshot rather than
a build-time dependency.  `bashdeps`, Make targets, submodules, updater
workflows, or other synchronization machinery SHALL NOT manage
`doc/standards/`.

Agent-facing instructions SHALL direct contributors to read applicable
standards and local ADRs before consequential work.  The README SHALL also
identify the adopted standards location and `.codingstandardrc` provenance
record for human contributors.

## Alternatives Considered

### Copy only the Bash documentation standard

Rejected because the shared release is designed as one governed snapshot.
Cherry-picking selected documents would obscure provenance and omit
cross-cutting requirements such as clean coding, development workflow,
release governance, and ADR maintenance.

### Track the upstream main branch

Rejected because a mutable branch cannot provide reproducible governance.
A concrete immutable release and archive digest make the adopted policy
auditable.

### Fetch standards through bashdeps

Rejected because shared standards are governance, not ordinary build
dependencies.  They need to remain committed and reviewable even when
dependency preparation or network access is unavailable.

## Consequences

Future changes must evaluate the standards that apply to the affected content
and follow them unless accepted local governance explicitly says otherwise.
Standards upgrades will replace the managed snapshot as a unit and update
`.codingstandardrc` provenance.

The repository gains an ADR practice because the broader modernization work
contains consequential build, compatibility, and release decisions.  The ADR
landing page will maintain current decision summaries above the
`<!-- adrctl-generated-footer -->` marker and a complete generated inventory
below it.

## Related Issues

- #110: Modernize repository governance, documentation, and build tooling
