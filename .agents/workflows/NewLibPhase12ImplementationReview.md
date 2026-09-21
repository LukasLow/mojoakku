# NewLibPhase12ImplementationReview

## Purpose

Review the implementation from `NewLibPhase11Implementation.md` for semantic fidelity, test integrity, error handling, resource/ownership correctness and structural independence.

## Inputs

- `mojoakku/<lib>/<LIB>_DOCS.md`.
- `mojoakku/<lib>/api/` and `mojoakku/<lib>/src/`.
- `mojoakku/<lib>/_tests/` and the frozen baseline from the Tests phase.
- Implementation diff and final green test log.
- Documented dependency edges.

## Preconditions

- `NewLibPhase11Implementation.md` completed and committed.
- Reviewer has read `<LIB>_DOCS.md` and the implementation diff.

## Roles

- Reviewer: performs the multi-axis review and issues go/no-go.
- Coder: responds to findings only; does not change code during review.

## Steps

1. Verify the recorded command reports the same passing count with 0 failing tests.
2. Diff `_tests/` against the reviewed baseline from `NewLibPhase10TestsReview.md` and confirm zero test tampering (no edits, deletions or weakened assertions).
3. For each documented behavior, inspect the implementation and confirm it matches the documented semantics (including return values and error conditions).
4. Review error handling: documented errors are raised, not swallowed; invalid input and timeout failures match the docs.
5. Review resource/ownership correctness: ownership transfer, close/idempotent close, no leaks, no double-free or use-after-close.
6. Review concurrency/IO correctness for non-blocking paths and `EINTR`/`EAGAIN` retry behavior as documented.
7. Confirm no hidden nested-library structure exists under `mojoakku/<lib>/` and that each used dependency edge is documented in the depending library's docs.
8. Confirm no undocumented API was invented and that every public symbol is justified in `<LIB>_DOCS.md`.
9. Record findings per axis with file:line references and severity.
10. If `NEEDS_WORK`, Manager returns the findings to `NewLibPhase11Implementation.md`.
11. If `APPROVED`, Manager logs the verdict via `agentlog`.
12. Manager commits the phase with a message naming the phase and verdict (e.g. `base64 phase 12: implementation review APPROVED`).
13. Manager hands off to final review.

## Artifacts / Outputs

- Implementation review report: semantic matrix, test-integrity result, error-handling, ownership/resource and structure findings.
- Explicit go/no-go decision for the Final Review phase.
- One git commit for the phase.

## Review Gate

- Go only if: implementation matches the documented semantics, there is no test tampering, error handling and resource/ownership are correct, and no hidden nested-library structure exists.
- Any semantic mismatch, test edit, ownership bug or undocumented API is a blocking finding and returns to `NewLibPhase11Implementation.md`.
- The phase is committed.

## Handoff: `NewLibPhase13FinalReview.md`
