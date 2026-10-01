# time_clock (Time) — Phase 1 research: frozen run config

Library: **`time_clock`** ("Time") — clocks, durations and instants.
Scope: a monotonic `Clock`, a signed `Duration` (span + arithmetic), and a
`Deadline` (instant on a monotonic clock + arithmetic), plus the clock/time
error surface. `net_socket`'s bounded waits depend on exactly these.

This file records the run configuration frozen by the Manager for Phase 1
(`NewLibPhase1Research.md`, Step 2). It is not end-user documentation.

## Selected languages and groups

One `researcher` covered all four groups. Mojo is served by the `mojov1` buch
and is **not** researched here; no `mojo.md` exists.

| Group | Languages | File(s) |
| --- | --- | --- |
| systems-lowlevel | C, C++ | `c.md`, `cpp.md` |
| systems-modern | Go, Rust | `go.md`, `rust.md` |
| scripting-web | Python, JS/TS | `python.md`, `js_ts.md` |
| managed-JVM | Java, Kotlin | `java.md`, `kotlin.md` |

Non-mandatory roster languages (C#, Zig, Odin, Swift, Perl, PHP, Dart, and the
functional/BEAM and data/science groups) were dropped for this run.

## One-line reason per language

- **C** — the POSIX clock/duration substrate (`clock_gettime`, `nanosleep`,
  `struct timespec`); the minimal baseline every other design improves on.
- **C++** — `std::chrono`'s `duration` + `time_point` + `steady_clock`; the
  canonical typed-duration/instant model this library should emulate.
- **Go** — `time.Duration`/`time.Time` (wall+monotonic in one type) and
  `context.WithTimeout`/`WithDeadline`; the timeout representation that a
  socket layer must interoperate with.
- **Rust** — `std::time::Duration`/`Instant` with the explicit
  checked/saturating method family; the safety model for overflow and
  representability.
- **Python** — `time.monotonic()`/`monotonic_ns()` plus `datetime.timedelta`;
  shows the float-vs-integer split and injectable clock metadata.
- **JS/TS** — `performance.now()` (monotonic, resolution-coarsened) vs
  `Date.now()`, and `setTimeout`/`clearTimeout`; the non-blocking/event-loop
  timeout model and its delay-overflow pitfalls.
- **Java** — `java.time.Duration` (dual seconds+nanos, signed, immutable) and
  `System.nanoTime()`; the directed-duration representation and the documented
  overflow-safe deadline comparison.
- **Kotlin** — `kotlin.time.Duration` (value class, `INFINITE`) +
  `TimeSource`/`TimeMark`/`TestTimeSource`; opaque source-bound instants and
  first-class test time.

## Frozen standardized question set

Every language file answers these in this exact order under these exact H2
headings (`NewLibPhase1Research.md`, Step 3):

1. Standard library support
2. Relevant community libraries
3. Exposed APIs
4. Error representation
5. Ownership semantics
6. Blocking / non-blocking
7. IPv4 / IPv6
8. Timeouts
9. TLS
10. Interesting design decisions
11. Decisions NOT to copy
12. Ideas fitting Mojo

For this domain, questions 7 (IPv4/IPv6) and 9 (TLS) are not applicable and
are answered explicitly with a one-line reason.

## Source rule

Every factual claim cites a URL or a `repo/path:line`. Unsourced statements are
marked `GUESS:` with the reason. The Mojo side is covered by the `mojov1`
buch, not by a generated `_dev/mojo.md`.
