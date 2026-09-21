# DependencyReview

## Purpose
Justify every new library dependency by checking license, maintenance status, size/supply-chain risk and documentation of the dependency edge.

## Inputs
- Proposed dependency: name, version, origin (crate/package/repo), and the reason it is needed.
- Depending library under `mojoakku/<lib>/` and its `<LIB>_DOCS.md`.
- Dependency graph: libraries may depend on another MojoAkku library as a graph edge (e.g. `http -> tcp -> socket`), never as directory nesting.
- Existing `mojoakku/<lib>/src/` code that could implement the need instead.

## Preconditions
- A concrete need is documented that cannot reasonably be met by the standard library or by an existing sibling library.
- No dependency is added to the build before this review passes.
- The dependency edge does not imply a physical parent/child directory relationship.

## Roles
- `manager`: opens the task, confirms the need, routes the review. Manager starts NO Manager.
- `researcher`: confirms license, upstream maintenance activity, release cadence and known advisories with sources.
- `idea-reviewer`: verifies the dependency edge is conceptually sound and justified against alternatives.
- `reviewer`: owns the review gate.
- `compliance`: consulted for license compatibility and legal risk.
- `docs`: records the justified edge in `<LIB>_DOCS.md`.

## Steps
1. `manager` opens the task and states the need that the dependency satisfies.
2. `researcher` reports, with sources: license and compatibility, last release and maintenance status, issue tracker health, known CVEs/advisories, and transitive dependency count.
3. `idea-reviewer` checks whether the standard library, `src/` code, or an existing sibling library already covers the need.
4. `reviewer` assesses supply-chain risk: dependency size, transitive tree, maintainer count, bus factor, and whether the edge is truly necessary.
5. `compliance` confirms the license is compatible with the project and flags obligations.
6. `manager` decides: accept, reject, or replace with an internal implementation.
7. `docs` records the accepted edge in the depending library's `<LIB>_DOCS.md`: what is used, why, and which alternative was rejected. The edge is conceptual, never a physical nesting.
8. `reviewer` applies the review gate.
9. `manager` commits the documented edge and any manifest change with a message naming the dependency.

## Artifacts / Outputs
- Dependency review report: license, maintenance, CVEs, transitive count, alternatives considered, decision.
- Updated `<LIB>_DOCS.md` with the documented dependency edge and its justification.
- Updated dependency manifest only after approval.
- Task-log entry referencing the report and decision.
- One git commit recording the accepted edge (and manifest change, if any).

## Review Gate
`reviewer` verifies: (a) the need is real and not satisfiable internally, (b) license and legal status are cleared by `compliance`, (c) maintenance and supply-chain risk are acceptably low, (d) the graph edge is documented in `<LIB>_DOCS.md` and creates no directory nesting. Any undocumented edge or unknown license => reject.

## Handoff: NewLibPhase11Implementation.md when the dependency is approved; BugFix.md or Refactor.md when a dependency is to be removed; otherwise close the task.
