# ADR-010: Consolidate GitHub Actions Dependabot Version Updates

Date: 2026-11-12

## Status

Accepted

## Decision

Continue weekly GitHub Actions Dependabot version updates, adding a
seven-day cooldown and replacing the minor/patch-only group with one
wildcard `actions-version-updates` group configured with
`applies-to: version-updates` and `patterns: ["*"]`. Eligible major,
minor, and patch routine version changes may appear together.

Security updates remain independent of the routine weekly update and
cooldown. Preserve the current `dependabot/fetch-metadata`
non-major-only automatic-merge condition: a group containing any
major-version upgrade must receive targeted manual review before merge.
Leave existing Dependabot PRs open until replacement coverage and
appropriate test evidence are demonstrated.

## Context and Drivers

The repository's existing weekly GitHub Actions Dependabot configuration
groups only minor and patch releases and has no cooldown. Major releases
can therefore generate separate review items. The verified
`coding_standards@v3.2.0` baseline recommends weekly grouped version
updates with seven-day cooldowns to reduce routine review volume while
retaining independent security response.

This project deploys TLS certificate material to RouterOS using SSH/SCP.
Its accepted ADRs govern configuration precedence, argv-safe commands,
domain validation, embedded bashlog, public compatibility paths,
three release flavors, documented testing, least-privilege publishing,
and derivative CI test reports. A GitHub Actions dependency update can
affect test and release authority even when the Bash implementation
is unchanged.

## Assumptions and Operational Constraints

- Only the GitHub Actions ecosystem is configured for Dependabot.
- The weekly schedule and existing auto-merge condition remain; a
  seven-day cooldown applies to routine version updates only.
- Effective required checks, CODEOWNERS approvals, branch protections,
  and GitHub security-update settings require independent verification.
- The existing auto-merge workflow has write-capable permissions.
  This policy does not broaden them, but updates to its dependencies
  deserve explicit supply-chain and permission review.
- ADR-006's runtime safety boundaries and ADR-007's validated
  six-asset release contract remain governing.
- ADR-008 Pages permissions and ADR-009 separate test-report publisher
  authority remain unchanged.
- No certificate, key, token, remote command, SSH option, deployment,
  public entry-point, or artifact-contract modification is authorized.
- Do not install optional upstream test-gate workflow or ruleset
  examples merely because the released standards contain them.

## Alternatives Considered

1. Keep weekly minor/patch-only grouping. Rejected because separate
   routine major update PRs increase review overhead without automatically
   strengthening review evidence.
2. Group major/minor/patch routine updates by ecosystem. Chosen with
   heightened manual review for groups containing major upgrades.
3. Change to monthly updates or longer cooldowns. Rejected without
   evidence that additional ordinary update delay is acceptable.
4. Auto-merge major-containing groups. Rejected because breaking
   changes or expanded workflow authority may affect deployment,
   testing, release, or security boundaries.
5. Close existing Dependabot PRs as soon as grouping changes. Rejected:
   the configuration alone cannot prove equivalent coverage or tests.

## Consequences and Tradeoffs

Routine version-update volume may decline, but resolution constraints,
breaking changes, and other failures can still produce multiple PRs.
Bundled failures may require isolation of individual dependencies;
narrowly scoped grouping exceptions must be reviewed rather than
using `ignore` to hide updates.

Each grouped upgrade remains subject to per-dependency release-note,
permission, compatibility, and CI evidence review. The highest-risk
dependency sets the required review depth. A passing linter alone does
not prove that RouterOS execution, artifact validation, or privileged
release publishing remains safe. Existing Dependabot PR #129 stays open
until actual successor updates demonstrably cover it and pass checks.

## Expected Outcomes and Verification

Observe future Dependabot runs, major upgrade metadata, actual required
checks, and independent security update settings. Measure PR counts
and review effort without assuming a one-PR-per-week guarantee.
No runtime, interface, release, or migration changes result directly
from this decision.

## Related Decisions

ADR-001 governs the released shared standards snapshot; ADR-002
governs dependency acquisition; ADR-006 and ADR-007 govern runtime
boundaries and release artifacts; ADR-008/009 govern documentation
publication and CI report authority. None is superseded here.
