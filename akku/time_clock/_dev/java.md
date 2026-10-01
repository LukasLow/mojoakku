# time_clock research: java

## 1. Standard library support

`java.time` (JSR-310, since Java 8) is the object model, and `java.lang.System`
provides the raw monotonic read.

- `java.time.Duration` — "A time-based amount of time, such as '34.5 seconds'.
  … models a quantity or amount of time in terms of seconds and nanoseconds".
  "The duration uses nanosecond resolution with a maximum value of the seconds
  that can be held in a `long`." It stores "a `long` representing seconds and an
  `int` representing nanosecond-of-second, which will always be between 0 and
  999,999,999". Source:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Duration.html .
- `java.time.Instant` — wall-clock instant on the time-line (UTC epoch),
  comparable, with `now()` and arithmetic. `GUESS:` exact wording from general
  knowledge; Duration page links to `Instant` and discusses its time-scale.
- `System.nanoTime()` — "Returns the current value of the running Java Virtual
  Machine's high-resolution time source, in nanoseconds. … can only be used to
  measure elapsed time and is not related to any other notion of system or
  wall-clock time." "nanosecond precision, but not necessarily nanosecond
  resolution". Source:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/System.html#nanoTime() .
- `System.currentTimeMillis()` — wall clock milliseconds.
  Source: same page.
- `java.time.temporal.ChronoUnit` provides units (`NANOS`, `SECONDS`, `DAYS`,
  …). `GUESS:` from general knowledge, referenced by the Duration page.

## 2. Relevant community libraries

- **Joda-Time** — the predecessor whose design became `java.time`.
  `GUESS:` not fetched.
- **`java.time.Clock`** is in the JDK itself and is the standard seam for
  injecting a clock (e.g. `Clock.fixed(...)`) in tests.
  `GUESS:` exact API from general knowledge, not fetched.
- No widely used non-JDK library remains necessary; JSR-310 replaced them.
  `GUESS:` assessment.

## 3. Exposed APIs

`Duration` (exact spellings from the Java 21 javadoc):

- Constant: `Duration.ZERO`.
- Factories: `ofDays`, `ofHours`, `ofMinutes`, `ofSeconds(long)`,
  `ofSeconds(long, long nanoAdjustment)`, `ofMillis`, `ofNanos`,
  `of(long, TemporalUnit)`, `parse(CharSequence)`,
  `between(Temporal, Temporal)`, `from(TemporalAmount)`.
- Arithmetic: `plus(Duration)`, `plus(long, TemporalUnit)`, `plusDays/Hours/
  Minutes/Seconds/Millis/Nanos`, `minus(...)` variants, `multipliedBy(long)`,
  `dividedBy(long)`, `dividedBy(Duration) -> long`, `negated()`, `abs()`.
- Predicates/accessors: `isZero()`, `isPositive()`, `isNegative()`,
  `getSeconds()`, `getNano()`, `toDays()`, `toHours()`, `toMinutes()`,
  `toSeconds()`, `toMillis()`, `toNanos()`, `getUnits()`.
- `truncatedTo(TemporalUnit)`, `withSeconds`, `withNanos`, `toString()`
  (ISO-8601 `PT8H6M12.345S`). Source: Duration javadoc, Method Summary.

`System`:

- `public static long nanoTime()` and `public static long currentTimeMillis()`.
  Source: System javadoc.

## 4. Error representation

- `Duration` arithmetic **throws exceptions**: `ArithmeticException` "if numeric
  overflow occurs" (all `plus`/`minus`/`multipliedBy`), and for `dividedBy`
  "if the divisor is zero or if numeric overflow occurs". `ofDays`/`ofHours`/
  `ofMinutes` throw `ArithmeticException` when the input exceeds capacity.
  Source: Duration javadoc.
- `of(long, TemporalUnit)` throws `DateTimeException` if the unit has an
  estimated duration, plus `ArithmeticException` on overflow. Source: same.
- `parse` throws `DateTimeParseException`; `from`/`between` throw
  `DateTimeException`/`ArithmeticException`. Source: same.
- `System.nanoTime()` returns a `long` and cannot signal overflow; the docs
  warn "Differences in successive calls that span greater than approximately
  292 years … will not correctly compute elapsed time due to numerical
  overflow." Source: System javadoc.

## 5. Ownership semantics

- `Duration` is an **immutable value-based class**: "This class is immutable and
  thread-safe." Users "should treat instances that are equal as
  interchangeable and should not use instances for synchronization". All
  mutating-looking methods return a copy. Source: Duration javadoc
  (class description, `withSeconds`, `plus`, etc.).
- `System.nanoTime()` returns a primitive `long`; no ownership.
- No handles, no free; GC manages object lifetime.

## 6. Blocking / non-blocking

- `Duration`/`Instant` never block. Blocking sleeps live elsewhere:
  `Thread.sleep(Duration)` (Java 21 overload) and
  `TimeUnit.MILLISECONDS.sleep(...)`. `GUESS:` exact overload from general
  knowledge, not fetched.
- Timed blocking waits: `Object.wait(long)`, `Condition.await(time, unit)`.
  `GUESS:` not fetched.
- Virtual threads (Java 21) make blocking waits cheap, but the API surface is
  unchanged. `GUESS:` not fetched.

## 7. IPv4 / IPv6

Not applicable to a time library; durations and instants carry no address
family.

## 8. Timeouts

- A timeout is a `Duration`; a deadline is an `Instant` (`Instant.now().plus(d)`)
  or, on the monotonic side, a raw `long` deadline in `nanoTime()` units.
  Source: Duration javadoc + System.nanoTime().
- **Overflow guidance is explicit**: to compare against a timeout, use
  `if (System.nanoTime() - startTime >= timeoutNanos)` rather than
  `if (System.nanoTime() >= startTime + timeoutNanos)` "because of the
  possibility of numerical overflow". Source: System javadoc.
- Absolute deadlines are wall-clock (`Instant`) and are affected by clock
  changes; monotonic waiting must use the `nanoTime` difference form.
  Source: System javadoc.

## 9. TLS

Not applicable to a time library; no transport, no TLS.

## 10. Interesting design decisions

- **Dual-field representation** (long seconds + int nanos, nanos always
  0..999,999,999): "The range of a duration requires the storage of a number
  larger than a `long`." Source: Duration javadoc.
- **Directed (signed) duration**: "The model is of a directed duration, meaning
  that the duration may be negative." A negative is "expressed by the negative
  sign of the seconds part" (e.g. −1 ns = −1 s + 999,999,999 ns).
  Source: Duration javadoc (`getSeconds`, `getNano`).
- **`between(startInclusive, endExclusive)`** frames a duration as the delta
  between two temporals, and may be negative. Source: Duration javadoc.
- **`dividedBy(Duration) -> long`** returns a whole count, a separate overload
  from `dividedBy(long) -> Duration`. Source: Duration javadoc.
- **Value-based class contract** forbids synchronization on instances.
  Source: Duration javadoc.
- **Overflow-safe comparison idiom is documented**, not hidden in a helper.
  Source: System javadoc.

## 11. Decisions NOT to copy

- **Throwing `ArithmeticException` from arithmetic** means every `plus` can
  fail; Mojo can make it explicit in the signature with `raises` rather than
  an unchecked runtime throw. Source: Duration javadoc.
- **Two-field seconds+nanos with an always-positive nanos field** is subtle for
  negatives; a single signed integer-nanosecond span is easier to reason about
  and to saturate. Source: Duration javadoc (`-1 nanosecond` storage).
- **Raw `long` nanoTime deadlines with a documented overflow idiom** push
  safety onto the caller; a typed `Deadline` with saturating subtraction is
  safer. Source: System javadoc.
- **`TemporalUnit`/`Temporal` genericity** adds a large type hierarchy for a
  library that only needs one monotonic clock; Mojo should stay concrete.
  (Source: Duration methods taking `TemporalUnit`.)
- **Value-based class identity warnings** are unnecessary complexity once the
  type is a plain Mojo value.

## 12. Ideas fitting Mojo

- **Signed `Duration` with positive/negative/zero predicates and `abs()`,
  `negated()`**, modelled on the Java method names that read clearly.
  (Source: Duration javadoc.)
- **Factory methods per unit** (`of_millis`, `of_seconds`) so raw ticks never
  leak. (Source: Duration javadoc.)
- **Representability as `raises`** (overflow/zero-divisor) instead of unchecked
  exceptions. (Source: Duration javadoc.)
- **Documented overflow-safe deadline comparison** as the recommended idiom.
  (Source: System javadoc.)
- **Immutable value type** with all operations returning new values.
  (Source: Duration javadoc "immutable and thread-safe".)

## Sources

- `java.time.Duration` (Java SE 21):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Duration.html
- `java.lang.System` (Java SE 21):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/System.html
