# Repository Instructions

## Governing Standards

Files beneath `doc/standards/` are governing project requirements, not
suggestions.  Read every standard applicable to the content being changed
before proposing or making changes.

Presence does not imply applicability.  General and cross-cutting standards
apply where relevant, language-specific standards apply to maintained content
in that language, and `doc/standards/examples/` is illustrative and
non-normative unless a governing standard explicitly says otherwise.

Accepted repository-specific ADRs and explicit local policies may refine or
supersede imported standards.  Do not silently deviate from either source.
Do not edit imported standards locally to create an exception; record
repository-specific exceptions in accepted local governance instead.

The adopted standards release and archive digest are recorded in
`.codingstandardrc`.  The complete managed snapshot lives under
`doc/standards/`.

## Repository Documentation

Before consequential work, read `README.md`, this file, `doc/adr/README.md`,
and the ADRs relevant to the requested change.  ADRs are governance.  A
change that materially affects behavior, interfaces, compatibility, security
boundaries, build/release contracts, or other consequential architecture
requires an ADR unless existing governance already covers the decision.

Committed ADRs use `Accepted` status.  Keep the maintained `Current Decisions`
digest in `doc/adr/README.md` synchronized with governing ADRs, preserve the
`<!-- adrctl-generated-footer -->` marker, and regenerate the inventory beneath
that marker with the repository tooling.

## Scope and Compatibility

Keep changes surgical and reviewable.  Preserve the public root entry point
`letsencrypt-routeros.bash` unless an accepted ADR explicitly changes that
contract.  Do not combine unrelated cleanup with requested work.

Prefer Bash built-ins and language features when they express an operation
clearly and reliably.  In particular, prefer `[[ ... ]]`, parameter
expansion, arrays, Bash regular expressions, arithmetic contexts, `printf`,
and `read`/`mapfile` over avoidable external helper processes.

## Build and Dependency Boundaries

`src/letsencrypt-routeros.bash` is maintained application source.  The root
`letsencrypt-routeros.bash` is a generated, committed compatibility artifact;
do not edit it directly.  `dist/` and `vendor/` are generated state and must
remain uncommitted.

Make directly bootstraps only the pinned `vendor/bashdeps.bash` dependency.
`dependencies.txt` owns ordinary repository dependencies.  `make deps` may use
the network; `make deps-check`, `make build`, `make adr-index`, and `make docs`
consume prepared state without fetching their own dependencies.  `make all`
performs dependency convergence followed by the ordinary distribution build.

The distribution contract produces `.dev.bash`, ordinary `.bash`, and
`.min.bash` flavors beneath `dist/`, plus an adjacent `.sha256` for each.
The flavors form one development-to-ordinary-to-minified chain.  Preserve the
root public script as the normalized ordinary compatibility artifact for direct
execution, sourcing, raw download, and container use.

## ADR and Reference Documentation

When adding or materially changing an ADR, update the curated `Current
Decisions` digest above the marker and run `make adr-index` after dependencies
are prepared.  Never hand-edit the generated inventory beneath the marker.

Maintained Bash documentation follows
`doc/standards/bash/documentation-standard.md`.  `make docs` validates
`src/letsencrypt-routeros.bash` with the pinned bash-doxygen filter and writes
ignored derivative HTML beneath `doc/reference/`.

## Characterization Testing

Behavior tests live beneath `tests/` and use Bats.  They must not require a
live RouterOS device or real credentials; use deterministic PATH-injected
fakes for external transport boundaries.  The canonical test command is
`make test`, which emits TAP through `bats --tap`.

Tests select the executable through `ROUTEROS_SSL_UNDER_TEST`.  `make test`
runs the same TAP suite against the root compatibility file and all three
`dist/` flavors.  Keep the suite artifact-agnostic.

The suite is regression coverage for the corrected runtime contract.  Preserve
TAP output and keep transport fakes deterministic.  Runtime changes must update
or extend tests when observable behavior changes.

