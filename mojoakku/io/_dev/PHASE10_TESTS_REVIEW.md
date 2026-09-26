# io Phase 10 — Tests Review

## Verdict: APPROVED

Reviewed the suite `mojoakku/io/_tests/` against `_dev/DESIGN.md`.

| Criterion | Result |
| --- | --- |
| A test file per documented concern; every public API has a success-path test | ✓ 11 files, 15 APIs |
| Test names match the `DESIGN.md` `Tests:` fields exactly | ✓ 75 = 75, no orphans |
| Documented edge cases covered (EOF, short read, UNEXPECTED_EOF, short/zero write, CLOSED, non-seekable→OTHER, negative limit→0, SpanCursor has no write, MultiReader, partial loss) | ✓ |
| No tautological tests | ✓ (the two fixture-only seek tests were removed in the rework) |
| Fixtures faithfully implement the trait contracts and can observe the claimed behaviour | ✓ |
| Red baseline recorded (files compile, fail via the library abort stubs, 0 compile errors) | ✓ 11 files / 0 passed / 11 stub-abort / 0 compile error |

Rework applied after pass 1 (5 findings):
1. removed the two tautological seek tests + their fixtures; documented why
   non-seekable/closed have no release-1 target;
2. added three `WOULD_BLOCK`-not-retried tests (`read_exact`, `write_all`,
   `copy`);
3. added `test_copy_partial_progress_writer_keeps_first_chunk`;
4. `baseline.log` now states the 75-test total and why a per-test count is
   unreachable;
5. `run_baseline.sh` classifies `ABORT:` before `error:`.

**Handoff:** `NewLibPhase11Implementation.md`.
