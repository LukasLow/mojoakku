# base64 research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `base64`.
Shared project file for this run: `165ad9c3` (task id `lib-base64`).

## Selected languages (frozen)

The 28-language baseline roster is a pool, not a mandate. For `base64` the
concept is a pure, self-contained codec that exists in essentially every
language, so presence of support is not a discriminator: the languages below are
the ones in which base64 differs in a way worth studying. Selection is frozen
for this run.

| lang | file | reason for inclusion |
| --- | --- | --- |
| C | `c.md` | no stdlib codec; OpenSSL/glibc ecosystem is the de-facto reference for C |
| C++ | `cpp.md` | no stdlib codec; shows how a modern C++ library shapes the API (alphabets, compile time) |
| Go | `go.md` | the richest stdlib surface: presets, `Append*` variants, streaming model, corruption offsets |
| Rust | `rust.md` | no stdlib codec; the crate ecosystem has the strongest alphabet/padding design |
| Python | `python.md` | `base64` + `binascii`; altchars/urlsafe/padding asymmetry, C-backed buffer semantics |
| Perl | `perl.md` | `MIME::Base64` XS core; 76-char line-breaking legacy and a silent decoder |
| Java | `java.md` | JDK Basic/URL/MIME + `wrap()` streams; checked exceptions, no Base32 in the JDK |
| Elixir | `elixir.md` | `Base` covers base16/32/32hex/64/64url; bang vs tuple API, SWAR notes |
| JS/TS | `js-ts.md` | `btoa`/`atob`, Node `Buffer`, `base64url`; the loosest and the most used API |

Mojo itself is covered by the `mojov1` buch, not by a researcher: Mojo facts are
read from `mojov1` (and corrected in place via `buch_update` if wrong).

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

## Reporting contract

Researchers do **not** write repo files. Each researcher reports its language
into the shared project file `165ad9c3` via `project-write`:

1. a header message with keys `lang-<lang>` (one-line status) and `path`;
2. the body chunked as `lang-<lang>-001`, `lang-<lang>-002`, ... so no single
   message is oversized.

Besides the source citations, researchers must mark derived statements with the
convention `(Assessment: derived from <sources>)`, where `<sources>` names the
section(s) or source(s) the conclusion is drawn from (e.g. `(Assessment: derived
from sections 7.2-7.4)`). An evaluation, design extrapolation or cross-source
conclusion that is not itself stated by a source carries this marker; the
existing shortened forms such as `(Assessment.)` are the same marker and must
stay distinguishable from quoted facts and from `GUESS:` items.

One `docs` agent then materializes every language into
`mojoakku/base64/.research/<lang>.md`, following the section structure in
`.agents/workflows/NewLibPhase1Research.md`.

## Status

| lang | header | body | file |
| --- | --- | --- | --- |
| C | done | done | `c.md` |
| C++ | done | done | `cpp.md` |
| Go | done (direct write) | — | `go.md` |
| Rust | done (direct write) | — | `rust.md` |
| Python | done (direct write) | — | `python.md` |
| Perl | done (direct write) | — | `perl.md` |
| Java | done (direct write) | — | `java.md` |
| Elixir | done (direct write) | — | `elixir.md` |
| JS/TS | done | done | `js-ts.md` |

The six `done (direct write)` files were produced in the first run, before the
reporting contract above existed. They stay as they are; the new contract
applies from C, C++ and JS/TS onward.
