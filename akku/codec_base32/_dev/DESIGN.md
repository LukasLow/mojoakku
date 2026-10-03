<!--
Design record for akku/codec_base32 — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 3 (API design, awaiting the
user approval gate and Phase 4 design review): every entry is `planned` and
`not implemented`.
-->

# codec_base32 — Design Record

## Purpose

`akku/codec_base32` is the single source of truth for the MojoAkku
`codec_base32` library. It covers the two RFC 4648 base32 schemes — base32
standard (`A-Z 2-7`) and base32hex (`0-9 A-V`) — through **one uniform API
shape**. It is designed for a low-vision user: one naming scheme, one option
model, one typed error, borrowed input, owned output and explicit streaming with
a mandatory flush. It is the **design record**, not end-user documentation:
end-user docs live inline in the `*.mojo` files. It keeps the status
bookkeeping, tests, rationale, reference-API comparisons, non-goals and open
questions; the implementation and its tests live in the code tree.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 15 entries in this document are `planned` and every entry's
`Implementation status:` is `not implemented` — this is Phase 3, before the
scaffold, test and implementation phases.

## Dependencies

`codec_base32` has **no dependency edge to any sibling MojoAkku library**. It is
a leaf in the dependency graph: it depends only on the Mojo standard library.
The catalogue file `.repo/todo/codec_base32.yml` declares
`depends_on: [codec_base64]`, but that is a **build-ordering hint in the
catalogue, not a code import**: nothing in this library's signatures or bodies
needs a type or function from `codec_base64`.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Encoding and decoding are pure in-memory transforms over `Span`, `StringSpan`, `String`, `List`, `Array`, `Bool`, `Int` and `UInt8`. No signature mentions a base64 concept, so no sibling edge can be technically justified. The catalogue's `codec_base64` ordering is satisfied by the fact that both libraries only depend on the Mojo standard library. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `codec_base32` needs none: every parameter
  and return type (`Span[UInt8]`, `StringSpan`, `String`, `List[UInt8]`, `Int`,
  `Bool`, `UInt8`) comes from the Mojo standard library. Adding an import would
  create coupling without a technical reason, which the dependency rules forbid.
- **No shared `Alphabet` type.** `codec_base32.Alphabet` and
  `codec_base64.Alphabet` are **separate types with the same name**. MojoAkku
  does **not** reuse `codec_base64.Alphabet` even though it already defines
  `B32_STANDARD`/`B32_HEX`: importing it would turn the catalogue's ordering hint
  into a real edge and make base32 depend on all of base64 for one constant.
  Each sibling owns its own value types; name symmetry (not type identity) is
  the shared convention (`go.md` §10 lists Go's base64/base32 naming symmetry as
  the model). If a future library wants to accept either, it can depend on both.
- **No physical nesting.** The absence of an edge is the conceptual statement.
  Physically, `akku/codec_base32/` is a flat sibling under `akku/`; it is never
  nested inside another library and no library is nested inside it. A dependency
  is a conceptual edge, never a parent/child relationship.
- **Direction of future edges.** If a later library (for example a DNS or MIME
  layer) needs base32, the edge points *from that library to `codec_base32`*,
  never from `codec_base32` outward. That does not change this document.

## Overview

MojoAkku `codec_base32` is a pure, in-process data-encoding library that covers
the two RFC 4648 base32 schemes — base32 standard (`A-Z 2-7`) and base32hex
(`0-9 A-V`) — through **one uniform API shape**. It is the sibling of
`codec_base64` and keeps that design's one-uniform-shape philosophy, but adapts
it to base32's geometry: **5 input bytes ↔ 8 symbols, 5 bits per symbol, `=`
padding to a multiple of 8**.

The problem space is covered by every reference language, so the value of this
library is not "another base32". It is a *predictable, consistent and
easy-to-read* surface for a low-vision user: one naming scheme, one option
model, one typed error, borrowed input, owned output and explicit streaming with
a mandatory flush. The research shows that the reference ecosystems each get one
or two of these right and rarely all at once:

- Go has the richest base32 stdlib surface (`StdEncoding`, `HexEncoding`,
  `WithPadding`, `Encode`, `EncodedLen`, a streaming encoder/decoder with an
  `end`/padding sentinel) but panics on bad configuration, uses a negative-rune
  padding sentinel and silently ignores CR/LF (`go.md` §7, §9, §11).
- Rust splits between a dedicated `base32` crate (typed `Error` with offsets,
  but no streaming and **no canonicality check**) and `data-encoding`
  (`DecodeError{position,kind}`, streaming `Encoder::append`/`finalize`,
  `check_trailing_bits`), which is the closest reference but carries a
  `Drop`-suppresses-errors footgun (`rust.md` §3, §4, §9, §11).
- Python 3.15 added `padded`/`canonical`/`ignorechars`/`casefold`/`map01`,
  confirming that padding, strictness and case should be explicit parameters,
  but the stdlib defaults to `canonical=False` and `casefold=False`, ships a
  separate `b32*`/`b32hex*` function pair per alphabet and no streaming
  (`python.md` §3, §7, §9, §11).
- Java has no JDK Base32; Commons Codec (builder, `LENIENT` default),
  Guava (`upperCase`/`lowerCase`/`ignoreCase`) and Bouncy Castle (whitespace
  ignored) fill the gap with three different config models and no typed
  offset error (`java.md` §1, §3, §4, §11).
- C and C++ expose the codec through caller-allocated buffers, `-1`
  sentinels/macros and `abort()`; cppcodec is the only C-family library with
  both RFC 4648 base32 variants and a precise `generates_padding()` /
  `requires_padding()` / `should_ignore()` contract, but it silently
  case-folds and has no streaming API (`c.md` §3, §11; `cpp.md` §7, §9, §11).
- Elixir `Base` shows the only three-way `:case` model (`:upper`/`:lower`/
  `:mixed`) and the allocation-free `valid32?` predicate, but its plain decoder
  collapses every failure to a bare `:error` and it has no streaming
  (`elixir.md` §4, §7, §9, §11).
- Perl `MIME::Base32` is the anti-reference: no error path at all, case-folding
  by `uc()` and unpadded output with no padding option (`perl.md` §4, §7, §11).
- JS/TS has no platform base32; two tiny community libraries expose a bare
  variant string plus one `padding` boolean and no canonicality checking or
  streaming (`js-ts.md` §1, §7, §9, §11).

Mojo's own stdlib has **no base32 at all**: the `mojov1/stdlib/base64` package
has exactly four functions (`b64encode`, `b64decode`, `b16encode`, `b16decode`),
takes borrowed `StringSpan`/`Span[UInt8]`, returns owned `String`/`List[UInt8]`,
and its decoders raise. Its `b32`-relevant constants do not exist, so the Mojo
anchor for the *shape* is `stdlib/base64` (`mojov1/stdlib/base64`); there is no
Mojo anchor for base32 behaviour, which is exactly the gap this library closes.

`codec_base32` depends on **no other MojoAkku library**. It can depend on the
Mojo standard library only, and nothing in this design requires a graph edge to
`codec_base64` or any other sibling. It needs no Python interpreter.

## Goals

1. **One consistent shape across both base32 alphabets.** base32 standard and
   base32hex use the same function names and the same option model, so learning
   one teaches the other. MojoAkku uses a single `encode`/`decode` surface
   because Go's base32/base64 naming symmetry and `data-encoding`'s per-constant
   API show that a uniform radix API is the most learnable, and Python's separate
   `b32*`/`b32hex*` function pairs show the cost of one function per alphabet
   (`go.md` §10, §12; `rust.md` §3; `python.md` §10).

2. **Zero-cost alphabet and policy specialization.** The alphabet and the
   padding/whitespace policies are compile-time inputs, so table lookups and
   branches are resolved while compiling and there is no runtime `variant`
   switch.

3. **Explicit policy, strict by default.** Padding, whitespace handling and
   canonicality are visible in the signature. Silent leniency is never the
   default (contrast Python's `canonical=False`, Java Commons Codec's `LENIENT`
   and Perl's silent deletion).

4. **Byte-first borrowing.** Encode borrows bytes; decode borrows encoded text;
   encode returns an owned `String`; decode returns an owned `List[UInt8]`.

5. **Allocation-free options.** A length function, an in-place encode/decode
   overload and an allocation-free validity predicate let a caller avoid
   allocations on the hot path.

6. **Structured failure.** A single typed error with a `kind` discriminant and a
   `position` so callers can distinguish bad symbol, bad length and bad padding
   (including an incomplete final quantum).

7. **Explicit streaming.** A stateful encoder and decoder carry the sub-quantum
   remainder (0–4 bytes on encode, 0–7 symbols on decode); the final flush is
   mandatory and cannot be silently skipped.

8. **Readability for a low-vision user.** Stable names, one option model, one
   error type, identical field names in every documented entry.

9. **Pure Mojo.** No hidden global state, no Python dependency, no `unsafe`
   requirement in the public surface.

## Non-Goals

Decisions the library deliberately does **not** copy, taken from the research
(`## 11` sections) or, where marked, from this design's own analysis. Each is a
`MojoAkku rejects … because …` statement naming the reference or the reasoned
design constraint.

- **Base16/hex in this library.** MojoAkku keeps `codec_base32` base32-only and
  ships **no** `HEX_LOWER`/`HEX_UPPER` alphabet and no base16 encode/decode.
  Base16 is already covered by the sibling `codec_base64` library, whose
  `Alphabet` value type names `HEX_LOWER`/`HEX_UPPER`, and whose catalogue
  summary already reads "Base64 and base32 encoding." Base32 is the remaining
  gap. Adding base16 here would duplicate an existing, tested surface in a
  second library for no user benefit. This is a **scope decision, not a backlog
  item**: there is no concrete base16 API candidate for `codec_base32`.
- **Implicit newline/whitespace ignoring.** MojoAkku rejects Go's implicit CR/LF
  skipping because `encoding/base32` strips `\r`/`\n` even though there is no
  strict mode to disable it, making the accepted input set unknowable from the
  signature (`go.md` §7, §11); whitespace tolerance is offered only as an
  explicit `Whitespace.IGNORE` policy.
- **Half-hearted whitespace tolerance.** MojoAkku rejects gnulib's "skip `\n`
  only when `ctx != NULL`" and cppcodec's `should_ignore` side effects because a
  whitespace rule that depends on how you call, or on the variant, is harder to
  reason about than one explicit policy (`c.md` §7, §10, §11; `cpp.md` §7).
- **Panic on bad configuration.** MojoAkku rejects Go's `NewEncoding`/
  `WithPadding` panics because a wrong alphabet is a programming error the
  compiler can reject and a wrong call-site option is a compile-time error, not
  a process abort (`go.md` §10, §11).
- **Negative padding sentinels.** MojoAkku rejects Go's `NoPadding = -1` rune
  because a magic negative value hides the policy from the reader; padding is a
  named `Padding` value (`go.md` §7, §11).
- **Mutable global encoding variables.** MojoAkku rejects Go's package-level
  `StdEncoding`/`HexEncoding` vars because a codec must have no hidden global
  state; the alphabets are compile-time constants, not variables
  (`go.md` §10, §11).
- **Python's separate function pair per alphabet and permissive canonicality
  default.** MojoAkku rejects `b32encode`/`b32hexencode` as separate names and
  the `canonical=False` default because one typed alphabet parameter plus a
  strict default is more uniform and safer (`python.md` §10, §11).
- **`map01` confusable mapping.** MojoAkku rejects `b32decode(map01=…)` because
  mapping `0/O` and `1/I/L` by default or opt-in is a documented security
  footgun and the default must stay strict (`python.md` §7, §11).
- **A three-way case enum in the first release.** MojoAkku rejects (defers)
  Elixir's `:case` `:upper`/`:lower`/`:mixed` and Guava's
  `ignoreCase()`/Python's `casefold` in the first release because the default is
  case-sensitive uppercase-only (Python, Go, Rust, Elixir all default that way)
  and a case policy multiplies the accepted-input matrix; the three-way enum is
  a concrete future API candidate and is recorded in `_dev/TODO.md`
  (`elixir.md` §7, §11; `python.md` §7; `java.md` §7).
- **Python's `casefold=False` as a boolean, if ever added.** Even the deferred
  case policy is a named enum, not a boolean: a boolean cannot express "all
  lower" vs "mixed" (`elixir.md` §10).
- **Java's checked exceptions and `Object`-erased bridge.** MojoAkku rejects
  `IOException`/`DecoderException` in a pure codec and the `encode(Object)`
  bridge because a malformed string is a data error, not an I/O condition, and
  Mojo is statically typed (`java.md` §11.1, §11.2).
- **Silent leniency by default.** MojoAkku rejects Commons Codec's `LENIENT`
  default (discarding non-zero trailing bits) and Bouncy Castle's unconditional
  whitespace ignoring because silent acceptance of malformed input hides
  corruption (`java.md` §4, §11.3).
- **No canonicality check.** MojoAkku rejects the dedicated Rust `base32` crate
  and Go base32, which accept non-zero trailing bits unconditionally, because
  RFC 4648 §3.5 exists precisely to prevent "multiple base-encoded strings being
  decoded to the same binary data"; `PaddingMode.STRICT` is the explicit toggle
  (`rust.md` §7, §11; `go.md` §10, §11; `c.md` §10).
- **MIME/line-wrapping options.** MojoAkku rejects OpenSSL's default 64-column
  wrapping, Perl's 76-char default and Java Commons Codec's line-length config
  because wrapping is a mail-transfer concern, not a codec concern; RFC 4648
  §3.1 says implementations must not add line feeds unless a referring spec
  directs them (`c.md` §11; `perl.md` §11; `java.md` §7, §11.5).
- **`abort()` or panic on a mis-sized output buffer.** MojoAkku rejects
  cppcodec's `noexcept`+`abort()` raw path and Rust's `BufferTooSmall` error
  because aborting the process is the wrong trade for a recoverable caller
  mistake; the in-place overloads append and the length function makes sizing
  total (`cpp.md` §4, §11; `rust.md` §11).
- **Unchecked public decode entry points.** MojoAkku rejects any "assumes valid
  input" decode because an API whose documented failure mode is undefined
  behaviour invites bugs; the checked form plus `is_valid` is enough
  (`js-ts.md` §11).
- **Per-variant class names / factory-per-alphabet.** MojoAkku rejects
  cppcodec's `base32_rfc4648`/`base32_hex` class pair and Guava's
  `base32()`/`base32Hex()` factories because a differently-named entry point per
  variant does not scale; an alphabet value plus a padding value composes
  (`cpp.md` §11; `java.md` §7, §10).
- **Bare `:error` with no reason.** MojoAkku rejects Elixir's lossy plain
  decoder because collapsing bad-symbol, bad-length and bad-padding into one atom
  destroys the diagnostic; the typed error keeps the reason (`elixir.md` §4,
  §11).
- **Silent-ignore decoding.** MojoAkku rejects Perl `MIME::Base32`'s `tr///`
  deletion and truncation because it makes malformed input indistinguishable
  from valid input and opens the RFC 4648 §3.3 covert channel (`perl.md` §4,
  §11; `c.md` §11).
- **Unpadded-only encoding.** MojoAkku rejects Perl's hard-coded unpadded output
  because RFC 4648 §3.2 pads by default and `Padding` must be an explicit,
  visible choice (`perl.md` §7, §11).
- **Timeouts, cancellation and async.** MojoAkku rejects any timeout/cancellation
  parameter because a pure memory transform has no I/O, no blocking resource and
  no await point; the research for every language records this as structurally
  not applicable (`c.md` §6, §8; `cpp.md` §6, §8; `go.md` §6, §8; `rust.md` §6,
  §8; `python.md` §6, §8; `perl.md` §6, §8; `js-ts.md` §6, §8; `java.md` §6, §8;
  `elixir.md` §6, §8).
- **Crockford, z-base-32, Nix, DNSSEC/DNSCurve and custom alphabets.** MojoAkku
  rejects (defers) these variants in the first release because the two RFC 4648
  base32 alphabets cover the real use cases and exotic alphabets multiply the
  test surface; they are concrete future API candidates and stay in
  `_dev/TODO.md` (`rust.md` §7, §10, §11; `cpp.md` §7, §11; `js-ts.md` §7).
- **I/O stream adapters.** MojoAkku rejects `io::Read`/`io::Write` wrappers
  (Commons Codec's `Base32InputStream`, Guava's `encodingStream`, Go's
  `NewDecoder`) in this library because the codec should stay a pure transform; a
  consumer can build adapters on `Encoder`/`Decoder` without a dependency edge
  here (`java.md` §9; `go.md` §9; `rust.md` §5).

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Alphabet as first-class value | Go `Encoding` with `encode[32]`/`decodeMap[256]`; `NewEncoding`, `StdEncoding`, `HexEncoding`; cppcodec one class per variant via `detail::base32<…>` | `go.md` §3, §7, §10; `cpp.md` §3, §7, §10 |
| Variant as type / zero-cost specialization | cppcodec `detail::codec<detail::base32<…>>`, `generates_padding()`/`requires_padding()`/`should_ignore()`; `data-encoding` `BASE32`/`BASE32HEX` constants | `cpp.md` §7, §10, §12; `rust.md` §3, §12 |
| Padding as explicit policy | Rust `base32` `Option<u8>` padding + valid runs `[0,6,4,3,1]`; Go `WithPadding`/`NoPadding`; Python 3.15 `padded`; Elixir `:padding` | `rust.md` §3, §7, §12; `go.md` §3, §7; `python.md` §3, §7, §12; `elixir.md` §3, §7 |
| Canonicality as explicit policy | gnulib trailing-bit masking `& 0x03`/`& 0x0f`/`& 0x01`/`& 0x07`; `data-encoding` `check_trailing_bits`; Python 3.15 `canonical`; Commons Codec `CodecPolicy.STRICT` | `c.md` §4, §10, §12; `rust.md` §7, §12; `python.md` §3, §7; `java.md` §4, §7 |
| Decode padding modes | Rust `DecodePaddingMode`; Commons Codec `LENIENT`/`STRICT`; Java "padding accepted but not required" | `rust.md` §7, §12; `java.md` §4, §7 |
| Explicit ignore/whitespace policy | gnulib `ctx`-scoped newline skipping with `ctx == NULL` = strict; cppcodec `should_ignore` = false for RFC 4648 variants; libsodium-style `ignore` (base64 sibling) | `c.md` §7, §10, §12; `cpp.md` §7 |
| Byte-first borrowed in / owned out | Mojo stdlib `b64encode(Span[UInt8]) -> String`, `b64decode(StringSpan) -> List[UInt8]`; cppcodec `encode(...) -> std::string`; Rust `encode(&[u8]) -> String` | `mojov1/stdlib/base64`; `cpp.md` §5, §12; `rust.md` §5, §12 |
| In-place / append output | Go `AppendEncode(dst, src) []byte` / `AppendDecode(dst, src) ([]byte, error)`; Java `encode(byte[],int,int)` + `getEncodedLength`; cppcodec `Result&` refill | `go.md` §3, §5, §12; `java.md` §3, §5, §12; `cpp.md` §5, §12 |
| Length functions | Go `EncodedLen`/`DecodedLen` (padded = `(n+4)/5*8`, unpadded = `n/5*8+(n%5*8+4)/5`); gnulib `BASE32_LENGTH` macro; Rust `encoded_length`/`decoded_length`; cppcodec `encoded_size`/`decoded_max_size` | `go.md` §3, §7, §12; `c.md` §3, §10, §12; `rust.md` §3, §12; `cpp.md` §3, §12 |
| Typed error with kind+offset | Rust `Error::InvalidSymbol{offset,symbol}`/`InvalidLength`/`InvalidPadding`; `data-encoding` `DecodeError{position,kind}` + `DecodeKind{Length,Symbol,Trailing,Padding}`; Go `CorruptInputError`; cppcodec `parse_error`/`invalid_input_length` | `rust.md` §4, §12; `go.md` §4; `cpp.md` §4, §12 |
| Partial output on error | Go `Decode(dst, src) (int, error)` "number of bytes successfully written and CorruptInputError"; gnulib `*outlen` on `false`; `data-encoding` `DecodePartial{read,written,error}` | `go.md` §4, §10, §12; `c.md` §4, §5; `rust.md` §4 |
| Streaming with explicit finalize | Go `NewEncoder` `Close` flush with `buf [5]byte`; gnulib `base32_decode_context {int i; char buf[8];}`; `data-encoding` `Encoder::append`/`finalize` ("required for correctness"); Commons Codec `BaseNCodec` context | `go.md` §5, §9, §12; `c.md` §5, §9, §10; `rust.md` §9, §12; `java.md` §9 |
| Streaming end-of-padding sentinel | Go decoder `end bool` "any additional data is an error"; gnulib decode stops at non-alphabet | `go.md` §9; `c.md` §4, §9 |
| Validity predicate without allocation | Elixir `valid32?`/`hex_valid32?` (justified as "more performant and memory efficient than … decode … and discard"); Commons Codec `isInAlphabet` | `elixir.md` §3, §10, §12; `java.md` §3 |
| Strict uppercase-only decode default | Python `casefold=False` ("For security purposes, the default is False"); Go base32 uppercase-only decode; Rust crates default case-sensitive; Elixir `:case` default `:upper` | `python.md` §7; `go.md` §7; `rust.md` §7; `elixir.md` §7 |
| Uniform radix shape | Go base64/base32 identical naming; Erlang one-table two-alphabet offsets | `go.md` §10, §12; `elixir.md` §7, §10 |
| Mojo language anchors | `Span`/`StringSpan` borrowed views; `List`/`String` owned; `comptime` value parameters; typed `raises` errors; `@explicit_destroy`; linear-value error paths | `mojov1/types/collections`; `mojov1/functions/parameters-and-generics`; `mojov1/errors/error-model`; `mojov1/decorators/explicit-destroy` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order.

**Option and error types**

1. `Alphabet` — compile-time value type selecting the symbol table; named
   constants `B32_STANDARD`, `B32_HEX`.
2. `Padding` — compile-time encode padding policy: `REQUIRED`, `OMITTED`.
3. `PaddingMode` — compile-time decode padding/canonicality policy: `STRICT`,
   `TOLERANT`.
4. `Whitespace` — compile-time decode whitespace policy: `REJECT`, `IGNORE`.
5. `ErrorKind` — compile-time discriminant for `Base32Error`:
   `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING`.
6. `Base32Error` — the one typed error carrying `kind: ErrorKind` and
   `position: Int`.

**One-shot encode/decode**

7. `encode` — encode borrowed bytes/text to an owned `String`; two overloads
   (`Span[UInt8]`, `StringSpan`).
8. `encode_into` — encode borrowed bytes/text into a caller-owned
   `mut result: String` and return the number of characters written; two
   overloads (`Span[UInt8]`, `StringSpan`).
9. `decode` — decode borrowed encoded text/bytes to an owned `List[UInt8]`,
   raising `Base32Error`; two overloads (`StringSpan`, `Span[UInt8]`).
10. `decode_into` — decode borrowed encoded text/bytes into a caller-owned
    `mut result: List[UInt8]` and return the number of bytes written, raising
    `Base32Error`; two overloads (`StringSpan`, `Span[UInt8]`).

**Buffer sizing and validation**

11. `encoded_len` — pure function returning the exact encoded length for `n`
    input bytes under a padding policy.
12. `decoded_len` — pure function returning the maximum decoded byte count for
    `n` encoded symbols.
13. `is_valid` — allocation-free predicate returning `Bool` for whether input
    conforms to an alphabet and the decode policies; never raises; two overloads
    (`StringSpan`, `Span[UInt8]`).

**Streaming**

14. `Encoder` — stateful encode value type owning the sub-quantum byte carry;
    `feed` + mandatory `finish` (and `discard`).
15. `Decoder` — stateful decode value type owning the sub-quantum symbol carry;
    `feed` + mandatory `finish` (and `discard`), raising `Base32Error`.

## Semantics

#### Terminology

- **Symbol** — one encoded character (one byte of the encoded text).
- **Quantum** — the smallest group of input bytes that maps to a whole number
  of symbols. base32: **5 bytes ↔ 8 symbols** (40 bits, 5 bits per symbol). The
  **carry** is the remainder of a partial quantum held by a streaming value
  between calls: 0–4 bytes on encode, 0–7 symbols on decode.
- **Padding** — the `=` symbol that completes the final partial quantum. The
  number of `=` characters is `(-n) mod 5` mapped `1→6, 2→4, 3→3, 4→1, 0→0` for
  `n mod 5`. Valid data-symbol counts in a final quantum are **2, 4, 5 or 7**;
  remainders **1, 3 and 6 are structurally impossible** (`go.md` §7; `cpp.md`
  §3; `c.md` §7).
- **Canonical** — padding is present in exactly the required count, no symbol
  follows padding, and the unused trailing bits of the final symbol are zero
  (RFC 4648 §3.5; `c.md` §4, §10).

All lengths are in bytes/symbols, not codepoints. All inputs are treated as
raw bytes; the library never performs UTF-8 conversion or normalisation.

---

### `Alphabet`

Status: planned

Signature:

```mojo
struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime B32_STANDARD = Alphabet(0)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(1)   # RFC 4648 §7,  0-9 A-V
```

Semantics:

- **Parameters / preconditions:** none; the value is a compile-time constant
  used as a function/struct **value parameter** (`[alphabet: Alphabet]`). The
  type is documented as **opaque**: the two `comptime` members are the complete
  public set, while the `_id` field and its `@doc_hidden` initializer are
  implementation details. Mojo has **no access control** — `_name` and
  `@doc_hidden` are conventions, not permissions
  (`mojov1/decorators/doc-hidden`) — so the constructor is technically reachable
  inside the package; the library defines behaviour only for `_id` values 0–1
  and no public entry point accepts a caller-supplied alphabet id. Callers use
  the named constants.
- **Return / meaning:** identifies the symbol table and the 5 bits-per-symbol
  geometry. Only the two RFC 4648 alphabets exist: `B32_STANDARD` (`A-Z 2-7`)
  and `B32_HEX` (`0-9 A-V`). There is **no URL-safe base32** (Go has none
  either, `go.md` §7) and **no Crockford** in this release. The alphabet does
  **not** carry a padding policy: padding is chosen by the separate
  `Padding`/`PaddingMode` parameter, so padded and unpadded variants are both
  expressible without a preset per combination (contrast Go's
  `RawStdEncoding`-style presets, `go.md` §3, §7).
- **Case policy (decode):** case handling is a fixed property of the alphabet,
  not a separate option, so the accepted symbol set is exactly what the alphabet
  constant names. Both `B32_STANDARD` and `B32_HEX` are **case-sensitive,
  uppercase-only**: lowercase `a-z`/`a-v` is `INVALID_SYMBOL`. Source: Python
  documents `casefold=False` as the default for `b32decode`/`b32hexdecode`,
  i.e. lowercase is not accepted unless requested (`python.md` §7); Go's base32
  `decodeMap` is built only from the uppercase alphabet and lowercase input is
  an illegal byte (`go.md` §7); both Rust base32 crates default to
  case-sensitive, with case-insensitivity an explicit opt-in
  (`rust.md` §7); Elixir's `:case` defaults to `:upper` (`elixir.md` §7). The
  encoder always emits uppercase. There is **no `Casefold`/`:case` parameter**
  in this release: a caller needing a different case policy maps the input or
  output itself, which keeps one option model and one alphabet value (Goals 1
  and 3). cppcodec's silent lowercase acceptance
  (`normalized_symbol`, `cpp.md` §7) and Perl's `uc()` case-folding
  (`perl.md` §7) are deliberate non-copies; a three-way case enum
  (`Upper`/`Lower`/`Mixed`) is a concrete future candidate in `_dev/TODO.md`
  (`elixir.md` §7; `python.md` §7; `java.md` §7).
- **Ownership:** value type; copied by value at compile time only. No heap, no
  lifetime.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply because the type is a
  compile-time constant and performs no I/O.

Errors: none in practice. The two named constants are the only `Alphabet`
values in the public *contract*, so code that stays on public names never
supplies an invalid alphabet (`go.md` §10 rejects the runtime `NewEncoding`
panic). This is a documented convention boundary, not a compiler-enforced one:
because Mojo has no access control, the `@doc_hidden` initializer is
technically reachable inside the package, and the library defines behaviour only
for `_id` values 0–1. Values outside that set are outside the API and their
behaviour is unspecified.

Tests:

- `test_base32_alphabet.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a compile-time Alphabet value parameter
because Go's runtime `Encoding` value is selected through `NewEncoding`, which
panics on a bad table and stores the encoding in mutable global `var`s
(`go.md` §7, §10, §11), while cppcodec's variant-as-type and Mojo's documented
value-parameter specialization remove all runtime alphabet dispatch
(`cpp.md` §10, §12; `mojov1/functions/parameters-and-generics` "value
parameters for compile-time specialization"). The buch documents scalar
(`factor: Int`) and `String` (`msg: String = "woof"`) value parameters plus a
*parameterized struct type* (`struct Bar[v: Int]`) — which is not the same as
using a user-struct **value** as a value-parameter type. Whether a user-defined
struct value is accepted as a value-parameter type is not evidenced by the buch;
the sibling `codec_base64` library proved in its Phase 7/11 that it works, so
this design relies on that sibling evidence and records it under
`## Open Questions`. If Phase 7 finds it unsupported, the fallback is a `UInt8`
id value parameter plus documented constants.

---

### `Padding` (encode policy)

Status: planned

Signature:

```mojo
struct Padding(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime REQUIRED = Padding(0)   # emit '=' to complete the final quantum
    comptime OMITTED  = Padding(1)   # never emit '='
```

Semantics:

- **Parameters / preconditions:** used as `[padding: Padding = Padding.REQUIRED]`
  on `encode`/`encode_into`/`Encoder`/`encoded_len`. Only the two named
  `comptime` members are part of the public set; the `_id` field and its
  `@doc_hidden` initializer are implementation details (no `@fieldwise_init`).
  Mojo has no access control, so the constructor is technically reachable inside
  the package, but the library defines behaviour only for ids 0–1.
- **Return / meaning:** controls only what the encoder **emits**. Decode is
  governed separately by `PaddingMode`, mirroring cppcodec's split of
  `generates_padding()` from `requires_padding()` (`cpp.md` §7, §10).
  `REQUIRED` emits the RFC 4648 §6 padding count after the data symbols: for
  `n mod 5` of `1, 2, 3, 4, 0` it emits `6, 4, 3, 1, 0` `=` characters,
  completing the final quantum to 8 symbols; `OMITTED` emits none.
- **Ownership:** value type; compile-time only.
- **Stream I/O:** not applicable (compile-time value, no I/O).

Errors: none.

Tests:

- `test_base32_padding.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses an explicit Padding value instead of an
implicit lax mode because Python 3.15's `padded` and Elixir's `:padding` show
users expect padding to be a deliberate, visible choice, while Go's
`WithPadding`/`NoPadding` and Rust's `Option<u8>` padding show the same on the
systems side (`python.md` §3, §7, §12; `elixir.md` §3, §7; `go.md` §3, §7;
`rust.md` §3, §7, §12). Perl's hard-coded unpadded output is the rejected
anti-pattern (`perl.md` §7, §11).

---

### `PaddingMode` (decode policy)

Status: planned

Signature:

```mojo
struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime STRICT   = PaddingMode(0)   # require canonical padding / no padding
    comptime TOLERANT = PaddingMode(1)   # padding optional, but consistent if present
```

Semantics:

- **Parameters / preconditions:** used as
  `[padding_mode: PaddingMode = PaddingMode.STRICT]` on `decode`/`decode_into`/
  `Decoder`/`is_valid`.
- **Return / meaning:**
  - `STRICT` — RFC 4648 canonical input only: if the final quantum is partial,
    the exact number of `=` symbols must be present (data-symbol counts 2, 4, 5
    or 7); a full final quantum must carry no `=`; a partial quantum with no
    padding is `INVALID_PADDING`. This is Rust's `RequireCanonical` plus a
    canonicality check (`rust.md` §7; `c.md` §4, §10).
  - `TOLERANT` — the final quantum may be padded or unpadded (Java's "accepted
    and interpreted …, but is not required"). If padding is present its count
    must still be exactly right, padding may only occur at the end, and no
    symbol may follow it, and a remainder of 1, 3 or 6 data symbols stays
    structurally impossible (`java.md` §7; `rust.md` §7 `Indifferent`).
    `TOLERANT` also **accepts non-zero trailing bits** in the final symbol
    (Rust `Indifferent` with `decode_allow_trailing_bits=true`); `STRICT`
    rejects them as `INVALID_SYMBOL`. The two modes therefore differ on
    canonicality, not only on padding (`rust.md` §7; `python.md` §7).
  - Unlike `codec_base64`, there is **no third `RequireNone` state**. A caller
    who must reject `=` scans for the padding symbol before choosing
    `TOLERANT`; `STRICT` is the complement and the default. Python's
    `canonical` flag is folded into this pair rather than exposed separately, so
    padding and canonicality stay one policy (contrast Python's separate
    `padded`/`canonical`, `python.md` §7, §11).
- **Ownership:** value type; compile-time only.
- **Stream I/O:** not applicable (compile-time value, no I/O).

Errors: invalid padding under either mode raises `INVALID_PADDING` (or
`INVALID_LENGTH` for a structurally impossible remainder); the error is a data
error and is recoverable.

Tests:

- `test_base32_padding_mode.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a two-value PaddingMode because Rust's
`Indifferent`/`RequireCanonical` pair and Commons Codec's
`LENIENT`/`STRICT` `CodecPolicy` show that padding/canonicality is a decode
policy distinct from the encode policy, while Java shows the tolerant mode is
useful for real-world interop (`rust.md` §7, §12; `java.md` §4, §7). Go's and
the dedicated Rust crate's absence of any canonicality check is the rejected
gap (`go.md` §10, §11; `rust.md` §7, §11).

---

### `Whitespace` (decode policy)

Status: planned

Signature:

```mojo
struct Whitespace(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime REJECT = Whitespace(0)   # default: any whitespace is INVALID_SYMBOL
    comptime IGNORE = Whitespace(1)   # skip space, tab, CR, LF, FF, VT
```

Semantics:

- **Parameters / preconditions:** used as
  `[whitespace: Whitespace = Whitespace.REJECT]` on `decode`/`decode_into`/
  `Decoder`/`is_valid`. With `IGNORE`, skipped whitespace advances the
  original-stream index used for `position`; it is simply not part of any
  quantum.
- **Return / meaning:** makes whitespace tolerance explicit. `REJECT` differs
  from Go base32 (which ignores `\r`/`\n` unconditionally) and from Bouncy
  Castle (which ignores whitespace with no strict switch); `IGNORE` preserves
  that tolerance as an opt-in (`go.md` §7, §9, §11; `java.md` §7, §11.3).
  Elixir's `Base` offers no `:ignore` for base32 at all, so `Whitespace` is
  MojoAkku's own explicit addition, shaped after gnulib's `ctx`-scoped newline
  skipping but without the pointer-dependent semantics (`elixir.md` §3;
  `c.md` §7, §10).
- **Ownership:** value type; compile-time only.
- **Stream I/O:** not applicable (compile-time value, no I/O).

Errors: under `REJECT`, a whitespace byte raises `INVALID_SYMBOL`; under
`IGNORE` whitespace never fails.

Tests:

- `test_base32_whitespace.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses an explicit Whitespace value because
gnulib's "newlines only when a context is passed" is a pointer-dependent
contract that is easy to miss (`c.md` §7, §10, §11), and Go's unconditional
newline skipping is a documented non-copy (`go.md` §7, §11); cppcodec's RFC 4648
variants correctly ignore nothing (`cpp.md` §7), which `REJECT` makes the
default.

---

### `ErrorKind`

Status: planned

Signature:

```mojo
struct ErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime INVALID_SYMBOL  = ErrorKind(0)   # byte not in alphabet / not padding, or non-zero trailing bits under STRICT
    comptime INVALID_LENGTH  = ErrorKind(1)   # impossible remainder for the alphabet
    comptime INVALID_PADDING = ErrorKind(2)   # wrong count/placement of '='

    # Writes the symbolic name, not the numeric _id, so `print(err)` reads
    # "INVALID_LENGTH" rather than "ErrorKind(_id=1)".
    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `Base32Error.kind`; never passed by
  a caller to a codec.
- **Return / meaning:** the machine-testable reason for a decode failure.
  `INVALID_LENGTH` is a whole-input structural error (base32 remainder 1, 3 or
  6 data symbols); `INVALID_PADDING` is a placement/count error; `INVALID_SYMBOL`
  is a bad byte. Under `PaddingMode.STRICT` the same `INVALID_SYMBOL` kind also
  covers a final symbol whose unused trailing bits are non-zero: the byte *is*
  in the alphabet, so it is not a separate alphabet failure, and folding it into
  `INVALID_SYMBOL` keeps the public discriminant at three values (dedicated
  `INVALID_TRAILING_BITS` and `INCOMPLETE` kinds are deliberately not added).
  The three kinds correspond to Rust's `Error`
  (`InvalidSymbol`/`InvalidLength`/`InvalidPadding`) and to `data-encoding`'s
  `DecodeKind { Length, Symbol, Trailing, Padding }` with `Trailing` likewise
  folded into `Symbol`; Python's `binascii.Incomplete` is a stream-retry hint,
  not a distinct data condition (`rust.md` §4; `python.md` §4).
- **Ownership:** value type; compile-time constants copied into the error value.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_base32_errors.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a three-value discriminant because Rust's
`base32::Error` and `data-encoding::DecodeError` both carry a machine-usable
kind plus an offset, and Elixir's bare `:error`, Perl's silent deletion and
gnulib's `false`-without-reason are the documented failure modes of collapsing
reasons (`rust.md` §4, §12; `elixir.md` §4, §11; `perl.md` §4, §11; `c.md` §4).

---

### `Base32Error`

Status: planned

Signature:

```mojo
@fieldwise_init
struct Base32Error(Copyable, Deinitable, Writable):
    var kind: ErrorKind
    var position: Int

    # Readable diagnostic: writes the symbolic `kind` name and the `position`
    # (the inherited `Writable` contract used by `print(err)`).
    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library; callers read the
  two fields in an `except`/`try` block. `position` is the zero-based index into
  the **original input stream** at which the failure was detected. For the
  one-shot functions the input is the single argument, so this is the index into
  that argument. For a streaming `Decoder` the index is **cumulative across the
  whole stream**: the total number of symbols fed before the offending one, so it
  is independent of how the input was split into chunks (`data-encoding`'s
  `position` "represents the first encountered error", `rust.md` §4, §9). Under
  `Whitespace.IGNORE`, skipped whitespace still advances the count (it occupies a
  position in the original stream). For `INVALID_LENGTH` `position` is the index
  of the first symbol of the structurally impossible remainder; for
  `INVALID_PADDING` it is the index at which the offending/partial final quantum
  begins; for `INVALID_SYMBOL` it is the index of the offending symbol.
  `position` never points past the number of symbols seen so far.
- **Return / meaning:** the single typed error every decoder declares via
  `raises Base32Error`. Implemented as a plain struct and `Writable`, following
  Mojo's typed-error model (`mojov1/errors/error-model`).
- **Ownership:** value type; `Copyable` and `Deinitable`, so it can be bound and
  inspected. It is deliberately **not** `ImplicitlyCopyable`, so a re-raise must
  transfer with `raise e^`; `raise e` (which copies) does not compile for a
  non-`ImplicitlyCopyable` error type
  (`mojov1/errors/error-model`, "Deinitialization and linear interactions").
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: a pure codec has no file
  descriptor, no blocking call and no external handle, so none of those
  conditions can arise. This is itself evidence that the codec sits above the
  I/O layer (research §6/§8 for every language; `c.md` §6; `go.md` §6).

Errors: it **is** the error. All decode failures are data errors and are
recoverable: the caller may fix the input, truncate at `position`, or switch
policy and retry. No decoder error is fatal or unrecoverable.

Tests:

- `test_base32_errors.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a struct with `kind`+`position` because
Rust's `InvalidSymbol{offset,symbol}` and cppcodec's `invalid_input_length`
show that a codec must report *where* and *why*, while Java's checked
`IOException`/`DecoderException` and Go's offset-only `CorruptInputError`
show the two failure modes to avoid (an I/O exception type for a data error,
and a position without a reason) (`rust.md` §4, §12; `cpp.md` §4, §12;
`java.md` §11.1, §11.2; `go.md` §4).

---

### `encode`

Status: planned

Signature:

```mojo
def encode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8]) -> String

def encode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan) -> String
```

Semantics:

- **Parameters / preconditions:** `input` is the raw bytes (first overload) or
  UTF-8 text treated as raw bytes (second overload; no UTF-8 conversion is
  performed, each byte is encoded). `input` is borrowed and may be empty; an
  empty input returns an empty `String`. `alphabet` and `padding` are
  compile-time; the defaults are standard base32 with required padding, so
  `encode(bytes)` is the predictable default.
- **Return / meaning:** an owned `String` containing exactly `encoded_len`
  characters of encoded text: full 5-byte quanta become 8 symbols, and a final
  partial quantum becomes 2, 4, 5 or 7 data symbols plus the padding count
  selected by `Padding`. Never raises for any input.
- **Ownership:** `input` is borrowed (immutable reference, `Span`/`StringSpan`,
  never copied or consumed). The returned `String` is newly allocated and owned
  by the caller; the library retains no reference to either. No hidden global
  state is read or written.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply; encode is a pure
  in-memory transform with no descriptor and no blocking point.

Errors: none for any `Span[UInt8]`/`StringSpan`; encode cannot fail. (This
matches gnulib's `base32_encode`, whose only "failure" is a caller buffer that
is too small, `c.md` §4.)

Tests:

- `test_base32_encode.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses borrowed-bytes-in / owned-String-out
because the Mojo stdlib's `b64encode` and cppcodec's
`encode(const uint8_t*, size_t) -> std::string` both borrow input while
returning a fresh value, and Rust's `encode(&self, data: &[u8]) -> String`
confirms the direction (`mojov1/stdlib/base64`; `cpp.md` §5, §12;
`rust.md` §5, §12).

---

### `encode_into`

Status: planned

Signature:

```mojo
def encode_into[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8], mut result: String) -> Int

def encode_into[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan, mut result: String) -> Int
```

Semantics:

- **Parameters / preconditions:** `input` is borrowed bytes (first overload) or
  UTF-8 text treated as raw bytes (second overload, matching `encode`'s
  `StringSpan` overload); `result` is a caller-owned, mutable `String`. The
  implementation must `reserve` capacity itself; `result` may have zero capacity
  on entry. The existing contents of `result` are appended to, not overwritten
  (append semantics, like Go's `AppendEncode`, `go.md` §3, §5).
- **Return / meaning:** the number of encoded characters appended to `result`.
  No new heap allocation is required beyond `result`'s own growth.
- **Ownership:** caller owns `result` and controls its allocator. On return,
  `result` is valid and contains its prior contents plus the encoded text.
  `input` stays borrowed. The function never retains a reference to either.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply (pure transform).

Errors: none; encode cannot fail.

Tests:

- `test_base32_encode_into.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses an appending in-place `mut result` overload
because Go's incremental building block is the `Append*` family —
`AppendEncode(dst, src) []byte` grows the caller's buffer — and Java's
`encode(byte[],int,int)` + `getEncodedLength` show the caller-buffer form
(`go.md` §3, §5, §12; `java.md` §3, §5). Append, not overwrite-at-offset-0, is
the documented contract; a caller who wants offset-0 behaviour clears `result`
first. This mirrors the Mojo stdlib in-place writer style
(`mojov1/stdlib/base64`).

---

### `decode`

Status: planned

Signature:

```mojo
def decode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) raises Base32Error -> List[UInt8]

def decode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8]) raises Base32Error -> List[UInt8]
```

Semantics:

- **Parameters / preconditions:** `input` is the encoded text (`StringSpan`) or
  the same bytes (`Span[UInt8]`); it is borrowed and may be empty (an empty
  input decodes to an empty `List[UInt8]`). The accepted symbol set, including
  which letter case is accepted, is fixed by `alphabet` (see the
  `### Alphabet` **Case policy (decode)**). The defaults are strict RFC 4648
  canonical input with whitespace rejected.
- **Return / meaning:** a newly allocated `List[UInt8]` of the decoded bytes.
  On success the result length is at most `decoded_len(input_length)`; it is
  exact only for a full final quantum that also carries no skipped bytes —
  because `decoded_len` counts every input symbol, including `=` padding symbols
  and (under `Whitespace.IGNORE`) whitespace bytes. With padding present or under
  `IGNORE`, `decoded_len` is an upper bound.
- **Ownership:** `input` is borrowed; the returned `List[UInt8]` is owned by the
  caller. The library holds no reference after return.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: there is no stream, no
  descriptor and no partial-read concept; "short input" is a data-length error,
  not an I/O condition.

Errors: `raises Base32Error`. `INVALID_LENGTH` for a structurally impossible
quantum remainder (1, 3 or 6 data symbols); `INVALID_PADDING` for
missing/excess/misplaced `=`; `INVALID_SYMBOL` for a byte outside the alphabet
(including lowercase, and whitespace under `REJECT`) or for a non-zero trailing
bit under `STRICT` canonical checking. There is no streaming-only kind:
`decode` and a streaming `finish` report the same three kinds for the same
malformed input. All are recoverable data errors. On failure no `List[UInt8]`
value is produced — the allocating form is atomic (contrast Go's partial output,
which is available through `decode_into`/`Decoder` instead; `go.md` §4, §10).

Tests:

- `test_base32_decode.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a `raises Base32Error` decoder returning an
owned `List[UInt8]` because the Mojo stdlib's `b64decode` already raises and
returns fresh bytes, and Rust's typed `Error` plus Python's `binascii.Error`
show the failure must carry a reason (`mojov1/stdlib/base64`; `rust.md` §12;
`python.md` §12).

---

### `decode_into`

Status: planned

Signature:

```mojo
def decode_into[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan, mut result: List[UInt8]) raises Base32Error -> Int

def decode_into[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8], mut result: List[UInt8]) raises Base32Error -> Int
```

Semantics:

- **Parameters / preconditions:** `input` is borrowed encoded text (`StringSpan`)
  or the same bytes (`Span[UInt8]`); `result` is a caller-owned, mutable
  `List[UInt8]`, possibly empty. The accepted symbol set and case policy are
  fixed by `alphabet` (see the `### Alphabet` **Case policy (decode)**). The
  implementation reserves capacity itself. Existing contents are appended to
  (append semantics).
- **Return / meaning:** the number of decoded bytes appended. On error, the
  complete quanta decoded before the first invalid quantum remain appended and
  the count of bytes appended is not returned (the error propagates instead);
  callers who need the partial progress can compare `len(result)` before and
  after. This mirrors Go's documented "number of bytes successfully written and
  CorruptInputError" (`go.md` §4, §10) and `data-encoding`'s `DecodePartial{
  read, written, error }` (`rust.md` §4), while keeping the return type simple.
- **Ownership:** caller owns `result`; on both success and error `result` is
  valid. `input` stays borrowed.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply (pure transform).

Errors: same `Base32Error` kinds as `decode`, all recoverable. A partial
prefix may already be appended when the error is raised; the appended prefix
is always a whole number of bytes (complete quanta only), never a partial
byte.

Tests:

- `test_base32_decode_into.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a partial-commit appending in-place decoder
because Go's `AppendDecode(dst, src) ([]byte, error)` grows the caller's
buffer and returns partial output alongside its error, and Go documents the
count as "the number of bytes successfully written and CorruptInputError"
(`go.md` §3, §4, §10, §12); data-encoding documents the same contract as
`DecodePartial{read, written, error}` (`rust.md` §4). This makes error recovery
first-class. cppcodec's `abort()` on an undersized buffer is rejected
(`cpp.md` §4, §11).

---

### `encoded_len`

Status: planned

Signature:

```mojo
def encoded_len[
    padding: Padding = Padding.REQUIRED,
](n: Int) -> Int
```

Semantics:

- **Parameters / preconditions:** `n` is the number of raw input bytes and must
  be `>= 0`; a negative argument is a caller programming error. Compile-time-
  callable: it is a pure, non-raising `def` with no FFI, so it may be used inside
  `comptime(...)` and in buffer sizing. There is deliberately **no `alphabet`
  parameter**: both RFC 4648 base32 alphabets share the 5↔8 geometry, so the
  alphabet cannot change the length. This is a base32-specific divergence from
  `codec_base64`'s `encoded_len[alphabet, padding]`, where the alphabet selects
  the radix and therefore the formula.
- **Return / meaning:** the exact encoded length:
  - `REQUIRED`: `8 * ((n + 4) // 5)`.
  - `OMITTED`: `(n * 8 + 4) // 5`, equivalently `8 * ((n + 4) // 5)` minus the
    RFC 4648 §6 padding count (the `n % 5` map `0/1/2/3/4 → 0/6/4/3/1`).
  - `n = 0` returns `0` in both cases. Matches gnulib's `BASE32_LENGTH` macro
    `((((n) + 4) / 5) * 8)` and Go's padded `(n+4)/5*8` / unpadded
    `n/5*8+(n%5*8+4)/5` (`c.md` §3, §10, §12; `go.md` §3, §7, §12).
- **Ownership:** pure function; no allocation, no state, no lifetime.
- **Stream I/O:** not applicable; the function performs no I/O.

Errors: none. The function is **total**: `n < 0` is a caller programming
error and is **defined** to return `0` (the empty-input length) rather than to
trap, keeping the function non-raising and compile-time-callable. Callers must
pass non-negative lengths; the defined `0` is a safety net, not a licence to
size a buffer for a negative count.

Tests:

- `test_base32_encoded_len.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a pure exact `encoded_len` because gnulib's
`BASE32_LENGTH` macro, Go's `EncodedLen`, Java Commons Codec's
`getEncodedLength` and cppcodec's `encoded_size` all exist to pre-size a buffer,
and a typed total function is strictly better than a preprocessor macro that
cannot fail safely (`c.md` §3, §10, §12; `go.md` §3, §12; `java.md` §3, §12;
`cpp.md` §12).

---

### `decoded_len`

Status: planned

Signature:

```mojo
def decoded_len(n: Int) -> Int
```

Semantics:

- **Parameters / preconditions:** `n` is the total input byte count used as a
  conservative upper bound (number of encoded symbols, including any padding
  and, under `Whitespace.IGNORE`, whitespace bytes; `>= 0`).
  Compile-time-callable (pure, non-raising, no FFI). There is deliberately **no
  parameter**: the base32 geometry is fixed, and padding mode does not change
  the bound because `n` counts `=` symbols like any other symbol.
- **Return / meaning:** the **maximum** number of decoded bytes for `n` symbols:
  `(n // 8) * 5` plus the partial-quantum contribution `n % 8` of `2, 4, 5, 7`
  contributing `1, 2, 3, 4` bytes respectively; a remainder of `1, 3, 6` is
  structurally impossible and contributes `0`. The map is therefore
  `2→1, 4→2, 5→3, 7→4`, everything else `→0`. Because `n` counts `=` symbols
  like any other input symbol, this is an upper bound whenever padding is
  present; the exact value is obtained from `decode`/`decode_into`.
  `n = 0` returns `0`. Aligns with Go's `DecodedLen` and Rust's
  `decoded_length`/`decoded_max_size` (`go.md` §3, §7; `rust.md` §3, §12;
  `cpp.md` §12).
- **Ownership:** pure function; no allocation, no state.
- **Stream I/O:** not applicable.

Errors: none. Total function: `n < 0` is a caller programming error and is
**defined** to return `0`, consistent with `encoded_len`.

Tests:

- `test_base32_decoded_len.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a maximum-size `decoded_len` because Go's
`DecodedLen`, Rust's `decoded_len_estimate` and cppcodec's `decoded_max_size`
all need a conservative output bound before decoding, and Mojo's explicit buffer
sizing benefits from a total function (`go.md` §3, §12; `rust.md` §3, §12;
`cpp.md` §12).

---

### `is_valid`

Status: planned

Signature:

```mojo
def is_valid[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) -> Bool

def is_valid[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8]) -> Bool
```

Semantics:

- **Parameters / preconditions:** `input` is the encoded text (`StringSpan`) or
  the same bytes (`Span[UInt8]`) to check, borrowed and possibly empty (an empty
  input is valid under every policy). The accepted symbol set and case policy
  are fixed by `alphabet` (see the `### Alphabet` **Case policy (decode)**).
  The policy parameters have the same meaning as in `decode`.
- **Return / meaning:** `True` iff `decode` with the same parameters would
  succeed, without allocating the decoded output. It performs the full decode
  validation — symbol-table membership (uppercase-only for both alphabets),
  quantum structure, padding count and placement, and, under
  `PaddingMode.STRICT`, the final symbol's zero trailing bits — but builds no
  output bytes (`elixir.md` §10, §12; `go.md` §7; `c.md` §4, §10).
- **Ownership:** `input` borrowed; returns a scalar `Bool`; the function
  allocates nothing and retains nothing.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply; no I/O occurs.

Errors: never raises. Every malformed condition is reported as `False`,
never as `Base32Error`.

Tests:

- `test_base32_is_valid.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses an allocation-free validity predicate because
Elixir's `valid32?`/`hex_valid32?` exist precisely to validate "without
allocating the decoded output", and the docs justify them as more efficient
than decode-then-discard (`elixir.md` §10, §12); Java's `isInAlphabet` shows the
same idea at symbol granularity (`java.md` §3).

---

### `Encoder` (streaming encode)

Status: planned

Signature:

```mojo
@explicit_destroy("call finish() or discard() before this encoder leaves scope")
struct Encoder[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](Deinitable where False):
    def __init__(out self)

    def feed(mut self, chunk: Span[UInt8], mut out: String) -> Int

    def feed(mut self, chunk: StringSpan, mut out: String) -> Int

    def finish(deinit self, mut out: String) -> Int

    def discard(deinit self)
```

Semantics:

- **Parameters / preconditions:** `feed` accepts successive borrowed chunks of
  any length, including empty, as either raw bytes (`Span[UInt8]`) or text
  (`StringSpan`); the two overloads mirror the one-shot `encode`. `out` is a
  caller-owned mutable `String` appended to. `finish`/`discard` consume the
  encoder. The carry size is `quantum_bytes - 1` (base32: **0–4 bytes**), stored
  in a small fixed `Array[UInt8, 8]` plus a count; it is never exposed.
- **Return / meaning:** `feed` returns the number of encoded characters appended
  for this chunk, encoding only complete 5-byte quanta and holding the
  remainder. `finish` encodes the final partial quantum (with padding if
  `Padding.REQUIRED`), appends it, and returns the number appended. `finish` is
  the **only** place padding is emitted, so no padding can appear mid-stream.
- **Ownership:** the encoder owns its carry; `out` is caller-owned. `feed`
  borrows the chunk, which may be freed by the caller immediately after `feed`
  returns. `finish`/`discard` consume `self` (`deinit self`), so calling
  `finish` after `discard` or vice versa is impossible by construction.
- **Stream I/O / flush contract:** EOF is not an I/O event here: it is the
  caller's call to `finish`. EINTR/EAGAIN and close do not apply. An abandoned
  `Encoder` is a compile-time error, so the final flush can never be silently
  skipped — exactly the guarantee Rust's `Drop` on `data-encoding::Encoder`
  deliberately does not give (`rust.md` §9, §11, §12). In Mojo 1.x
  `@explicit_destroy` **no longer** opts a struct out of `Deinitable`; the
  documented opt-out is the explicit conformance declaration
  `struct Encoder[…](Deinitable where False):`, which the declaration above
  carries together with the required error-string argument
  (`mojov1/decorators/explicit-destroy`, "Pitfalls").

Errors: none; encode cannot fail. `discard(deinit self)` drops the remainder
without emitting it — the explicit, non-silent way to abandon a stream.

Tests:

- `test_base32_encoder.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a `feed`/`finish` value type with a
mandatory `finish` because Go's `NewEncoder` requires `Close` to flush the final
partial block and carries a `[5]byte` buffer (`go.md` §5, §9, §12), and
data-encoding's `Encoder::finalize` is documented as "required for correctness,
otherwise some encoded data may be missing at the end" (`rust.md` §9, §12);
`@explicit_destroy` enforces the same contract with a compile-time diagnostic
instead of a silent `Drop`.

---

### `Decoder` (streaming decode)

Status: planned

Signature:

```mojo
@explicit_destroy("call finish() or discard() before this decoder leaves scope")
struct Decoder[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](Deinitable where False):
    def __init__(out self)

    def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) raises Base32Error -> Int

    def feed(mut self, chunk: Span[UInt8], mut out: List[UInt8]) raises Base32Error -> Int

    def finish(deinit self, mut out: List[UInt8]) raises Base32Error -> Int

    def discard(deinit self)
```

Semantics:

- **Parameters / preconditions:** `feed` accepts successive borrowed encoded-text
  chunks of any length, as either `StringSpan` or `Span[UInt8]`; the two
  overloads mirror the one-shot `decode`. `out` is a caller-owned mutable
  `List[UInt8]` appended to. `finish`/`discard` consume the decoder. The carry
  size is `quantum_symbols - 1` (base32: **0–7 symbols**), stored in a small
  fixed `Array[UInt8, 8]` plus a count; it is never exposed.
- **Return / meaning:** `feed` decodes symbols left to right, appends each
  complete 8-symbol quantum to `out`, holds back the sub-quantum remainder, and
  returns the number of bytes appended for this chunk. `finish` validates the
  final partial quantum and mirrors `decode` exactly:
  - a partial quantum whose symbol count is **structurally impossible** for the
    alphabet (base32 data-symbol remainder 1, 3 or 6) raises `INVALID_LENGTH`;
  - a structurally valid partial quantum (base32 data-symbol count 2, 4, 5 or 7)
    that, under `PaddingMode.STRICT`, lacks its canonical padding raises
    `INVALID_PADDING`; under `TOLERANT` it is completed without padding.
  Streaming introduces no extra kind; each input yields the same kind from
  `finish` as from `decode`. `finish` returns the bytes appended.

  **End-of-stream state (`Decoder`-only).** A padded final quantum is a
  *complete* quantum, so `feed` decodes it; but once a padding symbol has been
  consumed the logical stream has ended. `Decoder` therefore carries a persistent
  **stream-ended** flag. After it is set, any further non-ignored symbol in a
  later `feed` (or in `finish`) raises `INVALID_PADDING`, so
  `feed("MZXW6YTBOI======")` then `feed("AAAA")` fails just like
  `decode("MZXW6YTBOI======AAAA")`. This is Go's `end bool`/padding sentinel
  (`go.md` §9). Together with the hold-back rule this makes the streaming result
  equal to the one-shot result for the same concatenated bytes:
  `feed(c₁); … ; feed(cₙ); finish()` ≡ `decode(c₁ ++ … ++ cₙ)` — same output, same
  error kind, same `position`. This is a documented design requirement to be
  proven by the Phase-9/11 tests, not a buch fact.

  `discard(deinit self)` drops the retained carry **without validating it and
  without touching `out`**: an unvalidated partial quantum is silently abandoned
  (never decoded, never reported), `out` keeps exactly the complete quanta
  appended by prior `feed` calls, and the call cannot raise. It is the explicit,
  non-silent way to end a stream without flushing a remainder.
- **Ownership:** the decoder owns its carry; `out` is caller-owned. `feed` takes
  `mut self` — it **does not consume self**; the chunk is borrowed for the
  duration of the call only and may be freed immediately after `feed` returns.
  Only `finish`/`discard` take `deinit self` and consume the decoder.
- **Post-error state:** `feed` takes `mut self` — a *borrow*, not ownership —
  and Mojo raises by returning an error value, not by unwinding, so a raise ends
  the call and returns control with the caller still owning an initialized
  `Decoder`. That is the error model's rule: an error "interrupts normal
  execution flow … execution resumes" at the caller, and an explicitly destroyed
  ("linear") value must still be consumed on the error path — here by the
  caller's eventual `finish`/`discard` (`mojov1/errors/error-model`,
  "Deinitialization and linear interactions"). The decoder is therefore **not
  "poisoned" in a language-enforced sense**; the restriction is a documented
  usage rule, not a type-system state. `feed` does **not** consume `self`, so
  after a raise a further `feed(mut self, …)` resumes from the retained carry
  and a `finish(deinit self, …)` validates only what remains. The documented
  recovery is to stop using the errored decoder: call `discard(deinit self)` (or
  `finish` as appropriate) and start a fresh `Decoder` for unrelated input.
  **Phase-7 obligation:** the carry-atomicity detail — that each symbol is
  validated before it mutates the carry, so the carry holds only fully validated
  sub-quantum symbols on a raise — is a design requirement to be proven by the
  Phase-9/11 tests, not a buch fact.
- **Stream I/O / flush contract:** EOF is the caller's call to `finish`, not an
  I/O event; EINTR/EAGAIN and close do not apply. `@explicit_destroy` makes the
  final flush mandatory.

Errors: `raises Base32Error`. `feed` can raise `INVALID_SYMBOL` (a byte
outside the alphabet, including lowercase, or whitespace under `REJECT`) and
`INVALID_PADDING` (a padding symbol seen mid-stream, i.e. while more input is
still expected, or any symbol after the stream has ended); it **cannot** raise
`INVALID_LENGTH`, because `feed` holds back every sub-quantum remainder, so a
total-length impossibility is only knowable at `finish`. `finish` raises the full
`decode` set — `INVALID_SYMBOL`, `INVALID_LENGTH` (structurally impossible
remainder 1/3/6) and `INVALID_PADDING` (non-canonical padding on a structurally
valid remainder) — identically to `decode`. There is no streaming-only kind. All
are recoverable data errors. Complete quanta decoded before an error remain
appended (partial-commit semantics, as in `decode_into`). `is_valid` reports the
same verdict as `decode` for the same input and policies (see `### is_valid`).

Tests:

- `test_base32_decoder.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a streaming decoder carrying ≤7 symbols
because gnulib's `base32_decode_context { int i; char buf[8]; }` is exactly this
carry for pipes and sockets (`c.md` §5, §9, §10), Go's decoder holds leftover
encoded input and uses an `end` padding sentinel (`go.md` §9), and data-encoding
is the closest Rust reference with a documented mandatory `finalize`
(`rust.md` §9, §12); Elixir/Python/JS leave the carry to the caller and are the
gap this closes (`elixir.md` §9, §11; `python.md` §9, §12; `js-ts.md` §9, §11).

## Error Surface

There is exactly **one** error type: `Base32Error`, declared with
`raises Base32Error` on every decoder. It carries:

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | `ErrorKind` | `INVALID_SYMBOL`, `INVALID_LENGTH` or `INVALID_PADDING`. |
| `position` | `Int` | Zero-based index into the original input where the failure was detected. |

Which API can raise which kind:

| API | Raises | Kinds |
| --- | --- | --- |
| `encode`, `encode_into` | no | — |
| `encoded_len`, `decoded_len` | no | — |
| `is_valid` | no | — (returns `Bool`) |
| `decode`, `decode_into` | yes | `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING` |
| `Decoder.feed` | yes | `INVALID_SYMBOL`, `INVALID_PADDING` (never `INVALID_LENGTH`; a length impossibility is only knowable at `finish`) |
| `Decoder.finish` | yes | `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING` (same set as `decode`) |
| `Encoder.feed`, `Encoder.finish`, `Encoder.discard` | no | — |
| `Decoder.discard` | no | — |

Rules:

- **One error type per function.** Mojo allows at most one error type per
  signature; `Base32Error` is it. Callers that need a different error type wrap
  it at their own boundary (`mojov1/errors/error-model`).
- **Recoverable vs not.** Every kind is a *data* error and is recoverable: the
  caller may correct input, truncate at `position`, or change policy and retry.
  No codec failure is fatal or unrecoverable. There is no `assert`/abort path in
  the public surface.
- **No I/O errors.** `EINTR`, `EAGAIN`/would-block, `EOF` as an error, and
  close/shutdown errors **cannot** occur: the library performs no system call
  and owns no descriptor or handle. "End of input" is an explicit `finish`
  call, not a read returning zero. This absence is a property of a pure codec
  and is recorded for every reference language in the research (`c.md` §6, §8;
  `go.md` §6, §8; `java.md` §8; `rust.md` §8; `python.md` §8; `js-ts.md` §8;
  `elixir.md` §8; `perl.md` §6, §8; `cpp.md` §6, §8).
- **No allocation errors.** A failed allocation surfaces as Mojo's usual
  allocation failure, not as `Base32Error`; the length function lets callers
  avoid the situation.
- **Diagnostics.** `Base32Error` implements `Writable`, so `print(e)` yields a
  readable, allocation-cheap message including the kind and position, in the
  spirit of cppcodec's allocation-free `symbol_error` (`cpp.md` §4, §10).

## Conventions

These are the rules every entry in this document follows, and the rules every
sibling MojoAkku library copies.

- **One entry per public API member, in design order.** Names are stable; the
  `## Public API` list and the `## Semantics` entries are in the same order.
- **Identical field names and order in every entry.** Each entry uses exactly:
  `Status:`, `Signature:`, `Semantics:`, `Errors:`, `Tests:`,
  `Implementation status:`, `Rationale:`. No field is omitted, even when its
  value is `none` or empty.
- **Signature is the exact Mojo declaration.** It is copied verbatim from the
  approved design; Phase 7 stubs it unchanged. The documented `Span[UInt8]`
  spelling means `Span[UInt8, _]` (Mojo 1.x requires the origin parameter); see
  `## Open Questions`.
- **Semantics is complete.** It covers parameters/preconditions,
  return/meaning, ownership, and the stream-I/O / flush contract as applicable,
  plus any entry-specific policy (for example the `Alphabet` case policy, the
  base32 padding-count map, or the `Decoder` end-of-stream state).
- **Errors names every raised or returned error and says whether it is
  recoverable.** Pure functions say `none`.
- **Tests names the test file that covers the entry.** It is present for every
  entry after the test phase; the field is never removed.
- **Rationale is a `MojoAkku uses X because Y` statement** carried over from the
  design, naming the reference API and its research section.
- **Status and implementation status are honest.** Every entry is `planned` /
  `not implemented` in Phase 3 and becomes `implemented` after Phase 12/13.
- **Terminology is shared.** Symbol, quantum, carry, padding and canonical are
  defined once in `## Semantics ## Terminology` and used consistently.
- **Markdown tables use `|`.** No pipe-escaping artifacts; sources are cited as
  `<lang>.md §<section>`.

## Ownership and Lifecycle

**Borrowed input, owned output.** Every encode takes `Span[UInt8]` or
`StringSpan` by immutable reference and never copies or consumes it; every
decode does the same. Every allocating call returns a freshly owned `String`
(encode) or `List[UInt8]` (decode). This is the Mojo stdlib contract and the
cppcodec value-returning contract (`mojov1/stdlib/base64`; `cpp.md` §5, §12),
and it makes the C "input borrowed, output caller-owned" rule compiler-checked
instead of documented (`c.md` §5, §12).

**In-place output.** `encode_into` takes `mut result: String` and
`decode_into` takes `mut result: List[UInt8]`; the callee appends and the
caller owns and sizes the buffer. Argument exclusivity (Mojo) guarantees the
input and output cannot alias (`mojov1/types/collections`), which replaces C's
unenforceable `restrict` (`c.md` §5, §11).

**Streaming state.** `Encoder` and `Decoder` are value types owning only a
small fixed `Array` carry plus a count. They own no heap and no external
resource, so `@explicit_destroy` is used only to make the final flush
*mandatory*, not to manage memory. `feed` borrows `self` and its chunk;
`finish`/`discard` take `deinit self` and consume the value. Because automatic
destruction is disabled, the carry is released only when a named destructor
(`finish`/`discard`) runs; there is no ASAP `__deinit__` path for these types
(`mojov1/decorators/explicit-destroy`; `mojov1/errors/error-model`). The C
burden of a manually freed decode context and the Rust `Drop`-suppresses-errors
footgun both disappear (`c.md` §5, §9; `rust.md` §9, §11, §12).

**No hidden global state.** There are no mutable globals: alphabets, pad
policies and error kinds are `comptime` constants, so two threads (or two
fibers) using the library share nothing mutable. This directly answers Go's
package-level `var StdEncoding`/`HexEncoding` (`go.md` §10, §11) without needing
a lock. Thread-safety is therefore unconditional: the API has no shared mutable
state.

**Pure Mojo.** The design uses only `Span`, `StringSpan`, `String`, `List`,
`Array`, `Bool`, `Int`, `UInt8`, `comptime` parameters, typed `raises`, and
`@explicit_destroy`. It requires no Python interpreter, no `unsafe_*` operation
in the public surface, and no C dependency. `unsafe_ptr` would only appear in a
caller's own construction of a `Span` over foreign memory, never inside this
library (`mojov1/types/collections`; `c.md` §12).

**Lifecycle summary.**

| API | Consumes input? | Owns output? | Can be abandoned? |
| --- | --- | --- | --- |
| `encode` / `decode` | no (borrow) | caller owns result | yes (ordinary return) |
| `encode_into` / `decode_into` | no (borrow) | caller owns `result` | yes (ordinary return) |
| `is_valid` / length fns | no (borrow) | no allocation | n/a |
| `Encoder` / `Decoder` | no (borrow chunk) | caller owns `out` | **no** — `finish`/`discard` required |

## Open Questions

Most decisions are closed against the reviewed research and the `mojov1` buch.
**None** remains genuinely open at Phase 3; the items below are recorded as
closed so the Phase 4 review can verify them.

**Closed**

- **Scope: base16 is excluded.** `codec_base32` ships base32 standard and
  base32hex only. Base16 is already covered by `codec_base64`'s
  `Alphabet.HEX_LOWER`/`HEX_UPPER`, and the `codec_base64` catalogue summary
  says "Base64 and base32 encoding." This is a final scope decision, not a
  backlog candidate (see `## Non-Goals`).
- **The catalogue edge `depends_on: [codec_base64]` is not a code import.**
  `codec_base32` is a leaf that depends only on the Mojo standard library. The
  catalogue edge is a build-ordering hint; no type or function is imported from
  `codec_base64` (see `## Dependencies`).
- **Decode case policy is uppercase-only, fixed per alphabet.** `B32_STANDARD`
  and `B32_HEX` accept only their uppercase spellings; lowercase is
  `INVALID_SYMBOL`. Python (`casefold=False`), Go (uppercase-only), Rust
  (case-sensitive default) and Elixir (`:upper` default) agree; cppcodec's
  silent lowercase acceptance and Perl's `uc()` are documented non-copies. A
  three-way case enum is a backlog item, not part of this release.
- **Padding and canonicality are one decode policy (`PaddingMode`).**
  `STRICT`/`TOLERANT` folds Python's separate `padded`/`canonical`, Rust's
  `Indifferent`/`RequireCanonical` and Commons Codec's `LENIENT`/`STRICT` into
  one named choice; a caller needing "padding forbidden" scans for `=` first.
- **Whitespace tolerance is a policy, not implicit.** `Whitespace.REJECT` is the
  default; `IGNORE` is the explicit opt-in, replacing Go's unconditional
  newline skip and gnulib's pointer-dependent tolerance.
- **The error surface is a single typed struct with a `kind` discriminant and a
  `position`,** which Mojo supports directly (`mojov1/errors/error-model`).
- **Re-raising is `raise e^`:** `Base32Error` is `Copyable` but not
  `ImplicitlyCopyable`, so the transfer form is required
  (`mojov1/errors/error-model`).
- **`encode_into`/`decode_into` append;** this matches Go's `AppendEncode`/
  `AppendDecode` and the Mojo stdlib in-place writer, so the justification cites
  `Append*` rather than overwrite-at-offset-0 (`go.md` §3, §5, §12;
  `mojov1/stdlib/base64`).
- **`encoded_len`/`decoded_len` take no alphabet parameter,** unlike
  `codec_base64`: both base32 alphabets share the 5↔8 geometry, so an alphabet
  parameter would be a no-op (`go.md` §7; RFC 4648 §6, §7).
- **`decoded_len` gives an explicit partial-quantum contribution** for base32
  (`2→1, 4→2, 5→3, 7→4`; `1/3/6→0`).
- **Streaming uses `@explicit_destroy` with named `finish`/`discard` methods
  taking `deinit self`,** which Mojo 1.x documents and enforces
  (`mojov1/decorators/explicit-destroy`).
- **There is no I/O,** so EOF/EINTR/EAGAIN/close are structurally not
  applicable.

**Closed against sibling implementation evidence (codec_base64)** — to be
re-verified by Phase 7 if the compiler differs:

- **User-struct value as a value-parameter type works.** `codec_base64`'s
  Phase 7/11 compiled `[alphabet: Alphabet = …]` with user-defined `Alphabet`,
  `Padding`, `PaddingMode` and `Whitespace` values; the `UInt8`-id fallback is
  not expected to be needed. The buch's own page documents scalar and `String`
  value parameters and parameterized *types* but not user-struct values.
- **The named destructor signature works.** `codec_base64` compiled
  `finish(deinit self, mut out: String) -> Int` and its `raises` decoder form;
  callers transfer with `^` (e.g. `enc^.finish(out)`).
- **`Span[UInt8]` spelling.** Mojo 1.x requires an explicit origin, so the
  implementation is expected to write the idiomatic `Span[UInt8, _]`
  (wildcard origin). This is a syntax necessity, not an API change.

## Resolved during implementation (to be filled in Phase 7 / 11)

- (empty) — Phase 3 records no implementation-resolved items yet.
