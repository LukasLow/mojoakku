# Release

## Purpose
Prepare and cut a release: decide the version, write the changelog, verify docs and test evidence, and tag.

## Inputs
- Release scope: the libraries and changes included.
- Current version and tag state.
- `<LIB>_DOCS.md` for every included library.
- Test results for every included library.
- Changelog draft or commit history since the last release.

## Preconditions
- All included libraries have a green `_tests/` suite and passed their final reviews.
- No open `NEEDS_DEBUG`, `NEEDS_COMPLIANCE` or rejected review gate remains.
- `<LIB>_DOCS.md` for every included library is current (single source of truth).
- The release scope is frozen before the version decision.

## Roles
- `manager`: opens the release task, freezes scope, approves version and tag. Manager starts NO Manager.
- `docs`: writes the changelog and performs the docs check.
- `shell`: runs the full test suite and provides the tag command (via `smd`).
- `reviewer`: owns the release gate.
- `coder`: fixes any blocker found during the release check.
- `compliance`: consulted for legal/data-protection notes in the release.

## Steps
1. `manager` opens the task and freezes the release scope.
2. `manager` decides the version per the project's versioning rule (breaking change => major, new user-visible behavior => minor, fix only => patch) and records the rationale.
3. `docs` writes the changelog: one entry per user-visible change, grouped into features, fixes, performance, deprecations and breaking changes, each referencing the affected `mojoakku/<lib>/`.
4. `docs` performs the docs check: `<LIB>_DOCS.md`, API and README references agree with the shipped code; broken or stale links are fixed.
5. `shell` runs the full test suite for every included library and attaches the output as release evidence.
6. `reviewer` applies the release gate against scope, version, changelog completeness, docs consistency and test evidence.
7. `manager` authorizes the tag; `shell` creates and pushes the tag via `smd`.
8. `manager` records the release in the task log with the tag name and included libraries.

## Artifacts / Outputs
- Changelog entry for the release.
- Version decision with rationale.
- Full test evidence for every included library.
- Docs-check result (consistent / fixed items).
- Release tag created via `shell`.
- Task-log entry with tag name, version and scope.

## Review Gate
`reviewer` verifies: (a) scope is frozen and matches the changelog, (b) the version follows the versioning rule, (c) every user-visible change is in the changelog, (d) docs are consistent with the code, (e) the full test suite is green as attached evidence. A missing changelog entry, stale docs or a red suite => reject and block the tag.

## Handoff: BugFix.md if the release gate uncovers a defect, otherwise close the task; the next release starts again at Release.md.
