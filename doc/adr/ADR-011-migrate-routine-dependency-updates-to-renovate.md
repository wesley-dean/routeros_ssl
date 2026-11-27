# ADR-011: Migrate Routine Dependency Updates to Renovate

Date: 2026-11-26

## Status

Accepted

## Decision

Use the centrally operated Jenkins Renovate instance for scheduled, routine dependency version updates for this repository. Enroll the repository with a minimal root `renovate.json` and remove `.github/dependabot.yml` so scheduled Dependabot updates no longer compete with Renovate. GitHub-native Dependabot security updates remain the intended security channel, controlled by repository security settings rather than by this YAML file.

This decision supersedes ADR-010's **routine Dependabot version-update scheduling and grouping** requirements. Its safeguards around dependency review, code-owner approval, branch protections, release authority, and security-update independence remain applicable. It does not alter existing runtime behavior, release assets, CI permissions, or automated merge policy.

## Context and Drivers

The owner now operates Renovate centrally in Jenkins across `wesley-dean/*`, with repository discovery already configured. Maintaining routine Dependabot alongside Renovate creates duplicate update proposals and additional review overhead. The prior ADR-010 decision was appropriate for the former Dependabot-only arrangement, but its vendor-specific scheduled-update model no longer matches the selected operating environment.

## Assumptions and Constraints

- Jenkins already discovers the owner namespace and will run Renovate against repositories after access is granted.
- The root `renovate.json` schema declaration is sufficient enrollment; operational update cadence and grouping are managed centrally, not duplicated per repository.
- GitHub's dependency graph, alerts, and Dependabot security updates are independently configured; removing `.github/dependabot.yml` does **not** itself enable or verify those settings.
- Security updates and relevant review gates must remain effective during migration.
- Existing Dependabot routine-version PRs may be closed because Renovate will create successor updates; closing them does not establish that replacement versions are already tested or merged.
- Future dependency updates affecting elevated workflow or release authority still require specific review.

## Alternatives Considered

1. Continue Dependabot grouping under ADR-010. Rejected because it duplicates the centrally managed update stream.
2. Run Renovate and Dependabot together. Rejected because overlapping update PRs increase queue volume and can create conflicting branches.
3. Disable Dependabot security updates as well. Rejected because that would unnecessarily remove a security response channel.
4. Replicate all existing Dependabot grouping options in per-repository Renovate configuration. Rejected because central Jenkins Renovate policy is intended to own routine scheduling and grouping.

## Consequences and Verification

Renovate becomes responsible for discovering routine dependency updates after the migration PR is merged and repository access is provided. Existing open routine Dependabot PRs are closed separately; security-update PRs are not intentionally closed. The change removes duplicate routine schedulers but does not guarantee that new PRs appear immediately or that their tests pass. Verify the next Jenkins Renovate run, ensuing update PRs, GitHub security settings, and the usual review/check protections before declaring migration operationally complete.

## Related Decisions

ADR-010 is superseded only for routine Dependabot scheduling and grouping. Other accepted ADRs governing dependency integrity, runtime boundaries, CI permissions, documentation, releases, and validation remain effective.
