# os_poll — Phase 12 implementation review

## Verdict

`APPROVED` (after one rework round) — the implementation matches the documented
semantics; no test tampering remains; error handling, resource/ownership and the
FFI boundary are correct.

## First pass: `NEEDS_WORK`

One blocking finding: two `HANGUP` tests appeared in `_tests/` after the Phase-10
review, which the test-freeze rule reads as a silent edit. It was a
Manager-directed Phase-9/10 coverage amendment made before implementation
started; the resolution was to record it properly rather than revert a valid
coverage improvement.

## Resolution

- `_dev/PHASE10_TESTS_REVIEW.md` was added as the approved Phase-10 record: it
  states the original 24-function review and a documented addendum for the two
  `HANGUP` tests (24 → 26 functions, red baseline regenerated). The tests are
  frozen for Phase 11 from that point.
- Absolute-import note withdrawn: `from akku.<lib>._internal.<mod> import ...` is
  the project convention across siblings; the relative form does not compile from
  a top-level package module.
- Duplicated EINTR retry-and-rewait loop in `wait`/`wait_many` accepted as
  non-blocking (shared helper deferred).

## Axes verified

- **Semantics:** INVALID_FD / INVALID_TIMEOUT guards; EINTR retried with the
  remaining timeout recomputed from a monotonic deadline, so the caller's bound is
  never exceeded; `ZERO` = one non-blocking poll; empty set returns 0 immediately;
  negative-fd slot skipped in `wait_many`; a bad fd reports `PollEvents.INVALID`,
  never an exception; a timeout is a value, not an error.
- **Test integrity:** `_tests/` matches the recorded Phase-10/Phase-9 state.
- **Ownership/resources:** no dup, close or retention of fds; per-call native
  record array; no leak, double-free or use-after-close.
- **FFI:** `RawPollFd` = `int`/`short`/`short`; `nfds` = `c_ulong` (Linux) /
  `c_uint` (macOS); errno via `__errno_location` / `__error`.
- **Structure:** flat sibling, no nested library, no invented public API.

## Re-review

`APPROVED` — no remaining findings.
