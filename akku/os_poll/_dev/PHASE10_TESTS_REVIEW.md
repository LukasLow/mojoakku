# os_poll — Phase 10 tests review (record + documented addendum)

## Verdict

`APPROVED` — the Phase-9 test suite encodes the documented semantics; the red
baseline was reproduced (6 files, 0 passed, 6 failed, all stub aborts, 0
compile/import errors at that time, 24 test functions).

## Accepted coverage gaps (non-blocking, recorded)

1. A real peer-close `HANGUP` was not exercised end-to-end by `wait`/`wait_many`
   (only simulated at the value level).
2. `PollErrorKind.SYSCALL` has no realistic deterministic trigger.
3. `wait_many` had no `INVALID_TIMEOUT` test (shared validation logic with `wait`).
4. `test_zero_timeout_returns_immediately` uses a loose upper threshold.

## Manager-directed addendum (between Phase 10 and Phase 11)

Gap 1 was closed by an explicit Manager decision before implementation started:
two end-to-end `HANGUP` tests were added — `test_peer_close_reports_hangup` in
`test_os_poll_wait.mojo` and in `test_os_poll_wait_many.mojo`. They close the
write end of a libc pipe and assert the read end reports `HANGUP`.

Consequence: the suite grew from 24 to **26 test functions** and the red baseline
was regenerated (`_tests/baseline.log`, now "26 test functions"). This addendum
is the approved record of that change; it is a Phase-9/10 coverage amendment, not
a Phase-11 test edit. After the amendment the tests are frozen for Phase 11.
