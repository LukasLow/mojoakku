# time_clock research: js_ts

## 1. Standard library support

JavaScript has **no duration type**. Time is represented as plain numbers
(milliseconds), and there are two distinct clocks:

- `Date.now()` — wall clock, "relative to the Unix epoch (1970-01-01T00:00:00Z)
  and dependent on the system clock"; may be affected by clock adjustments.
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Performance/now
  ("Performance.now vs. Date.now").
- `performance.now()` — "returns a high resolution timestamp in milliseconds …
  the time elapsed since `Performance.timeOrigin`"; "relative to the
  `timeOrigin` property which is a **monotonic clock**: its current time never
  decreases and isn't subject to adjustments". Returns a `DOMHighResTimeStamp`.
  Source: same page.
- Timeouts: `setTimeout(code, delay)` / `setInterval` / `clearTimeout`.
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout .
- `AbortController` + `AbortSignal.timeout(ms)` is the modern cancellation
  primitive. `GUESS:` not fetched this pass.
- Node.js adds `process.hrtime.bigint()` (monotonic nanoseconds) and
  `node:timers/promises` with `setTimeout`/`scheduler`. `GUESS:` not fetched.
  The Node docs are the authority: https://nodejs.org/api/ .

## 2. Relevant community libraries

- **`luxon`** — immutable `Duration` and `DateTime` objects, wall-clock
  focused. `GUESS:` not fetched.
- **`dayjs`** (with `duration` plugin) — lightweight datetime/duration.
  `GUESS:` not fetched.
- **`date-fns`** — function-based date/duration utilities. `GUESS:` not fetched.
- **`tinybench` / `performance-now`** — benchmarking/monotonic shims.
  `GUESS:` not fetched.
- No community library provides a monotonic *deadline* abstraction; the platform
  APIs are used directly. `GUESS:` assessment.

## 3. Exposed APIs

- `Date.now() -> number`, `new Date()`, `date.getTime() -> number` — wall
  clock milliseconds. `GUESS:` member names standard; MDN page not fetched for
  Date specifically.
- `performance.now() -> DOMHighResTimeStamp` (milliseconds, floating point,
  "up to microsecond precision"). Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Performance/now .
- `performance.timeOrigin` — epoch offset so `timeOrigin + now()` is a
  wall-clock instant. Source: same page.
- `setTimeout(func, delay?, param1?, ...N?) -> number` returns a positive
  integer timeout ID; `clearTimeout(id)` cancels.
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout .
- No `Duration`, no `add`, no `compare` API — arithmetic is `+`/`-` on numbers.

## 4. Error representation

- `setTimeout` throws `SyntaxError` if `code` cannot be parsed and `TypeError`
  for unsupported first-argument types (Trusted Types). Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout
  (Exceptions).
- No error is reported for delay overflow: "The `delay` argument is converted to
  a signed 32-bit integer, which limits the value to 2147483647 ms, or roughly
  24.8 days. Delays of more than this value will cause an integer overflow" and
  can fire immediately. Source: same page, "Maximum delay value".
- Non-number delays are silently coerced ("1 second" becomes `0`). Source: same
  page, "Non-number delay values are silently coerced into numbers".

## 5. Ownership semantics

- Pure values (numbers) and opaque platform handles; GC-managed, no explicit
  ownership. The timeout ID returned by `setTimeout` is a capability that must
  be kept to call `clearTimeout`. Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout
  (Return value).

## 6. Blocking / non-blocking

- There is **no blocking sleep** in the browser: `setTimeout()` "returns
  immediately after scheduling the callback"; the thread is never blocked.
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout
  ("Working with asynchronous functions").
- Timers are callback/event-loop based; promise chaining is used to sequence.
  Source: same page.
- `performance.now()` itself never blocks.

## 7. IPv4 / IPv6

Not applicable to a time library; timestamps and delays carry no address family.

## 8. Timeouts

- Relative timeout: `setTimeout(fn, delayMs)`; cancellation via
  `clearTimeout(id)`. Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout .
- Actual delay "may be longer than set"; nested timeouts are clamped to a
  minimum of 4 ms after 5 levels, and inactive tabs are throttled (Firefox
  ≥1 s; Chrome up to once per minute under intensive throttling).
  Source: same page, "Reasons for longer delays than specified".
- No absolute-deadline API in the browser; a deadline is computed as
  `t0 = performance.now(); t0 + timeoutMs` and checked against
  `performance.now()`. `GUESS:` idiom inferred from the monotonic-clock
  description.
- `performance.now()` resolution is coarsened for security: 5 µs in
  cross-origin-isolated documents, 100 µs otherwise. Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Performance/now
  ("Security requirements").

## 9. TLS

Not applicable to a time library; there is no transport to secure.

## 10. Interesting design decisions

- **Two clocks with explicitly different contracts**: `Date.now` (wall,
  adjustable) and `performance.now` (monotonic, never decreasing).
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Performance/now .
- **`timeOrigin` separates the clock origin from the reading**, fixing the
  Level-1 problem of comparing timestamps across pages. Source: same page
  ("performance.now specification changes").
- **Resolution is deliberately coarsened** in non-isolated contexts (100 µs)
  to defeat timing attacks and fingerprinting. Source: same page.
- **Cancellation is an opaque ID + `clearTimeout`**, not a token/callback.
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout .
- **Delay is a signed 32-bit ms integer**, an explicit, documented overflow
  boundary. Source: same page.

## 11. Decisions NOT to copy

- **No duration type at all** — arithmetic on bare milliseconds loses all type
  safety; Mojo should have distinct `Duration`/`Deadline` types.
- **Silent coercion and silent overflow** of the delay value (string "1 second"
  → 0; >2^31 ms → immediate fire) are bugs by design. Mojo should validate and
  raise. Source: same page.
- **Callback/event-loop scheduling** with no blocking sleep makes timeouts hard
  to reason about; a socket-wait primitive should accept an explicit deadline.
  Source: same page ("Working with asynchronous functions").
- **Coarsened resolution** is a deliberate browser security trade-off that a
  systems time library should not inherit. Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Performance/now .
- **32-bit millisecond delay limit** (~24.8 days) should not bound a Mojo
  duration; use a wide integer. Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout .

## 12. Ideas fitting Mojo

- **Two named clocks** (`now_monotonic` for waits, wall clock separate), like
  `performance.now` vs `Date.now`. Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Performance/now .
- **Opaque `Deadline` with cancellation** analogous to `{id, clearTimeout}`,
  but as a typed value with a `cancel()`/drop path.
- **Documented resolution** rather than an exposed API, mirroring how MDN
  documents `performance.now` resolution. Source: same page.
- **Explicit delay validation** replacing silent coercion/overflow.
- **Microsecond-or-better precision as floating point** is unnecessary for
  waits; Mojo's integer-nanosecond span avoids JS's float compromise.

## Sources

- `Performance.now()`:
  https://developer.mozilla.org/en-US/docs/Web/API/Performance/now
- `Window.setTimeout()`:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout
- High Resolution Time spec: https://w3c.github.io/hr-time/
