# ADR-004: Generate Reference Documentation and ADR Inventory

Date: 2026-09-23

## Status

Accepted

## Context

The modernization introduces both Doxygen-style Bash documentation and local
ADRs.  Generated reference HTML should be reproducible from maintained source
without becoming another source of truth, while the ADR landing page needs to
combine a curated current-decision digest with a complete mechanically
maintained inventory.

The shared Bash documentation standard is designed for `bash-doxygen`, and the
shared ADR standard defines `doc/adr/README.md` plus the
`<!-- adrctl-generated-footer -->` ownership marker.  Both tools are available
as pinned release artifacts and fit the bashdeps dependency boundary from
ADR-002.

## Decision

The repository SHALL pin `bash-doxygen` and `adrctl` in `dependencies.txt` and
consume those prepared artifacts through Make targets.

`make docs` SHALL:

1. require the prepared `vendor/doxygen-bash.awk` filter;
2. require a system Doxygen executable;
3. run bash-doxygen in strict mode against `letsencrypt-routeros.bash`;
4. remove stale generated reference output;
5. run Doxygen with the committed `Doxyfile`; and
6. verify that `doc/reference/index.html` was produced.

`doc/reference/` is generated derivative state and SHALL remain ignored.
Publishing that HTML through GitHub Pages is not part of this decision.

`doc/adr/README.md` SHALL contain maintained current-decision summaries above
`<!-- adrctl-generated-footer -->`.  `make adr-index` SHALL fail if that marker
is missing or duplicated, preserve the maintained prefix, generate the complete
inventory with the pinned `adrctl`, normalize the generated heading beneath the
landing page, and replace the footer only when content changed.

CI SHALL prepare and verify dependencies, build and syntax-check the
distribution artifact, verify its checksum, regenerate the ADR inventory and
require no diff, and generate Doxygen reference documentation.  This validation
does not introduce the Bats behavior suite reserved for issue #111.

## Alternatives Considered

### Commit generated Doxygen HTML

Rejected because HTML is derivative output.  Regenerating it from maintained
source and pinned tooling avoids large mechanical diffs and source-of-truth
ambiguity.

### Hand-maintain the complete ADR list

Rejected because the exhaustive inventory is mechanical state and can drift.
The maintained portion of the landing page should spend human attention on the
current-decision digest rather than duplicating filenames by hand.

### Let adrctl rewrite the whole landing page

Rejected because the current-decision summaries are maintained project
knowledge.  The ownership marker provides a clear boundary between curated and
generated content.

### Publish reference documentation to Pages immediately

Deferred because issue #110 requires a reliable `docs` target, not a public
documentation hosting contract.  A later change can add Pages publication if
there is a demonstrated need.

## Consequences

Documentation changes can be validated locally and in CI using the same pinned
filter.  Generated HTML never needs to be reviewed as maintained source.

ADR changes must keep the curated landing-page digest synchronized and run the
inventory target before merge.  Missing markers or unexpected adrctl output are
hard failures rather than permission to append guessed content.

## Related Decisions

- ADR-001: Adopt Shared Coding Standards
- ADR-002: Adopt Make and bashdeps Dependency Boundary

## Related Issues

- #110: Modernize repository governance, documentation, and build tooling
