# prim_endian research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `prim_endian`.

Endianness handling is a small, pure, self-contained concept (byte-order
conversion and host-endian detection) that exists in essentially every language,
so presence of support is not a discriminator: the languages below are the ones
in which byte-order handling differs in a way worth studying.

## Selected languages (frozen)

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | POSIX `htons`/`ntohs`/`htonl`/`ntohl` + `<endian.h>` `htobe*`/`be*toh`/`le*toh` are the de-facto C reference; C++20 `std::endian` + `std::byteswap` are the modern header-only design |
| systems-modern | 1 | Go, Rust | Go `encoding/binary` ByteOrder interface with `binary.BigEndian`/`LittleEndian` is the richest value-based API; Rust `to_be_bytes`/`from_be_bytes` + `from_ne_bytes` and `to_le`/`to_be` on integers are the clearest const-generic design |
| scripting-web | 1 | Python, JS/TS | Python `int.to_bytes`/`from_bytes` with `byteorder` + `sys.byteorder`; JS `DataView` with explicit `littleEndian` flag is the loosest and most used API |
| managed-JVM | 1 | Java | `java.nio.ByteBuffer.order(ByteOrder)` + `ByteOrder.nativeOrder()` — mutable cursor-carried byte order, a distinct design |
| functional/BEAM | 1 | Elixir | binary pattern-matching with `endian`/`big`/`little`/`native` size modifiers; `:erlang` byte-order builtins — a unique declarative approach |

Optional group not selected this run: **data/science** (Julia, R).

Deliberately not selected this run (available in the roster, but dropped with a
reason): C#, Zig, Odin, Swift (systems-modern — no distinct byte-order API
signal beyond the selected two; Zig `@byteSwap` is noted from the group 2 file
if found), Perl, PHP, Dart (scripting-web), Kotlin (managed-JVM — delegates to
`java.nio.ByteBuffer`), OCaml, F#, Haskell (functional/BEAM — no distinct
byte-order story beyond Elixir's binary matching).

Researchers started: **5** (one per selected group; under the limit of 6).
Mojo is read from the `mojov1` buch, not researched from the internet.

## Question set (adapted for endian)

The standard 12 questions apply in order. Three socket-specific questions are
replaced by endian equivalents; everything else is unchanged:

- Q5 (was ownership/lifetime of socket+handle) → whether conversion is
  value-returning or in-place, and the ownership semantics of the input/output
  value (integer vs. buffer slice).
- Q7 (was IPv4/IPv6) → which byte orders are represented (big, little, native,
  network) and whether a single abstraction covers all of them.
- Q9 (was TLS) → how host native endianness is detected and reported
  (compile-time constant, runtime query, or not at all).

Q6 (blocking vs async), Q8 (timeouts/cancellation) and Q10-Q12 are kept
verbatim: for a pure numeric operation the interesting answers are "not
applicable, and here is why", which is itself evidence.

## Writing contract

Each researcher writes its language files **directly** into
`akku/prim_endian/_dev/<lang>.md`, one file per language of its group, using
exactly the section structure in `.agents/workflows/NewLibPhase1Research.md`.
There is no reporting-project and no `docs` materialization pass.

Besides the source citations, derived statements are marked
`(Assessment: derived from <sources>)`; unsourced statements are marked `GUESS:`
with the reason no source exists.

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
| Mojo | (buch) | `mojo.md` | linked to buch |

Phase 1 is complete: 8 language files written directly by 5 researchers (one per
selected group), Mojo linked to the `mojov1` buch. The review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.

## Later phases

- Phase 9 baseline: `baseline-tests.log` (8 test files, 36 tests, 8/8 failing —
  the intended red state against the not-yet-implemented stubs).
