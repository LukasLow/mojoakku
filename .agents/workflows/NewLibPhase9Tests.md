# NewLibPhase9Tests

## Purpose

Write the complete behavioral test suite for `mojoakku/<lib>` from the documented semantics before any implementation exists, and record the failing baseline.

## Inputs

- `mojoakku/<lib>/<LIB>_DOCS.md` (authoritative semantics).
- `mojoakku/<lib>/API.mojo` (stubs defining names and signatures).
- `mojoakku/<lib>/_tests/` (target directory, no `__init__.mojo`).
- Existing test conventions from sibling libraries under `mojoakku/*/_tests/`.

## Preconditions

- `NewLibPhase8ScaffoldReview.md` completed with a go decision.
- `<LIB>_DOCS.md` is frozen for this phase; open questions were resolved in Design/Docs.

## Roles

- Coder: writes the test files and runs the baseline.
- Reviewer (next phase): validates coverage and the baseline evidence.

## Steps

1. Extract from `<LIB>_DOCS.md` every documented behavior, precondition, postcondition and error condition; build a concern list.
2. Map each concern to exactly one test file named `test_<lib>_<concern>.mojo` in `mojoakku/<lib>/_tests/` (one concern per file).
3. Ensure every documented public API has at least one test exercising its documented success path.
4. Derive edge-case tests directly from the docs and cover at minimum: EOF, `EINTR`/`EAGAIN`, non-blocking behavior, ownership/close semantics, timeouts, and invalid input.
5. Write assertions against documented semantics only — no assertions against implementation internals, and no self-referential (tautological) tests.
6. Do not create `__init__.mojo` in `_tests/` and do not modify `API.mojo` to accommodate tests.
7. Run the full test suite for the library.
8. Record the objective baseline: exact test command, total test count, and the count of failing tests (expected: tests fail because stubs raise "not yet implemented"). Save the raw output to a baseline log file.
9. Commit tests and the baseline log.

## Artifacts / Outputs

- `mojoakku/<lib>/_tests/test_<lib>_<concern>.mojo` files, one concern per file.
- Baseline log with the exact command and the failing test count.
- Concern-to-test-file coverage map.

## Review Gate

- Entry gate for `NewLibPhase10TestsReview.md`: every documented concern has a test file, all required edge cases are present, and a reproducible failing baseline with an explicit failing-test count exists.
- Tests failing at this stage is the intended state; green tests here indicate a leaked implementation and block the phase.

## Handoff: `NewLibPhase10TestsReview.md`
