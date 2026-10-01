# os_poll — Phase 13 final review

## Verdict

`APPROVED` (GO) — docs, API, tests and implementation are consistent; no blocking
findings.

## Test evidence

Command: `cd akku/os_poll && sh ../../.repo/scrupts/libraries.sh test`

Result: **26 passed, 0 failed, 0 skipped** across 6 files
(2 + 5 + 4 + 3 + 6 + 6); log `_tests/implementation.log`. The suite holds 26 test
functions (`_tests/baseline.log`).

## Consistency matrix

- Every public symbol in `akku/os_poll/*.mojo` matches its inline `# API-DOCS`
  block: no undocumented symbol, no missing symbol, no signature drift (including
  `PollFd.clear(mut self)`).
- Every documented behavior has a test and an implementation that agree
  (readiness, EINTR recompute, zero-timeout probe, empty-set early return,
  negative-fd skip / INVALID_FD, INVALID bit and HANGUP reported as values, never
  exceptions, INVALID_TIMEOUT).
- Test integrity: `_tests/` matches the recorded Phase-10 state
  (`_dev/PHASE10_TESTS_REVIEW.md`, incl. the documented 24 → 26 HANGUP addendum)
  and `_dev/PHASE12_IMPLEMENTATION_REVIEW.md`.

## Dependency / layout audit

- Leaf library: no sibling dependency edge; imports only `std.ffi`, `std.sys`,
  `std.time`, `std.os` and its own `_internal`.
- Layout complete: `__init__.mojo`; one file per public API entry directly under
  `akku/os_poll/` (7 files, no `api/`, no `API.mojo`, no `src/`);
  `_internal/poll_native.mojo` (the genuinely shared FFI boundary); `_tests/`
  without `__init__.mojo`; `Taskfile.yml`; `_dev/DESIGN.md`; `_dev/TODO.md`.
- No physical nesting.

## Backlog audit

`_dev/TODO.md` holds only unshipped candidates, one line each with a
`<lang>.md §N` origin; shipped APIs are absent. Accurate.

## Open follow-ups (non-blocking)

**Deferred APIs (mirrored in `_dev/TODO.md`):** `PollTimeout.infinite()`,
`wait_until(deadline)`, a timeout-remainder out-param, `ReadySet`/`poll_into`,
`poll_until(predicate)`, `PollOutcome`, `READ_HANGUP`; `epoll`, `kqueue`, `select`
fallback, `ppoll`/`pselect`, a `backend()` query, Windows support; a stateful
`Poller` (register/modify/unregister), a `wakeup` handle, an opaque per-fd token;
an async readiness surface.

**Quality notes (owner: a future refactor pass):** a shared EINTR retry helper in
`_internal/poll_native.mojo` (the loop is duplicated in `wait`/`wait_many`);
`PollErrorKind.SYSCALL` has no deterministic test; `wait_many` has no
`INVALID_TIMEOUT` test; `test_zero_timeout_returns_immediately` uses a loose time
threshold.
