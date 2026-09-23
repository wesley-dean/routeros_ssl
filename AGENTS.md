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
