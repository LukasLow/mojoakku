# io research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `io`.

## What the library is

`mojoakku/io` is **Byte and text streams**: the read/write abstraction layer that
every later networking library (`socket` → `tcp` → `http`) sits on. The Mojo
standard library covers console I/O, files and the **write** traits
(`Writer`/`Writable`) — see `mojov1/stdlib/io` — but it has **no `Reader` trait
and no generic byte/text stream abstraction**. That gap is this library's
reason to exist; the write side is the stdlib-first case (wrap/extend).

## Selected languages (frozen)

Streams exist in every language, so presence of support is not a discriminator.
The languages below are the ones whose **stream/reader-writer designs differ in a
way worth studying**.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | C `FILE*`/POSIX `read`/`write` with `-1`+`errno`; C++ `iostream`/`streambuf` with sentinel `EOF` and formatted vs unformatted layers — the two oldest stream models |
| systems-modern | 1 | Go, Rust | Go's minimal `io.Reader`/`io.Writer` interfaces are the cleanest small contract; Rust's `Read`/`Write` traits with `Result<usize>` + `ErrorKind` are the strongest error-typed stream design |
| scripting-web | 1 | Python, JS/TS | Python's `IOBase`/file-like protocol with `read`/`readline` conventions; Node `Readable`/`Writable` + WHATWG streams for async/backpressure |
| managed-JVM | 1 | Java | the richest layering: `InputStream`/`Reader` vs `OutputStream`/`Writer`, decorators (`Buffered*`), and checked `IOException` |
| functional/BEAM | 1 | Elixir | `IO`/`IO.Stream` plus the Erlang port/process I/O model; passive vs active modes (a distinct blocking story) |

Optional group not selected this run: **data/science** (Julia, R) — no distinct
stream API signal beyond the selected languages.

Deliberately not selected this run (available in the roster, but dropped with a
reason): C#, Zig, Odin, Swift (systems-modern — no stream design beyond the
selected four); Perl, PHP, Dart (scripting-web — `IO::Handle` adds nothing over
Python/JS; PHP streams are wrapper-URL centric, not a reader/writer design);
Kotlin (managed-JVM — delegates to `java.io`); OCaml, F#, Haskell (functional/BEAM
— `Lwt`/`Pipes`/lazy `IO` add no signal beyond Go/Rust/Elixir).

Researchers started: **5** (one per selected group; well under the limit of 6).
Mojo is read from the `mojov1` buch, not researched from the internet.

## Question set (adapted for io)

The standard 12 questions apply in order. The socket-specific questions are
replaced by io equivalents; everything else is unchanged:

- Q5 (was ownership/lifetime of socket+handle) → ownership and lifetime of the
  read/write buffer, the stream handle and its buffered state; who allocates and
  who frees.
- Q7 (was IPv4/IPv6) → byte streams vs text streams: how the two are
  distinguished, how buffering is layered, and how a partial read (fewer bytes
  than requested) is reported.
- Q9 (was TLS) → end-of-stream and error signalling: how EOF is reported, how a
  short/zero read differs from an error, and how a stream signals failure.

Q6 (blocking vs non-blocking) and Q8 (timeouts/cancellation) are kept verbatim —
for streams they are core design, not "not applicable".

## Writing contract

Each researcher writes its language files **directly** into
`mojoakku/io/_dev/<lang>.md`, one file per language of its group, using exactly
the section structure in `.agents/workflows/NewLibPhase1Research.md`. There is no
reporting-project and no `docs` materialization pass.

Besides the source citations, derived statements are marked
`(Assessment: derived from <sources>)`; unsourced statements are marked `GUESS:`
with the reason no source exists.

The Mojo side is **not** a generated file: it lives in the `mojov1` buch
(`mojov1/stdlib/io`) and is read from there.

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
| Elixir | functional/BEAM | `elixir.md` | done |
| Mojo | (buch) | `mojov1/stdlib/io` | covered by buch |

All eight language files were written directly by their group's researcher: 5
researchers, one per selected group. Phase 1 is complete; the review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.
