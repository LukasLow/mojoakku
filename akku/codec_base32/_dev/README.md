# codec_base32 research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `codec_base32`.

## Selected languages (frozen)

base32 is the sibling of base64 and follows the same run shape. The nine
languages are exactly the base64 run's selection, kept for comparability: base32
is a pure, self-contained codec that exists in essentially every language, so
presence is not a discriminator — the languages below are the ones in which
base32 differs in a way worth studying.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher, no
`mojo.md`).

| group | languages | reason |
| --- | --- | --- |
| systems-lowlevel | C, C++ | C has no ISO base32; gnulib and cppcodec are the de-facto C-family references, and cppcodec is the only surveyed library that ships the RFC 4648 base32/base32hex **and** Crockford variants behind one API |
| systems-modern | Go, Rust | Go's `encoding/base32` has the richest stdlib surface (standard + `HexEncoding`, stream encoder/decoder, offset errors); Rust has the strongest alphabet/padding/streaming crate designs (`base32`, `data-encoding`, `base64ct`) |
| scripting-web | Python, Perl, JS/TS | Python `base32`/`b32hex` with `casefold`/`map01`; Perl puts base32 in a separate, single-maintainer CPAN dist (`MIME::Base32`) while base64 is core; JS/TS has no platform base32 at all, only community libraries |
| managed-JVM | Java | the JDK has **no** Base32, only Base64 and `HexFormat`; Guava, Commons Codec and Bouncy Castle fill the gap with different config models |
| functional/BEAM | Elixir | `Base` covers base16/32/32hex/64/64url with `:case` and `:padding`; research covers the BEAM/Erlang side |

Researcher: **1** (this run is executed by a single researcher per the task
assignment; the base64 run's per-group split is not reproduced here). Mojo is
read from the `mojov1` buch, not researched from the internet.

## Question set (frozen, adapted for base32)

The standard 12 questions apply in order, with exactly these three adapted for
base32:

- Q5 → buffer and ownership semantics of encode input and of the produced
  output.
- Q7 → alphabet variants: standard base32 (RFC 4648 §6), base32hex (§7), case
  handling, Crockford/other, and padding. **This is the base32-specific heart.**
- Q9 → streaming / incremental chunked encode/decode and how leftover bytes
  (encode) and leftover symbols (decode) are carried across calls.

Q6 (blocking vs async), Q8 (timeouts/cancellation) and Q10-Q12 are kept
verbatim: for a pure codec the interesting answers are "not applicable, and
here is why", which is itself evidence.

## Writing contract

Each language file lives directly in `akku/codec_base32/_dev/<lang>.md` and uses
exactly the section structure of `.agents/workflows/NewLibPhase1Research.md`
with the adapted Q5/Q7/Q9 headers. Besides source citations, derived statements
are marked `(Assessment: derived from <sources>)`; unsourced statements are
marked `GUESS:` with the reason no source exists.

Base32 constants used throughout (source: RFC 4648 §6/§7/§9-10,
https://www.rfc-editor.org/rfc/rfc4648.txt):

- 5 input bytes ↔ 8 symbols, 5 bits per symbol; padding `=` to a multiple of 8.
- standard alphabet `A-Z 2-7`; base32hex alphabet `0-9 A-V`.
- valid padding lengths on decode: 0, 1, 3, 4, 6 `=`; 2, 5, 7 are impossible.
- test vectors: `"f"→MY======`, `"fo"→MZXQ====`, `"foo"→MZXW6===`,
  `"foob"→MZXW6YQ=`, `"fooba"→MZXW6YTB`, `"foobar"→MZXW6YTBOI======`;
  base32hex uses `CO======` … `CPNMUOJ1E8======`.
- encoded length = `8 * ceil(n/5)`.

## Status

| lang | file | state |
| --- | --- | --- |
| C | `c.md` | done |
| C++ | `cpp.md` | done |
| Go | `go.md` | done |
| Rust | `rust.md` | done |
| Python | `python.md` | done |
| Perl | `perl.md` | done |
| JS/TS | `js-ts.md` | done |
| Java | `java.md` | done |
| Elixir | `elixir.md` | done |
| Mojo | `mojov1/stdlib/base64` | covered by buch (no base32 in stdlib) |

All nine language files were written by the single researcher of this run. Phase
1 is complete; the review happens in `.agents/workflows/NewLibPhase2ResearchReview.md`.
