<!--
Design record for akku/time_clock — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 5 (docs: complete shared
sections and per-entry blocks); no code exists yet, so every entry is `planned` /
`not implemented`.
-->

# time_clock — Design Record

## Purpose

`akku/time_clock` is the single source of truth for the MojoAkku **time**
library: a monotonic `Clock`, a signed integer-nanosecond `Duration` (span +
arithmetic), and an opaque `Deadline` (an instant on that monotonic clock +
arithmetic), plus the clock/time error surface.

It is the foundation that the bounded-wait networking stack needs: `net_socket`
(a `net_*` sibling) depends on exactly these three types to express a timeout and
to measure elapsed time, so `time_clock` is a **leaf** that later libraries point
at, never the reverse.

The library is designed for a low-vision user: **one** clock entry point, **one**
span type, **one** instant type, **one** typed error, value semantics everywhere,
and an **explicit overflow policy** that raises instead of silently wrapping.

The Mojo standard library already ships `std.time` — `monotonic()`,
`perf_counter_ns()`, `sleep()` and `time_function()` (`mojov1/stdlib/time`) — but
it exposes only **raw `Int` nanoseconds** with no span type, no arithmetic and no
instant type. That gap is this library's reason to exist: `time_clock` wraps the
single stable-enough primitive (`std.time.monotonic()`) into typed values and
supplies the arithmetic the stdlib does not.

**Scope of release 1: monotonic time only.** Wall-clock time, calendar dates,
blocking `sleep`, cancellation and injectable test clocks are deliberately
deferred (see `## Non-Goals` and `_dev/TODO.md`); the error kinds and the design
reserve their place so they can be added additively.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 5 entries in this document are `planned`, and every entry's
`Implementation status:` is `not implemented`. These two fields are reconciled
explicitly for Phase 5: `Status` uses `planned` (designed and documented, no code
exists yet), while `Implementation status` uses the literal value
`not implemented` that `NewLibPhase5Docs.md` requires in this phase (nothing is
built yet) — they do not conflict. The entries become `scaffolded` at Phase 7,
`tested` at Phase 10 and `implemented` at Phase 12.

## Dependencies

`time_clock` has **no dependency edge to any sibling MojoAkku library**. It is a
leaf in the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Every signature is built from the Mojo standard library (`Int`, `UInt8`, `Bool`, `String`, `Some[Writer]`, `std.time.monotonic`). No signature mentions a stream, socket, file, buffer, URL or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `time_clock` needs none: `Duration` and
  `Deadline` are each one `Int`, and the only external call is
  `std.time.monotonic()` from the Mojo standard library. Adding an edge would
  create coupling without a technical reason, which the dependency rules forbid.
- **No FFI edge.** The capability ledger marks this library `mojoNeeds:
  [pure-mojo]` (`.repo/todo/time_clock.yml`). `std.time.monotonic()` is a
  standard-library call, not a direct libc call, so `time_clock` requires no
  `c-ffi` capability of its own.
- **No physical nesting.** `akku/time_clock/` is a flat sibling under `akku/`.
- **Direction of future edges.** Later libraries (`net_socket`, `async_scheduler`,
  `security_ratelimit`, `dev_benchmark`, `db_cache`, `proto_ntp`, … — all list
  `depends_on: [time_clock]` in `.repo/todo/`) point **to** `time_clock`, never
  the reverse.

## Overview

MojoAkku `time_clock` is a pure, in-process, deterministic value library with
**three public value types and one typed error**, all built on the single
primitive `std.time.monotonic()`:

- **`Duration`** — a **signed** span, stored as one `Int` nanosecond count. It
  carries per-unit constructors, truncating unit accessors, sign predicates and
  `abs`, add/sub/negate/scaled/divided_by arithmetic, and a total order. Every
  fallible arithmetic operation **raises** `TimeError` instead of wrapping.
- **`Deadline`** — an **opaque** monotonic instant, stored as one `Int` tick with
  **no public raw-tick accessor**. It supports `+ Duration`, `- Duration`,
  `Deadline - Deadline -> Duration` (signed), a total order, and the three
  queries `is_expired()`, `remaining()` and `elapsed()`.
- **`Clock`** — the **one** clock entry point, a bare static `Clock.now() ->
  Deadline` backed by `std.time.monotonic()`. There is no clock-id parameter, no
  template clock and no second clock.
- **`TimeError` / `TimeErrorKind`** — one typed error with a small, closed
  two-value discriminant (`OVERFLOW`, `DIVISION_BY_ZERO`).

The mental model a user needs is exactly three sentences:

1. `Clock.now()` gives a `Deadline` whose **absolute value is meaningless** — the
   origin is undefined and platform-specific, so only differences are valid
   (`c.md` §1 APPLICATION USAGE; `python.md` §1).
2. `Deadline + Duration` is the single canonical timeout composition, and
   `Clock.now() >= deadline` is the canonical expiry test (`go.md` §10, §12;
   `rust.md` §8).
3. `Duration` is what you get from `Deadline - Deadline`, and it is **signed**, so
   a negative result is the ordinary "it is already too late" case, not an error
   (`rust.md` §11; `java.md` §10).

Cross-cutting shape:

- **One monotonic clock only.** The research is unanimous that a wall clock and a
  monotonic clock must not be conflated (`go.md` §11 rejects Go's wall+monotonic
  `Time`; `cpp.md` §10/§11 splits `system_clock` from `steady_clock`), so release
  1 ships the **monotonic** clock alone; a wall clock is a deferred candidate
  (`_dev/TODO.md`).
- **Integer nanoseconds, never floats.** `Duration` is one `Int`, so there is no
  floating-point drift and no precision-loss compromise; Python's `float`
  `monotonic()` and JS's `DOMHighResTimeStamp` are the anti-references
  (`python.md` §11; `js_ts.md` §11).
- **Opaque instant.** `Deadline` exposes no raw tick, so "absolute value is
  meaningless" is enforced by the type, not by a comment (`c.md` §11; `rust.md`
  §10).
- **Explicit overflow.** Every fallible arithmetic operation declares
  `raises TimeError`; there is no silent two's-complement wrap and no UB. This is
  the single deliberate replacement for Go/C/C++'s silent wrap
  (`go.md` §11; `c.md` §11; `cpp.md` §11) and Rust's panic (`rust.md` §11).
- **Value semantics, no hidden global state.** All three value types are
  `Copyable`, `ImplicitlyCopyable`, `Deinitable`; no library type owns a
  resource, holds a handle, or mutates process-global state.

The problem space is covered by every reference language, so the value of this
library is not "another duration". It is a *predictable, consistent and
easy-to-read* surface for a low-vision user. The research shows the reference
ecosystems each get one or two pieces right and rarely all at once:

- Go has the cleanest "timeout = deadline = now + duration" composition but wraps
  `Duration` arithmetic silently under two's-complement rules (`go.md` §10, §11).
- Rust has the strongest representability model (`checked_*`/`saturating_*`) but
  panics on operator overflow, has an unsigned-only `Duration`, and a
  platform-dependent `Instant` range (`rust.md` §10, §11).
- Python has the correct monotonic contract ("only the difference … is valid")
  but no monotonic instant type and a float-first representation (`python.md`
  §10, §11).
- Java has a clear signed/directed `Duration` and documents the overflow-safe
  comparison idiom, but throws `ArithmeticException` from every `plus` and stores
  seconds+nanos in two fields (`java.md` §10, §11).
- C and C++ have no arithmetic on the value type (C) or unchecked UB/silent
  wrap (C++), and push normalisation and overflow onto the caller (`c.md` §11;
  `cpp.md` §11).
- JS/TS has no duration type at all and a 32-bit millisecond delay trap
  (`js_ts.md` §11).
- Kotlin has opaque source-bound instants and an injectable test source but
  conflates "very large" with "no timeout" via `INFINITE` (`kotlin.md` §10, §11).

Mojo's own `std.time` is the direct Mojo anchor: it has `monotonic() -> Int` and
`perf_counter_ns() -> Int`, both with an **undefined reference point**
(`mojov1/stdlib/time`), and no span/instant types — the gap this library closes.

`time_clock` depends on **no other MojoAkku library**. It needs no Python
interpreter and no direct FFI.

## Goals

1. **One monotonic clock, one entry point.** `Clock.now()` is the only way to
   read time. MojoAkku uses a single concrete static entry point because C++
   exposes `steady_clock::now()` only and `cpp.md` §12 recommends one concrete
   monotonic clock over a template/clock-id parameter, while `go.md` §12 shows
   "timeout = deadline" needs exactly one clock.

2. **Signed integer-nanosecond span with familiar verbs.** `Duration` is one
   `Int` with unit constructors, truncating accessors, sign predicates,
   `abs`/negate and add/sub/scaled/divided_by. MojoAkku uses a single signed
   nanosecond span because Go's `type Duration int64` (`go.md` §3) and Java's
   "directed duration" (`java.md` §10) show signed spans are the natural model,
   and Python's float seconds plus Rust's unsigned-only `Duration` are the
   documented anti-references (`python.md` §11; `rust.md` §11).

3. **Opaque instant, differences only.** `Deadline` has no raw-tick accessor;
   the only operations are `± Duration`, `- Deadline`, comparison and the three
   now-relative queries. MojoAkku uses an opaque instant because POSIX states the
   absolute value of `CLOCK_MONOTONIC` "is meaningless" (`c.md` §1, §11) and
   Rust's `Instant` is "opaque and useful only with `Duration`" (`rust.md` §10).

4. **Explicit overflow, never a silent wrap.** Every fallible `Duration` and
   `Deadline` arithmetic operation declares `raises TimeError` with kind
   `OVERFLOW`; division by zero raises `DIVISION_BY_ZERO`. MojoAkku uses a typed
   `raises` because Go wraps silently (`go.md` §11), C has no arithmetic at all
   (`c.md` §11), C++ signed overflow is UB (`cpp.md` §11) and Rust panics on the
   operator forms (`rust.md` §11).

5. **One typed error with a closed discriminant.** All failures are `TimeError`
   with `kind ∈ {OVERFLOW, DIVISION_BY_ZERO}`. MojoAkku uses one error type
   because Rust funnels fallible arithmetic through one `Error`/`Option` shape
   (`rust.md` §4) and this repository already established the
   `kind`+`detail`-style pattern in `io_core` (`IoError`) and `prim_bit`
   (`BitError`); Java's unchecked `ArithmeticException` on every `plus` is
   rejected (`java.md` §11).

6. **Errors as values, no panic and no sentinel.** Absence never exists in this
   domain (there is no "no duration"), and a representability failure is a typed
   value, not a `-1`/abort/exception. MojoAkku uses typed errors because
   `cpp.md` §11 rejects `abort()` and `go.md` §11 rejects the silent sentinel.

7. **Value semantics, no hidden global state.** `Duration`, `Deadline`,
   `TimeError` and `TimeErrorKind` are `Copyable`/`Deinitable` value types;
   `Clock` is a stateless static entry point. MojoAkku uses value types because
   C++ `duration`/`time_point`, Go `Duration`/`Time` and Kotlin's inline value
   class are all pass-by-value (`cpp.md` §5; `go.md` §5; `kotlin.md` §10).

8. **Readability for a low-vision user.** Stable names, one span type, one
   instant type, one error type, identical field names in every documented entry,
   and a documented overflow policy in the signature.

9. **Pure Mojo.** No hidden global state, no Python dependency, no direct FFI and
   no `unsafe_*` in the public surface.

## Non-Goals

Decisions the library deliberately does **not** copy, taken from the research
`## 11` sections. Each is a `MojoAkku rejects … because …` statement. Items that
are concrete, theoretically-possible-in-Mojo API candidates are **also** listed in
`_dev/TODO.md`; a decision that is not possible or not wanted in Mojo stays only
here.

- **One type carrying wall and monotonic time.** MojoAkku rejects Go's `Time`
  struct with both readings because the dual reading makes semantics subtle and
  platform-dependent ("on some systems the monotonic clock will stop if the
  computer goes to sleep", `go.md` §11); the monotonic instant stays separate
  from wall time.
- **Silent two's-complement wrap on duration arithmetic.** MojoAkku rejects Go's
  int64 wrap (`go.md` §11) because a timing primitive must never lose a carry
  silently; `__add__`/`__sub__`/`__neg__`/`scaled` raise `OVERFLOW`.
- **Unsigned-only `Duration`.** MojoAkku rejects Rust's `u64`+`u32` unsigned span
  (`rust.md` §11) because `remaining = deadline - now` and an elapsed-time
  deficit are naturally signed; Rust then needs `checked_sub`/`abs_diff` just to
  express "before".
- **Panic-on-overflow operator forms.** MojoAkku rejects Rust's `Add`/`Sub`/
  `Mul` panic-or-wrap (`rust.md` §11) because a hidden panic is worse for a
  low-level primitive than an explicit `raises` in the signature.
- **A platform-dependent instant range.** MojoAkku rejects Rust's macOS/Linux
  divergence for large `Instant` additions (`rust.md` §11) because the
  representable range must be defined once, by the `Int` carrier, not by the OS.
- **Seconds + nanoseconds dual-field storage.** MojoAkku rejects Java's `long`
  seconds + `int` nanos with an always-positive nanos field (`java.md` §11)
  because a single signed integer-nanosecond span is easier to reason about,
  compare and overflow-check.
- **Raw `long` monotonic deadlines plus a documented overflow idiom.** MojoAkku
  rejects Java's `System.nanoTime()`-as-deadline guidance (`java.md` §11) because
  a typed `Deadline` makes the safe path the only path.
- **Hand-normalised `timespec` arithmetic.** MojoAkku rejects C's "two integers
  and no operators" model (`c.md` §11) because requiring callers to normalise
  `tv_sec`/`tv_nsec` carries is a bug farm.
- **`errno` + `-1` sentinel.** MojoAkku rejects C's out-of-band error slot
  (`c.md` §11) because Mojo raises a typed error and a global error slot cannot be
  copied.
- **`time_t`/`long` representation limits.** MojoAkku rejects the 32-bit `time_t`
  trap documented by POSIX `EOVERFLOW` (`c.md` §11) because the carrier is one
  explicit `Int`, defined once.
- **Unchecked / UB duration arithmetic.** MojoAkku rejects C++'s unchecked
  operators and signed-overflow UB (`cpp.md` §11) because the default must be
  checked, not undefined.
- **Lossy implicit/explicit conversion subtlety.** MojoAkku rejects C++'s
  `duration_cast`-only-when-lossy rule (`cpp.md` §11) because conversions here are
  explicit named constructors and accessors, never silent.
- **Clock as a template/type parameter.** MojoAkku rejects
  `time_point<Clock, Duration>` (`cpp.md` §11) because a single concrete monotonic
  `Clock` reads better and removes every clock-generic signature.
- **Float `Rep` in the same type family.** MojoAkku rejects `duration<double>`
  (`cpp.md` §11) and JS's bare-float milliseconds (`js_ts.md` §11) because a
  nanosecond-integer deadline must not drift.
- **`high_resolution_clock` as a monotonic source.** MojoAkku rejects the alias
  that may equal either `system_clock` or `steady_clock` (`cpp.md` §11); the one
  clock is guaranteed monotonic.
- **Float-seconds-first representation.** MojoAkku rejects Python's
  `float`-returning `monotonic()` and JS's `DOMHighResTimeStamp` (`python.md`
  §11; `js_ts.md` §11) because integer nanoseconds avoid the documented precision
  loss.
- **Two parallel monotonic clock names.** MojoAkku rejects Python's
  `monotonic`/`perf_counter` duality (`python.md` §11) because they coincide only
  as a CPython 3.13 implementation detail; one monotonic clock is enough.
- **No monotonic instant type at all.** MojoAkku rejects Python's
  `start + timeout`-on-floats idiom (`python.md` §11) because a typed `Deadline`
  is safer and reads better.
- **Platform-dependent clock semantics.** MojoAkku rejects Python's "semantics
  varies among platforms" module contract (`python.md` §11) because a library
  whose whole point is predictable wait timing must define its contract once.
- **`sleep(0)` as a yield.** MojoAkku rejects treating a zero sleep as a
  scheduling primitive (`python.md` §11); blocking `sleep` is out of scope
  (deferred) and will define zero-duration behaviour explicitly if it ships.
- **Infinite-on-overflow.** MojoAkku rejects Kotlin's `Duration.INFINITE`
  (`kotlin.md` §11) because it conflates "very large" with "no timeout"; a
  no-timeout sentinel is a deferred explicit representation, not a magic value.
- **Unit-conversion extension properties on the numeric types.** MojoAkku rejects
  Kotlin's `Long.hours`/`toDuration` (`kotlin.md` §11) because constructors belong
  on `Duration`, not on `Int`.
- **`toInt`/`toLong` clamping conversions.** MojoAkku rejects Kotlin's silent
  clamp (`kotlin.md` §11); accessors are explicitly truncating and documented.
- **`times`/`div` overloaded for `Int` and `Double`.** MojoAkku rejects
  `kotlin.md` §11's float path; scaling is integer-only (`scaled`, `divided_by`).
- **JS's 32-bit millisecond delay boundary and silent coercion.** MojoAkku
  rejects the ~24.8-day limit and the string→0 coercion (`js_ts.md` §11) because
  the span is a wide signed `Int` and constructors validate.
- **A 4 ms nested-timeout clamp and browser resolution coarsening.** MojoAkku
  rejects JS's deliberate timing-attack coarsening and event-loop clamping
  (`js_ts.md` §11) because a systems time library must not inherit browser
  security trade-offs; resolution is documented, not degraded.
- **`context`'s value bag and channel cancellation.** MojoAkku rejects Go's
  `WithValue` and `Done()`+`CancelFunc` (`go.md` §11) because a timeout type must
  not double as a key-value carrier and a `Deadline` value is leak-free.
- **Mutable stored deadlines.** MojoAkku rejects Go's `SetDeadline` and Java's
  `setSoTimeout(0 == infinite)` as mutable stream state (`go.md` §8, §11;
  `java.md` §8) because a timeout is a per-operation value, never stored state.
  (This is the design contract `net_socket` will consume.)
- **Async/await in the core.** MojoAkku rejects pulling `async`/`await` into the
  clock surface because Mojo's `async` is documented unstable
  (`mojov1/concurrency/async-and-parallelism`); `Clock.now()` never awaits.
- **Wall-clock, calendar and date arithmetic.** MojoAkku defers the wall clock
  (`now_wall`) and all calendar/date work to later libraries because the
  monotonic contract must be settled first; `time_datetime` is a separate
  catalogue entry.
- **Blocking `sleep`, cancellation and injectable test clocks.** MojoAkku defers
  `sleep(Duration)`, an explicit cancellation token, an `INFINITE`/no-timeout
  sentinel and a `TestClock` because release 1 is the pure value layer; each is a
  concrete candidate in `_dev/TODO.md`.
- **Saturating/checked/optional method families.** MojoAkku rejects adding
  `saturating_add`/`checked_add`/`abs_diff` beside the raising operators in
  release 1 (`rust.md` §11 recommends them, but one raising form is the smallest
  complete surface); the variants are concrete candidates in `_dev/TODO.md`.
- **String parsing/formatting of durations.** MojoAkku defers `parse_duration`
  and a human-readable `to_string` to a later release; `Duration`'s `Writable`
  output is the canonical machine form only.

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Single monotonic instant type | Rust `Instant` ("opaque and useful only with `Duration`"); POSIX `CLOCK_MONOTONIC` ("absolute value is meaningless"); C++ `steady_clock`; Java `System.nanoTime()` | `rust.md` §1, §10; `c.md` §1, §11; `cpp.md` §10; `java.md` §3 |
| Signed duration span | Go `type Duration int64`; Java `Duration` ("directed … may be negative"); Python `datetime.timedelta` | `go.md` §1, §3; `java.md` §1, §10; `python.md` §3 |
| Integer nanoseconds, no float | Python `monotonic_ns()` ("to avoid the precision loss caused by the float type"); Kotlin `inWholeNanoseconds` | `python.md` §10, §11; `kotlin.md` §3 |
| Unit constructors + unit accessors | Go `time.Second` constants; Java `ofMillis`/`ofSeconds`/`toMillis`; Rust `from_millis`/`from_micros`/`as_secs`; C++ `duration_cast` | `go.md` §3; `java.md` §3; `rust.md` §3; `cpp.md` §3 |
| Sign predicates and `abs` | Java `isZero`/`isPositive`/`isNegative`/`abs`/`negated`; Go `Abs` | `java.md` §3; `go.md` §3 |
| Timeout = deadline = now + duration | Go `context.WithTimeout` (`WithDeadline(now+d)`); Rust `Instant + Duration`; Kotlin `TimeMark`/`elapsedNow` | `go.md` §10, §12; `rust.md` §8, §12; `kotlin.md` §10, §12 |
| Expiry as comparison, not addition | Java `System.nanoTime() - start >= timeout` idiom (overflow-safe) | `java.md` §8, §12 |
| Opacity of the instant | Rust `Instant` (no raw accessor); POSIX monotonic "meaningless" | `rust.md` §10; `c.md` §11 |
| Explicit overflow policy | Rust `checked_*`/`saturating_*`/panic; Go silent wrap; C++ UB; JS silent overflow | `rust.md` §3, §11; `go.md` §11; `cpp.md` §11; `js_ts.md` §4, §11 |
| Typed error + closed kind | Rust `SystemTimeError`; Java `ArithmeticException` (rejected shape); and MojoAkku `io_core` `IoError`/`IoErrorKind` | `rust.md` §4; `java.md` §4; `akku/io_core/_dev/DESIGN.md` |
| Value semantics + `Copy` | C++ `duration`/`time_point`; Go `Duration`/`Time`; Kotlin `@JvmInline value class Duration` | `cpp.md` §5; `go.md` §5; `kotlin.md` §5, §10 |
| Monotonic origin undefined | Python `time.monotonic` ("reference point … undefined … only the difference … is valid"); Mojo `std.time.monotonic`/`perf_counter_ns` | `python.md` §1; `mojov1/stdlib/time` |
| Mojo language anchors | `@staticmethod`; typed `raises`; `comptime` members; `Equatable`; `Writable`/`write_to`; `Some[Writer]` | `mojov1/decorators/staticmethod`; `mojov1/errors/error-model`; `mojov1/types/operator-support`; `mojov1/idioms/patterns` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order. The order follows the frozen scope the Manager
set for this library (value types first, error surface last).

1. `Duration` — a **signed integer-nanosecond span** with unit constructors and
   accessors, sign predicates, `abs`, raising add/sub/negate/scaled/divided_by
   and a total order. (`duration.mojo`)
2. `Deadline` — an **opaque monotonic instant** (one `Int`, no raw accessor) with
   `± Duration`, `Deadline - Deadline -> Duration`, a total order and the
   `is_expired`/`remaining`/`elapsed` queries. (`deadline.mojo`)
3. `Clock` — the **one monotonic clock entry point**: static `now() -> Deadline`
   backed by `std.time.monotonic()`. (`clock.mojo`)
4. `TimeErrorKind` — the **closed two-value discriminant** for `TimeError`:
   `OVERFLOW`, `DIVISION_BY_ZERO`. (`time_error_kind.mojo`)
5. `TimeError` — the **one typed error**: `kind: TimeErrorKind`,
   `detail: String`; `Writable`. (`time_error.mojo`)

## Error Surface

There is exactly **one** error type: `TimeError`, declared with
`raises TimeError` on every fallible time operation. It carries:

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | `TimeErrorKind` | `OVERFLOW` or `DIVISION_BY_ZERO`. |
| `detail` | `String` | Opaque, human-readable context (never parsed). |

Which API can raise:

| API | Raises | Kinds |
| --- | --- | --- |
| `Duration.from_micros` / `from_millis` / `from_seconds` | yes | `OVERFLOW` (the unit scaling does not fit the `Int` carrier) |
| `Duration.from_nanos` | no | — (total) |
| `Duration.__add__` / `__sub__` / `__neg__` / `scaled` | yes | `OVERFLOW` |
| `Duration.divided_by` | yes | `DIVISION_BY_ZERO` (`divisor == 0`); `OVERFLOW` (`MIN / -1`, the quotient 2^63 does not fit `Int`) |
| `Duration.abs` | yes | `OVERFLOW` (only for the one most-negative span) |
| `Duration.as_*`, `is_*`, `__eq__`, `__lt__`/`__le__`/`__gt__`/`__ge__`, `compare` | no | — (total) |
| `Deadline.__add__` / `__sub__(Duration)` | yes | `OVERFLOW` |
| `Deadline.__sub__(Deadline)` | yes | `OVERFLOW` (only at the numeric extreme) |
| `Deadline.remaining` / `elapsed` | yes | `OVERFLOW` (only at the numeric extreme) |
| `Deadline.is_expired`, `__eq__`, comparisons, `compare` | no | — (total) |
| `Clock.now` | no | — (`std.time.monotonic()` does not raise) |
| `TimeErrorKind` / `TimeError` construction | no | — (they *are* the error) |

Rules:

- **One error type per function.** Mojo allows at most one error type per
  signature; `TimeError` is it.
- **Every arithmetic overflow raises `OVERFLOW`.** There is no wrapping and no
  saturation in release 1 (`go.md` §11; `rust.md` §11; `cpp.md` §11).
- **Division by zero raises `DIVISION_BY_ZERO`.** No `Inf`/`NaN` duration and no
  panic.
- **All conditions are recoverable data errors.** The caller can retry with a
  smaller operand, a different unit, or a non-zero divisor. None is fatal and
  none aborts.
- **No OS errno leak.** `detail` may name the failing operation, but callers
  branch on `kind`, never on strings.
- **Diagnostics.** `TimeError` and `TimeErrorKind` implement `Writable`, so
  `print(e)` yields a readable kind + detail message.

**Non-applicable conditions — explicit analogues.** This domain has no stream,
descriptor, signal or transport, so the usual stream edge cases do not exist.
Each is mapped deliberately rather than left as a gap:

- **No EOF concept.** There is no end of input. The **analogue is deadline
  expiry**: "the wait is over" is `Deadline.is_expired() == True` (equivalently a
  `remaining()` `<= Duration.ZERO`), a normal outcome reported by a `Bool`/
  `Duration`, never an error and never a sentinel (`go.md` §8; `c.md` §8).
- **No EINTR / interruption.** `Clock.now()` reads a monotonic register and
  cannot block, so no signal can interrupt it and no retry policy applies. The
  one operation that would be interruptible, a future blocking `sleep(Duration)`,
  is deferred to `_dev/TODO.md` with the EINTR contract to be defined there
  (`c.md` §6, §11; `python.md` §11).
- **No EAGAIN / would-block.** There is no partial progress and no non-blocking
  handle; a value operation either produces its value or raises.
- **No close/shutdown.** No library type owns a handle or a resource, so there is
  nothing to close and no "after close" state (`c.md` §5; `rust.md` §5).
- **No IPv4/IPv6.** Time values carry no address family (`c.md` §7; `go.md` §7).
- **No TLS.** There is no transport to secure (`c.md` §9; `go.md` §9).

## Conventions

These are the rules every entry in this document follows, and the rules a
sibling MojoAkku library copying the pattern should keep.

- **One entry per public API member, in design order.** Names are stable; the
  `## Public API` list and the `## Semantics` entries are in the same order.
- **Identical field names and order in every entry.** Each entry uses exactly:
  `Status:`, `Signature:`, `Semantics:`, `Errors:`, `Tests:`,
  `Implementation status:`, `Rationale:`. No field is omitted.
- **Signature is the exact Mojo declaration.** It is copied verbatim by Phase 5/7.
- **Semantics is complete.** Covers parameters/preconditions, return/meaning,
  ownership, the overflow/edge behaviour and the (non-applicable) stream-I/O
  contract.
- **Errors names every raised error and says whether it is recoverable.** Total
  functions say `none`.
- **Tests names the test file that covers the entry and its planned
  test-function names.** Present for every entry.
- **Rationale is a `MojoAkku uses X because Y` statement** naming the reference
  API and its research section.
- **Status and implementation status are honest.** All entries are `planned` /
  `not implemented` at Phase 5 (see `## Status legend` for the field reconciliation).
- **Time is monotonic-only and integer-nanosecond.** No wall clock, no float.
- **Terminology is shared.** Span, instant, monotonic clock, expiry and overflow
  are defined once in `## Semantics ## Terminology`.
- **Markdown tables use `|`.** Sources are cited as `<lang>.md §<section>` and
  `mojov1/<page>`.

## Ownership and Lifecycle

**Pure values, no resources.** `Duration` and `Deadline` each wrap a single
`Int`; `TimeErrorKind` wraps a single `UInt8`; `TimeError` wraps a
`TimeErrorKind` plus an owned `String`. None owns a handle, an allocation beyond
the error `String`, or a resource with a destructor side effect, so there is no
`close`, no explicit destroy and no lifecycle hazard (`cpp.md` §5; `kotlin.md`
§5).

**Copyable, cheaply.** `Duration`, `Deadline` and `TimeErrorKind` are
`ImplicitlyCopyable` — the compiler may insert copies freely. `TimeError` is
`Copyable` but deliberately **not** `ImplicitlyCopyable`, so a re-raise must
transfer with `raise e^` (the `IoError`/`BitError` MojoAkku convention;
`mojov1/errors/raising-and-propagation`).

**No hidden global state.** Nothing in `time_clock` writes process-global state.
`Clock.now()` reads the platform monotonic clock — it is a pure function of
external time, not a mutable global, and it takes no argument and stores nothing.
The error kinds are `comptime` constants.

**ASAP destruction.** Every value is freed at its last use; there is no
destructor side effect and nothing to abandon.

**Lifecycle summary.**

| API | Consumes input? | Owns output? | Can be abandoned? |
| --- | --- | --- | --- |
| `Duration` | no (value, `ImplicitlyCopyable`) | itself (caller) | yes |
| `Deadline` | no (value, `ImplicitlyCopyable`) | itself (caller) | yes |
| `Clock.now` | no | returns a `Deadline` by value | yes |
| `TimeError` | no (raised by transfer) | its `detail` `String` | yes (once caught) |
| `TimeErrorKind` | no (value, `ImplicitlyCopyable`) | itself (caller) | yes |

**Pure Mojo.** The design uses only `Int`, `UInt8`, `Bool`, `String`,
`Some[Writer]`, `std.time.monotonic` and typed `raises`. It requires no Python
interpreter, no direct FFI and no `unsafe_*` in the public surface.

## Open Questions

**None at handoff.** Every design question raised by the research is resolved
here or recorded as a future API candidate in `_dev/TODO.md`:

- *Monotonic only, or wall + monotonic?* → **monotonic only** in release 1;
  `now_wall` is a TODO candidate (`go.md` §11 rejects the dual type).
- *Signed or unsigned `Duration`?* → **signed** (`remaining`/`elapsed` are
  naturally signed; `rust.md` §11).
- *One `Int` or seconds+nanos?* → **one `Int`** (`java.md` §11 avoids the
  two-field negative representation).
- *Overflow: wrap, saturate, panic or raise?* → **raise `TimeError`**
  (`go.md` §11; `cpp.md` §11; `rust.md` §11); saturating/checked variants are
  backlog.
- *Instant: raw tick accessor or opaque?* → **opaque** (`c.md` §11; `rust.md`
  §10).
- *Expiry as a boolean or an error?* → **a boolean**, `is_expired()`, with a
  signed `remaining()` (`java.md` §8 overflow-safe comparison idiom).
- *How many error kinds?* → **two** (`OVERFLOW`, `DIVISION_BY_ZERO`); a future
  parse/format or wall-clock layer is additive.

## Semantics

#### Terminology

- **Span** — a signed amount of elapsed time, carried by `Duration`; its base
  unit is one nanosecond.
- **Instant / deadline** — a point on the monotonic timeline, carried by
  `Deadline`. Its absolute value has no meaning; only a difference of two
  instants (a `Duration`) is valid.
- **Monotonic clock** — the platform clock behind `Clock.now()`, which cannot
  move backwards and is unaffected by wall-clock adjustments. Its **origin is
  undefined**.
- **Expiry** — the condition `Clock.now() >= deadline`. It is not an error; it is
  reported by `is_expired()` and by a non-positive `remaining()`.
- **Overflow** — the arithmetic result does not fit the `Int` carrier. It raises
  `TimeError` with kind `OVERFLOW`; it never wraps or saturates in release 1.

All durations are in nanoseconds at the type boundary. There is no float path and
no calendar/date concept in this library.

---

### `Duration`

Status: planned

Signature:

```mojo
struct Duration(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var _nanos: Int

    @doc_hidden
    def __init__(out self, nanos: Int)

    comptime ZERO = Duration(0)

    @staticmethod
    def from_nanos(n: Int) -> Self
    @staticmethod
    def from_micros(n: Int) raises TimeError -> Self
    @staticmethod
    def from_millis(n: Int) raises TimeError -> Self
    @staticmethod
    def from_seconds(n: Int) raises TimeError -> Self

    def as_nanos(self) -> Int
    def as_micros(self) -> Int
    def as_millis(self) -> Int
    def as_seconds(self) -> Int

    def is_zero(self) -> Bool
    def is_positive(self) -> Bool
    def is_negative(self) -> Bool
    def abs(self) raises TimeError -> Self

    def __add__(self, rhs: Self) raises TimeError -> Self
    def __sub__(self, rhs: Self) raises TimeError -> Self
    def __neg__(self) raises TimeError -> Self
    def scaled(self, factor: Int) raises TimeError -> Self
    def divided_by(self, divisor: Int) raises TimeError -> Self

    def __lt__(self, other: Self) -> Bool
    def __le__(self, other: Self) -> Bool
    def __gt__(self, other: Self) -> Bool
    def __ge__(self, other: Self) -> Bool
    def compare(self, other: Self) -> Int

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions.** The carrier is a single `Int`
  (`_nanos`); the raw `__init__` is `@doc_hidden` and the named public route is
  `from_nanos` (or one of the unit constructors). `n` is any signed `Int`; there
  is no invalid bit pattern, so construction is total except for unit scaling
  overflow (below). `from_micros`/`from_millis`/`from_seconds` multiply by
  `1_000`/`1_000_000`/`1_000_000_000` inside a checked multiply and raise
  `OVERFLOW` if the product does not fit.
- **Return / meaning.** `Duration` is a **signed** span.
  - `ZERO` — the additive identity (`Duration(0)`), a `comptime` constant.
  - `as_nanos` returns the raw count; `as_micros`/`as_millis`/`as_seconds`
    return the count divided by the unit, **truncating toward zero** (`-1 ns` →
    `0 s`), matching Mojo's `/` integer rule (`mojov1/basics/operators`,
    "truncates toward zero") and Java/Rust's `to*`/`as_*` conventions
    (`java.md` §3; `rust.md` §3).
  - `is_zero`/`is_positive`/`is_negative` classify the sign.
  - `abs` returns the magnitude; it delegates to `__neg__` for a negative span
    and therefore raises `OVERFLOW` for the single most-negative value whose
    magnitude is not representable (Go's `Abs` special-cases exactly this value —
    `go.md` §4 — but silently changes the magnitude, which the explicit model
    rejects).
  - `__add__`/`__sub__` add/subtract two spans; `__neg__` flips the sign;
    `scaled(factor)` multiplies by a signed scalar; `divided_by(divisor)`
    divides by a signed scalar, truncating toward zero. `scaled` and
    `divided_by` are **named methods**, not `*`/`/` operators, so a caller cannot
    mistake a scalar operation for a span operation (Rust's `Mul<u32>`/`Div<u32>`
    operators are not copied; `rust.md` §3, §11).
  - The comparison set is a **total order** on the nanosecond count:
    `__eq__` (from `Equatable`'s field-wise default; the single field is the
    count, so no override is needed), `__lt__`/`__le__`/`__gt__`/`__ge__`
    (explicit, no `Comparable` conformance — the frozen conformance set is
    `Equatable` only, and Mojo operators do not require a trait,
    `mojov1/types/operator-support`), and `compare(other) -> Int` returning
    `-1`/`0`/`1` for callers that want a three-way result (the `net_ip`
    `compare` convention).
- **Ownership.** Value type, `ImplicitlyCopyable`; passing and returning by value
  copies the single `Int`, so there is no ownership transfer to reason about
  (`cpp.md` §5; `go.md` §5).
- **Overflow / edge behaviour.** The explicit replacement for
  Go/C/C++'s silent wrap:
  - `__add__`/`__sub__`/`__neg__`/`scaled` check the `Int` result and raise
    `TimeError(OVERFLOW, ...)` instead of wrapping (`go.md` §11).
  - `divided_by(0)` raises `TimeError(DIVISION_BY_ZERO, ...)`; no `Inf`/`NaN`.
  - `divided_by(-1)` of the most-negative span raises `TimeError(OVERFLOW, ...)`:
    the true quotient 2^63 has no `Int` representation, so it is checked exactly
    like the additive cases rather than silently wrapping to `MIN` (the two
    distinct failure modes of `divided_by` are therefore `DIVISION_BY_ZERO` and
    `OVERFLOW`).
  - `abs()` of the most-negative span raises `OVERFLOW` (see above).
  - `from_nanos` cannot overflow; the unit constructors can and raise.
  - A zero span is valid and common (`Duration.ZERO`); `is_zero` is the test.
- **Stream I/O.** EOF/EINTR/EAGAIN/close do not apply: `Duration` is a pure
  in-memory value with no descriptor, no blocking point and no partial progress.
  The expiry analogue lives on `Deadline` (see `## Error Surface`).

Errors: `raises TimeError` — `OVERFLOW` from `from_micros`/`from_millis`/
`from_seconds`/`__add__`/`__sub__`/`__neg__`/`scaled`/`abs` and from
`divided_by` for `MIN / -1`, and `DIVISION_BY_ZERO` from `divided_by(0)`. All are
recoverable data errors: the caller retries with smaller operands, a different
unit, a non-zero divisor, or a divisor other than `-1` for the overflowing case.
No condition is fatal.

Tests:

- `_tests/test_time_duration.mojo`
  - `test_duration_from_units_and_accessors` — `from_seconds(2).as_millis() == 2000`.
  - `test_duration_as_truncates_toward_zero` — `from_nanos(-1).as_seconds() == 0`.
  - `test_duration_sign_predicates` — positive/zero/negative classification.
  - `test_duration_abs` — positive and negative magnitudes.
  - `test_duration_add_sub_negate` — the arithmetic identities.
  - `test_duration_scaled_and_divided_by` — integer scaling and truncation.
  - `test_duration_compare_and_operators` — `-1`/`0`/`1` and all six comparisons.
  - `test_duration_zero_constant` — `Duration.ZERO == from_nanos(0)`.
  - `test_duration_write_to_canonical` — `print` shows the canonical span.
  - `test_duration_value_semantics` — `conforms_to(Duration, Copyable/ImplicitlyCopyable/Equatable)`.
- `_tests/test_time_duration_overflow.mojo`
  - `test_duration_add_overflow_raises` — `MAX + 1ns` → `OVERFLOW`.
  - `test_duration_sub_overflow_raises` — `MIN - 1ns` → `OVERFLOW`.
  - `test_duration_neg_overflow_raises` — `-MIN` → `OVERFLOW`.
  - `test_duration_scaled_overflow_raises` — a huge factor → `OVERFLOW`.
  - `test_duration_from_millis_overflow_raises` — unit scaling → `OVERFLOW`.
  - `test_duration_abs_of_min_raises` — `abs(MIN)` → `OVERFLOW`.
  - `test_duration_divided_by_zero_raises` — divisor `0` → `DIVISION_BY_ZERO`.
  - `test_duration_divided_by_neg_one_min_raises` — `MIN / -1` → `OVERFLOW`.

Implementation status: not implemented

Rationale: MojoAkku uses a **signed integer-nanosecond span** because Go's
`type Duration int64` (`go.md` §3) and Java's "directed duration" that "may be
negative" (`java.md` §10) show signed spans are the natural model for
`remaining = deadline - now`, while Rust's unsigned-only `Duration` has to add
`checked_sub`/`abs_diff` just to express "before" (`rust.md` §11). It is one
`Int`, not Java's seconds+nanos pair, because the two-field encoding of a
negative (`-1 ns` stored as `-1 s + 999,999,999 ns`) is subtly hard to read
(`java.md` §11). `__add__`/`__sub__`/`__neg__`/`scaled` **raise** `OVERFLOW` and
`divided_by` raises `DIVISION_BY_ZERO` for divisor `0` and `OVERFLOW` for
`MIN / -1` because Go wraps silently under
two's-complement rules (`go.md` §11), C has no arithmetic on the value at all
(`c.md` §11), C++ signed overflow is UB (`cpp.md` §11) and Rust's operator forms
panic (`rust.md` §11); a typed `raises` makes the failure visible in the
signature, as C's `EOVERFLOW` and Java's `ArithmeticException` intend
(`c.md` §4; `java.md` §4). Named `scaled`/`divided_by` replace Rust's `Mul<u32>`/
`Div<u32>` operators and its float `mul_f64`/`div_f64` (`rust.md` §3, §11) so the
scalar nature is obvious and no float path exists. The unit constructors follow
Java's `ofMillis`/`ofSeconds` and Rust's `from_millis`/`from_micros` (`java.md`
§3; `rust.md` §3), and the truncating accessors follow Java's `toMillis`/
`toSeconds` and Rust's `as_secs`/`as_millis` (`java.md` §3; `rust.md` §3).
`abs`/sign predicates follow Java's `abs`/`isNegative`/`isPositive`/`isZero`
naming (`java.md` §3, §12). The class of failure is one typed `TimeError` because
this repository already taught a low-vision user the `kind`+`detail` shape in
`io_core`/`prim_bit`.

---

### `Deadline`

Status: planned

Signature:

```mojo
struct Deadline(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var _t: Int

    @doc_hidden
    def __init__(out self, t: Int)

    def __add__(self, rhs: Duration) raises TimeError -> Self
    def __sub__(self, rhs: Duration) raises TimeError -> Self
    def __sub__(self, rhs: Self) raises TimeError -> Duration

    def __lt__(self, other: Self) -> Bool
    def __le__(self, other: Self) -> Bool
    def __gt__(self, other: Self) -> Bool
    def __ge__(self, other: Self) -> Bool
    def compare(self, other: Self) -> Int

    def is_expired(self) -> Bool
    def remaining(self) raises TimeError -> Duration
    def elapsed(self) raises TimeError -> Duration

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions.** A `Deadline` is one opaque `Int` tick. It is
  **never constructed by a caller**: the public producers are `Clock.now()` and
  `Deadline ± Duration`; the raw `__init__` is `@doc_hidden`. There is **no raw
  tick accessor** and no `to_nanos`, so "absolute value is meaningless" is a
  type-level property, not a comment (POSIX: the absolute value of
  `CLOCK_MONOTONIC` "is meaningless", `c.md` §1, §11; Rust's `Instant` is
  "opaque and useful only with `Duration`", `rust.md` §10).
- **Return / meaning.**
  - `deadline + duration` returns a new instant shifted forward; `deadline -
    duration` shifts it backward. Together they are the single canonical timeout
    composition `Clock.now() + timeout` (`go.md` §10, §12).
  - `a - b` returns a **signed `Duration`**: positive when `a` is later, negative
    when `a` is earlier. This is why `Duration` is signed, and why a "swapped
    instants" result is an ordinary negative value rather than a panic or a
    silent zero — explicitly rejecting Rust's saturating `duration_since` that
    "obscures programming errors where earlier and later instants are accidentally
    swapped" (`rust.md` §11).
  - The comparison set is a **total order** on the tick (so `a < b` reads
    naturally); `__eq__` comes from `Equatable`'s field-wise default,
    `__lt__`/`__le__`/`__gt__`/`__ge__` are explicit, and `compare` returns
    `-1`/`0`/`1`. No addition is involved, which is the overflow-safe comparison
    idiom Java documents (`java.md` §8, §12).
  - `is_expired()` is `Clock.now() >= self` — a **total** comparison with no
    arithmetic, so it cannot overflow and never raises. Expiry is a normal
    outcome, not an error (`go.md` §8; `c.md` §8 — the EOF analogue).
  - `remaining()` is `self - Clock.now()`, **signed**: positive while there is
    time left, `ZERO` at the instant, negative once expired.
  - `elapsed()` is `Clock.now() - self`, **signed**: positive once the instant
    has passed, the mirror query (`kotlin.md` §10, `TimeMark.elapsedNow`).
- **Ownership.** Value type, `ImplicitlyCopyable`; copying carries the single
  tick. No handle, no resource (`kotlin.md` §10: `TimeMark` is a value; `cpp.md`
  §5: `time_point` is a value).
- **Overflow / edge behaviour.** `__add__`/`__sub__(Duration)` check the `Int`
  result and raise `TimeError(OVERFLOW, ...)`. `__sub__(Deadline)` and the
  `remaining()`/`elapsed()` pair can only overflow at the extreme of the `Int`
  range, where they raise the same `OVERFLOW` rather than wrap. A deadline in the
  past is normal and is signalled by `is_expired()`/negative `remaining()`, never
  by an error. There is no "already expired" exception (contrast Go's
  `DeadlineExceeded` sentinel, `go.md` §4, which is the caller's business, not the
  value's).
- **Stream I/O.** EOF/EINTR/EAGAIN/close do not apply: a `Deadline` is a value
  and blocks nothing. The three queries are pure and read `Clock.now()`; they do
  not retain or cache it. **The expiry analogue is here**: `is_expired()` is the
  explicit "the wait is over" outcome that replaces EOF in this domain (see
  `## Error Surface`).

Errors: `raises TimeError` — `OVERFLOW` from `__add__`/`__sub__` and, only at the
`Int` extreme, from `remaining()`/`elapsed()`. All recoverable (clamp the
duration / choose a nearer deadline). `is_expired()` and the comparison set never
raise.

Tests:

- `_tests/test_time_deadline.mojo`
  - `test_deadline_add_and_sub_duration` — shift forward and backward.
  - `test_deadline_sub_deadline_is_signed` — later `-` earlier is positive, and
    the reverse is negative.
  - `test_deadline_compare_and_operators` — `-1`/`0`/`1` and all six comparisons.
  - `test_deadline_is_expired_past_and_future` — past `True`, future `False`.
  - `test_deadline_remaining_positive_then_negative` — signed `remaining`.
  - `test_deadline_elapsed_negative_then_positive` — signed `elapsed`.
  - `test_deadline_no_raw_accessor` — no method returns the tick (a `conforms_to`
    / surface check, expressed as a compile-time test).
  - `test_deadline_add_overflow_raises` — `MAX +` a span → `OVERFLOW`.
  - `test_deadline_value_semantics` — `conforms_to(Deadline, Copyable/ImplicitlyCopyable/Equatable)`.
  - `test_deadline_write_to_canonical` — `print` shows the canonical form.

Implementation status: not implemented

Rationale: MojoAkku uses an **opaque instant over one `Int`** because Rust's
`Instant` is "opaque and useful only with `Duration`" with no raw accessor
(`rust.md` §10) and POSIX warns that the absolute value of `CLOCK_MONOTONIC` "is
meaningless" (`c.md` §11), so exposing a raw tick would invite exactly the misuse
C recommends against. `Deadline ± Duration` and `Deadline - Deadline -> Duration`
mirror C++ `time_point` and Rust `Instant` (`cpp.md` §12; `rust.md` §12), and the
"timeout = deadline = now + duration" composition is Go's single canonical
primitive (`go.md` §10, §12). The signed difference deliberately rejects Rust's
saturating `duration_since`, which the Rust docs admit "obscures programming
errors" (`rust.md` §11). Comparisons use no addition, following Java's
documented overflow-safe `nanoTime()` comparison idiom (`java.md` §8, §12).
`is_expired`/`remaining`/`elapsed` are the two queries Kotlin's
`TimeMark.elapsedNow` plus a deadline provide (`kotlin.md` §10, §12). Overflow
raises because Go's raw `nanoTime` deadlines "will not correctly compute elapsed
time due to numerical overflow" and push the guard onto the caller (`java.md`
§11); the typed `Deadline` makes the safe path the only path.

---

### `Clock`

Status: planned

Signature:

```mojo
struct Clock:
    @staticmethod
    def now() -> Deadline
```

Semantics:

- **Parameters / preconditions.** None. `Clock` is a stateless namespace: it has
  no fields, is never constructed, and exposes exactly one method. It is the
  **only** clock entry point in the library — there is no clock-id argument, no
  template clock and no second (wall) clock (`cpp.md` §12; `go.md` §12).
- **Return / meaning.** `now()` returns a `Deadline` wrapping the current
  `std.time.monotonic()` reading. The contract, stated exactly once:
  - the clock is **monotonic**: it does not move backwards;
  - its **origin is undefined** and platform-specific — a raw value is not a
    date, not an epoch offset, and not comparable across processes or boots;
  - only the **difference** of two readings (a `Duration`) is valid.
  This is the documented Python `time.monotonic` contract ("The reference point
  of the returned value is undefined, so that only the difference between the
  results of two calls is valid", `python.md` §1, §10) and the Mojo
  `std.time.monotonic`/`perf_counter_ns` contract ("the reference point … is
  undefined", `mojov1/stdlib/time`).
- **Ownership.** Static; returns a `Deadline` by value. `Clock` itself holds
  nothing and can be abandoned trivially.
- **Overflow / edge behaviour.** None: reading a monotonic register cannot fail
  and produces an `Int` that fits by definition. `now()` never raises and never
  blocks. Two calls are non-decreasing.
- **Stream I/O.** EOF/EINTR/EAGAIN/close do not apply: `now()` does not block and
  reads no descriptor (`c.md` §6). A future `sleep(Duration)` would be the
  blocking call and is deferred (`_dev/TODO.md`).

Errors: none — `std.time.monotonic()` returns an `Int` directly and never
raises.

Tests:

- `_tests/test_time_clock.mojo`
  - `test_clock_now_is_deadline` — `now()` yields a `Deadline`.
  - `test_clock_now_non_decreasing` — two calls do not move backwards
    (`now2 - now1 >= ZERO`).
  - `test_clock_now_advances_after_work` — a busy loop produces `elapsed() > 0`
    (bounded, non-flaky assertion).
  - `test_clock_now_difference_is_duration` — `now() - now()` is a `Duration`.

Implementation status: not implemented

Rationale: MojoAkku uses a **single static `Clock.now()`** because C++
`steady_clock` exposes only `now()` and `cpp.md` §12 recommends one concrete
monotonic clock over a template/clock-id parameter, while Go's model shows that
"timeout = deadline" needs exactly one clock (`go.md` §12). It is a static method
on a stateless type rather than a free function so the name reads as
"the clock" and so an injectable `TestClock` can later be added without changing
`Clock.now()` callers (`kotlin.md` §12 — deferred in `_dev/TODO.md`). The backing
call is `std.time.monotonic()` (`mojov1/stdlib/time`), whose undefined-origin
contract is copied verbatim; `perf_counter_ns` is deliberately not exposed
because its only documented difference (including sleep time) is irrelevant to a
non-blocking read and would reintroduce Python's two-parallel-clock confusion
(`python.md` §11).

---

### `TimeErrorKind`

Status: planned

Signature:

```mojo
struct TimeErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    # Explicit override of Equatable's field-wise default: compares the
    # discriminant `_id` only (see Semantics).
    def __eq__(self, other: Self) -> Bool

    comptime OVERFLOW         = TimeErrorKind(0)
    comptime DIVISION_BY_ZERO = TimeErrorKind(1)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions.** Read from `TimeError.kind`; never passed by a
  caller to a time operation. The type is **opaque**: the two `comptime` members
  are the complete public set; `_id` and its `@doc_hidden` initializer are
  implementation details (Mojo has no access control — `mojov1/decorators/doc-hidden`).
  `__eq__` is written explicitly as an intentional override mirroring the
  `IoErrorKind`/`BitErrorKind` pattern (`mojov1/types/operator-support`,
  `mojov1/idioms/patterns`); `err.kind == TimeErrorKind.OVERFLOW` works.
- **Return / meaning.** The machine-testable reason a time operation failed:
  - `OVERFLOW` — an arithmetic result or a unit scaling does not fit the `Int`
    carrier. Maps to C's `EOVERFLOW` (`c.md` §4) and Java's
    `ArithmeticException`-on-overflow (`java.md` §4) as a value.
  - `DIVISION_BY_ZERO` — `divided_by(0)` was requested. Kept distinct from
    `OVERFLOW` because it is a different caller mistake with a different fix, the
    way Java separates the zero-divisor case from numeric overflow in
    `Duration.dividedBy` (`java.md` §4).
  The two values are the **complete** set of ways any release-1 operation can
  fail. A future parse/format or wall-clock layer can add members additively.
- **Ownership.** Value type; `comptime` constants copied into the error value.
- **Overflow / edge behaviour.** Not applicable: a `TimeErrorKind` is a
  two-valued discriminant holding a `UInt8`, so constructing one and comparing
  two of them cannot overflow, wrap or fail. The overflow *condition* it labels
  lives in the arithmetic that raises `TimeError`, never in the kind itself.
- **Stream I/O.** Not applicable.

Errors: none — it is a discriminant, not an operation.

Tests:

- `_tests/test_time_error.mojo`
  - `test_error_kind_members_distinct` — the two members differ and each equals
    itself.
  - `test_error_kind_eq` — `==` compares the discriminant only.
  - `test_error_kind_writable` — `write_to` prints `OVERFLOW` and
    `DIVISION_BY_ZERO`, never the number.

Implementation status: not implemented

Rationale: MojoAkku uses a **closed `UInt8`-tagged discriminant** because this
repository already taught a low-vision user one error shape in `io_core`
(`IoError`/`IoErrorKind`) and `prim_bit` (`BitError`/`BitErrorKind`), and a small
closed set is enough for a value library. `OVERFLOW` and `DIVISION_BY_ZERO` are
kept separate because they are different caller mistakes, following Java's
distinct zero-divisor condition (`java.md` §4); Rust's `checked_*` returning
`None` is not copied as the primary surface because it discards the reason
(`rust.md` §4, §11). A dedicated `UNREPRESENTABLE`/`PLATFORM` kind is
deliberately not added; the set stays closed and small, and a new member is
additive when a need is proven.

---

### `TimeError`

Status: planned

Signature:

```mojo
@fieldwise_init
struct TimeError(Copyable, Deinitable, Writable):
    var kind: TimeErrorKind
    var detail: String

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions.** Constructed by the library on failure; callers
  read the two fields in an `except`/`try` block. `kind` is the closed
  discriminant (see `TimeErrorKind`). `detail` is an opaque, human-readable
  string naming the failing operation and the operands (for example
  `"Duration.__add__ overflow"`); it must **not** be parsed, because it is not
  part of the API surface. Unlike `io_core`'s `IoError` there is no separate `op`
  field: the domain has only five fallible operations and the operation name
  lives in `detail`, which keeps the error to the two fields the frozen scope
  names.
- **Return / meaning.** The single typed error every fallible time operation
  declares via `raises TimeError`. There is no "no duration" and no EOF, so the
  error never means "the value is absent" — absence is impossible in this domain
  (`## Error Surface`).
- **Ownership.** Value type; `Copyable` and `Deinitable`, so it can be bound and
  inspected. It is deliberately **not** `ImplicitlyCopyable`, so a re-raise must
  transfer with `raise e^` (`mojov1/errors/raising-and-propagation`; the
  `IoError`/`BitError` convention).
- **Overflow / edge behaviour.** Constructing a `TimeError` cannot fail. The
  arithmetic that raises it is fully described per entry.
- **Stream I/O.** EOF/EINTR/EAGAIN/close do not apply: a value error carries no
  descriptor.

Errors: it **is** the error. Every condition is a recoverable data error: retry
with smaller operands, a different unit, or a non-zero divisor. Nothing is fatal
and nothing aborts.

Tests:

- `_tests/test_time_error.mojo`
  - `test_error_fields_kind_detail` — the two fields are readable in a `try`/`except`.
  - `test_error_write_to_includes_kind_and_detail` — `print(e)` names the kind.
  - `test_error_copyable_and_deinitable` — `copy()` works; `conforms_to` holds.
  - `test_error_not_implicitly_copyable` — a re-raise must transfer with `raise e^`.
  - `test_error_reraise_transfer` — a caught error re-raises with `^`.

Implementation status: not implemented

Rationale: MojoAkku uses a struct with **`kind` + `detail`** because Rust funnels
fallible arithmetic through one error shape and carries context
(`rust.md` §4), Java's unchecked `ArithmeticException` on every `plus` is the
rejected form (`java.md` §11), and MojoAkku's own `io_core`/`prim_bit` established
the typed-error-with-closed-kind pattern this library copies. Two fields rather
than `io_core`'s three is deliberate: the frozen scope names exactly `kind` and
`detail`, and the operation name is not worth a third public field for five
operations. `TimeError` is not `ImplicitlyCopyable` so re-raising is an explicit
transfer, the convention this repository already uses (`IoError`, `BitError`).
