# ADR-006: Embed bashlog and Harden Runtime Boundaries

Date: 2026-09-23

## Status

Accepted

## Context

Issue #112 is the first modernization stage that intentionally changes runtime
behavior.  The characterization suite established by ADR-005 now protects the
public contract, so the condition that led ADR-003 to defer a maintained
`src/` layout no longer applies.

The runtime also needs to adopt the bashlog dependency already anticipated by
ADR-002 while preserving the historical directly downloadable root executable.
Requiring `vendor/bashlog.bash` beside that public file would break the
standalone-consumer contract.

The legacy implementation additionally constructs SSH and SCP commands as
scalar strings, interpolates unvalidated values into RouterOS command text,
relies on `set -e` and `exit` for library control flow, and suppresses or
bypasses cleanup failures.  These behaviors make quoting, failure propagation,
and partial-failure cleanup difficult to reason about.

## Decision

This ADR supersedes ADR-003 only where ADR-003 says the root
`letsencrypt-routeros.bash` file is the maintained implementation.  The root
path remains the stable public executable and sourceable compatibility path.

The canonical maintained application source SHALL move to
`src/letsencrypt-routeros.bash`.  The committed root
`letsencrypt-routeros.bash` SHALL be a deterministic generated compatibility
artifact.

The repository SHALL use bashlog v0.0.18 for runtime error and warning records.
ADR-002's initial selection of `bashlog.dev.bash` is superseded for this
single-artifact stage by the ordinary release artifact:

- artifact: `bashlog.bash`;
- destination: `vendor/bashlog.bash`; and
- SHA-256:
  `186562a526a42d3f105e36ca1006669246ee9149c83d12e0ba9044f2159fff8d`.

`make build` SHALL assemble standalone consumer artifacts from the verified
bashlog bytes followed by maintained application source, with one shebang.
The generated `dist/letsencrypt-routeros.bash` SHALL retain real build
provenance.  The committed root compatibility artifact SHALL normalize version,
build-date, and build-commit provenance to stable development values so it does
not become self-referential.  CI SHALL rebuild and require no diff in the
committed root artifact.

The runtime SHALL target Bash 4.3 or newer, matching bashlog's runtime floor.
The application itself SHOULD use Bash built-ins wherever clear and reliable.
Its intrinsic external runtime commands are SSH and SCP.

Configuration files remain trusted executable Bash.  Configuration precedence
SHALL be:

1. inherited environment/default variable state;
2. either an explicit `CONFIG_FILE`, or automatic discovery;
3. for discovery, `.env` followed by `letsencrypt-routeros.settings`;
4. command-line options;
5. positional values only for still-unset fields; and
6. final built-in defaults, including `ROUTEROS_USER=admin`.

An explicit `CONFIG_FILE` SHALL suppress automatic discovery.  The absence of
all configuration files SHALL NOT itself be an error when command-line or
environment configuration is otherwise complete.

SSH and SCP invocation SHALL use Bash argv arrays rather than scalar command
strings.  The legacy `ROUTEROS_SSH_OPTIONS` string remains supported and is
tokenized on shell whitespace without `eval`; shell quoting embedded inside
that string is not interpreted as a secondary shell language.

Values interpolated into RouterOS command text SHALL pass an explicit
conservative validation boundary.  Domain-derived RouterOS filenames and
certificate names accept only ASCII letters, digits, underscore, dot, and
hyphen, with an alphanumeric or underscore first character.  Unsupported
RouterOS services SHALL return an error rather than terminate a sourcing shell.

Reusable functions SHALL return status rather than exit their caller.
Successful sourcing SHALL return zero and SHALL NOT enable application
`errexit` in the caller.  The root compatibility artifact SHALL be committed
with executable mode.

Final remote-file cleanup SHALL be attempted after certificate/key processing
begins, including upload, import, and service-configuration failures.  Cleanup
failure SHALL be observable.  When both a primary operation and final cleanup
fail, the primary operation's documented exit category SHALL win and the
cleanup failure SHALL also be logged.

The fixed post-SCP sleep is removed because successful SCP completion is already
a synchronous transfer boundary.

## Alternatives Considered

### Source vendor/bashlog.bash at consumer runtime

Rejected because raw-download and release consumers would no longer receive a
standalone program and runtime execution would become coupled to repository
layout.

### Copy bashlog implementation into maintained application source

Rejected because that would duplicate upstream dependency code and weaken the
digest-verified dependency boundary established by ADR-002.

### Keep the root file as maintained source until issue #113

Rejected because bashlog adoption itself creates the standalone packaging
problem.  Characterization now exists, so the earlier reason to defer the
source/generated split has expired.

### Use eval to preserve shell quoting in ROUTEROS_SSH_OPTIONS

Rejected because configuration text should not become another dynamically
evaluated shell program merely to reconstruct argv.  Trusted configuration
files can already use Bash to construct other settings, while the compatibility
string remains intentionally whitespace-tokenized.

### Escape arbitrary RouterOS command-language input

Rejected because a small conservative identifier grammar is easier to inspect
and test than a general RouterOS quoting/escaping implementation.

### Use an EXIT trap for all cleanup

Rejected because the file is explicitly sourceable and should not take
ownership of caller traps.  Explicit orchestration provides deterministic
cleanup for handled workflow failures without mutating a sourcing shell's trap
state.

## Consequences

Maintainers edit `src/letsencrypt-routeros.bash` and regenerate the committed
root compatibility artifact through Make.  Consumers keep the historical root
path and receive embedded bashlog without `vendor/` or network requirements.

Error and warning records move to bashlog's STDERR boundary.  Progress output
remains application-owned on STDOUT.

The corrected CLI, configuration, sourceability, cleanup, and command-boundary
behavior becomes regression-tested under ADR-005.  Issue #113 may later
supersede the artifact-shape portions of this decision when it introduces the
development, ordinary, and minified distribution chain.

## Related Decisions

- ADR-002: Adopt Make and bashdeps Dependency Boundary
- ADR-003: Preserve Public Entry Point and Single-Artifact Distribution
- ADR-005: Use Bats Characterization Tests with TAP Output

## Related Issues

- #112: Fix confirmed runtime bugs and harden RouterOS interactions
- #113: Adopt three-flavor distribution artifacts
