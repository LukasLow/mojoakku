# NewLibPhase10TestsReview

## Purpose

Verify that the test suite authored in `NewLibPhase9Tests.md` genuinely encodes the documented semantics and that the failing baseline was actually observed.

## Inputs

- `mojoakku/<lib>/<LIB>_DOCS.md`.
- `mojoakku/<lib>/_tests/` (all test files).
- Baseline log and the exact test command from the Tests phase.
- Scaffold `api/` files (for signature cross-checking).

## Preconditions

- `NewLibPhase9Tests.md` completed and committed.
- Reviewer has read `<LIB>_DOCS.md` in full.

## Roles

- Reviewer: validates coverage, non-tautology and baseline evidence; issues go/no-go.
- Coder: responds to findings only; does not change tests during review.

## Steps

1. Re-run the recorded test command (the per-library runner) and confirm the reported failing-test count matches the baseline log.
2. For each test file, map its assertions back to a specific documented sentence in `<LIB>_DOCS.md`; flag assertions with no documented basis.
3. Confirm every documented public API has at least one success-path test.
4. Confirm the required edge cases are each covered by a real test: EOF, `EINTR`/`EAGAIN`, non-blocking, ownership/close, timeouts, invalid input.
5. Inspect for tautological or vacuous tests (e.g. asserting a constant, catching all exceptions without checking the error, tests that pass regardless of behavior).
6. Confirm no test asserts against internal implementation details that contradict the private `src/` boundary.
7. Confirm `_tests/` contains no `__init__.mojo` and that the `api/` stubs were not modified to make tests easier.
8. Record coverage gaps, non-tautology findings and the baseline reproduction result.
9. If `NEEDS_WORK`, Manager sends the findings back into `NewLibPhase9Tests.md`.
10. If `APPROVED`, Manager logs the verdict via `agentlog`.
11. Manager commits the phase with a message naming the phase and verdict (e.g. `base64 phase 10: tests review APPROVED`).
12. Manager hands off to implementation.

## Artifacts / Outputs

- Tests review report: concern coverage matrix, edge-case matrix, non-tautology findings, baseline reproduction evidence.
- Explicit go/no-go decision for the Implementation phase.
- One git commit for the phase.

## Review Gate

- Go only if: tests test the documented semantics, all listed edge cases are covered, no tautological tests exist, and the failing baseline is reproduced.
- Any missing concern/edge case or unverifiable baseline is a blocking finding and returns to `NewLibPhase9Tests.md`.
- The phase is committed.

## Handoff: `NewLibPhase11Implementation.md`
