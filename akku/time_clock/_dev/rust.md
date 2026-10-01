# time_clock research: rust

## 1. Standard library support

`std::time` (module doc: "Temporal quantification"):

- `Duration` — "A `Duration` type to represent a span of time, typically used
  for system timeouts." Each is "a whole number of seconds and a fractional
  part represented in nanoseconds". Source:
  https://doc.rust-lang.org/std/time/struct.Duration.html .
- `Instant` — "A measurement of a monotonically nondecreasing clock. Opaque
  and useful only with `Duration`." Source:
  https://doc.rust-lang.org/std/time/struct.Instant.html .
- `SystemTime` — "A measurement of the system clock"; `SystemTimeError`,
  `TryFromFloatSecsError`, and the `UNIX_EPOCH` constant complete the module.
  Source: https://doc.rust-lang.org/std/time/index.html .
- `Duration` is **unsigned** (stored as `u64` seconds + `u32` nanos); negative
  spans are represented by `checked_sub` returning `None` or by signed
  arithmetic elsewhere. Source: struct.Duration `pub struct Duration { /* private
  fields */ }` and `checked_sub` docs.

## 2. Relevant community libraries

- **`tokio::time`** — async `sleep`, `Timeout`, `Instant`, `interval`; the
  de-facto async timer. `GUESS:` not fetched this pass.
- **`futures-timer`** — runtime-agnostic timer. `GUESS:` not fetched.
- **`humantime`** — human-readable duration parsing/formatting. `GUESS:` not
  fetched.
- The stdlib split (Duration/Instant/SystemTime + checked/saturating methods)
  is mature enough that community crates mostly add async or formatting.
  `GUESS:` assessment.

## 3. Exposed APIs

`Duration` (exact names from docs.rs):

- Constants: `ZERO` and `MAX` are stable; `SECOND`/`MILLISECOND`/`MICROSECOND`/
  `NANOSECOND` are still **nightly-only** under the `duration_constants`
  feature (tracking issue #57391) as of the cited page. `MAX` is
  `Duration::new(u64::MAX, 999_999_999)` and "about 584,942,417,355 years".
  Source: https://doc.rust-lang.org/std/time/struct.Duration.html
  (each constant's stability note).
- Constructors: `new(secs: u64, nanos: u32)`, `from_secs`, `from_millis`,
  `from_micros`, `from_nanos`, `from_nanos_u128`, `from_secs_f64`,
  `from_secs_f32`, plus nightly `from_weeks`/`from_days`, stable
  `from_hours`/`from_mins` (1.91).
- Accessors: `as_secs() -> u64`, `as_millis()/as_micros()/as_nanos() -> u128`,
  `as_secs_f64/f32`, `subsec_millis/micros/nanos()`.
- Arithmetic: `Add`, `Sub`, `AddAssign`, `SubAssign`, `Mul<u32>`,
  `Div<u32>`, `MulAssign`, `DivAssign`, `Sum`; `checked_add`, `checked_sub`,
  `checked_mul`, `checked_div`, `saturating_add`, `saturating_sub`,
  `saturating_mul`, `abs_diff`.
- `Mul`/`Div` by scalar only support `u32` — "no multiply/divide by f64
  operators"; float scaling is via `mul_f64`, `div_f64`, `mul_f32`, `div_f32`.
- Comparison: `PartialEq`, `Eq`, `PartialOrd`, `Ord`, `Hash`, `Copy`, `Clone`,
  `Default` (zero). Source: struct.Duration page, Trait Implementations.

`Instant`:

- `Instant::now()`, `duration_since(earlier) -> Duration`,
  `checked_duration_since(earlier) -> Option<Duration>`,
  `saturating_duration_since(earlier) -> Duration`, `elapsed() -> Duration`,
  `checked_add(Duration) -> Option<Instant>`, `checked_sub(Duration) ->
  Option<Instant>`. Source: struct.Instant page.
- `Add<Duration>`, `Sub<Duration>`, `Sub<Instant> -> Duration`, `Copy`,
  `Ord`, `Hash`. Source: struct.Instant page, Trait Implementations.

## 4. Error representation

- `Duration` construction from floats panics: `from_secs_f64`/`from_secs_f32`
  "will panic if `secs` is negative, overflows `Duration` or not finite";
  `try_from_secs_f64`/`try_from_secs_f32` are the non-panicking variants.
  Source: struct.Duration page.
- Arithmetic that can overflow: `Add`/`Sub`/`Mul` **panic** in debug or wrap;
  the `checked_*` methods return `Option<Duration>` (`None` on overflow;
  `checked_sub` also `None` when the result would be negative).
  Source: struct.Duration page (`checked_add`, `checked_sub`, `checked_mul`,
  `checked_div`, `saturating_*`).
- `SystemTime`'s `duration_since`/`elapsed` return `SystemTimeError`, "used to
  learn how far in the opposite direction a system time lies".
  Source: https://doc.rust-lang.org/std/time/index.html .
- `Instant` does **not** error on wrong-order subtraction: `duration_since`
  "saturates" to zero and `checked_duration_since` returns `None`; the docs
  note "future Rust versions may reintroduce panics".
  Source: struct.Instant page, Monotonicity.

## 5. Ownership semantics

- `Duration` and `Instant` are `Copy` value types; passing and returning by
  value is idiomatic. Source: struct.Duration / struct.Instant Trait
  Implementations (`Copy`, `Clone`).
- `Instant` is opaque ("Opaque and useful only with `Duration`") — there is
  **no** method to read raw seconds; only compare and subtract.
  Source: struct.Instant page description.
- `GUESS:` no heap, no handle, no free — a consequence of the types being
  `Copy` scalars; not stated as such on the cited page.

## 6. Blocking / non-blocking

- `std::thread::sleep(Duration)` blocks the thread; docs use
  `use std::thread::sleep;`.
  Source: struct.Instant example in https://doc.rust-lang.org/std/time/index.html .
- Async sleeping is not in std; `tokio::time::sleep` and friends provide it.
  `GUESS:` not fetched this pass.
- `Instant` itself never blocks.

## 7. IPv4 / IPv6

Not applicable to a time library; instants and durations carry no address
family.

## 8. Timeouts

- A timeout is a `Duration`; an absolute deadline is `Instant + Duration`
  (via `Add<Duration>` or `checked_add`). `Instant::checked_add` is the
  non-panicking form. Source: struct.Instant page.
- The canonical wait loop measures `now.elapsed() >= timeout` or
  `Instant::now() + timeout` and compares. Source: struct.Instant example
  ("Instant::now()", "elapsed()").
- Cross-platform caution: adding a very large `Duration` to `Instant` "may
  panic if the underlying structure cannot represent the new point in time",
  and behaviour is OS-specific (the solar-10-millennia example "is fine on
  Linux but panics on macOS"). Source: struct.Instant page, "OS-specific
  behaviors".
- Rust docs advise "durations of up to around one hundred years" for
  cross-platform code. Source: struct.Instant page.

## 9. TLS

Not applicable to a time library; no transport, no TLS.

## 10. Interesting design decisions

- **Unsigned `Duration` + explicit checked/saturating family.** No negative
  durations; the "went backwards" case is modelled as `None`/zero, giving a
  precise, panic-free option. Source: struct.Duration page.
- **Opaque `Instant`** forces all use through `Duration`; raw ticks are not
  exposed. Source: struct.Instant page.
- **Saturating on monotonicity violation** rather than panicking: `elapsed`,
  `duration_since`, and `Sub` saturate to zero "to work around … bugs and
  platforms not offering monotonic clocks". Source: struct.Instant page,
  Monotonicity.
- **Three clocks, three types**: `Instant` (monotonic), `SystemTime` (wall),
  `Duration` (span). Source: index page.
- **`Duration::MAX` is defined to contain the difference between two
  `Instant`s/`SystemTime`s** — a deliberate, documented bound.
  Source: struct.Duration page.
- **`abs_diff`** gives a non-panicking absolute difference.
  Source: struct.Duration page.

## 11. Decisions NOT to copy

- **Panic-on-overflow for `Add`/`Sub`/`Mul`/float constructors.** A Mojo API
  should make the failure explicit (`raises`) or always saturate; hidden panic
  is worse for a low-level timing primitive. Source: struct.Duration page.
- **Unsigned-only `Duration`.** A signed span is more natural for
  `remaining = deadline - now` and for representing elapsed-time deficits;
  Rust then needs `checked_sub`/`abs_diff` to express "before". The Mojo
  scope explicitly wants signed arithmetic. Source: struct.Duration page.
- **Platform-dependent `Instant` range.** The macOS/Linux divergence for large
  additions is a portability trap; Mojo should define its representable range
  once. Source: struct.Instant page, OS-specific behaviors.
- **`duration_since` silently saturating** "obscures programming errors where
  earlier and later instants are accidentally swapped" (the docs say so
  themselves) — better to offer an explicit checked form and make saturation
  opt-in. Source: struct.Instant page, Monotonicity.
- **Float scaling methods** (`mul_f64`, `div_f64`) as part of the core type;
  keep them out of a nanosecond-integer deadline API. Source: struct.Duration
  page.

## 12. Ideas fitting Mojo

- **Signed `Duration` with add/sub/mul/div/negate/compare** plus a
  checked/saturating variant for each fallible op, echoing Rust's method
  naming (`saturating_add`, `checked_sub`) which reads predictably.
- **Opaque `Deadline`/`Instant`**: only `now`, `+ Duration`, `- Duration`,
  `- Instant`, and comparisons. (Source: struct.Instant page.)
- **`checked_add`/`checked_sub` on the instant** for representability, so the
  caller never hits UB. (Source: struct.Instant page.)
- **`Duration::MAX`-style documented bound** and a `ZERO` constant.
  (Source: struct.Duration page.)
- **`raises` instead of panic** for float→duration or out-of-range
  construction, with a non-raising checked variant. (Source: struct.Duration
  `try_from_secs_f64`.)
- **Value semantics / `Copy`** for both types. (Source: Trait Implementations.)

## Sources

- `std::time` module: https://doc.rust-lang.org/std/time/index.html
- `std::time::Duration`: https://doc.rust-lang.org/std/time/struct.Duration.html
- `std::time::Instant`: https://doc.rust-lang.org/std/time/struct.Instant.html
