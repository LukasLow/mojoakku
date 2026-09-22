# Release

## Purpose
Prepare and cut a release: decide the version, write the changelog, verify docs and test evidence, and tag.

## Inputs
- Release scope: the libraries and changes included.
- Current version and tag state (`git describe --tags --abbrev=0`).
- The `.changes/*.md` files accumulated since the last tag (the change list).
- The inline `# API-DOCS` blocks for every included library.
- Test results for every included library (`task ci`).

## Preconditions
- All included libraries have a green `_tests/` suite and passed their final reviews.
- No open `NEEDS_DEBUG`, `NEEDS_COMPLIANCE` or rejected review gate remains.
- The inline `# API-DOCS` blocks for every included library are current.
- `.changes/` contains at least one change file; the release scope is frozen.

## Roles
- `manager`: opens the release task, freezes scope, approves the version and tag, and creates and pushes the tag (via direct host git). Manager starts NO Manager.
- `docs`: writes the changelog from the `.changes/` files and performs the docs check.
- `coder`: runs the full test suite (via `task ci`) and fixes any blocker found during the release check.
- `reviewer`: owns the release gate.
- `compliance`: consulted for legal/data-protection notes in the release.

## Steps
1. `manager` opens the task and freezes the release scope.
2. `manager` computes the version with `task changes:version` (always `0.x.y`: any
   `NEW`/`BREAKING`/`DEPRECATED` change is a minor bump, only
   `FIX`/`SECURITY`/`PERFORMANCE`/`INTERNAL` is a patch bump; **major is never
   bumped**) and records the rationale.
3. `docs` writes the changelog: it groups the `.changes/*.md` category lines
   (NEW → Added, FIX → Fixed, SECURITY → Security, PERFORMANCE → Changed,
   DEPRECATED → Deprecated, BREAKING → Changed/Breaking, INTERNAL → Changed)
   into the `CHANGELOG.md` section under the computed version, each referencing
   the affected `mojoakku/<lib>/`.
4. `docs` performs the docs check: the inline `# API-DOCS` blocks, API and README
   references agree with the shipped code; broken or stale links are fixed.
5. `coder` runs the full test suite (`task ci`) for every included library and
   attaches the output as release evidence.
6. `reviewer` applies the release gate against scope, version, changelog completeness, docs consistency and test evidence.
7. `manager` authorizes the tag, then creates and pushes it via direct host git.
8. `manager` moves the consumed `.changes/*.md` files to
   `.changes/archive/<version>/`, so `.changes/` starts empty for the next cycle.
9. `manager` records the release in the task log with the tag name and included libraries.

## Artifacts / Outputs
- Changelog entry for the release.
- Version decision with rationale.
- Full test evidence for every included library.
- Docs-check result (consistent / fixed items).
- Release tag created by `manager` (via direct host git).
- Task-log entry with tag name, version and scope.

## Review Gate
`reviewer` verifies: (a) scope is frozen and matches the changelog, (b) the version follows the versioning rule, (c) every user-visible change is in the changelog, (d) docs are consistent with the code, (e) the full test suite is green as attached evidence. A missing changelog entry, stale docs or a red suite => reject and block the tag.

## Handoff: BugFix.md if the release gate uncovers a defect, otherwise close the task; the next release starts again at Release.md.
