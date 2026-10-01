# time_clock research: python

## 1. Standard library support

`time` (procedural) and `datetime` (object-oriented); `time` is documented as
"always available" but platform-dependent, delegating to the platform C library
"with the same name", so "the semantics of these functions varies among
platforms" (https://docs.python.org/3/library/time.html).

- Monotonic clock: `time.monotonic() -> float` — "a clock that cannot go
  backwards. … The reference point of the returned value is undefined, so that
  only the difference between the results of two calls is valid." Backed by
  `QueryPerformanceCounter` on Windows, `mach_absolute_time` on macOS,
  `clock_gettime(CLOCK_HIGHRES)`/`(CLOCK_MONOTONIC)` elsewhere.
  Source: https://docs.python.org/3/library/time.html#time.monotonic .
- `time.monotonic_ns() -> int` — same but nanoseconds, "to avoid the precision
  loss caused by the float type". Source: same page.
- `time.perf_counter()` / `perf_counter_ns()` — "highest available resolution",
  includes time elapsed during sleep; CPython implements it with the same clock
  as `monotonic()`. Source: same page.
- `time.time() -> float` and `time.time_ns() -> int` — wall clock since epoch.
  Source: same page.
- `time.get_clock_info(name)` returns a namespace with `adjustable`,
  `implementation`, `monotonic`, `resolution`. Source: same page.
- `datetime.timedelta` — a **signed** duration with days/seconds/microseconds,
  full arithmetic and comparison. `GUESS:` page not fetched this pass; the
  `time` page only links to `datetime` ("More object-oriented interface").
- `datetime.datetime` / `datetime.timedelta` are wall-clock, not monotonic;
  Python has **no** monotonic instant type. `GUESS:` inferred from the
  `monotonic()` docs (reference point undefined, only differences valid).

## 2. Relevant community libraries

- **`monotonic`** (PyPI) — backport providing a guaranteed monotonic clock on
  old/odd platforms. `GUESS:` not fetched.
- **`pytimeparse`** — duration string parsing. `GUESS:` not fetched.
- **`pendulum`** — richer datetime/timedelta, wall-clock focused.
  `GUESS:` not fetched.
- The stdlib covers monotonic reading + `timedelta` arithmetic, so community
  libraries are mostly parsing, time zones, or test clocks. `GUESS:` assessment.

## 3. Exposed APIs

`time` module (exact spellings):

- Clock readers: `monotonic()`, `monotonic_ns()`, `perf_counter()`,
  `perf_counter_ns()`, `process_time()`, `process_time_ns()`, `thread_time()`,
  `thread_time_ns()`, `time()`, `time_ns()`.
- Clock metadata: `get_clock_info(name)` with names `'monotonic'`,
  `'perf_counter'`, `'process_time'`, `'thread_time'`, `'time'`.
- Sleep: `time.sleep(seconds)`.
- Low-level: `clock_gettime(clk_id)`, `clock_gettime_ns(clk_id)`,
  `clock_getres(clk_id)`, `clock_settime`, `clock_settime_ns`;
  `CLOCK_MONOTONIC`, `CLOCK_MONOTONIC_RAW`, `CLOCK_BOOTTIME`,
  `CLOCK_REALTIME`, `CLOCK_TAI`, etc. Source: same page, Clock ID Constants.
- `datetime.timedelta` exposes `.days`, `.seconds`, `.microseconds`,
  `.total_seconds()`, and `+`, `-`, `*`, `/`, comparison.
  `GUESS:` exact member names from general knowledge, not fetched.

## 4. Error representation

- `time` raises exceptions for bad input/platform issues rather than returning
  codes: e.g. `localtime()` "may raise `OverflowError` … and `OSError`";
  `mktime()` may raise `OverflowError` or `ValueError`.
  Source: https://docs.python.org/3/library/time.html .
- `datetime.timedelta` overflow raises `OverflowError` in CPython.
  `GUESS:` from general knowledge, not fetched.
- `time.sleep()` itself is documented to restart after a signal if no exception
  is raised (PEP 475), so interruption does not surface as an error.
  Source: https://docs.python.org/3/library/time.html#time.sleep .

## 5. Ownership semantics

- Everything is an immutable Python object (float/int for `time`, `timedelta`
  value object for `datetime`); reference-counted, no explicit ownership.
  `GUESS:` general Python semantics, not fetched.

## 6. Blocking / non-blocking

- `time.sleep(seconds)` blocks the calling thread. Source:
  https://docs.python.org/3/library/time.html#time.sleep .
- Async: `asyncio.sleep(delay)` yields control; it is not a blocking sleep.
  `GUESS:` not fetched this pass.
- `time.monotonic()` itself never blocks.

## 7. IPv4 / IPv6

Not applicable to a time library; time values carry no address family.

## 8. Timeouts

- A timeout is a plain number of seconds (`float`) or a `timedelta`.
  `time.sleep` "may be longer than requested by an arbitrary amount" and uses
  `clock_nanosleep()`/`nanosleep()`/`select()` on Unix (resolution 1 ns / 1 ns
  / 1 µs). Source: https://docs.python.org/3/library/time.html#time.sleep .
- `asyncio.wait_for(awaitable, timeout)` is the async timeout primitive.
  `GUESS:` not fetched.
- Because `monotonic()` has an undefined origin, an absolute deadline is
  `start = monotonic(); deadline = start + timeout`, and expiry is
  `monotonic() >= deadline`. `GUESS:` idiom inferred from the undefined-origin
  statement.

## 9. TLS

Not applicable to a time library; no transport, no TLS.

## 10. Interesting design decisions

- **`get_clock_info` exposes `adjustable` and `monotonic` as data**, letting a
  caller introspect a clock's contract instead of trusting a name.
  Source: https://docs.python.org/3/library/time.html#time.get_clock_info .
- **Integer-nanosecond variants of every clock** (`*_ns`) exist specifically
  to avoid float precision loss. Source: same page.
- **`perf_counter` and `monotonic` are the same clock on CPython 3.13+**, but
  the API keeps two names for portability/intent.
  Source: same page (`perf_counter`, "Changed in version 3.13").
- **Signal-interrupted sleep is transparently restarted** (PEP 475) unless the
  handler raises. Source: same page.
- **`CLOCK_BOOTTIME`** is offered as a suspend-aware monotonic clock distinct
  from `CLOCK_MONOTONIC`. Source: same page, Clock ID Constants.

## 11. Decisions NOT to copy

- **Float seconds as the primary representation.** `monotonic()` returns
  `float`; the docs themselves warn about precision loss and add `_ns`
  variants. Mojo should use integer nanoseconds from the start.
- **Two parallel names for the same clock** (`monotonic` vs `perf_counter` on
  CPython) is portability cruft; one monotonic clock is enough for a socket
  wait. Source: same page.
- **No monotonic instant type at all.** Python forces `start + timeout` on
  floats; a typed `Deadline` is safer and reads better.
- **Platform-dependent semantics** ("semantics of these functions varies among
  platforms") is exactly the uncertainty a Mojo library should remove.
  Source: https://docs.python.org/3/library/time.html (module intro).
- **`time.sleep(0)` is discouraged** in favour of `pass`; a `sleep` API should
  define zero-duration behaviour explicitly. Source:
  https://docs.python.org/3/library/time.html#time.sleep .

## 12. Ideas fitting Mojo

- **Integer-nanosecond monotonic clock** as the single source, with no float
  path in the core. (Source: `monotonic_ns`, `perf_counter_ns`.)
- **`Deadline` = `now + timeout`** with an undefined-origin instant, matching
  the documented monotonic contract. (Source: `time.monotonic`.)
- **A clock-info/metadata accessor** (`resolution`, `monotonic`) if Mojo wants
  to document expected resolution; Python shows it can be data, not prose.
  (Source: `get_clock_info`.)
- **Signed duration arithmetic** like `timedelta`, but over an integer
  nanosecond span rather than day/second/microsecond fields.
- **`raises` for overflow / bad construction**, replacing `OverflowError`.
  (Source: `mktime`/`localtime` error notes.)

## Sources

- `time` module: https://docs.python.org/3/library/time.html
- `time.monotonic`: https://docs.python.org/3/library/time.html#time.monotonic
- `time.sleep`: https://docs.python.org/3/library/time.html#time.sleep
- `time.get_clock_info`:
  https://docs.python.org/3/library/time.html#time.get_clock_info
