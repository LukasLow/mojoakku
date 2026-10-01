# time_clock research: c

## 1. Standard library support

C has no duration or instant *type*; it has a clock API and a raw timespec
struct. All of it is in `<time.h>`.

- `struct timespec` holds `time_t tv_sec` plus `long tv_nsec`
  (`0 <= tv_nsec < 1000 million`). This is the closest thing C has to an
  instant/duration carrier, but it carries **no arithmetic operators**.
  Source: POSIX `clock_getres` page, ERRORS `[EINVAL]` on `tv_nsec`
  (https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_gettime.html).
- `int clock_gettime(clockid_t clock_id, struct timespec *tp)` reads a clock.
  Source: POSIX `clock_gettime` SYNOPSIS (same URL).
- `int clock_getres(clockid_t clock_id, struct timespec *res)` reads the
  resolution; a NULL `res` means "do not return it". Source: same page,
  DESCRIPTION.
- `int clock_settime(clockid_t clock_id, const struct timespec *tp)` sets a
  clock and **fails with `EINVAL` for `CLOCK_MONOTONIC`**. Source: same page,
  DESCRIPTION and ERRORS.
- `CLOCK_REALTIME` is mandatory; `CLOCK_MONOTONIC` is mandatory when the
  Monotonic Clock option is present. `CLOCK_MONOTONIC` "represents the amount
  of time since an unspecified point in the past"; its absolute value is
  meaningless. Source: same page, DESCRIPTION and APPLICATION USAGE.
- `int nanosleep(const struct timespec *rqtp, struct timespec *rmtp)` sleeps
  the calling thread; on interruption it returns -1/EINTR and, if `rmtp` is
  non-NULL, writes the **remaining** interval into it. Source: POSIX
  `nanosleep` page (https://pubs.opengroup.org/onlinepubs/9699919799/functions/nanosleep.html).
- `int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec
  *rqtp, struct timespec *rmtp)` sleeps on a specified clock; with
  `TIMER_ABSTIME` set it sleeps until the clock reaches the absolute `rqtp`.
  Source: POSIX `clock_nanosleep` SYNOPSIS and DESCRIPTION
  (https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_nanosleep.html).
  Resetting `CLOCK_REALTIME` makes an already-past absolute time expire
  immediately. Source: POSIX `clock_gettime` DESCRIPTION.
- `time_t time(time_t *t)` / `double difftime(time_t, time_t)` give wall-clock
  seconds; `struct tm`/`mktime`/`strftime` are calendar, not interval, tools.
  Source: POSIX `<time.h>` XBD referenced from both pages above.
- `timespec_get` (C11, `TIME_UTC`) exists as a C-standard wall-clock reader.
  `GUESS:` exact C11 wording — not fetched in this pass; the POSIX page is the
  verified source and does not cover C11.

## 2. Relevant community libraries

- `libuv`: `uv_hrtime()` returns a monotonic high-resolution timestamp in
  nanoseconds. `GUESS:` name/signature from general knowledge, not fetched in
  this pass; official docs at https://docs.libuv.org/ .
- GLib: `g_get_monotonic_time()` / `g_get_real_time()` return microseconds.
  `GUESS:` name from general knowledge, not fetched.
- These add nothing over `clock_gettime` for a duration/instant API; they are
  mostly portability shims. `GUESS:` assessment.
- No established, widely used standalone C "Duration/Deadline" value type
  library was found. `GUESS:` based on this search pass.

## 3. Exposed APIs

Exact spellings from POSIX:

- `struct timespec { time_t tv_sec; long tv_nsec; };`
- `clockid_t` values: `CLOCK_REALTIME`, `CLOCK_MONOTONIC`,
  `CLOCK_PROCESS_CPUTIME_ID`, `CLOCK_THREAD_CPUTIME_ID`.
- Functions: `clock_getres`, `clock_gettime`, `clock_settime`, `nanosleep`,
  `clock_nanosleep`, `time`, `difftime`, `mktime`, `localtime`, `gmtime`,
  `strftime`.
- There is **no** `add`, `sub`, `mul`, `div`, `compare`, `expired`, or
  `remaining` function for `timespec`; the caller writes the arithmetic over
  `tv_sec`/`tv_nsec` and normalises the nanosecond carry itself.
  Source: POSIX `clock_gettime` page shows only the raw read/write/sleep surface.

## 4. Error representation

- Return value `0` on success, `-1` on error with `errno` set. Source: POSIX
  `clock_gettime` RETURN VALUE.
- `clock_gettime`: `EINVAL` for an unknown clock; `EOVERFLOW` if the seconds do
  not fit in `time_t`. Source: same page, ERRORS.
- `clock_settime`: `EINVAL` if `tp` is outside range or the nanosecond field is
  `< 0` or `>= 1000 million`, or if the clock is `CLOCK_MONOTONIC`;
  `EPERM` if not privileged. Source: same page, ERRORS.
- `nanosleep`: `-1`/`EINTR` when interrupted by a signal, `-1`/`EINVAL` when
  `tv_nsec < 0` or `>= 1000 million`. Source: POSIX `nanosleep` RETURN VALUE
  and ERRORS.
- No error type, no out-of-band channel; sentinel `-1` + global `errno`.

## 5. Ownership semantics

- Everything is a plain by-value C struct; `clock_gettime` fills a caller-owned
  `struct timespec` via out-pointer. No heap, no free, no handle. Source:
  POSIX `clock_gettime` SYNOPSIS (`struct timespec *tp` out-parameter).
- `nanosleep`'s `rmtp` is also caller-owned and may alias `rqtp` ("the rqtp and
  rmtp arguments can point to the same object"). Source: POSIX `nanosleep`
  RETURN VALUE.

## 6. Blocking / non-blocking

- `nanosleep` blocks the calling thread. Source: POSIX `nanosleep` DESCRIPTION.
- There is no async/timeout parameter on the clock reads themselves; asynchrony
  is built by the caller from signals, `clock_nanosleep` absolute wake-ups, or
  threads. Source: POSIX `clock_nanosleep` DESCRIPTION (relative vs absolute
  sleeps, https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_nanosleep.html)
  and `nanosleep` DESCRIPTION (signal interruption).

## 7. IPv4 / IPv6

Not applicable to a time library; clocks, durations and deadlines carry no
network address family.

## 8. Timeouts

- Timeouts are represented as a relative `struct timespec` passed to
  `nanosleep`, or an absolute one via `clock_nanosleep` + `TIMER_ABSTIME`.
  Source: POSIX `nanosleep` SYNOPSIS and POSIX `clock_nanosleep` SYNOPSIS and
  DESCRIPTION
  (https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_nanosleep.html).
- Because a signal aborts `nanosleep` with `EINTR` and returns the remaining
  time in `rmtp`, a correct timeout loop must re-arm with the remainder.
  Source: POSIX `nanosleep` RETURN VALUE.
- `CLOCK_REALTIME` absolute deadlines are re-evaluated if the clock is set:
  a requested absolute time in the past expires immediately. Source: POSIX
  `clock_gettime` DESCRIPTION.

## 9. TLS

Not applicable to a time library; clocks have no transport and thus no TLS
layer.

## 10. Interesting design decisions

- **Clock id as the selector, not a separate type**: one `clock_gettime` reads
  any clock; the meaning lives in the `clockid_t`. Source: POSIX
  `clock_gettime` SYNOPSIS.
- **Monotonic clocks are read-only**: `clock_settime(CLOCK_MONOTONIC)` fails
  with `EINVAL`, which encodes the invariant in the error surface. Source:
  POSIX `clock_gettime` ERRORS.
- **Raw representation, caller-owned arithmetic**: `timespec` is a pair of
  integers with no methods, which makes carry/normalisation and overflow the
  caller's problem. Source: POSIX `clock_gettime` page (only raw access is
  specified).
- **Relative vs absolute sleep is a flag**, not a different function name:
  `clock_nanosleep` + `TIMER_ABSTIME`. Source: POSIX `clock_nanosleep`
  DESCRIPTION
  (https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_nanosleep.html).
- **EINTR is explicit and lossless**: the remainder is handed back. Source:
  POSIX `nanosleep` RETURN VALUE.

## 11. Decisions NOT to copy

- **No arithmetic on the value type.** Requiring callers to hand-normalise
  `tv_sec`/`tv_nsec` is a bug farm; a Mojo library should provide add/sub/
  compare/negation on its own types.
- **`errno` + `-1` sentinel.** Mojo raises a typed error; a global error slot
  and sentinel is not copyable.
- **`time_t`/`long` representation limits.** `time_t` can be 32-bit; the
  POSIX `EOVERFLOW` case shows the representability trap. Source: POSIX
  `clock_gettime` ERRORS. A new API should pick an explicit bit width.
- **Absolute monotonic values.** POSIX notes the absolute value of
  `CLOCK_MONOTONIC` is meaningless, so exposing a raw monotonic integer as an
  "instant" invites misuse. Source: POSIX `clock_gettime` APPLICATION USAGE.
  Mojo should keep the instant opaque and only compare/subtract it.

## 12. Ideas fitting Mojo

- **Opaque instant + arithmetic span** mirroring `time_point`/`duration`
  semantics rather than exposing raw tick counts. (Motivated by POSIX
  APPLICATION USAGE: monotonic absolute values are meaningless.)
- **Typed error instead of `errno`**: `clock_gettime` really only fails with
  "unknown clock" (`EINVAL`) and "does not fit" (`EOVERFLOW`); both map to a
  Mojo `raises` set. (Source: POSIX ERRORS.)
- **Saturating/checked subtraction** instead of hand-normalised carry: the C
  world has no checked ops, so Mojo can do strictly better.
- **A `sleep(Duration)` primitive** and an absolute-deadline primitive, as
  `nanosleep` + `clock_nanosleep(TIMER_ABSTIME)` split them. (Source: POSIX
  `nanosleep` and `clock_nanosleep` SYNOPSIS/
  DESCRIPTION, https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_nanosleep.html.)
- **Value semantics + `Copy`**: `struct timespec` is pass-by-value and
  trivially copyable; Mojo's own value types map directly.

## Sources

- POSIX `clock_getres`/`clock_gettime`/`clock_settime`:
  https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_gettime.html
- POSIX `nanosleep`:
  https://pubs.opengroup.org/onlinepubs/9699919799/functions/nanosleep.html
- POSIX `clock_nanosleep`:
  https://pubs.opengroup.org/onlinepubs/9699919799/functions/clock_nanosleep.html
