# time_clock research: cpp

## 1. Standard library support

`<chrono>` (since C++11) is the model everyone else in the systems world
copies. It has three parts, all in `namespace std::chrono`:

- **Clocks**: `system_clock` (wall), `steady_clock` (monotonic, "will never be
  adjusted"), `high_resolution_clock`.
  Source: https://en.cppreference.com/w/cpp/chrono (Clocks section).
- **`time_point<Clock, Duration>`**: "a duration of time that has passed since
  the epoch of a specific clock"; it stores a `Duration` internally.
  Source: https://en.cppreference.com/w/cpp/chrono/time_point .
- **`duration<Rep, Period>`** with `Period = std::ratio<...>`: "a count of
  ticks of type `Rep` and a tick period … a compile-time rational fraction
  representing the time in seconds from one tick to the next".
  Source: https://en.cppreference.com/w/cpp/chrono/duration .
- Predefined durations: `nanoseconds`, `microseconds` (int55), `milliseconds`
  (int45), `seconds` (int35), `minutes` (int29), `hours` (int23); C++20 adds
  `days`, `weeks`, `months`, `years`. Each up to `hours` covers at least
  ±292 years. Source: same duration page, Helper types.
- `steady_clock` "represents a monotonic clock. The time points of this clock
  cannot decrease … the time between ticks … is constant", with `is_steady`
  always `true`. Source: https://en.cppreference.com/w/cpp/chrono/steady_clock .

## 2. Relevant community libraries

- **Howard Hinnant's `date` library** — the reference implementation that
  C++20's `<chrono>` calendars/time zones were based on.
  `GUESS:` maintainer/license details not fetched this pass.
- **`absl::Time`** (Abseil) — `absl::Now()`, `absl::Duration`,
  `absl::Time`; Google. `GUESS:` API names from general knowledge, not fetched.
- **Boost.Chrono** — predates `std::chrono`, now mostly superseded.
  `GUESS:` not fetched.
- No further community library is needed in the systems-modern sense; the
  stdlib is the de-facto design reference. `GUESS:` assessment.

## 3. Exposed APIs

- `duration`: `count()`, `zero()`, `min()`, `max()`, unary `+`/`-`, `++`/`--`,
  compound `+=`/`-=`/`*=`/`/=`/`%=`. Source: duration page, Member functions.
- Non-member `+ - * / %`, full comparison set, `duration_cast`, and C++17
  `floor`/`ceil`/`round`/`abs`. Source: duration page, Non-member functions.
- `time_point`: `time_since_epoch()`, `operator+=`/`-=`, `min()`/`max()`,
  non-member `+`/`-` (time_point ± duration), full comparison, `time_point_cast`.
  Source: time_point page, Member functions / Non-member functions.
- `steady_clock::now()` returns `time_point<steady_clock>`.
  Source: steady_clock page, Member functions.
- Literals (C++14): `h`, `min`, `s`, `ms`, `us`, `ns` in
  `std::literals::chrono_literals`. Source: duration page, Literals.
- `duration_cast<ToDuration>(d)` performs an explicit tick-period conversion;
  implicit conversion is allowed only when it is lossless.
  Source: duration page, Non-member functions + Notes.
- `(end - start) / 1ms` is a documented way to get the unit count.
  Source: time_point page, Example.

## 4. Error representation

- The core types do **not** raise. Arithmetic on `duration`/`time_point` is
  plain integer (or floating) arithmetic with **no overflow checking**, so
  signed overflow is UB; the caller must bound values. `GUESS:` exact
  UB statement from the C++ core-language rule, not fetched on the chrono page.
- `time_point_cast` / `duration_cast` are lossy by design and never report it.
  Source: duration page (conversion requires a cast when precision is lost).
- The C++20 calendar/time-zone layer introduces exceptions
  (`nonexistent_local_time`, `ambiguous_local_time`), but those are outside a
  clock/duration/instant library. Source: https://en.cppreference.com/w/cpp/chrono
  (Calendar / Time zone sections list the two exception classes).

## 5. Ownership semantics

- `duration` and `time_point` are **value types**: "The only data stored in a
  `duration` is a tick count of type `Rep`"; `time_point` stores a `Duration`.
  Sources: duration page CLASS TEMPLATE intro; time_point page intro.
- Both are copyable and movable; there is no handle, no heap, no free. They
  are trivially usable as function arguments and return values by value.
  `GUESS:` trivial-copyability is a consequence of the stored scalar, not
  fetched as an explicit sentence.

## 6. Blocking / non-blocking

- `std::chrono` itself never blocks; it only reads clocks and computes values.
  Source: the chrono, duration, steady_clock pages describe only value
  operations and `now()`.
- Sleeping/timeout blocking lives in `<thread>` (`std::this_thread::sleep_for`,
  `sleep_until`) and in timed waits such as
  `std::condition_variable::wait_for` / `wait_until` and
  `std::future::wait_for`. `GUESS:` these exact names from general knowledge;
  not fetched on the pages above.

## 7. IPv4 / IPv6

Not applicable to a time library; durations and instants are address-family
agnostic.

## 8. Timeouts

- Timeouts are expressed as a `duration` (relative) or a `time_point`
  (absolute). The two are distinct static types, so "relative vs absolute" is
  encoded in the type system rather than a flag. `GUESS:` this characterisation
  follows from the two types existing; no single sentence states it.
- `wait_for(duration)` vs `wait_until(time_point)` is the common library shape
  for this split. `GUESS:` API names not fetched this pass.
- Clock differences: `time_point`s from different clocks are **not comparable**
  (the time_point example prints "Different clocks are not comparable").
  Source: time_point page, Example.
- Overflow is possible; `duration::max()`/`min()` are the representable bounds.
  Source: duration page, Member functions.

## 9. TLS

Not applicable to a time library; there is no transport to secure.

## 10. Interesting design decisions

- **Tick period in the type.** `duration<Rep, Period>` makes unit conversion a
  compile-time concern (`duration_cast`, `common_type`), so
  `milliseconds(1s)` works without runtime scaling. Source: duration page,
  CLASS TEMPLATE + Helper classes.
- **time_point carries its clock in the type**, which statically prevents
  comparing times from different clocks. Source: time_point page, Member types
  (`Clock clock`) and Example.
- **Separate monotonic clock type** (`steady_clock`) rather than a flag or
  clock-id argument. Source: steady_clock page.
- **Checked-free arithmetic for speed**: `min()`/`max()` expose the bounds but
  operators do not check. Source: duration page, Member functions.
- **`time_since_epoch()` is the only escape hatch** from an opaque time_point;
  raw comparison across clocks is not offered. Source: time_point page.

## 11. Decisions NOT to copy

- **No overflow-checked arithmetic** on duration/time_point: C++ signed
  overflow is UB. Mojo should default to checked or saturating, matching
  Rust's `checked_*`/`saturating_*` split.
- **Unchecked implicit vs explicit conversion subtlety** (`duration_cast`
  required only when lossy) is powerful but subtle; a Mojo API should keep
  conversion explicit and obvious. (Source: duration page conversion rules.)
- **Clock as a template parameter** forces `time_point<Clock,Duration>` into
  every signature; for a single monotonic `Clock` a concrete type is simpler
  and reads better. (Source: time_point page, CLASS TEMPLATE.)
- **Float `Rep` in the same type family** allows silent precision loss
  (`duration<double>`); a monotonic deadline should stay integer-nanosecond to
  avoid floating-point drift. `GUESS:` precision concern inferred, not quoted.
- **`high_resolution_clock` is an alias** that may equal either
  `system_clock` or `steady_clock`, which makes it unsuitable as a guaranteed
  monotonic source. `GUESS:` alias behaviour from general knowledge; the
  cppreference page says only "the clock with the shortest tick period".

## 12. Ideas fitting Mojo

- **`Duration` (signed span) + `Deadline` (opaque instant on a monotonic
  clock)**, mirroring `duration` + `time_point`, with `Deadline = Clock.now() + d`
  and `remaining = deadline - Clock.now()`. (Source: time_point page.)
- **Checked/saturating add, sub, mul, div, negate** as explicit methods, since
  C++ leaves overflow unchecked. (Contrast: duration page has no checked ops.)
- **`now()` as the only clock entry point** on a single concrete monotonic
  clock; no clock-id parameter and no template clock. (Contrast: steady_clock
  page exposes `now()` only.)
- **Comparison and subtraction only on the same clock**, enforced by the type
  rather than by a runtime check. (Source: time_point Example.)
- **Unit constructors and `count`/`as_*` accessors** so users never touch raw
  ticks: `Duration.from_millis(...)`, `.as_millis()`. (Source: duration page,
  Helper types / `count`.)
- **`raises` for representability failures** where C++ has UB; a typed error
  is strictly safer. (Contrast: duration page shows no error surface.)

## Sources

- Chrono library overview: https://en.cppreference.com/w/cpp/chrono
- `std::chrono::duration`: https://en.cppreference.com/w/cpp/chrono/duration
- `std::chrono::time_point`: https://en.cppreference.com/w/cpp/chrono/time_point
- `std::chrono::steady_clock`:
  https://en.cppreference.com/w/cpp/chrono/steady_clock
