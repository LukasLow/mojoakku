# APIReview

## Purpose
Check a proposed or landed public API change for consistency with the inline `# API-DOCS` blocks, naming, error surface and backward compatibility.

## Inputs
- The API change: before/after signatures, types, error behavior.
- `mojoakku/<lib>/*.mojo` (agreed public surface) and `mojoakku/<lib>/__init__.mojo` (exports).
- The inline `# API-DOCS` blocks in `mojoakku/<lib>/*.mojo` and `__init__.mojo` (single source of truth).
- Call sites in dependent sibling libraries.
- Existing tests in `mojoakku/<lib>/_tests/`.

## Preconditions
- The API is either proposed (design time) or already landed (post-implementation review); the state is stated explicitly.
- A design decision exists for any new public symbol; API decisions are justified in the inline `# API-DOCS` blocks.
- No API change ships without this review.

## Roles
- `manager`: opens the task, routes the review, records the decision. Manager starts NO Manager.
- `idea-reviewer`: owns API/abstraction consistency and ergonomics.
- `reviewer`: owns the review gate.
- `explore`: finds all call sites and dependent usages with `file:line`.
- `docs`: updates the inline `# API-DOCS` blocks so they stay the single source of truth.
- `coder`: applies required changes found by the review.
- `compliance`: consulted for legal or data-protection implications.

## Steps
1. `manager` opens the task and marks it design-time or post-landing.
2. `docs` diffs the API against the inline `# API-DOCS` blocks and lists every undocumented or contradicting element.
3. `explore` finds all call sites and dependent libraries affected by the change.
4. `idea-reviewer` checks naming consistency with existing MojoAkku conventions, argument order, ergonomics, and that the abstraction fits the sibling layout.
5. `idea-reviewer` checks the error surface: error types/messages are explicit, consistent across the library, and documented.
6. `reviewer` checks backward compatibility: breaking changes require an explicit decision and migration note; no silent removals or signature changes.
7. `coder` applies corrections found in steps 2-6; `docs` re-syncs the inline `# API-DOCS` blocks.
8. `reviewer` applies the review gate.
9. `manager` commits the API change with a message naming the symbol and the library.

## Artifacts / Outputs
- API review report: verdict, undocumented items, naming findings, compatibility findings, required changes.
- Updated API files `mojoakku/<lib>/*.mojo`, `__init__.mojo` and the inline `# API-DOCS` blocks when corrections were required.
- Migration note for any accepted breaking change.
- Task-log entry referencing the report.
- One git commit carrying the accepted API change.

## Review Gate
`reviewer` verifies: (a) the API files and the inline `# API-DOCS` blocks agree on every public symbol, (b) naming and error surface are consistent with the library, (c) backward compatibility is either preserved or explicitly accepted with a migration note, (d) all call sites are accounted for. Any undocumented public symbol or silent breaking change => reject.

## Handoff: NewLibPhase3Design.md if the API needs redesign, NewLibPhase11Implementation.md for corrections, or CreatePR.md when the change is accepted and user-visible; otherwise close the task.
