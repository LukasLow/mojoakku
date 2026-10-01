# os_poll research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `os_poll`.

## What the library is

`akku/os_poll` is **Readiness**: synchronous file-descriptor readiness with
**bounded** waits — a portable `poll()`-style query ("which of these fds is
readable/writable/hung-up right now, waiting at most this long?"). It is NOT
async: no event loop, no callbacks, no runtime, no O_NONBLOCK requirement — one
thread waits and gets control back when an fd is ready or the timeout elapses.
It is the dependency the future `net_socket` rebuild uses to make every wait
(connect/read/write/accept) timeout-bounded in-code (see
`akku_later/net_socket/_dev/TODO.md`).

## Selected languages (frozen)

Every selected language has a fd-readiness primitive or a directly relevant
readiness abstraction, and each adds a distinct design signal.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | the origin: POSIX `poll`/`select`/`ppoll` with `-1`+`errno`, `pollfd`, three timeout units; C++ `chrono` durations and explicit status enums as the modern fix |
| systems-modern | 1 | Go, Rust | Go `x/sys/unix.Poll`/`Ppoll` (thin blocking wrapper) vs the runtime netpoller; Rust nix/rustix `PollFd<'fd>` + `PollTimeout` newtype with fallible `Duration` conversion and typed overflow |
| scripting-web | 1 | Python, JS/TS | Python `select`/`selectors` two-layer model with PEP 475 EINTR-retry-and-recompute; Node has NO synchronous fd readiness (libuv-internal) — documented as the anti-reference |
| managed-JVM | 1 | Java, Kotlin | Java `Selector`/`SelectionKey` (`OP_READ`/`OP_WRITE` bitmask, `select(timeout)`, deferred cancellation) over epoll/kqueue/poll; Kotlin delegates to it and to `platform.posix` |

Optional group not selected this run: **functional/BEAM** (Elixir, OCaml, F#,
Haskell) — no fd-readiness design beyond the selected languages.
**data/science** (Julia, R) not selected — no distinct readiness signal.

Deliberately not selected this run (available in the roster, dropped with a
reason): C#, Zig, Odin, Swift (systems-modern — no readiness design beyond
C/Go/Rust); Perl, PHP, Dart (scripting-web — no synchronous poll API signal worth
a separate file); functional/BEAM (Erlang delegates to `poll`, covered by the
POSIX group's principle).

Researchers started: **4** (one per selected group; under the limit of 6). Mojo
is read from the `mojov1` buch, not researched from the internet.

## Question set (adapted for os_poll)

The standard 12 questions apply in order. The socket-specific questions are
replaced by readiness equivalents; everything else is unchanged:

- Q5 (was ownership/lifetime of socket+handle) → ownership and lifetime of the
  fd, the pollfd array and the result set; who allocates and who frees; whether
  the fd may be closed while being polled.
- Q7 (was IPv4/IPv6) → which kernel primitives exist (select/poll/epoll/kqueue/
  IOCP) and how a single portable abstraction covers them.
- Q9 (was TLS) → bounded vs unbounded waits, EINTR/signal handling, and
  timeout-unit overflow (e.g. `int` milliseconds truncating a large bound to
  infinity).

Q6 (blocking vs non-blocking) and Q8 (timeouts/cancellation) are kept verbatim —
for readiness they are core design, not "not applicable".

## Writing contract

Each researcher writes its language files **directly** into
`akku/os_poll/_dev/<lang>.md`, one file per language of its group, using exactly
the section structure in `.agents/workflows/NewLibPhase1Research.md`, with the
frozen headings `## 1. Standard library support` … `## 12. Ideas fitting Mojo`
and a `## Sources` section. There is no reporting-project and no `docs`
materialization pass. Every factual claim carries a source (URL or
`repo/path:line`); unsourced statements are marked `GUESS:` with the reason.

The Mojo side is **not** a generated file: it lives in the `mojov1` buch
(`mojov1/interop/calling-c`, `mojov1/errors/error-model`,
`mojov1/memory/ownership-and-lifetimes`, `mojov1/keywords/comptime`) and is read
from there.

## Status

| lang | group | file | state |
| --- | --- | --- | --- |
| C | systems-lowlevel | `c.md` | done |
| C++ | systems-lowlevel | `cpp.md` | done |
| Go | systems-modern | `go.md` | done |
| Rust | systems-modern | `rust.md` | done |
| Python | scripting-web | `python.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Kotlin | managed-JVM | `kotlin.md` | done |
| Mojo | (buch) | `mojov1/interop/calling-c` | covered by buch |

All eight language files were written directly by their group's researcher: 4
researchers, one per selected group. Phase 1 is complete; the review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.
