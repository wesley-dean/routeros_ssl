# ADR-005: Use Bats Characterization Tests with TAP Output

Date: 2026-09-23

## Status

Accepted

## Context

The repository is entering a behavior-correction phase, but the existing Bash
implementation has accumulated several confirmed defects and implicit runtime
contracts.  Correcting those defects without first recording current observable
behavior would make it difficult to distinguish intentional fixes from
accidental compatibility changes.

The tool also performs destructive operations against RouterOS certificate,
file, and service state.  A routine unit or pull-request test must not require
a live RouterOS device, real SSH credentials, or real certificate deployment.

Issue #111 therefore requires a characterization suite before issue #112
changes runtime behavior.  The maintainer has also selected TAP as the canonical
human- and automation-readable test output.

## Decision

This decision supersedes ADR-004 only insofar as ADR-004 described CI before
the characterization suite existed.  Documentation-generation governance from
ADR-004 remains unchanged.

The repository SHALL use Bats for behavior-oriented Bash tests beneath
`tests/`.  The canonical Make entry point SHALL invoke Bats with `--tap` so
test output is TAP.

Tests SHALL NOT require a live RouterOS device.  SSH, SCP, sleep, and similar
process boundaries SHALL be controlled through deterministic PATH-injected test
doubles where necessary.  Tests SHOULD prefer Bash and Bats-native mechanisms
over avoidable external helper programs.

The test harness SHALL select the executable under test through the
`ROUTEROS_SSL_UNDER_TEST` environment variable.  When that variable is not
set, tests SHALL target the historical root `letsencrypt-routeros.bash`
entry point.  This allows the same suite to target generated artifacts without
duplicating test logic.

CI SHALL run the same characterization suite separately against:

- the maintained root entry point; and
- `dist/letsencrypt-routeros.bash`.

Separate invocations preserve each run as a valid TAP stream.

Bats itself is a developer and CI executable and SHALL be installed by the
development environment or CI runner rather than fetched through
`dependencies.txt`.  The bashdeps manifest remains reserved for pinned
file-like repository dependencies.

Known defects SHALL NOT be silently canonized as desirable behavior.  When a
defect is useful to characterize before correction, the test name or
documentation SHALL identify it as a known defect tied to issue #112.
Desired corrected behavior MAY be represented by skipped Bats tests until
#112 makes them pass.

## Alternatives Considered

### Test against a live RouterOS device

Rejected because it would require credentials, network reachability, mutable
infrastructure, and destructive state changes.  It would also make pull-request
validation slow and nondeterministic.

### Mock functions only

Rejected as the sole strategy because function-level tests would miss command
construction, PATH lookup, option parsing, configuration loading, exit status,
and source-versus-execute behavior.  Function substitution remains useful for
narrow characterization where the behavior under test is specifically a
function wrapper.

### Vendor Bats through bashdeps

Rejected because Bats is an executable test runner supplied by normal
development and CI environments, not a runtime or build artifact embedded in
the consumer program.  Keeping it outside `dependencies.txt` preserves the
dependency boundary established by ADR-002.

### Emit Bats' default pretty formatter

Rejected because TAP is stable, machine-readable, and explicitly selected for
this repository.  CI log presentation should not replace or hide the TAP stream.

## Consequences

Behavior changes in #112 will have a visible regression baseline.  Some tests
will intentionally describe defective current behavior or remain skipped until
that work is implemented, and those tests will need to be revised or enabled as
the corresponding defect is corrected.

Issue #113 can reuse the same harness for development, ordinary, and minified
artifacts by changing only `ROUTEROS_SSL_UNDER_TEST`.  No separate flavor-
specific suite should be necessary unless a future artifact has an intentionally
different external contract.

## Related Decisions

- ADR-002: Adopt Make and bashdeps Dependency Boundary
- ADR-003: Preserve Public Entry Point and Single-Artifact Distribution
- ADR-004: Generate Reference Documentation and ADR Inventory

## Related Issues

- #111: Add Bats characterization tests for current behavior
- #112: Fix confirmed runtime bugs and harden RouterOS interactions
- #113: Adopt three-flavor distribution artifacts
