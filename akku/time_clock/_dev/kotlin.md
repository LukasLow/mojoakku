# time_clock research: kotlin

## 1. Standard library support

`kotlin.time` (stdlib) is "API for measuring time intervals and calculating
durations" (https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/).

- `value class Duration` — "Represents the amount of time one instant of time is
  away from another instant." "can store duration values up to ±146 years with
  nanosecond precision, and up to ±146 million years with millisecond precision.
  If a duration-returning operation … produces a duration value that doesn't fit
  into the above range, the returned `Duration` is **infinite**."
  Source: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/-duration/ .
- `TimeSource` and `TimeMark` — "A source of time for measuring time intervals"
  and "a time point notched on a particular `TimeSource` … bound to the time
  source it was taken from"; `TimeSource.Monotonic` is the standard monotonic
  source. Source: kotlin.time package page.
- `ComparableTimeMark` — a `TimeMark` "that can be compared for difference with
  other time marks obtained from the same `TimeSource.WithComparableMarks`".
  Source: kotlin.time package page.
- `DurationUnit` enum; `Clock` (interface) and `Instant` (class) are documented
  **"Since Kotlin 2.3"** — "A source of `Instant` values" / "A moment in time".
  Sources: kotlin.time package page;
  https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/-instant/ ("Since
  Kotlin 2.3").
- `TestTimeSource` — "A time source that has programmatically updatable
  readings. It is useful as a predictable source of time in tests."
  Source: kotlin.time package page.

## 2. Relevant community libraries

- **`kotlinx-datetime`** — date/time on top of `kotlin.time`; "Date and time"
  in the Kotlin API docs index. `GUESS:` not fetched.
- **`kotlinx-coroutines`** `delay(Duration)` and `withTimeout(Duration)` — the
  async timeout primitives built on `kotlin.time.Duration`.
  `GUESS:` not fetched this pass.
- No separate third-party duration library is needed; the stdlib is complete.
  `GUESS:` assessment.

## 3. Exposed APIs

`Duration` (exact names):

- Properties: `absoluteValue`, `inWholeDays`, `inWholeHours`,
  `inWholeMinutes`, `inWholeSeconds`, `inWholeMicroseconds`,
  `inWholeMilliseconds`, `inWholeNanoseconds` (all `Long`).
- Operators: `plus(Duration)`, `minus(Duration)`, `times(Double|Int)`,
  `div(Double|Int)`, `div(Duration) -> Double`, `unaryMinus()`,
  `compareTo(Duration)`.
- Predicates: `isFinite()`, `isInfinite()`, `isNegative()`, `isPositive()`.
- Conversions: `toDouble(unit)`, `toInt(unit)`, `toLong(unit)`,
  `toIsoString()`, `toString(unit, decimals)`, `toComponents { … }`,
  `toJavaDuration()` (JVM).
- Companions/constants: `Duration.INFINITE` ("can be used to represent infinite
  timeouts"), `Duration.ZERO`. `GUESS:` `ZERO` from general knowledge; the page
  states `INFINITE`.
- Construction: `toDuration(unit)` on `Int`/`Long`/`Double`, and the extension
  properties `hours`, `minutes`, `seconds`, etc.
  Source: https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/-duration/ .

`TimeSource`/`TimeMark`:

- `TimeSource.markNow() -> TimeMark`, `TimeMark.elapsedNow() -> Duration`,
  `measureTime { }`, `measureTimedValue { }`, `TimeSource.asClock(origin)`.
  Source: kotlin.time package page.

## 4. Error representation

- Kotlin does **not** throw on duration overflow: "If a duration-returning
  operation … doesn't fit into the above range, the returned `Duration` is
  infinite." Source: Duration page.
- `isFinite()`/`isInfinite()` are the intended checks; `INFINITE` is a legal
  value, not an error. Source: Duration page.
- `toInt`/`toLong` conversions on an out-of-range duration clamp (like Kotlin
  numeric conversions). `GUESS:` general Kotlin conversion semantics, not
  fetched on this page.
- The `@ExperimentalTime` opt-in annotation gates the API for older versions.
  Source: kotlin.time package page.

## 5. Ownership semantics

- `Duration` is a `@JvmInline value class` — on the JVM it erases to the
  underlying scalar, so it is a zero-overhead value with no identity.
  Source: Duration page (`@JvmInline value class Duration`).
- `TimeMark` is bound to its `TimeSource`; comparing marks from different
  sources is not supported by `ComparableTimeMark` (only marks from the same
  `TimeSource.WithComparableMarks`). Source: kotlin.time package page.
- `GUESS:` no handles, no manual free; JVM GC manages lifetime (general
  Kotlin/JVM semantics, not a sentence on the cited pages).

## 6. Blocking / non-blocking

- `kotlin.time` itself never blocks; it only reads marks and computes durations.
  `measureTime { }` measures an elapsed interval around a block.
  Source: kotlin.time package page.
- Blocking: `Thread.sleep(Duration)` on the JVM. `GUESS:` from general
  knowledge.
- Async: `kotlinx.coroutines.delay(Duration)` / `withTimeout(Duration)`.
  `GUESS:` not fetched.

## 7. IPv4 / IPv6

Not applicable to a time library; durations and time marks carry no address
family.

## 8. Timeouts

- A timeout is a `Duration`; `Duration.INFINITE` "can be used to represent
  infinite timeouts". Source: Duration page.
- An elapsed measurement is `start.elapsedNow()` on a `TimeMark`; a deadline is
  `start + timeout`. Source: kotlin.time package page (`TimeMark.elapsedNow`).
- `TestTimeSource` allows deterministic timeout tests by advancing time
  manually. Source: kotlin.time package page.
- Coroutine timeouts use `withTimeout(Duration)`. `GUESS:` not fetched.

## 9. TLS

Not applicable to a time library; no transport, no TLS.

## 10. Interesting design decisions

- **`INFINITE` as a first-class duration value** removes a whole class of
  "no timeout" special-casing (`isInfinite()` check). Source: Duration page.
- **Range stated in two precisions**: ±146 years at nanosecond precision,
  ±146 million years at millisecond precision — overflow degrades to infinity
  rather than wrapping. Source: Duration page.
- **`TimeMark` is bound to a source**, and comparability is a separate
  capability (`ComparableTimeMark`), so mixing sources is a type error, not a
  runtime surprise. Source: kotlin.time package page.
- **`TestTimeSource` is in the stdlib**, making time injectable without a
  third-party mocking library. Source: kotlin.time package page.
- **`value class`** gives type safety with no allocation. Source: Duration page.
- **`measureTime`/`measureTimedValue`** as inline helpers return the duration
  (and optionally a value), so timing is not ad-hoc. Source: package page.

## 11. Decisions NOT to copy

- **Infinite-on-overflow** conflates "very large" with "no timeout"; a Mojo
  library that needs a sentinel for "no timeout" should make it an explicit
  option/deadline state, not a magic infinite duration. Source: Duration page.
- **Unit conversion extension properties on `Long`/`Double`** pollutes the
  numeric type's API; a Mojo `Duration` should keep constructors on the
  duration type. Source: Duration page (construction via `toDuration` /
  `hours` on numbers).
- **`@ExperimentalTime` opt-in gating** is version churn; a new library should
  simply define its own stable surface. Source: kotlin.time package page.
- **`toInt`/`toLong` clamping conversions** can silently hide range errors;
  prefer checked conversion. `GUESS:` clamp behaviour inferred.
- **Overloading `times`/`div` for both `Int` and `Double`** invites float
  precision drift; a nanosecond-integer API should expose integer scaling only.

## 12. Ideas fitting Mojo

- **`TimeMark`-style opaque instant bound to a clock**, with subtraction only
  within the same source. (Source: kotlin.time package page.)
- **`elapsedNow()` / remaining** as the two queries on an instant/deadline.
  (Source: `TimeMark.elapsedNow`.)
- **Injectable time source** (`TestTimeSource`-like) as a first-class concept
  for deterministic tests. (Source: kotlin.time package page.)
- **`value class` equivalent**: Mojo value type over a single integer, zero
  overhead. (Source: `@JvmInline value class Duration`.)
- **Explicit no-timeout representation** (rather than an infinite duration).
- **`measureTime` helper** returning a duration around a block, mirroring
  `measureTime`/`measureTimedValue`. (Source: kotlin.time package page.)

## Sources

- `kotlin.time` package:
  https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/
- `kotlin.time.Duration`:
  https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/-duration/
