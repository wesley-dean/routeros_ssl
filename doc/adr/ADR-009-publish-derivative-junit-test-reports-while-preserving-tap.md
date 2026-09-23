# ADR-009: Publish Derivative JUnit Test Reports While Preserving TAP

Date: 2026-09-23

## Status

Accepted

## Context

ADR-005 established Bats characterization tests with TAP as the canonical
human- and automation-readable test output.  The repository now runs the same
behavior suite against the root compatibility artifact and all three generated
distribution flavors, but pull-request reviewers primarily see only the overall
workflow status unless they open the validation logs.

GitHub can surface structured test results as checks, annotations, job summaries,
and durable pull-request comments when supplied with JUnit XML.  Bats supports a
console formatter and an independent report formatter during the same execution,
so JUnit reporting does not require replacing TAP or running the test suite a
second time.

Publishing pull-request comments and checks requires GitHub write permissions.
The validation workflow executes repository and pull-request code, including code
from forks and Dependabot branches, so granting those permissions directly to the
validation job would weaken its current read-only trust boundary.

## Decision

TAP SHALL remain the canonical console and CI log format for the characterization
suite established by ADR-005.

`make test` SHALL run each Bats invocation with TAP as its console formatter and
JUnit as an additional report formatter.  JUnit output SHALL be generated from the
same Bats execution rather than by re-running the suite.

The four test surfaces SHALL write reports beneath ignored derivative state:

```text
test-results/
├── root/report.xml
├── development/report.xml
├── ordinary/report.xml
└── minified/report.xml
```

The test target SHALL attempt all four artifact surfaces even when an earlier Bats
invocation fails.  It SHALL return a nonzero status when any invocation fails so
the validation workflow remains authoritative for pass/fail status while still
producing the most complete test report practical for review.

`test-results/` SHALL remain uncommitted generated state, SHALL be removed by
the repository cleanup target, and SHALL be excluded explicitly from MegaLinter
in addition to being covered by ignored-file handling.

The `Validate` workflow SHALL retain read-only repository permissions.  Its
code-executing validation job SHALL upload generated JUnit reports after test
execution, including on ordinary test or validation failure unless the run was
cancelled.

The source GitHub event metadata SHALL be uploaded by a separate job in the same
workflow that does not check out or execute repository code.  This keeps pull-
request code from controlling the event artifact used later to associate results
with a pull request.

A separate `workflow_run` workflow SHALL publish test results after `Validate`
completes successfully or unsuccessfully.  The publishing workflow SHALL:

1. execute from the trusted default-branch workflow definition;
2. use `actions: read` to download the isolated event and test-result artifacts
   from the completed workflow run;
3. use `checks: write` and `pull-requests: write` only for result publication;
4. not check out, source, or execute pull-request repository code;
5. use the preserved source event metadata so pull requests from forks and
   Dependabot branches can be associated correctly;
6. publish JUnit reports as a stable GitHub check and an updated durable
   pull-request comment for `pull_request` validation events; and
7. skip result publication when validation failed before any JUnit report could
   be produced.

The publisher SHALL use pinned action revisions.  The first-party
`actions/download-artifact` action SHALL be preferred for cross-run artifact
retrieval so the repository does not introduce an additional downloader when the
GitHub-provided action satisfies the requirement.

## Alternatives Considered

### Replace TAP with JUnit

Rejected because ADR-005 deliberately selected TAP as the canonical test stream,
and JUnit is more useful here as derivative CI reporting data than as the primary
developer-facing output.

### Run the suite once for TAP and again for JUnit

Rejected because Bats can emit the TAP console stream and JUnit report from the
same invocation.  Re-running would increase CI time and introduce the possibility
that the two representations describe different executions.

### Publish from the validation job

Rejected because publishing checks and pull-request comments requires write
permissions.  The validation job executes potentially untrusted pull-request code
and should remain read-only.

### Use pull_request_target

Rejected because combining privileged `pull_request_target` execution with
checkout or execution of untrusted pull-request code creates an avoidable security
boundary hazard.  The `workflow_run` handoff keeps code execution in the
read-only workflow and publication in the privileged workflow.

### Publish only for same-repository pull requests

Rejected because the structured test feedback is also useful for fork and
Dependabot contributions.  Preserving the source event and publishing from
`workflow_run` supports those cases without granting the untrusted validation run
write authority.

## Consequences

Local and CI test logs continue to present TAP, preserving the established
repository test interface.  Every ordinary complete test run additionally creates
four JUnit reports that CI can aggregate into review-oriented output.

Test runs now continue across all artifact flavors after an individual flavor
fails, while the final `make test` status remains nonzero when any failure
occurred.  Reviewers therefore receive broader failure information without
weakening the test gate.

The repository gains a second CI workflow with narrowly scoped write permissions.
That workflow consumes only uploaded event metadata and JUnit data and does not
execute pull-request code.  Event metadata is produced by a no-checkout job, while
JUnit remains explicitly untrusted reporting data from the code-executing
validation job.

The `workflow_run` publisher must exist on the default branch before GitHub will
use it for completed validation runs.  Therefore, the pull request introducing
this workflow cannot fully demonstrate its own durable PR comment through that new
publisher; end-to-end publication becomes active after the change is merged.

## Refines

ADR-005 remains governing for the Bats characterization suite and canonical TAP
output.  This decision refines ADR-005 only by permitting derivative JUnit reports
from the same executions and by defining their CI publication boundary.

## Related Decisions

- ADR-002: Adopt Make and bashdeps Dependency Boundary
- ADR-005: Use Bats Characterization Tests with TAP Output
- ADR-007: Adopt Three-Flavor Distribution Artifacts

## Related Issues

- #119: Publish Bats test results as durable pull request feedback
