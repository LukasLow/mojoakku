# time_clock research: go

## 1. Standard library support

Two packages: `time` and `context`.

- `type Duration int64` — "the elapsed time between two instants as an int64
  nanosecond count. The representation limits the largest representable
  duration to approximately 290 years."
  Source: https://pkg.go.dev/time#Duration .
- `type Time struct { ... }` — a wall-clock reading plus, optionally, a
  monotonic clock reading. Source: https://pkg.go.dev/time#Time and the
  package Overview ("Monotonic Clocks").
- Unit constants: `Nanosecond`, `Microsecond`, `Millisecond`, `Second`,
  `Minute`, `Hour`; there is deliberately **no Day or larger** "to avoid
  confusion across daylight savings time zone transitions".
  Source: https://pkg.go.dev/time#pkg-constants .
- `context.Context` — "carries deadlines, cancellation signals, and other
  request-scoped values across API boundaries".
  Source: https://pkg.go.dev/context#Context .

## 2. Relevant community libraries

- `golang.org/x/time/rate` — token-bucket rate limiter built on `time`.
  `GUESS:` not fetched this pass.
- `github.com/benbjohnson/clock` — mockable `Clock` interface for tests.
  `GUESS:` not fetched.
- `github.com/jonboulle/clockwork` — another fake-clock test library.
  `GUESS:` not fetched.
- The stdlib covers clocks/durations/deadlines so completely that community
  libraries are almost entirely **test doubles**. `GUESS:` assessment.

## 3. Exposed APIs

`time` package (exact spellings from pkg.go.dev):

- Package-level funcs: `func Now() Time`, `func Since(t Time) Duration`,
  `func Until(t Time) Duration`, `func ParseDuration(s string) (Duration, error)`,
  `func Sleep(d Duration)`, `func After(d Duration) <-chan Time`,
  `func Tick(d Duration) <-chan Time`.
- `Duration` methods: `Abs()`, `Hours() float64`, `Microseconds() int64`,
  `Milliseconds() int64`, `Minutes() float64`, `Nanoseconds() int64`,
  `Seconds() float64`, `Round(m Duration) Duration`, `Truncate(m Duration)
  Duration`, `String() string`.
- Arithmetic is by Go **operators** on `Duration` (it is an `int64`): `+`, `-`,
  `*`, `/`, and comparisons. `GUESS:` operator support follows from it being a
  defined int64 type; the doc page shows `time.Duration(seconds) * time.Second`.
- `Time` methods relevant here: `Add(d Duration) Time`, `Sub(u Time) Duration`,
  `Before(u Time) bool`, `After(u Time) bool`, `Equal(u Time) bool`,
  `Compare(u Time) int`, `AddDate`, `Round`, `Truncate`, `IsZero()`.
  Source: https://pkg.go.dev/time#Time .

`context` package:

- `func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)`
  and `func WithDeadline(parent Context, d time.Time) (Context, CancelFunc)`.
- `Context` interface: `Deadline() (deadline time.Time, ok bool)`,
  `Done() <-chan struct{}`, `Err() error`, `Value(key any) any`.
  Source: https://pkg.go.dev/context#Context .

## 4. Error representation

- Ordinary Go: functions return `(result, error)`; `ParseDuration` returns
  `(Duration, error)`.
- `context` uses **sentinel errors**: `var Canceled = errors.New("context
  canceled")` and `var DeadlineExceeded error = deadlineExceededError{}`.
  `Context.Err()` returns `DeadlineExceeded` or `Canceled`; `Cause(ctx)`
  returns a caller-supplied cause. Source: https://pkg.go.dev/context#pkg-variables
  and `#Cause`.
- `Duration.Abs()` has an explicit special case: `Duration(math.MinInt64)` is
  converted to `Duration(math.MaxInt64)`, "reducing its magnitude by 1
  nanosecond". Source: https://pkg.go.dev/time#Duration.Abs .

## 5. Ownership semantics

- `Duration` is a defined `int64`; `Time` is an opaque struct. Both are
  value types copied on assignment; no ownership, no free.
  Source: https://pkg.go.dev/time#Duration and `#Time`.
- `*Ticker` and `*Timer` are pointers with `Stop()`; `context.CancelFunc` is a
  `func()` that must be called to release resources ("Failing to call the
  CancelFunc leaks the child and its children until the parent is canceled").
  Source: https://pkg.go.dev/context#WithCancel .

## 6. Blocking / non-blocking

- `time.Sleep(d)` "pauses the current goroutine for at least the duration d.
  A negative or zero duration causes Sleep to return immediately."
  Source: https://pkg.go.dev/time#Sleep .
- `context` is the non-blocking/cancellation channel: `Done()` returns a
  channel closed on cancel; callers `select` on it.
  Source: https://pkg.go.dev/context#Context .
- Go concurrency is goroutines + channels; `After`/`Tick` return time
  channels, and `context.Done()` is used in `select` for cancellation.
  Source: https://pkg.go.dev/time#After and `#Tick`, context Overview.

## 7. IPv4 / IPv6

Not applicable to a time library; `time`/`duration`/`context` carry no network
address and are address-family agnostic.

## 8. Timeouts

- Relative timeout: `context.WithTimeout(parent, d)` which is documented as
  `WithDeadline(parent, time.Now().Add(timeout))`.
  Source: https://pkg.go.dev/context#WithTimeout .
- Absolute deadline: `context.WithDeadline(parent, d)`; "the returned
  Context.Done channel is closed when the deadline expires, when the returned
  cancel function is called, or when the parent context's Done channel is
  closed, whichever happens first."
  Source: https://pkg.go.dev/context#WithDeadline .
- Cancellation is first-class and composed: `context.AfterFunc(ctx, f)` runs
  `f` after cancellation and returns a `stop` function.
  Source: https://pkg.go.dev/context#AfterFunc .
- Timer resolution: "On Unix, the resolution is ~1ms. On Windows version 1803
  and newer, the resolution is ~0.5ms."
  Source: https://pkg.go.dev/time#hdr-Timer_Resolution .

## 9. TLS

Not applicable to a time library; there is no transport and no TLS layer.

## 10. Interesting design decisions

- **Time carries both wall and monotonic readings.** `time.Now()` returns a
  `Time` containing both; comparisons and `Sub` use the monotonic reading
  when both sides have one, else the wall reading. This gives monotonic
  elapsed-time semantics under one public type.
  Source: https://pkg.go.dev/time (Monotonic Clocks).
- **Monotonic is not part of `Duration`** and is stripped by `Round(0)`,
  `AddDate`, `In`, `Local`, `UTC`, and by all serialization.
  Source: https://pkg.go.dev/time (Monotonic Clocks).
- **Cancellation is a channel, not a callback**: `Done() <-chan struct{}`
  composes with `select`. Source: https://pkg.go.dev/context#Context .
- **Timeout is defined in terms of deadline** (`WithTimeout` = `WithDeadline`
  with `now+d`), so only one primitive is canonical.
  Source: https://pkg.go.dev/context#WithTimeout .
- **`Duration` is just an int64**: arithmetic is operator-based and overflow
  is silent, but `Abs` guards the one dangerous case explicitly.
  Source: https://pkg.go.dev/time#Duration.Abs .

## 11. Decisions NOT to copy

- **Silent int64 overflow on `Duration` arithmetic.** Go wraps; a Mojo API
  should expose checked/saturating operations. (Contrast: only `Abs` has an
  explicit guard; https://pkg.go.dev/time#Duration.Abs .)
- **Two representations in one `Time`** (wall + optional monotonic) makes the
  semantics subtle and platform-dependent ("on some systems the monotonic
  clock will stop if the computer goes to sleep"). For a library whose whole
  point is monotonic wait timing, keep the monotonic instant **separate** from
  wall time. Source: https://pkg.go.dev/time (Monotonic Clocks).
- **`context`'s Value bag**: "Use context Values only for request-scoped data
  ... not for passing optional parameters." A timeout type should not double
  as a generic key-value carrier. Source: https://pkg.go.dev/context#WithValue .
- **Cancellation via channel + `CancelFunc`** requires discipline ("Failing to
  call the CancelFunc leaks ..."); for a bounded socket wait, a plain
  `Deadline` value plus a timeout argument is simpler and leak-free.
  Source: https://pkg.go.dev/context#WithCancel .

## 12. Ideas fitting Mojo

- **Duration as a signed integer-nanosecond span** with unit accessors and
  `abs`/`round`/`truncate`, matching Go's naming closely enough to be familiar.
  Source: https://pkg.go.dev/time#Duration .
- **Timeout = deadline = now + duration** as the single canonical composition,
  exactly as Go defines `WithTimeout`. (Source: https://pkg.go.dev/context#WithTimeout .)
- **`sub`/`before`/`after`/`compare` on instants**, with the instant opaque.
  Source: https://pkg.go.dev/time#Time .
- **Explicit special-case handling at the numeric edge** (Go's `Abs` of
  `MinInt64`), which maps well to a Mojo `raises` or documented saturation.
  Source: https://pkg.go.dev/time#Duration.Abs .
- **Resolution query as documentation, not API**: Go documents timer
  resolution rather than exposing it; Mojo can document expected resolution
  similarly. Source: https://pkg.go.dev/time#hdr-Timer_Resolution .

## Sources

- `time` package: https://pkg.go.dev/time
- `time.Duration`: https://pkg.go.dev/time#Duration
- `time.Time`: https://pkg.go.dev/time#Time
- `context` package: https://pkg.go.dev/context
