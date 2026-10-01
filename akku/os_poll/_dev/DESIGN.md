<!--
Design record for akku/os_poll — NOT end-user documentation.
End-user docs live inline in the `*.mojo` files (`# API-DOCS` blocks) and in
`__init__.mojo`. This file keeps developer-facing reasoning: status, semantics,
tests, rationale, reference-API comparisons, non-goals and open questions.
State after Phase 5 (design docs complete); no code exists yet.
All 7 entries are `planned` / `not implemented`.
-->

# os_poll — Design Record

## Purpose

`akku/os_poll` is **Readiness**: synchronous file-descriptor readiness with
**bounded** waits. It answers one question portably — "which of these file
descriptors is readable, writable or broken, waiting at most this long?" — by
calling POSIX `poll(2)` through a small, predictable value API.

It exists because the Mojo standard library has no readiness primitive, and
because the future `net_socket` rebuild needs every wait (connect, read, write,
accept) to be timeout-bounded in code instead of relying on an external GNU
`timeout` (see `akku_later/net_socket/_dev/TODO.md`). `os_poll` is **not** an
event loop: there are no callbacks, no registration, no runtime and no
`O_NONBLOCK` requirement. One thread waits and gets control back when an fd is
ready or the timeout elapses.

Supported targets: **Linux and macOS**. Windows is out of scope for release 1.

## Status legend

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All seven entries are `planned` and `not implemented` at Phase 5 (docs); no code exists yet.

## Dependencies

`os_poll` has **no dependency edge to any sibling MojoAkku library**. It is a
leaf: it uses only `std.ffi` (the `poll` symbol, `c_int`/`c_uint`/`c_short`/
`c_ulong`), `std.sys` (`CompilationTarget`, for the platform split) and
`std.time` (`monotonic`, for EINTR timeout recomputation). Both integer aliases
are needed for the `nfds` argument, which is `nfds_t`: `c_ulong` on Linux and
`c_uint` on macOS, so both are imported from `std.ffi`.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Readiness is an OS primitive; every parameter and return type is a Mojo builtin or a type owned by `os_poll` itself. No sibling type is required. |

- **Rejected edge `os_poll -> io_core`.** Reusing `IoError`/`IoErrorKind` was
  considered and rejected: `io_core` is the **stream** layer and sits *above* an
  OS readiness primitive; making the OS layer depend on the stream layer inverts
  the natural direction and would drag `io_core` under every future OS
  primitive. Readiness errors (invalid timeout, invalid fd, closed fd, raw
  syscall failure) also do not map one-to-one onto stream error kinds. Consumers
  that already speak `IoError` (e.g. `net_socket`) map `PollError` to `IoError`
  at their boundary with an explicit, documented conversion.
- **No physical nesting.** `akku/os_poll/` is a flat sibling under `akku/`.

## Overview

The API is a small, uniform value surface:

- **One event bitmask**, `PollEvents`, with the six portable `poll(2)` bits
  `READ`, `WRITE`, `ERROR`, `HANGUP`, `INVALID`, `PRIORITY`, plus a `NONE` empty
  set. It is one value type used both as an *interest* mask and as a *result*
  mask.
- **One bounded timeout type**, `PollTimeout`, carrying **milliseconds** only —
  one unit, one representation, never a sentinel. `os_poll` deliberately cannot
  express an unbounded wait.
- **One descriptor record**, `PollFd`, holding `fd`, the requested `events` and
  the returned `revents`. The caller owns the record; the library never owns an
  fd.
- **Two wait entry points**: `wait(fd, events, timeout)` for one descriptor
  (the shape the `net_socket` consumer needs) and `wait_many(fds, timeout)` for
  a caller-owned set. Both return readiness, never a callback.
- **One typed error**, `PollError` with a closed `PollErrorKind`. A timeout is
  **not** an error: it is an empty readiness result.

The mental model: `wait` is "sleep at most N ms, then tell me what is ready";
the empty set means nothing became ready in time. The call can never block
indefinitely.

## Goals

- A portable, synchronous, **bounded** readiness query for Linux and macOS.
- A surface a low-vision user can read: one naming scheme, one timeout unit,
  one typed error, one result type.
- Never an unbounded wait; never a silent timeout truncation.
- `EINTR` handled in the library loop, with the remaining timeout recomputed, so
  the caller's bound is respected (PEP 475 lesson).
- Enough for `net_socket` to bound connect/read/write/accept without an external
  `timeout` binary.

## Non-Goals

Decisions deliberately **not** copied from the reference ecosystems:

- **Unbounded waits** (negative/NULL timeout, `PollTimeout.infinite()`). Rejected
  because the library's whole purpose is boundedness; a caller who wants to wait
  forever loops. (origin: `c.md` §11, `python.md` §11)
- **Multiple timeout units and sentinels** (C's ms/`timeval`/`timespec`, Python's
  seconds vs ms and `None`/`0`/negative). Rejected: exactly one type and one
  unit (milliseconds). (origin: `c.md` §11, `python.md` §11, `rust.md` §11)
- **Timeout truncation to "infinite"** (pre-2.6.37 `epoll_wait`) or Java's silent
  `min(MAX)` clamp. Rejected: an out-of-range timeout raises
  `INVALID_TIMEOUT`; saturation is an explicit `PollTimeout.clamped`. (origin:
  `c.md` §11, `java.md` §11)
- **`select`/`fd_set`** (fixed `FD_SETSIZE`, three sets, `nfds = maxfd + 1`).
  Rejected: `poll`'s single array is strictly better. (origin: `c.md` §11,
  `python.md` §11)
- **A stateful selector/poller** (`register`/`modify`/`unregister`, live key
  sets, deferred cancellation). Rejected for release 1: event-loop shaped and
  unnecessary for a synchronous bounded query; deferred to the backlog. (origin:
  `java.md` §11, `python.md` §11)
- **Callbacks / async / completion models** (libuv `uv_poll_cb`, Go netpoller,
  `mio`, IOCP). Rejected: Mojo `async` is unstable and this library is the
  synchronous subset. (origin: `js-ts.md` §11, `go.md` §11, `rust.md` §11)
- **A runtime backend SPI** (Java `SelectorProvider`, Python `_can_use` probe).
  Rejected in favour of compile-time platform selection; there is no runtime
  choice to make between Linux and macOS. (origin: `java.md` §11)
- **`-1` + global `errno` sentinel returns.** Rejected: typed `raises`. (origin:
  `c.md` §11, `go.md` §11)
- **`0` meaning "wait forever"** (Java `select(0)`). Rejected: an explicit
  timeout type. (origin: `java.md` §11)
- **Node's clamp of delays > 2^31 ms down to 1 ms.** Rejected: never. (origin:
  `js-ts.md` §11)

## Reference APIs

| Reference | What is taken | What is rejected |
| --- | --- | --- |
| POSIX `poll(2)` (`c.md` §3) | the `pollfd` in/out shape (interest in, revents out), the bit semantics, `fd < 0` skips a slot, ERROR/HANGUP/INVALID reported regardless of interest | `-1`+`errno`, `int` ms overflow, negative-infinite sentinel |
| Rust `nix`/`rustix` (`rust.md` §3, §10) | the three-sentinel unification into one `PollTimeout`, fd borrowed not owned, `revents` as a value | `Option` conflation of "unknown bits", dynamic `io::Error` |
| Python `select`/`selectors` (`python.md` §3, §9) | PEP 475 EINTR retry **with timeout recomputation**; error bits in the result, not exceptions | seconds-vs-ms split, `None`/`0`/negative sentinels, duck-typed `fileno()` |
| Java `Selector`/`SelectionKey` (`java.md` §3, §10) | the `OP_*` bitmask vocabulary mapped onto readiness bits; ms timeout with `0` = non-blocking | deferred cancellation, live mutable sets, `0` = infinite, runtime provider SPI |
| Go `x/sys/unix.Poll`/`Ppoll` (`go.md` §3, §9) | thin blocking wrapper on the calling thread; negative = infinite is *not* copied | the `int` ms wrapper's precision/overflow loss, runtime netpoller coupling |
| C++ `wait_for` status enums (`cpp.md` §10, §12) | an explicit readiness *result* instead of a bare count | duration-template soup, `PollOutcome`/`poll_until` (deferred) |

## Public API

The ordered index; each entry is specified in its own block below and becomes
one file under `akku/os_poll/` in Phase 7.

1. `PollEvents` — the portable readiness bitmask (READ/WRITE/ERROR/HANGUP/INVALID/PRIORITY), used as interest and as result.
2. `PollErrorKind` — closed discriminant for `PollError`.
3. `PollError` — the one typed readiness error.
4. `PollTimeout` — a bounded timeout in milliseconds (no infinite form).
5. `PollFd` — one descriptor record: fd, requested events, returned revents.
6. `wait` — bounded wait for one descriptor; returns its readiness bits.
7. `wait_many` — bounded wait for a caller-owned set of `PollFd`; returns the ready count.

## Error Surface

Exactly one error type, `PollError`, carrying `kind: PollErrorKind`, `op: String`
and `detail: String`. Only the setup/wait call can raise; a **timeout is not an
error** (it is the empty result). Kinds:

- `INVALID_TIMEOUT` — the timeout is negative or exceeds `PollTimeout.MAX_MILLIS`.
- `INVALID_FD` — a single-fd `wait` was given a negative fd.
- `SYSCALL` — any other `poll(2)` failure; the numeric value is in `detail`.

`poll(2)` itself only fails with `EINTR`, `EINVAL`, `EFAULT` or `ENOMEM`
(`c.md` §4); it never returns `EBADF`. A bad or closed descriptor is therefore
**not** a raised error: it is reported per-descriptor in `revents` as `INVALID`
(`POLLNVAL`). `EINTR` is **never** surfaced either: `wait`/`wait_many` retry it
internally and recompute the remaining timeout. All kinds are recoverable by a
correct caller (fix the argument).

## Conventions

- One timeout unit: **milliseconds**, carried by `PollTimeout`.
- Event masks compose with `|` and are tested with `contains`/`is_*`; the six
  shipped bit values equal Linux's and macOS's `poll(2)` bit values.
- A wait is bounded by construction; there is no infinite timeout.
- The library never allocates with the caller's data and never owns an fd; it
  takes a borrowed descriptor number and writes results into caller storage.
- `fd < 0` in `wait_many` skips that entry (POSIX semantics); in single-fd
  `wait` it is `INVALID_FD`.
- Synchronous only: no async, no callbacks, no threads.

## Ownership and Lifecycle

- **The fd is borrowed.** `os_poll` only reads an integer descriptor; it never
  dups, closes or retains it. The caller keeps ownership and must not close an
  fd in another thread while a wait is in flight (documented POSIX hazard).
- **The `PollFd` set is caller-owned.** `wait_many` takes `MutSpan[PollFd, _]`,
  clears each `revents` before the call and writes results back; it allocates no
  caller-visible result container.
- **`PollEvents`, `PollTimeout` and `PollFd` are value types** (copyable); the
  library holds no hidden global state.
- The internal native `pollfd` array is a library-owned **per-call** buffer: it
  is allocated by the library for the duration of one wait, is never
  caller-allocated and never appears in the API, and is freed before the call
  returns. The "never allocates with the caller's data" contract therefore
  still holds.

## Open Questions

None open at Phase 3. Items that resolved to concrete future API candidates were
moved to `_dev/TODO.md` (unbounded timeout, absolute-deadline wait, `epoll`/
`kqueue`/`select`/`ppoll` entry points, stateful poller, wakeup handle,
`READ_HANGUP`, Windows, async).

## API entry: PollEvents

- **Status:** planned
- **Signature:**
  ```
  struct PollEvents(Copyable, Deinitable, Equatable, Writable):
      var _bits: UInt16
      @doc_hidden def __init__(out self, bits: UInt16)
      comptime NONE     = PollEvents(0x0000)
      comptime READ     = PollEvents(0x0001)
      comptime PRIORITY = PollEvents(0x0002)
      comptime WRITE    = PollEvents(0x0004)
      comptime ERROR    = PollEvents(0x0008)
      comptime HANGUP   = PollEvents(0x0010)
      comptime INVALID  = PollEvents(0x0020)
      def bits(self) -> UInt16
      def is_empty(self) -> Bool
      def __bool__(self) -> Bool
      def contains(self, other: Self) -> Bool
      def is_readable(self) -> Bool
      def is_writable(self) -> Bool
      def has_error(self) -> Bool
      def has_hangup(self) -> Bool
      def is_invalid(self) -> Bool
      def __or__(self, other: Self) -> Self
      def __and__(self, other: Self) -> Self
      def __eq__(self, other: Self) -> Bool
      def write_to(self, mut writer: Some[Writer])
  ```
- **Semantics:** One value type used both as the **interest** mask (which events
  you want) and the **result** mask (which events occurred). `READ`/`WRITE` are
  interest bits; `ERROR`/`HANGUP`/`INVALID` are always reported by `poll(2)`
  even when not requested, so `contains` on them is meaningful in a result.
  `PRIORITY` is the portable "urgent data" bit. `NONE` is the empty set; a wait
  that times out yields `NONE`. The six shipped bit values are **identical on
  Linux and macOS** (`POLLIN=0x0001`, `POLLPRI=0x0002`, `POLLOUT=0x0004`,
  `POLLERR=0x0008`, `POLLHUP=0x0010`, `POLLNVAL=0x0020`), so no platform branch
  is needed. `|` and `&` combine; `contains(other)` is true when every bit of
  `other` is present.
- **Errors:** none (a pure value type).
- **Tests:** `test_os_poll_events.mojo` — bit values, `|`/`&`, `contains`, `is_*`
  predicates, `NONE` is empty and falsy, printing shows symbolic names.
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses a single `PollEvents` value type for both
  interest and result because POSIX `poll(2)` and Rust `nix`/`rustix` both use
  one bit-set for both directions (`c.md` §3, `rust.md` §3), and because one
  type removes the "which mask am I holding?" question for a low-vision user.
  Java's separate `interestOps()`/`readyOps()` pair is rejected as two surfaces
  for one concept (`java.md` §3). The constants are `comptime` values, matching
  `IoErrorKind` in `io_core` and the research's `comptime`-bitflags idea
  (`go.md` §12). `POLLRDHUP` is not shipped because Linux has it and macOS does
  not (`c.md` §3); it is deferred to `_dev/TODO.md`.

## API entry: PollErrorKind

- **Status:** planned
- **Signature:**
  ```
  struct PollErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
      var _id: UInt8
      @doc_hidden def __init__(out self, id: UInt8)
      def __eq__(self, other: Self) -> Bool
      comptime INVALID_TIMEOUT = PollErrorKind(0)
      comptime INVALID_FD      = PollErrorKind(1)
      comptime SYSCALL         = PollErrorKind(2)
      def write_to(self, mut writer: Some[Writer])
  ```
- **Semantics:** Read from `PollError.kind` inside an except block; never
  constructed by a caller. The three kinds are the complete, closed set.
  `INTERRUPTED` is deliberately absent because `EINTR` is retried internally and
  can never surface. `CLOSED` is also absent because `poll(2)` has no `EBADF`
  failure (`c.md` §4): a bad or closed descriptor surfaces per-descriptor as
  `revents.INVALID`, not as an exception.
- **Errors:** none (a discriminant).
- **Tests:** `test_os_poll_events.mojo` covers printing/equality of the kind;
  the `INVALID_TIMEOUT` path is exercised in `test_os_poll_timeout.mojo`.
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses a closed discriminant instead of leaking raw
  errno because C's `errno` is a clobberable global (`c.md` §11) and Go's
  dynamic `error` forces `errors.Is` type assertions (`go.md` §11); a closed
  `comptime` set matches `io_core`'s `IoErrorKind` and is directly testable.

## API entry: PollError

- **Status:** planned
- **Signature:**
  ```
  @fieldwise_init
  struct PollError(Copyable, Deinitable, Writable):
      var kind: PollErrorKind
      var op: String
      var detail: String
      def write_to(self, mut writer: Some[Writer])
  ```
- **Semantics:** Constructed by the library when a wait fails; read in an
  except block. `op` is a short operation name (`"wait"` / `"wait_many"`);
  `detail` is opaque and must not be parsed. A **timeout is not** a `PollError`;
  it is an empty `PollEvents` / a `0` count.
- **Errors:** none — `PollError` *is* the error; constructing it cannot fail.
  Raise-by-transfer with `raise e^` (Copyable but not ImplicitlyCopyable),
  matching `IoError`.
- **Tests:** `test_os_poll_events.mojo` (printing), `test_os_poll_wait.mojo`
  (INVALID_FD path).
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses one typed error with a closed kind because
  Java's four overlapping exception types for one conceptual failure
  (`java.md` §11) and Rust's boxed `io::Error` both lose the machine-testable
  reason; the three-field shape matches `io_core`'s `IoError` for consistency
  across the project. The `op` field follows Go's `*OpError`/`*PathError`, which
  carry the operation name alongside the underlying error (`go.md` §4), and
  Java's exception hierarchy, which likewise reports the failing operation
  (`java.md` §4).

## API entry: PollTimeout

- **Status:** planned
- **Signature:**
  ```
  struct PollTimeout(Copyable, Deinitable, Equatable, Writable):
      var millis: Int
      comptime MAX_MILLIS = 2_147_483_647
      comptime ZERO = PollTimeout(0)
      comptime MAX  = PollTimeout(2_147_483_647)
      def __init__(out self, millis: Int)
      @staticmethod def clamped(millis: Int) -> Self
      def is_zero(self) -> Bool
      def write_to(self, mut writer: Some[Writer])
  ```
- **Semantics:** A bounded wait in **milliseconds**, `0 <= millis <= MAX_MILLIS`
  (`MAX_MILLIS` is `poll(2)`'s `int` maximum, ≈ 24.8 days). `ZERO` polls once and
  returns immediately (non-blocking). The raw constructor is non-raising (so
  `comptime ZERO` works); `wait`/`wait_many` validate the range and raise
  `INVALID_TIMEOUT` outside it. `clamped(millis)` saturates — negative → `0`,
  too large → `MAX_MILLIS` — for callers who prefer saturation over an error.
  There is **no** infinite form.
- **Errors:** none from the constructor; the range violation surfaces as
  `PollError(INVALID_TIMEOUT, "wait", ...)` from the wait call. `clamped` cannot
  fail.
- **Tests:** `test_os_poll_timeout.mojo` — `ZERO`/`MAX`, `is_zero`, `clamped`
  saturation and negative clamp, `millis`.
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses one milliseconds type because C mixes `int` ms,
  `timeval` and `timespec` with three infinite sentinels (`c.md` §8, §11) and
  Python mixes seconds and ms with `None`/`0`/negative (`python.md` §8, §11).
  The `MAX_MILLIS` bound follows nix's `PollTimeout` newtype and rustix's
  `INVAL`-on-oversized behaviour (`rust.md` §10): overflow is surfaced, not
  silently truncated as in Java (`java.md` §9). The absence of an infinite form
  is the deliberate bounded-wait rule.

## API entry: PollFd

- **Status:** planned
- **Signature:**
  ```
  struct PollFd(Copyable, Deinitable, Writable):
      var fd: Int
      var events: PollEvents
      var revents: PollEvents
      def __init__(out self, fd: Int, events: PollEvents)
      def is_ready(self) -> Bool
      def clear(self)
      def write_to(self, mut writer: Some[Writer])
  ```
- **Semantics:** One descriptor record. `fd` is the caller's borrowed
  descriptor number; `events` is the interest mask; `revents` starts empty and
  holds the result after `wait_many`. `is_ready()` is `revents` non-empty;
  `clear()` resets `revents` to `NONE` for reuse across loop iterations. A
  negative `fd` is carried through and skipped by `poll(2)` (POSIX), so a caller
  can mask a slot for one call without rebuilding the array.
- **Errors:** none (a value type).
- **Tests:** `test_os_poll_fd.mojo` — construction sets empty `revents`, `is_ready`
  false before and true after a result is written, `clear` resets.
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses a value record instead of Java's live mutable
  `SelectionKey` because a returned value needs no `isValid()`/`remove()` dance
  and no deferred cancellation (`java.md` §10, §11); the in/out `fd`/`events`/
  `revents` shape mirrors POSIX `pollfd` (`c.md` §3) and Rust's `PollFd`
  (`rust.md` §3), while the fields stay Mojo-idiomatic (`Int`, `PollEvents`)
  rather than raw C types, so no `c_int`/`c_short` leaks into the public API.

## API entry: wait

- **Status:** planned
- **Signature:**
  ```
  def wait(fd: Int, events: PollEvents, timeout: PollTimeout) raises PollError -> PollEvents
  ```
- **Semantics:** Wait at most `timeout.millis` milliseconds for `fd` to become
  ready for `events`. Returns the readiness bits observed: `READ`/`WRITE`
  (requested and satisfied), plus `ERROR`/`HANGUP`/`INVALID` (always reported by
  `poll(2)`). On timeout returns `NONE` (empty) — this is **not** an error.
  Preconditions: `fd >= 0` (else `INVALID_FD`), `0 <= timeout.millis <=
  MAX_MILLIS` (else `INVALID_TIMEOUT`). `timeout = PollTimeout.ZERO` performs
  exactly one `poll` and returns immediately (non-blocking). `EINTR` is retried
  internally: after an
  interrupt the remaining bound is recomputed from `std.time.monotonic()` so the
  total wait never exceeds the requested timeout; if the remaining time is
  `<= 0`, the call returns `NONE`. The call never blocks longer than the bound.
  Ownership: the fd is borrowed and never closed; the result is an owned value.
- **Errors:** `INVALID_FD` (negative fd), `INVALID_TIMEOUT` (out-of-range
  timeout), `SYSCALL` (any other `poll(2)` failure, numeric code in `detail`).
  All are recoverable. `EINTR` is never raised, and a closed-but-valid-numbered
  fd yields `revents.INVALID` (`POLLNVAL`) rather than an exception.
- **Tests:** `test_os_poll_wait.mojo` (readiness via a libc pipe: write end ready
  for write; after writing, read end ready for read; empty-before-data returns
  `NONE` on a zero timeout), `test_os_poll_bounded.mojo` (a 50 ms wait returns
  within a generous upper bound).
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses a single-descriptor `wait` returning a mask
  because the `net_socket` consumer needs exactly `wait(fd, events, timeout_ms)`
  and because returning the mask (not a count) makes "timed out" and "became
  ready" distinguishable without a separate status enum (`cpp.md` §12,
  `c.md` §10). The EINTR retry-and-recompute follows PEP 475 as cited in the
  research (`python.md` §9); Python's naive "restart the full timeout" is
  rejected because it would let a signal extend a bounded wait.

## API entry: wait_many

- **Status:** planned
- **Signature:**
  ```
  def wait_many(mut fds: MutSpan[PollFd, _], timeout: PollTimeout) raises PollError -> Int
  ```
- **Semantics:** Wait at most `timeout.millis` ms for any descriptor in the
  caller-owned `fds` set. First clears every `fds[i].revents`, then calls
  `poll(2)` over the whole set and writes each result back. Returns the number
  of entries whose `revents` is non-empty; `0` means the timeout elapsed (not an
  error). `fds[i].fd < 0` skips that entry (POSIX). `timeout =
  PollTimeout.ZERO` performs exactly one `poll` and returns immediately
  (non-blocking); an **empty span returns `0` immediately** without sleeping.
  `EINTR` is retried with the remaining bound
  recomputed, exactly as in `wait`. Precondition: `0 <= timeout.millis <=
  MAX_MILLIS` (else `INVALID_TIMEOUT`).
- **Errors:** `INVALID_TIMEOUT`, `SYSCALL`. `EINTR` never
  surfaces. A per-descriptor problem such as a closed-but-pollable fd is
  reported in that entry's `revents` (`INVALID`, `POLLNVAL`), not as an
  exception.
- **Tests:** `test_os_poll_wait_many.mojo` (two libc pipes, one read end written:
  count is 1 and the right `revents` is set; both ready → 2; a negative-fd slot
  is skipped), `test_os_poll_bounded.mojo` (bounded return).
- **Implementation status:** not implemented
- **Rationale:** MojoAkku uses one caller-owned `MutSpan[PollFd, _]` and returns
  the ready count because that is exactly `poll(2)`'s in/out contract (`c.md`
  §3) and because it allocates no caller-visible result container. Python's
  `poll()` returning a fresh `(fd, event)` list (`python.md` §3) is rejected as
  an extra allocation per wait; Go/Rust's returned count (`go.md` §3,
  `rust.md` §3) is adopted. The empty-set early return avoids `poll(2)`'s
  surprising "sleep the full timeout with nothing registered" behaviour
  (`c.md` §9).

## Open follow-ups

All resolved to backlog items in `_dev/TODO.md`; none block release 1.
