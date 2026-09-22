# base64 research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `base64` (restart).

## Selected languages (frozen)

base64 is a pure, self-contained codec that exists in essentially every
language, so presence of support is not a discriminator: the languages below are
the ones in which base64 differs in a way worth studying.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | no stdlib codec; OpenSSL/glibc and modern C++ libraries are the de-facto C-family reference |
| systems-modern | 1 | Go, Rust | Go has the richest stdlib surface; Rust has the strongest alphabet/padding crate design |
| scripting-web | 1 | Python, Perl, JS/TS | Python `base64`/`binascii` asymmetry; Perl `MIME::Base64` XS + line-breaking legacy; JS/TS is the loosest and most used API |
| managed-JVM | 1 | Java | JDK Basic/URL/MIME + `wrap()` streams, checked exceptions, no Base32 in the JDK |
| functional/BEAM | 1 | Elixir | `Base` covers base16/32/32hex/64/64url; bang vs tuple API; research covers the BEAM/Erlang side |

Optional group not selected this run: **data/science** (Julia, R).

Deliberately not selected this run (available in the roster, but dropped with a
reason): C#, Zig, Odin, Swift (systems-modern — no base64 API signal beyond the
selected four), PHP, Dart (scripting-web), Kotlin (managed-JVM — delegates to
`java.util.Base64`), OCaml, F#, Haskell (functional/BEAM — no distinct base64
story).

Researchers started: **5** (one per selected group; well under the limit of 6).
Mojo is read from the `mojov1` buch, not researched from the internet.

## Question set (adapted for base64)

The standard 12 questions apply in order. Three socket-specific questions are
replaced by base64 equivalents; everything else is unchanged:

- Q5 (was ownership/lifetime of socket+handle) → buffer and ownership semantics
  of encode input and of the produced output.
- Q7 (was IPv4/IPv6) → alphabet variants (standard/URL-safe/others) and padding
  handling.
- Q9 (was TLS) → streaming: incremental/chunked encode and decode, and how
  leftover bytes are carried across calls.

Q6 (blocking vs async), Q8 (timeouts/cancellation) and Q10-Q12 are kept
verbatim: for a pure codec the interesting answers are "not applicable, and
here is why", which is itself evidence.

## Writing contract

Each researcher writes its language files **directly** into
`mojoakku/base64/_dev/<lang>.md`, one file per language of its group, using
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
| Perl | scripting-web | `perl.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Elixir | functional/BEAM | `elixir.md` | done |
| Mojo | (buch) | `mojov1/stdlib/base64` | covered by buch |

All nine language files were written directly by their group's researcher in the
restart run: 5 researchers, one per selected group. Phase 1 is complete; the
review happens in `.agents/workflows/NewLibPhase2ResearchReview.md`.
