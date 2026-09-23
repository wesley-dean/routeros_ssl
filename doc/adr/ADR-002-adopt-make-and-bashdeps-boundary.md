# ADR-002: Adopt Make and bashdeps Dependency Boundary

Date: 2026-09-23

## Status

Accepted

## Context

The repository currently consists primarily of one Bash script plus container
and CI configuration.  Modernization requires repeatable dependency
preparation, documentation generation, ADR maintenance, artifact construction,
and later behavior testing without turning the runtime tool into a package of
loosely installed helper files.

Related Bash projects use Make as the repository-level orchestration surface
and `bashdeps` as a small digest-verified fetcher for ordinary development and
build dependencies.  The dependency manager cannot fetch itself, so it needs a
separate bootstrap trust boundary.

## Decision

The repository SHALL use a root Makefile as the canonical interface for build,
dependency, documentation, and maintenance operations.  Make SHALL execute
recipes with Bash under `-eu -o pipefail`.

The Makefile SHALL directly bootstrap only `vendor/bashdeps.bash`, pinned to
`bashdeps v0.4.1` with SHA-256
`5131ebb6a3a85e1d76624a37146c2442b2e57be6ffd8139b9590d28239876701`.
`dependencies.txt` SHALL own ordinary repository dependencies.  The initial
manifest SHALL pin:

- `bashlog.dev.bash` from bashlog `v0.0.18`;
- `adrctl.bash` from adrctl `v0.0.16`; and
- `doxygen-bash.awk` from bash-doxygen `v0.5.2`.

`vendor/` is generated state and SHALL NOT be committed.  `make deps` may use
the network to converge dependency state.  `make deps-check`, `make build`,
`make adr-index`, and `make docs` SHALL consume already prepared dependency
bytes without performing their own network fetches.  `make all` SHALL perform
dependency convergence and then build the distribution artifact.

Where Bash built-ins provide a clear and reliable implementation, repository
tooling and runtime changes SHOULD prefer them over avoidable helper processes.
External commands remain appropriate for capabilities that are intrinsically
external, including SSH/SCP, cryptographic checksum utilities, Doxygen, and the
AWK-based bash-doxygen filter.

Pinning bashlog in this decision does not itself change runtime diagnostics.
The actual migration from direct diagnostic output to bashlog belongs to the
separate bug-fix/hardening work tracked by issue #112.

## Alternatives Considered

### Vendor dependencies in Git

Rejected because generated dependency state would obscure the small maintained
source surface and make dependency updates harder to audit.  Release URLs and
digests in `dependencies.txt` provide a smaller review boundary.

### Download dependencies independently in each target

Rejected because multiple ad hoc download implementations would duplicate
trust, retry, and verification logic.  One pinned bashdeps bootstrap keeps the
network boundary explicit.

### Introduce a larger language/package ecosystem

Rejected because the project is intentionally Bash-centric and the required
development dependencies are individual release artifacts.  A larger package
manager would add operational surface without solving a current requirement.

## Consequences

Developers may run `make all` from a clean checkout to prepare dependencies and
construct the current distribution artifact.  Offline work is supported after
dependency preparation through verification and build targets that do not
fetch from the network.

The generated `vendor/` directory becomes a defined repository boundary and is
excluded from source scanning.  Future dependencies must be pinned by immutable
identity and digest through the same manifest unless a later ADR changes the
dependency model.

## Related Decisions

- ADR-001: Adopt Shared Coding Standards

## Related Issues

- #110: Modernize repository governance, documentation, and build tooling
- #112: Fix confirmed runtime bugs and harden RouterOS interactions
