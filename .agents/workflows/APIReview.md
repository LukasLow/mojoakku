# APIReview

## Purpose
Check a proposed or landed public API change for consistency with `<LIB>_DOCS.md`, naming, error surface and backward compatibility.

## Inputs
- The API change: before/after signatures, types, error behavior.
- `mojoakku/<lib>/api/` (agreed public surface) and `mojoakku/<lib>/__init__.mojo` (exports).
- `<LIB>_DOCS.md` of the affected library (single source of truth).
- Call sites in dependent sibling libraries.
- Existing tests in `mojoakku/<lib>/_tests/`.

## Preconditions
- The API is either proposed (design time) or already landed (post-implementation review); the state is stated explicitly.
- A design decision exists for any new public symbol; API decisions are justified in `<LIB>_DOCS.md`.
- No API change ships without this review.

## Roles
- `manager`: opens the task, routes the review, records the decision. Manager starts NO Manager.
- `idea-reviewer`: owns API/abstraction consistency and ergonomics.
- `reviewer`: owns the review gate.
- `explore`: finds all call sites and dependent usages with `file:line`.
- `docs`: updates `<LIB>_DOCS.md` so it stays the single source of truth.
- `coder`: applies required changes found by the review.
- `compliance`: consulted for legal or data-protection implications.

## Steps
1. `manager` opens the task and marks it design-time or post-landing.
2. `docs` diffs the API against `<LIB>_DOCS.md` and lists every undocumented or contradicting element.
3. `explore` finds all call sites and dependent libraries affected by the change.
4. `idea-reviewer` checks naming consistency with existing MojoAkku conventions, argument order, ergonomics, and that the abstraction fits the sibling layout.
5. `idea-reviewer` checks the error surface: error types/messages are explicit, consistent across the library, and documented.
6. `reviewer` checks backward compatibility: breaking changes require an explicit decision and migration note; no silent removals or signature changes.
7. `coder` applies corrections found in steps 2-6; `docs` re-syncs `<LIB>_DOCS.md`.
8. `reviewer` applies the review gate.
9. `manager` commits the API change with a message naming the symbol and the library.

## Artifacts / Outputs
- API review report: verdict, undocumented items, naming findings, compatibility findings, required changes.
- Updated `api/` files, `__init__.mojo` and `<LIB>_DOCS.md` when corrections were required.
- Migration note for any accepted breaking change.
- Task-log entry referencing the report.
- One git commit carrying the accepted API change.

## Review Gate
`reviewer` verifies: (a) the `api/` files and `<LIB>_DOCS.md` agree on every public symbol, (b) naming and error surface are consistent with the library, (c) backward compatibility is either preserved or explicitly accepted with a migration note, (d) all call sites are accounted for. Any undocumented public symbol or silent breaking change => reject.

## Handoff: NewLibPhase3Design.md if the API needs redesign, NewLibPhase11Implementation.md for corrections, or Release.md when the change is user-visible and accepted; otherwise close the task.
