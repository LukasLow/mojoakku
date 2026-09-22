# BASE64_DOCS

## Purpose

`mojoakku/base64` is the single source of truth for the MojoAkku `base64`
library. It defines the public API, the full semantics of every entry, the error
surface, the ownership and lifecycle rules, and the conventions that every
sibling library copies. It is designed for a low-vision user: one naming scheme,
one option model, one typed error, borrowed input, owned output and explicit
streaming with a mandatory flush. This document contains no implementation and no
tests; those follow in later phases.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. Default in this phase. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 15 entries in this document are `planned`, and every entry's
`Implementation status:` is `not implemented`, in this phase.

## Dependencies

`base64` has **no dependency edge to any sibling MojoAkku library**. It is a
leaf in the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Encoding and decoding are pure in-memory transforms over `Span`, `StringSpan`, `String`, `List` and `Array`. No signature mentions a socket, file, buffer, URL or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `base64` needs none: every parameter and
  return type (`Span[UInt8]`, `StringSpan`, `String`, `List[UInt8]`, `Int`,
  `Bool`, `UInt8`, `Array`) comes from the Mojo standard library. Adding an edge
  would create coupling without a technical reason, which the dependency rules
  forbid.
- **No physical nesting.** The absence of an edge is the conceptual statement.
  Physically, `mojoakku/base64/` is a flat sibling under `mojoakku/`; it is never
  nested inside another library and no library is nested inside it. A dependency
  is a conceptual edge, never a parent/child relationship.
- **Direction of future edges.** If a later library (for example an HTTP or MIME
  layer) needs base64, the edge points *from that library to `base64`*, never
  from `base64` outward. That does not change this document.

## Overview

MojoAkku `base64` is a pure, in-process data-encoding library that covers the
RFC 4648 family — base64 (standard), base64url, base32 (standard), base32hex and
base16/hex — through **one uniform API shape**. It is the single source of truth
for the library; it contains no implementation and no tests.

The problem space is well covered by every reference language, so the value of
this library is not "another base64". It is a *predictable, consistent and
easy-to-read* surface for a low-vision user: one naming scheme, one option
model, one typed error, borrowed input, owned output, and explicit streaming
with a mandatory flush. The research shows that the reference ecosystems each
get one or two of these right and rarely all at once:

- Go has the richest stdlib surface and a uniform radix naming (`StdEncoding`,
  `WithPadding`, `Encode`, `EncodedLen`) but panics on bad configuration, uses a
  negative-rune padding sentinel, silently ignores newlines and stores the
  encoding in mutable global `var`s (`go.md` §11).
- Rust has the strongest alphabet/padding/error design (typed `DecodeError` with
  offsets, `DecodePaddingMode`, three-way output ownership) but ships deprecated
  free functions next to the engine, panics on overflow, and suppresses write
  errors in `Drop` (`rust.md` §3, §4, §11).
- Python 3.15 added `padded`/`canonical`/`ignorechars`, confirming that padding
  and strictness should be explicit parameters, but the stdlib still ships a
  lossy `validate=False` default and a legacy file-object API (`python.md` §3,
  §11).
- Java has allocate-and-return, caller-buffer and `String` forms plus
  `withoutPadding()` and typed stream wrappers, but no base32, checked
  exceptions in a pure codec and `Object`-erased bridges (`java.md` §1, §11).
- C and C++ expose the codec through caller-allocated buffers, `-1` sentinels
  and `abort()` (`c.md` §3, §11; `cpp.md` §11).
- Elixir `Base` shows the allocation-free `valid64?` predicate and a single
  option model, but its plain decoders collapse every failure to `:error`
  (`elixir.md` §4, §11).
- Perl `MIME::Base64` is the anti-reference: malformed input is silently
  ignored and line-wrapping is the default (`perl.md` §4, §11).

Mojo's own stdlib `base64` package (`mojov1/stdlib/base64`) is the direct Mojo
anchor: it has exactly four functions (`b64encode` with three overloads
including `mut result: String`, `b64decode`, `b16encode`, `b16decode`), takes
borrowed `StringSpan`/`Span[UInt8]`, returns owned `String`/`List[UInt8]`, and
its decoders raise. It has **no alphabet parameter, no base32, and no
streaming** — the three gaps this library closes.

`base64` depends on **no other MojoAkku library**. It is a leaf in the
dependency graph: it can depend on the Mojo standard library only, and nothing
in this design requires a graph edge to `socket`, `tcp` or any other sibling.
It needs no Python interpreter.

## Goals

1. **One consistent shape across the whole radix family.** base64, base64url,
   base32, base32hex and base16/hex all use the same function names and the same
   option model, so learning one teaches the rest. MojoAkku uses a single
   `encode`/`decode` surface because Go's base64/base32 naming symmetry and
   `data-encoding`'s per-constant API show that a uniform radix API is the most
   learnable, and Go's separate `hex` package for base16 shows the cost of
   inconsistency (`go.md` §10, §12; `rust.md` §3).

2. **Zero-cost alphabet specialization.** The alphabet and the padding/whitespace
   policies are compile-time inputs, so table lookups and branches are resolved
   while compiling and there is no runtime `variant` switch.

3. **Explicit policy, strict by default.** Padding, whitespace handling and
   canonicality are visible in the signature. Silent leniency is never the
   default.

4. **Byte-first borrowing.** Encode borrows bytes; decode borrows encoded text;
   encode returns an owned `String`; decode returns an owned `List[UInt8]`.

5. **Allocation-free options.** Length functions, an in-place encode/decode
   overload and an allocation-free validity predicate let a caller avoid
   allocations on the hot path.

6. **Structured failure.** A single typed error with a `kind` discriminant and a
   `position` so callers can distinguish bad symbol, bad length and bad padding
   (including an incomplete final quantum).

7. **Explicit streaming.** A stateful encoder and decoder carry the sub-quantum
   remainder; the final flush is mandatory and cannot be silently skipped.

8. **Readability for a low-vision user.** Stable names, one option model, one
   error type, identical field names in every documented entry.

9. **Pure Mojo.** No hidden global state, no Python dependency, no `unsafe`
   requirement in the public surface.

## Non-Goals

Decisions the library deliberately does **not** copy, taken from the research
(`## 11` sections) or, where marked, from this design's own analysis. Each is a
`MojoAkku rejects … because …` statement naming the reference or the reasoned
design constraint.

- **Implicit newline/whitespace ignoring.** MojoAkku rejects Go's implicit CR/LF
  skipping because `encoding/base64` strips newlines even under `Strict()`, which
  makes the accepted input set unknowable from the signature (`go.md` §7, §11);
  whitespace tolerance is offered only as an explicit `Whitespace.IGNORE`
  policy.
- **Panic on bad configuration.** MojoAkku rejects Go's `NewEncoding`/`WithPadding`
  panics because a wrong alphabet is a programming error the compiler can reject
  and a wrong call-site option is a compile-time error, not a process abort
  (`go.md` §11).
- **Negative padding sentinels.** MojoAkku rejects Go's `NoPadding = -1` rune
  because a magic negative value hides the policy from the reader; padding is a
  named `Padding` value (`go.md` §11).
- **Mutable global encoding variables.** MojoAkku rejects Go's package-level
  `StdEncoding`/`RawStdEncoding` vars because a codec must have no hidden global
  state; the presets are compile-time constants, not variables (`go.md` §11).
- **Lax cross-alphabet decode.** MojoAkku rejects Node's `'base64'` accepting
  the URL-safe alphabet (and js-base64's mixed-alphabet `isValid`) because it
  blurs which encoding was validated; the alphabet is chosen explicitly
  (`js-ts.md` §7, §11).
- **Python's legacy file-object API and two Base16 spellings.** MojoAkku rejects
  `base64.encode`/`decode(input, output)` and the `hexlify`/`b16encode`
  duplication because two overlapping surfaces with different container types
  are unlearnable; streaming is its own typed abstraction and base16 has one
  name (`python.md` §11).
- **Python's `map01` confusable mapping.** MojoAkku rejects `b32decode(map01=…)`
  because mapping `0/O` and `1/I/L` by default is a documented security footgun
  and the default must stay strict (`python.md` §7, §11).
- **Java's `Object`-erased bridge and checked exceptions in a pure codec.**
  MojoAkku rejects `encode(Object)`/`DecoderException` because Mojo is statically
  typed and a malformed string is a data error, not an I/O condition
  (`java.md` §11.1, §11.2, §11.9).
- **MIME/line-wrapping options.** MojoAkku rejects OpenSSL's default 64-column
  wrapping, Perl's 76-char `$eol` default and Java's `getMimeEncoder` because
  wrapping is a mail-transfer concern, not a codec concern (`c.md` §11;
  `perl.md` §11; `java.md` §1). (A future library may layer wrapping on top.)
- **`abort()` or panic on a mis-sized output buffer.** MojoAkku rejects
  cppcodec's `noexcept`+`abort()` raw path and Rust's overflow panic because
  aborting the process is the wrong trade for a recoverable caller mistake; the
  in-place overloads return a count and the length functions make sizing total
  (`cpp.md` §11; `rust.md` §11).
- **Unchecked public decode entry points.** MojoAkku rejects
  `decode_slice_unchecked` because an API whose documented failure mode is a
  panic invites bugs; the checked form plus `decoded_len` is enough
  (`rust.md` §11).
- **Per-variant class names / factory-per-alphabet.** MojoAkku rejects
  cppcodec's `base64_url_unpadded` class and Java's `getUrlEncoder()` factory
  because a differently-named entry point per variant does not scale and hides
  the two orthogonal choices; an alphabet value plus a padding value composes
  (`cpp.md` §11; `java.md` §7, §10).
- **Arbitrary custom alphabets and exotic variants.** MojoAkku rejects
  `Alphabet::new`-style custom tables (Rust), Crockford base32, BIN_HEX, BCRYPT
  and IMAP-MUTF7 because the RFC 4648 alphabets plus case choices cover the real
  use cases and exotic alphabets multiply the test surface (`rust.md` §11;
  `cpp.md` §7). Elixir `Base` corroborates the no-custom-alphabet position: its
  alphabets are hard-coded character lists, "fixed at compile time and not
  user-pluggable — there is no custom-alphabet API" (`elixir.md` §7; note §11
  merely flags extensibility as a possible future want, not as a shipped
  feature).
- **Bare `:error` with no reason.** MojoAkku rejects Elixir's lossy plain
  decoder because collapsing bad-symbol, bad-length and bad-padding into one atom
  destroys the diagnostic; the typed error keeps the reason (`elixir.md` §11).
- **Silent-ignore decoding.** MojoAkku rejects Perl `MIME::Base64`'s
  "any character not part of the subset is silently ignored" because it makes
  malformed input indistinguishable from valid input and opens the RFC 4648 §3.3
  covert channel (`perl.md` §11; `c.md` §11).
- **Timeouts, cancellation and async.** MojoAkku rejects any timeout/cancellation
  parameter because a pure memory transform has no I/O, no blocking resource and
  no await point; the research for every language records this as structurally
  not applicable (`c.md` §6,§8; `cpp.md` §6,§8; `go.md` §6,§8; `rust.md` §6,§8;
  `python.md` §6,§8; `perl.md` §6,§8; `js-ts.md` §6,§8; `java.md` §6,§8;
  `elixir.md` §6,§8).
- **A constant-time "secure" engine and a SIMD engine.** MojoAkku rejects adding
  `base64ct`-style branch-free engines and `base64-simd` engines to the first
  public API because they are implementation variants that must not shape the
  surface; they can arrive later behind the same signatures (`rust.md` §10, §11).
- **A separable `flush` + argument-light `finish`.** MojoAkku rejects splitting
  the encoder into `flush(mut self, …)` plus an argument-light
  `finish(deinit self)` because it would detach the mandatory terminal call from
  the flush and weaken Goal 7 ("the final flush cannot be silently skipped"). The
  destructor-with-`out` form keeps flush and terminal call atomic; the split is a
  fallback only if Phase 7 cannot compile the extra-argument destructor.
- **I/O stream adapters.** MojoAkku rejects `io::Read`/`io::Write` wrappers
  (`DecoderReader`/`EncoderWriter`, JDK `wrap`, Go `NewDecoder`) in this library
  because the codec should stay a pure transform; a consumer can build adapters
  on `Encoder`/`Decoder` without a dependency edge here (`rust.md` §5;
  `java.md` §9).

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Alphabet as first-class value | Go `Encoding` with `encode[64]`/`decodeMap[256]`; `NewEncoding`, `StdEncoding`, `URLEncoding`, `HexEncoding` | `go.md` §3, §7, §10 |
| Variant as type / zero-cost specialization | cppcodec `detail::codec<detail::base64<…>>`, `generates_padding()`/`requires_padding()`/`should_ignore()` | `cpp.md` §7, §10, §12 |
| Padding as explicit policy | Rust `DecodePaddingMode{Indifferent,RequireCanonical,RequireNone}` + `encode_padding`; Go `WithPadding`/`NoPadding`; Python 3.15 `padded`; Java `withoutPadding()` | `rust.md` §3, §7, §12; `go.md` §3, §7; `python.md` §3, §12; `java.md` §3, §12 |
| Explicit ignore/whitespace policy | libsodium `ignore` string with `NULL` = strict; `data-encoding` `ignore` | `c.md` §10, §12; `rust.md` §7 |
| Byte-first borrowed in / owned out | Mojo stdlib `b64encode(Span[UInt8]) -> String`, `b64decode(StringSpan) -> List[UInt8]`; ES 2027 `Uint8Array.fromBase64`/`toBase64`; C++ `std::span` input (base64pp) | `mojov1/stdlib/base64`; `js-ts.md` §5, §12; `cpp.md` §3, §12 |
| In-place output overload | Mojo stdlib `b64encode(input_bytes, mut result: String)`; Go `Encode(dst, src)`; Java `encode(src, dst) -> int`; cppcodec `Result&` refill | `mojov1/stdlib/base64`; `go.md` §3, §12; `java.md` §3, §12.1; `cpp.md` §3, §12 |
| Length functions | Perl `encoded_base64_length`/`decoded_base64_length`; Go `EncodedLen`/`DecodedLen`; Java/Commons `getEncodedLength`; cppcodec `encoded_size`/`decoded_max_size`; Rust `encoded_len`/`decoded_len_estimate` | `perl.md` §3, §10, §12; `go.md` §3; `java.md` §12.9; `cpp.md` §3, §12; `rust.md` §3, §12 |
| Typed error with kind+offset | Rust `DecodeError::InvalidByte(usize,u8)`/`InvalidLength`/`InvalidLastSymbol`/`InvalidPadding`; `data-encoding` `DecodeError{position,kind}`; Python `binascii.Error` vs `Incomplete`; Go `CorruptInputError`; cppcodec `parse_error`/`symbol_error` | `rust.md` §4, §12; `python.md` §4, §12; `go.md` §4; `cpp.md` §4, §12 |
| Streaming with explicit finalize | Rust `EncoderWriter::finish`, `extra_input:[u8;3]`; `data-encoding` `Encoder::append`/`finalize`; JS `setFromBase64 -> {read,written}` and `stop-before-partial`; Java `wrap` "flush all possible leftover bytes"; OpenSSL `EVP_EncodeFinal` | `rust.md` §5, §9, §12; `js-ts.md` §5, §9, §12; `java.md` §9, §12.6; `c.md` §9 |
| Validity predicate without allocation | Elixir `valid64?`/`valid32?`/`valid16?` (SWAR) | `elixir.md` §3, §10, §12 |
| Strict canonicality (trailing bits) | gnulib trailing-bit rejection; glibc `b64_pton`; Go `Strict()`; Commons Codec `CodecPolicy.STRICT`; RFC 4648 §3.5 | `c.md` §3, §10, §12; `go.md` §7; `java.md` §7, §10 |
| Compile-time reverse table | Perl `index_64`; js-base64 `lookup`/`revLookup`; cppcodec `make_lookup_table` | `perl.md` §12; `js-ts.md` §12; `cpp.md` §10 |
| Uniform radix shape | Go base64/base32 identical naming; Erlang one-table two-alphabet offsets | `go.md` §10, §12; `elixir.md` §7, §10 |
| Mojo language anchors | `Span`/`StringSpan` borrowed views; `List`/`String` owned; `comptime` value parameters; typed `raises` errors; `@explicit_destroy`; `with` | `mojov1/types/collections`; `mojov1/functions/parameters-and-generics`; `mojov1/errors/error-model`; `mojov1/decorators/explicit-destroy` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order.

**Option and error types**

1. `Alphabet` — compile-time value type selecting the symbol table; named
   constants `B64_STANDARD`, `B64_URL`, `B32_STANDARD`, `B32_HEX`, `HEX_LOWER`,
   `HEX_UPPER`.
2. `Padding` — compile-time encode padding policy: `REQUIRED`, `OMITTED`.
3. `PaddingMode` — compile-time decode padding policy: `STRICT`, `TOLERANT`.
4. `Whitespace` — compile-time decode whitespace policy: `REJECT`, `IGNORE`.
5. `ErrorKind` — compile-time discriminant for `Base64Error`:
   `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING`.
6. `Base64Error` — the one typed error carrying `kind: ErrorKind` and
   `position: Int`.

**One-shot encode/decode**

7. `encode` — encode borrowed bytes/text to an owned `String`; two overloads
   (`Span[UInt8]`, `StringSpan`).
8. `encode_into` — encode borrowed bytes/text into a caller-owned
   `mut result: String` and return the number of characters written; two
   overloads (`Span[UInt8]`, `StringSpan`).
9. `decode` — decode borrowed encoded text/bytes to an owned `List[UInt8]`,
   raising `Base64Error`; two overloads (`StringSpan`, `Span[UInt8]`).
10. `decode_into` — decode borrowed encoded text/bytes into a caller-owned
    `mut result: List[UInt8]` and return the number of bytes written, raising
    `Base64Error`; two overloads (`StringSpan`, `Span[UInt8]`).

**Buffer sizing and validation**

11. `encoded_len` — pure function returning the exact encoded length for `n`
    input bytes under an alphabet and padding policy.
12. `decoded_len` — pure function returning the maximum decoded byte count for
    `n` encoded symbols under an alphabet.
13. `is_valid` — allocation-free predicate returning `Bool` for whether input
    conforms to an alphabet and the decode policies; never raises; two overloads
    (`StringSpan`, `Span[UInt8]`).

**Streaming**

14. `Encoder` — stateful encode value type owning the sub-quantum byte carry;
    `feed` + mandatory `finish` (and `discard`).
15. `Decoder` — stateful decode value type owning the sub-quantum character
    carry; `feed` + mandatory `finish` (and `discard`), raising `Base64Error`.

## Semantics

#### Terminology

- **Symbol** — one encoded character (one byte of the encoded text).
- **Quantum** — the smallest group of input bytes that maps to a whole number
  of symbols. base64: 3 bytes ↔ 4 symbols; base32: 5 bytes ↔ 8 symbols;
  base16: 1 byte ↔ 2 symbols. The **carry** is the remainder of a partial
  quantum held by a streaming value between calls.
- **Padding** — the `=` symbol that completes the final partial quantum for
  base64 and base32. base16 has no padding concept (`cpp.md` §7).
- **Canonical** — padding is present in exactly the required count, no symbols
  follow padding, and the unused trailing bits of the final symbol are zero
  (RFC 4648 §3.5; `c.md` §10).

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

    comptime B64_STANDARD = Alphabet(0)   # RFC 4648 §4,  A-Z a-z 0-9 + /
    comptime B64_URL      = Alphabet(1)   # RFC 4648 §5,  A-Z a-z 0-9 - _
    comptime B32_STANDARD = Alphabet(2)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(3)   # RFC 4648 §7,  0-9 A-V
    comptime HEX_LOWER    = Alphabet(4)   # RFC 4648 §8,  0-9 a-f
    comptime HEX_UPPER    = Alphabet(5)   # RFC 4648 §8,  0-9 A-F
```

Semantics:

- **Parameters / preconditions:** none; the value is a compile-time constant
  used as a function/struct **value parameter** (`[alphabet: Alphabet]`). The
  type is documented as **opaque**: the six `comptime` members are the complete
  public set, while the `_id` field and its `@doc_hidden` initializer are
  implementation details. Mojo has **no access control** — `_name` and
  `@doc_hidden` are conventions, not permissions
  (`mojov1/decorators/doc-hidden`) — so the constructor is technically reachable
  inside the package; the library defines behaviour only for `_id` values 0–5 and
  no public entry point accepts a caller-supplied alphabet id. Callers use the
  named constants.
- **Return / meaning:** identifies the symbol table, the symbols-per-quantum
  ratio and whether padding exists. `B64_URL` is only the alphabet; its padding
  is chosen by the separate `Padding`/`PaddingMode` parameter, so URL-safe
  padded and URL-safe unpadded are both expressible (contrast Go's
  `RawURLEncoding` preset, `go.md` §3).
- **Case policy (decode):** case handling is a fixed property of the chosen
  alphabet, not a separate option, so the accepted symbol set is exactly what
  the alphabet constant names:
  - `B64_STANDARD`/`B64_URL` are **case-sensitive**: upper- and lower-case
    letters are different symbols with different values (RFC 4648 §4; the
    alphabet is inherently two-case, `elixir.md` §7).
  - `B32_STANDARD`/`B32_HEX` are **case-sensitive, uppercase only**: lowercase
    `a-z`/`a-v` is `INVALID_SYMBOL`. Source: Python documents
    `casefold=False` as the default for `b32decode`/`b32hexdecode`, i.e. lowercase
    is not accepted unless requested (`python.md` §7), and cppcodec's
    `base32_rfc4648`/`base32_hex` tables are uppercase-only (`cpp.md` §7).
    Go's `go.md` §7 is **not** cited for case sensitivity — it only says the
    `decodeMap` is built from the uppercase alphabet and is silent on whether
    lowercase is rejected, so treating Go as corroboration here is a **GUESS**
    that Phase 7 must verify against the Go source. Elixir's opt-in
    `:case`/`:mixed` is deliberately **not** copied for base32 (`elixir.md` §7);
    callers who need lowercase interop normalise case before calling.
  - `HEX_LOWER`/`HEX_UPPER` are **case-sensitive on decode**, each accepting only
    its own case: `HEX_UPPER` accepts `0-9 A-F`, `HEX_LOWER` accepts `0-9 a-f`;
    the other case is `INVALID_SYMBOL`. The two constants thus differ in both the
    case the encoder *emits* and the case the decoder *accepts*, symmetrically.
    This follows RFC 4648 §8, which defines base16 with an uppercase alphabet and
    no case folding, and matches the Mojo stdlib's `b16decode`, which is strictly
    uppercase `[0-9A-F]` (`mojov1/stdlib/base64`). It is a deliberate divergence
    from Go's `encoding/hex` and cppcodec's `hex_upper`/`hex_lower`, which accept
    both cases (`go.md` §7; `cpp.md` §7). The research flags lenient base16 case
    as a **decision not to copy**: Perl's `pack "H*"` accepts both cases and
    `perl.md` §11 records that RFC 4648 "explicitly recommends against [this] for
    security", because case-alteration of an encoded string can be used to defeat
    naive equality checks (RFC 4648 §12). A caller that needs to accept mixed
    case normalises it before calling, keeping the default strict and predictable
    (Goals 3 and 8).
  There is no `Casefold` parameter: a caller needing a different case policy
  maps the input or output itself, which keeps one option model and one
  alphabet value (`Goals` 1 and 3).
- **Ownership:** value type; copied by value at compile time only. No heap, no
  lifetime.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply because the type is a
  compile-time constant and performs no I/O.

Errors: none in practice. The six named constants are the only `Alphabet`
values in the public *contract*, so code that stays on public names never
supplies an invalid alphabet (`go.md` §11 rejects the runtime `NewEncoding`
panic). This is a documented convention boundary, not a compiler-enforced one:
because Mojo has no access control, the `@doc_hidden` initializer is
technically reachable inside the package (see **Parameters / preconditions**
above), and the library defines behaviour only for `_id` values 0–5. Values
outside that set are outside the API and their behaviour is unspecified.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a compile-time Alphabet value parameter
because Go's runtime `variant` integer and Rust's `Alphabet::new` pay per-call
branching/validation, while cppcodec's variant-as-type and Mojo's documented
value-parameter specialization remove all runtime alphabet dispatch
(`go.md` §7,§10; `rust.md` §12; `cpp.md` §10,§12;
`mojov1/functions/parameters-and-generics` "value parameters for compile-time
specialization"). The buch documents scalar (`factor: Int`) and `String`
(`msg: String = "woof"`) value parameters plus a *parameterized struct type*
(`struct Bar[v: Int]`) — which is not the same as using a user-struct **value**
as a value-parameter type. Whether a user-defined struct value is accepted as a
value-parameter type is therefore not evidenced by the buch and is tracked in
`## Open Questions` (`mojov1/functions/parameters-and-generics`, "Value
parameters and how to choose", "Optional, keyword, and variadic parameters").
If Phase 7 finds it unsupported, the fallback is a `UInt8` id value parameter
plus documented constants.

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
  on `encode`/`encode_into`/`Encoder`. Only the two named `comptime` members are
  part of the public set; the `_id` field and its `@doc_hidden` initializer are
  implementation details (no `@fieldwise_init`). Mojo has no access control, so
  the constructor is technically reachable inside the package, but the library
  defines behaviour only for ids 0–1. `REQUIRED` is only meaningful
  for base64 and base32; for `HEX_LOWER`/`HEX_UPPER` both values produce
  identical output because base16 has no padding (`cpp.md` §7
  hex_upper/hex_lower "n/a").
- **Return / meaning:** controls only what the encoder **emits**. Decode is
  governed separately by `PaddingMode`, mirroring cppcodec's split of
  `generates_padding()` from `requires_padding()` (`cpp.md` §10).
- **Ownership:** value type; compile-time only.
- **Stream I/O:** not applicable (compile-time value, no I/O).

Errors: none.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses an explicit Padding value instead of an
implicit lax mode because Python's `validate=False` default, Java's
`withoutPadding()`, Go's `WithPadding`/`NoPadding` and Rust's `encode_padding`
all show users expect padding to be a deliberate, visible choice
(`python.md` §12; `java.md` §12.5; `go.md` §7; `rust.md` §7).

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
    the exact number of `=` symbols must be present; a full final quantum must
    carry no `=`; a partial quantum with no padding is `INVALID_PADDING`. This is
    Rust's `RequireCanonical` (`rust.md` §7).
  - `TOLERANT` — the final quantum may be padded or unpadded (Java's "accepted
    and interpreted …, but is not required"). If padding is present its count
    must still be exactly right, padding may only occur at the end, and no symbol
    may follow it (`java.md` §7 "if there is a padding character present in the
    final unit, the correct number of padding character(s) must be present",
    `rust.md` §7 `Indifferent`). `TOLERANT` also **accepts non-zero trailing
    bits** in the final symbol (Rust `Indifferent` with
    `decode_allow_trailing_bits=true`); `STRICT` rejects them as
    `INVALID_SYMBOL`. The two modes therefore differ on canonicality, not only on
    padding (`rust.md` §7).
  - For `HEX_LOWER`/`HEX_UPPER` (base16) there is no padding symbol at all, so
    `STRICT` and `TOLERANT` are equivalent: neither accepts a `=`, and a `=` is
    `INVALID_SYMBOL` under both. `padding_mode` is still a declared parameter on
    the base16 overloads for API uniformity (Goal 1), but it selects no
    behaviour there.
- **Ownership:** value type; compile-time only.
- **Stream I/O:** not applicable (compile-time value, no I/O).

Errors: invalid padding under either mode raises `INVALID_PADDING` (or
`INVALID_LENGTH` for a structurally impossible remainder); the error is a data
error and is recoverable.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a two-value PaddingMode because Rust's
`Indifferent`/`RequireCanonical` pair and Commons Codec's `CodecPolicy` show
that "padding present/absent" is a decode policy distinct from the encode
policy, while Java shows the tolerant mode is useful for real-world interop
(`rust.md` §12; `java.md` §10.6,§12.5). Rust's third state, `RequireNone`
(padding *forbidden*), is deliberately **not** represented. Its reason is
narrow: `TOLERANT` already accepts an unpadded quantum, so a caller who must
reject `=` performs that one check itself — a `StringSpan`/`Span` scan for the
padding symbol before choosing the mode — and then decodes with `TOLERANT`.
`STRICT` is the complement and is the default. A third compile-time state would
add a policy that is exactly "TOLERANT plus a caller-side negative scan", at
the cost of a wider accepted-input model; the phrase
"three-state-compatible" was therefore dropped as inaccurate (`rust.md` §7).

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
  from the Mojo stdlib, which ignores whitespace in `b64decode`; `IGNORE`
  preserves that behaviour as an opt-in (`mojov1/stdlib/base64`).
- **Ownership:** value type; compile-time only.
- **Stream I/O:** not applicable (compile-time value, no I/O).

Errors: under `REJECT`, a whitespace byte raises `INVALID_SYMBOL`; under
`IGNORE` whitespace never fails.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses an explicit Whitespace value because
libsodium's `ignore` string with `NULL` meaning strict is the cleanest
precedent for caller-chosen skipping, while Go silently ignores CR/LF even
under `Strict()` and is explicitly rejected as a non-copy (`c.md` §10,§12;
`go.md` §11).

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

- **Parameters / preconditions:** read from `Base64Error.kind`; never passed by a
  caller to a codec.
- **Return / meaning:** the machine-testable reason for a decode failure.
  `INVALID_LENGTH` is a whole-input structural error (base64 remainder 1, base16
  odd length, base32 remainder 1/3/6); `INVALID_PADDING` is a placement/count
  error; `INVALID_SYMBOL` is a bad byte. Under `PaddingMode.STRICT` the same
  `INVALID_SYMBOL` kind also covers a final symbol whose unused trailing bits are
  non-zero: the byte *is* in the alphabet, so it is not a separate alphabet
  failure, and folding it into `INVALID_SYMBOL` keeps the public discriminant at
  three values (dedicated `INVALID_TRAILING_BITS` and `INCOMPLETE` kinds are
  deliberately not added). A partial final quantum with missing padding raises
  `INVALID_PADDING` from *both* `decode` and a streaming `finish`, so no
  streaming-only kind is needed. The three kinds correspond to Rust's
  `DecodeError` (`InvalidByte`/`InvalidLength`/`InvalidLastSymbol`/
  `InvalidPadding`, where the non-zero-trailing-bit case is `InvalidLastSymbol`
  and maps here to `INVALID_SYMBOL`) and to `data-encoding`'s
  `DecodeKind { Length, Symbol, Trailing, Padding }` with `Trailing` likewise
  folded into `Symbol`; Python's `binascii.Incomplete` is a stream-retry hint,
  not a distinct data condition, so it does not warrant a kind here
  (`rust.md` §4; `python.md` §4).
- **Ownership:** value type; compile-time constants copied into the error value.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a three-value discriminant because Rust and
data-encoding both carry a machine-usable kind plus an offset, and Elixir's
bare `:error` and Perl's "silently ignored" are the documented failure modes of
collapsing reasons (`rust.md` §4,§12; `elixir.md` §11; `perl.md` §11).

---

### `Base64Error`

Status: planned

Signature:

```mojo
@fieldwise_init
struct Base64Error(Copyable, Deinitable, Writable):
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
  is independent of how the input was split into chunks (Rust re-bases decoder
  offsets onto the whole-stream position the same way, `rust.md` §4,§9). Under
  `Whitespace.IGNORE`, skipped whitespace still advances the count (it occupies a
  position in the original stream). For `INVALID_LENGTH` `position` is the index
  of the first symbol of the structurally impossible remainder; for
  `INVALID_PADDING` it is the index at which the offending/partial final quantum
  begins; for `INVALID_SYMBOL` it is the index of the offending symbol.
  `position` never points past the number of symbols seen so far.
- **Return / meaning:** the single typed error every decoder declares via
  `raises Base64Error`. Implemented as a plain struct and `Writable`, following
  Mojo's typed-error model (`mojov1/errors/error-model`).
- **Ownership:** value type; `Copyable` and `Deinitable`, so it can be bound and
  inspected. It is deliberately **not** `ImplicitlyCopyable`, so a re-raise must
  transfer with `raise e^`; `raise e` (which copies) does not compile for a
  non-`ImplicitlyCopyable` error type (`mojov1/errors/raising-and-propagation`).
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: a pure codec has no file
  descriptor, no blocking call and no external handle, so none of those
  conditions can arise. This is itself evidence that the codec sits above the
  I/O layer (research §6/§8 for every language; `c.md` §6, `go.md` §6).

Errors: it **is** the error. All decode failures are data errors and are
recoverable: the caller may fix the input, truncate at `position`, or switch
policy and retry. No decoder error is fatal or unrecoverable.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a struct with `kind`+`position` because
Rust's `DecodeError` offsets and cppcodec's `symbol_error` show that a codec
must report *where* and *why*, and Java's checked `IOException` and Commons
Codec's `Object`-bridge show how not to type the failure (`rust.md` §4,§12;
`cpp.md` §4,§12; `java.md` §11.1,§11.2).

---

### `encode`

Status: planned

Signature:

```mojo
def encode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8]) -> String

def encode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan) -> String
```

Semantics:

- **Parameters / preconditions:** `input` is the raw bytes (first overload) or
  UTF-8 text treated as raw bytes (second overload; no UTF-8 conversion is
  performed, each byte is encoded). `input` is borrowed and may be empty; an
  empty input returns an empty `String`. `alphabet` and `padding` are
  compile-time; the defaults are standard base64 with required padding, so
  `encode(bytes)` is the predictable default.
- **Return / meaning:** an owned `String` containing exactly `encoded_len` bytes
  of encoded text. Never raises for any input.
- **Ownership:** `input` is borrowed (immutable reference, `Span`/`StringSpan`,
  never copied or consumed). The returned `String` is newly allocated and owned
  by the caller; the library retains no reference to either. No hidden global
  state is read or written.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply; encode is a pure
  in-memory transform with no descriptor and no blocking point.

Errors: none for any `Span[UInt8]`/`StringSpan`; encode cannot fail. (This
matches libsodium's "encoding cannot fail except by programming error",
`c.md` §4.)

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses borrowed-bytes-in / owned-String-out
because the Mojo stdlib's `b64encode` and C++ base64pp's
`encode(std::span<uint8_t const>)` both borrow input while returning a fresh
value, and ES 2027's byte-first `Uint8Array` API confirms the direction
(`mojov1/stdlib/base64`; `cpp.md` §12; `js-ts.md` §12).

---

### `encode_into`

Status: planned

Signature:

```mojo
def encode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8], mut result: String) -> Int

def encode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan, mut result: String) -> Int
```

Semantics:

- **Parameters / preconditions:** `input` is borrowed bytes (first overload) or
  UTF-8 text treated as raw bytes (second overload, matching `encode`'s
  `StringSpan` overload); `result` is a
  caller-owned, mutable `String`. The implementation must `reserve` capacity
  itself; `result` may have zero capacity on entry. The existing contents of
  `result` are appended to, not overwritten (append semantics, like Go's
  `AppendEncode`, `go.md` §3).
- **Return / meaning:** the number of encoded characters appended to `result`.
  No new heap allocation is required beyond `result`'s own growth.
- **Ownership:** caller owns `result` and controls its allocator. On return,
  `result` is valid and contains its prior contents plus the encoded text.
  `input` stays borrowed. The function never retains a reference to either.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply (pure transform).

Errors: none; encode cannot fail.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses an appending in-place `mut result` overload
because Go's incremental building block is the `Append*` family —
`AppendEncode(dst, src) []byte` grows the caller's buffer and returns the
extended slice, with no hidden global state (`go.md` §3, §10, §12) — and the
Mojo stdlib's `b64encode(input_bytes, mut result: String)` writes into the
caller's `String` while reserving capacity, so `result` may be a 0-capacity
string on entry (`mojov1/stdlib/base64`). Append, not overwrite-at-offset-0,
is the documented contract; a caller who wants offset-0 behaviour clears
`result` first.

---

### `decode`

Status: planned

Signature:

```mojo
def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) raises Base64Error -> List[UInt8]

def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8]) raises Base64Error -> List[UInt8]
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

Errors: `raises Base64Error`. `INVALID_LENGTH` for an impossible quantum
remainder; `INVALID_PADDING` for missing/excess/misplaced `=`; `INVALID_SYMBOL`
for a byte outside the alphabet (including whitespace under `REJECT`) or for a
non-zero trailing bit under `STRICT` canonical checking. There is no
streaming-only kind: `decode` and a streaming `finish` report the same three
kinds for the same malformed input. All are recoverable data errors. On
failure no `List[UInt8]` value is produced — the allocating form is
atomic (contrast Go's partial output, which is available through
`decode_into`/`Decoder` instead; `go.md` §10).

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a `raises Base64Error` decoder returning an
owned `List[UInt8]` because the Mojo stdlib's `b64decode` already raises and
returns fresh bytes, and Rust's typed `DecodeError` plus Python's
`binascii.Error` show the failure must carry a reason (`mojov1/stdlib/base64`;
`rust.md` §12; `python.md` §12).

---

### `decode_into`

Status: planned

Signature:

```mojo
def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan, mut result: List[UInt8]) raises Base64Error -> Int

def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8], mut result: List[UInt8]) raises Base64Error -> Int
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
  CorruptInputError" (`go.md` §4,§10) and `data-encoding`'s `DecodePartial{
  read, written, error }` (`rust.md` §4), while keeping the return type simple.
- **Ownership:** caller owns `result`; on both success and error `result` is
  valid. `input` stays borrowed.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply (pure transform).

Errors: same `Base64Error` kinds as `decode`, all recoverable. A partial
prefix may already be appended when the error is raised; the appended prefix
is always a whole number of bytes (complete quanta only), never a partial
byte.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a partial-commit appending in-place decoder
because Go's `AppendDecode(dst, src) ([]byte, error)` grows the caller's
buffer and returns partial output alongside its error, and Go documents the
count as "the number of bytes successfully written and CorruptInputError"
(`go.md` §3, §4, §10, §12); data-encoding documents the same contract as
`DecodePartial{read, written, error}` (`rust.md` §4). This makes error recovery
first-class. cppcodec's `abort()` and base64pp's reasonless `optional` are
rejected (`cpp.md` §11). The append contract (not overwrite-at-offset-0)
matches the Mojo stdlib in-place style and keeps a caller's prior data intact
(`mojov1/stdlib/base64`).

---

### `encoded_len`

Status: planned

Signature:

```mojo
def encoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](n: Int) -> Int
```

Semantics:

- **Parameters / preconditions:** `n` is the number of raw input bytes and must
  be `>= 0`; a negative argument is a caller programming error. Compile-time-
  callable: it is a pure, non-raising `def` with no FFI, so it may be used inside
  `comptime(...)` and in buffer sizing.
- **Return / meaning:** the exact encoded length:
  - base64 (`REQUIRED`): `4 * ((n + 2) // 3)`; base64 (`OMITTED`):
    `ceil(n / 3) * 4 - ((3 - n % 3) % 3)`, with the empty input returning `0`.
  - base32 (`REQUIRED`): `8 * ((n + 4) // 5)`; base32 (`OMITTED`):
    `(n * 8 + 4) // 5` (equivalently `8 * ((n + 4) // 5)` minus the RFC 4648 §6
    padding count, whose map is `n % 5` of 0/1/2/3/4 → 0/6/4/3/1).
  - base16: `2 * n` for both padding values.
  `n = 0` returns `0` in every case.
- **Ownership:** pure function; no allocation, no state, no lifetime.
- **Stream I/O:** not applicable; the function performs no I/O.

Errors: none. The function is **total**: `n < 0` is a caller programming
error and is **defined** to return `0` (the empty-input length) rather than to
trap, keeping the function non-raising and compile-time-callable. Callers must
pass non-negative lengths; the defined `0` is a safety net, not a licence to
size a buffer for a negative count.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a pure exact `encoded_len` because Perl's
`encoded_base64_length`, Go's `EncodedLen`, Commons Codec's
`getEncodedLength` and cppcodec's `encoded_size` all exist to pre-size a
buffer, and a total function is strictly better than C's two-call `dlen = 0`
size query (`perl.md` §12; `go.md` §12; `java.md` §12.9; `cpp.md` §12;
`c.md` §10).

---

### `decoded_len`

Status: planned

Signature:

```mojo
def decoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
](n: Int) -> Int
```

Semantics:

- **Parameters / preconditions:** `n` is the total input byte count used as a
  conservative upper bound (number of encoded symbols, including any padding
  and, under `Whitespace.IGNORE`, whitespace bytes; `>= 0`).
  Compile-time-callable (pure, non-raising, no FFI).
- **Return / meaning:** the **maximum** number of decoded bytes for `n` symbols:
  - base64: `(n // 4) * 3` plus the contribution of a partial final quantum
    (`n % 4` of 2 → 1, of 3 → 2, of 1 → 0 with strict validation rejecting it).
  - base32: `(n // 8) * 5` plus the partial-quantum contribution: `n % 8` of
    2, 4, 5 or 7 contributes 1, 2, 3 or 4 bytes respectively; `n % 8` of 1, 3
    or 6 is a structurally impossible remainder and contributes 0. (The map is
    therefore `2→1, 4→2, 5→3, 7→4`, everything else `→0`.)
  - base16: `n // 2`.
  Because `n` counts `=` symbols like any other input symbol, this is an upper
  bound whenever padding is present; the exact value is obtained from
  `decode`/`decode_into`. `n = 0` returns `0`.
- **Ownership:** pure function; no allocation, no state.
- **Stream I/O:** not applicable.

Errors: none. Total function: `n < 0` is a caller programming error and is
**defined** to return `0`, consistent with `encoded_len`.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a maximum-size `decoded_len` because Rust's
`decoded_len_estimate`, Boost.Beast's `decoded_size` and Java's caller-buffer
contract all need a conservative output bound before decoding, and Mojo's
explicit buffer sizing benefits from a total function (`rust.md` §3,§12;
`cpp.md` §3; `java.md` §12.9).

---

### `is_valid`

Status: planned

Signature:

```mojo
def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) -> Bool

def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
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
  validation — symbol-table membership (with the alphabet's case policy),
  quantum structure, padding count and placement, and, under
  `PaddingMode.STRICT`, the final symbol's zero trailing bits — but builds no
  output bytes (`go.md` §7; `rust.md` §7; `elixir.md` §10,§12).
- **Ownership:** `input` borrowed; returns a scalar `Bool`; the function
  allocates nothing and retains nothing.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply; no I/O occurs.

Errors: never raises. Every malformed condition is reported as `False`,
never as `Base64Error`.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses an allocation-free validity predicate because
Elixir's `valid64?`/`valid32?`/`valid16?` exist precisely to validate "without
allocating the decoded output", and the docs justify them as more efficient
than decode-then-discard (`elixir.md` §10,§12).

---

### `Encoder` (streaming encode)

Status: planned

Signature:

```mojo
@explicit_destroy("call finish() or discard() before this encoder leaves scope")
struct Encoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
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
  caller-owned mutable `String`
  appended to. `finish`/`discard` consume the encoder. The carry size is
  `quantum_bytes - 1` (base64: 0–2 bytes; base32: 0–4 bytes; base16: none),
  stored in a small fixed `Array[UInt8, 8]` plus a count; it is never exposed.
  (The array is sized 8 so the largest carry — base32's 4 bytes — plus the
  in-progress byte always fits; the count, not the array, bounds the remainder.)
- **Return / meaning:** `feed` returns the number of encoded characters appended
  for this chunk, encoding only complete quanta and holding the remainder.
  `finish` encodes the final partial quantum (with padding if
  `Padding.REQUIRED`), appends it, and returns the number appended. `finish` is
  the **only** place padding is emitted, so no padding can appear mid-stream.
- **Ownership:** the encoder owns its carry; `out` is caller-owned. `feed`
  borrows the chunk, which may be freed by the caller immediately after `feed`
  returns. `finish`/`discard` consume `self` (`deinit self`), so calling
  `finish` after `discard` or vice versa is impossible by construction.
- **Stream I/O / flush contract:** EOF is not an I/O event here: it is the
  caller's call to `finish`. EINTR/EAGAIN and close do not apply. An abandoned
  `Encoder` is a compile-time error, so the final flush can never be silently
  skipped — which is exactly the guarantee Rust's `Drop` deliberately does not
  give (`rust.md` §9,§12). In 1.x `@explicit_destroy` **no longer** opts a struct
  out of `Deinitable`; the documented opt-out is the explicit conformance
  declaration `struct Encoder[…](Deinitable where False):`, which the declaration
  above carries together with the required error-string argument
  (`mojov1/decorators/explicit-destroy`, "Pitfalls"; Mojo v1.0.0 release notes).

Errors: none; encode cannot fail. `discard(deinit self)` drops the
remainder without emitting it — the explicit, non-silent way to abandon a
stream.

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a `feed`/`finish` value type with a
mandatory `finish` because Rust's `EncoderWriter::finish` and data-encoding's
`Encoder::finalize` are documented as "required for correctness", while Rust's
`Drop` suppresses write errors and is a rejected footgun (`rust.md` §9,§11,
§12); `@explicit_destroy` enforces the same contract with a compile-time
diagnostic. The exact signature of the named destructor (extra `mut out`
argument plus `-> Int`) is a consciously open item; see `## Open Questions`.

---

### `Decoder` (streaming decode)

Status: planned

Signature:

```mojo
@explicit_destroy("call finish() or discard() before this decoder leaves scope")
struct Decoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](Deinitable where False):
    def __init__(out self)

    def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) raises Base64Error -> Int

    def feed(mut self, chunk: Span[UInt8], mut out: List[UInt8]) raises Base64Error -> Int

    def finish(deinit self, mut out: List[UInt8]) raises Base64Error -> Int

    def discard(deinit self)
```

Semantics:

- **Parameters / preconditions:** `feed` accepts successive borrowed encoded-text
  chunks of any length, as either `StringSpan` or `Span[UInt8]`; the two
  overloads mirror the one-shot `decode`. `out` is a caller-owned mutable
  `List[UInt8]` appended
  to. `finish`/`discard` consume the decoder. The carry size is
  `quantum_symbols - 1` (base64: 0–3 characters; base32: 0–7; base16: 0–1),
  stored in a small fixed `Array[UInt8, 8]` plus a count; it is never exposed.
- **Return / meaning:** `feed` decodes symbols left to right, appends each
  complete quantum to `out`, holds back the sub-quantum remainder, and returns
  the number of bytes appended for this chunk. `finish` validates the final
  partial quantum and mirrors `decode` exactly:
  - a partial quantum whose symbol count is **structurally impossible** for the
    alphabet (base64 remainder 1, base16 odd length, base32 remainder 1/3/6)
    raises `INVALID_LENGTH`;
  - a structurally valid partial quantum (base64 2/3, base32 2/4/5/7) that, under
    `PaddingMode.STRICT`, lacks its canonical padding raises `INVALID_PADDING`;
    under `TOLERANT` it is completed without padding.
  Streaming introduces no extra kind; each input yields the same kind from
  `finish` as from `decode`. `finish` returns the bytes appended.

  **End-of-stream state (`Decoder`-only).** A padded final quantum is a
  *complete* quantum, so `feed` decodes it; but once a padding symbol has been
  consumed the logical stream has ended. `Decoder` therefore carries a persistent
  **stream-ended** flag. After it is set, any further non-ignored symbol in a
  later `feed` (or in `finish`) raises `INVALID_PADDING`, so
  `feed("Zg==")` then `feed("AAAA")` fails just like `decode("Zg==AAAA")`.
  Together with the hold-back rule this makes the streaming result equal to the
  one-shot result for the same concatenated bytes:
  `feed(c₁); … ; feed(cₙ); finish()` ≡ `decode(c₁ ++ … ++ cₙ)` — same output, same
  error kind, same `position` (see below). This is a documented design
  requirement to be proven by the Phase-9/11 tests, not a buch fact.

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
  `Decoder`. That is the error model's rule: an error "interrupts normal execution
  flow … execution resumes" at the caller, and an explicitly destroyed
  ("linear") value must still be consumed on the error path — here by the
  caller's eventual `finish`/`discard` (`mojov1/errors/error-model`, "Errors are
  alternate return values" and "Deinitialization and linear interactions"). The
  decoder is therefore **not "poisoned" in a language-enforced sense**; the
  restriction is a documented usage rule, not a type-system state. `feed` does
  **not** consume `self`, so after a raise a further `feed(mut self, …)` resumes
  from the retained carry and a `finish(deinit self, …)` validates only what
  remains. The documented recovery is to stop using the errored decoder: call
  `discard(deinit self)` (or `finish` as appropriate) and start a fresh `Decoder`
  for unrelated input. **Phase-7 obligation:** the carry-atomicity detail — that
  each symbol is validated before it mutates the carry, so the carry holds only
  fully validated sub-quantum symbols on a raise — is a design requirement to be
  proven by the Phase-9/11 tests, not a buch fact.
- **Stream I/O / flush contract:** EOF is the caller's call to `finish`, not an
  I/O event; EINTR/EAGAIN and close do not apply. `@explicit_destroy` makes the
  final flush mandatory.

Errors: `raises Base64Error`. `feed` can raise `INVALID_SYMBOL` (a byte
outside the alphabet, or whitespace under `REJECT`) and `INVALID_PADDING` (a
padding symbol seen mid-stream, i.e. while more input is still expected);
it **cannot** raise `INVALID_LENGTH`, because `feed` holds back every sub-quantum
remainder, so a total-length impossibility is only knowable at `finish`.
`finish` raises the full `decode` set — `INVALID_SYMBOL`, `INVALID_LENGTH`
(structurally impossible remainder) and `INVALID_PADDING` (non-canonical
padding on a structurally valid remainder) — identically to `decode`. There is
no streaming-only kind. All are recoverable data errors.
Complete quanta decoded before an error remain appended (partial-commit
semantics, as in `decode_into`). `is_valid` reports the same verdict as
`decode` for the same input and policies (see `### is_valid`).

Tests:

Implementation status: not implemented

Rationale: MojoAkku uses a streaming decoder carrying ≤(quantum-1)
symbols because Rust's `DecoderReader` carries leftovers in fixed buffers and
JS's `setFromBase64 -> {read,written}` with `stop-before-partial` is the
documented userland pattern for exactly this carry, while Elixir/Python leave
it to the caller and are the gap this closes (`rust.md` §9,§12; `js-ts.md` §9,
§12; `elixir.md` §9,§11; `python.md` §12).

## Error Surface

There is exactly **one** error type: `Base64Error`, declared with
`raises Base64Error` on every decoder. It carries:

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
  signature; `Base64Error` is it. Callers that need a different error type wrap
  it at their own boundary (`mojov1/errors/error-model`).
- **Recoverable vs not.** Every kind is a *data* error and is recoverable: the
  caller may correct input, truncate at `position`, or change policy and retry.
  No codec failure is fatal or unrecoverable. There is no `assert`/abort path in
  the public surface.
- **No I/O errors.** `EINTR`, `EAGAIN`/would-block, `EOF` as an error, and
  close/shutdown errors **cannot** occur: the library performs no system call
  and owns no descriptor or handle. "End of input" is an explicit `finish`
  call, not a read returning zero. This absence is a property of a pure codec
  and is recorded for every reference language in the research (`c.md` §6,§8;
  `go.md` §6,§8; `java.md` §8; `rust.md` §8; `python.md` §8; `js-ts.md` §8;
  `elixir.md` §8; `perl.md` §8; `cpp.md` §6,§8).
- **No allocation errors.** A failed allocation surfaces as Mojo's usual
  allocation failure, not as `Base64Error`; the length functions let callers
  avoid the situation.
- **Diagnostics.** `Base64Error` implements `Writable`, so `print(e)` yields a
  readable, allocation-cheap message including the kind and position, in the
  spirit of cppcodec's allocation-free `symbol_error` (`cpp.md` §10).

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
  approved design; Phase 7 stubs it unchanged.
- **Semantics is complete.** It covers parameters/preconditions,
  return/meaning, ownership, and the stream-I/O / flush contract as applicable,
  plus any entry-specific policy (for example the `Alphabet` case policy or the
  `Decoder` end-of-stream state).
- **Errors names every raised or returned error and says whether it is
  recoverable.** Pure functions say `none`.
- **Tests is present but empty in this phase.** Test names are added in the
  test phase; the field is never removed.
- **Rationale is a `MojoAkku uses X because Y` statement** carried over from the
  design, naming the reference API and its research section.
- **Status and implementation status are honest.** All entries are `planned`
  and `not implemented` until a later phase changes them.
- **No implementation and no tests are written in this phase.** This document
  is documentation only.
- **Terminology is shared.** Symbol, quantum, carry, padding and canonical are
  defined once in `## Semantics ## Terminology` and used consistently.
- **Markdown tables use `|`.** No pipe-escaping artifacts; sources are cited as
  `<lang>.md §<section>`.

## Ownership and Lifecycle

**Borrowed input, owned output.** Every encode takes `Span[UInt8]` or
`StringSpan` by immutable reference and never copies or consumes it; every
decode does the same. Every allocating call returns a freshly owned `String`
(encode) or `List[UInt8]` (decode). This is the Mojo stdlib contract and the
C++ `std::span`-in/`std::vector`-out contract (`mojov1/stdlib/base64`;
`cpp.md` §12), and it makes the C "input borrowed, output caller-owned" rule
compiler-checked instead of documented (`c.md` §5,§12).

**In-place output.** `encode_into` takes `mut result: String` and
`decode_into` takes `mut result: List[UInt8]`; the callee appends and the
caller owns and sizes the buffer. Argument exclusivity (Mojo) guarantees the
input and output cannot alias (`mojov1/memory/ownership-and-lifetimes`), which
replaces C's unenforceable `restrict` (`c.md` §5,§11).

**Streaming state.** `Encoder` and `Decoder` are value types owning only a
small fixed `Array` carry plus a count. They own no heap and no external
resource, so `@explicit_destroy` is used only to make the final flush
*mandatory*, not to manage memory. `feed` borrows `self` and its chunk;
`finish`/`discard` take `deinit self` and consume the value. Because automatic
destruction is disabled, the carry is released only when a named destructor
(`finish`/`discard`) runs; there is no ASAP `__deinit__` path for these types
(`mojov1/lifecycle/death`). The C burden of `EVP_ENCODE_CTX_free` and the Rust
`Drop`-suppresses-errors footgun both disappear (`c.md` §5,§9; `rust.md`
§11,§12).

**No hidden global state.** There are no mutable globals: alphabets, pad
policies and error kinds are `comptime` constants, so two threads (or two
fibers) using the library share nothing mutable. This directly answers Go's
package-level `var StdEncoding` (`go.md` §11) and the Rust engine's
`Send + Sync` shared-reference design (`rust.md` §6) without needing a lock.
Thread-safety is therefore unconditional: the API has no shared mutable state.

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
**Three** items remain genuinely open (see **Open** below).

**Closed**

- The alphabet is a compile-time value parameter; Mojo's documented scalar and
  `String` value-parameter idiom (`def speak[a: Int = 3, msg: String = "woof"]()`,
  `def multiplier[factor: Int]`) covers the intent
  (`mojov1/functions/parameters-and-generics`). The stronger claim — that a
  user-struct **value** may itself be a value-parameter type — is *not* evidenced
  by the buch and is listed under **Open**, not closed. (`struct Bar[v: Int]` is
  a parameterized *type*, not a struct value used as a value parameter.)
- The option and error-kind types (`Alphabet`, `Padding`, `PaddingMode`,
  `Whitespace`, `ErrorKind`) carry no `@fieldwise_init` and therefore expose no
  public arbitrary-id constructor; only their named `comptime` members exist in
  the public contract. Mojo has no access control (`_name` is a convention, not
  a permission, `mojov1/decorators/doc-hidden`), so this is a documented
  convention boundary rather than a compiler-enforced one.
- Padding and whitespace are explicit `comptime` policies with named constants,
  not booleans or sentinels.
- The error surface is a single typed struct with a `kind` discriminant and a
  `position`, which Mojo supports directly (`mojov1/errors/error-model`).
- Re-raising is `raise e^`: `Base64Error` is `Copyable` but not
  `ImplicitlyCopyable`, so the transfer form is required
  (`mojov1/errors/raising-and-propagation`).
- `encode_into`/`decode_into` append; this matches Go's `AppendEncode`/
  `AppendDecode` and the Mojo stdlib in-place writer, so the justification now
  cites `Append*` rather than overwrite-at-offset-0.
- Decode case policy is fixed per alphabet: base64 is case-sensitive;
  base32 is case-sensitive (uppercase only); base16 is **case-sensitive on
  decode**, each `HEX_*` constant accepting only its own case (RFC 4648 §8; the
  lenient Go/cppcodec/Perl behaviour is a documented non-copy). A
  `Casefold`-style policy is deliberately not offered; see the `### Alphabet`
  **Case policy (decode)** and `perl.md` §11, `cpp.md` §7, `python.md` §7,
  `elixir.md` §7.
- `decoded_len` gives an explicit partial-quantum contribution for both base64
  and base32.
- `decode_into` and `is_valid` offer both `StringSpan` and `Span[UInt8]`
  overloads, matching `decode`.
- Streaming uses `@explicit_destroy` with named `finish`/`discard` methods
  taking `deinit self`, which Mojo 1.x documents and enforces
  (`mojov1/decorators/explicit-destroy`).
- The `flush`-before-`finish` restructure was considered and **rejected** as a
  resolved decision: splitting the encoder into `flush(mut self, …)` plus an
  argument-light `finish(deinit self)` would detach the mandatory terminal call
  from the flush and weaken Goal 7 ("the final flush cannot be silently
  skipped"). The destructor-with-`out` form keeps flush and terminal call atomic
  (see `## Non-Goals`), so this is not an open item.
- There is no I/O, so EOF/EINTR/EAGAIN/close are structurally not applicable.

**Open**

- **Go base32 decode case sensitivity.** `go.md` §7 says only that base32's
  `decodeMap` is built from the uppercase alphabet and is silent on lowercase
  rejection, so the Go corroboration for `B32_*` uppercase-only is a **GUESS**;
  Python (`casefold=False`) and cppcodec (uppercase-only tables) carry the claim.
  Still unverified against the Go source; the Mojo behaviour follows
  Python/cppcodec and RFC 4648.

**Resolved during implementation (Phase 7 / 11)**

- **Named destructor signature — RESOLVED (works).** Phase 7 compiled
  `finish(deinit self, mut out: String) -> Int` (and the `raises` decoder form)
  unchanged; the documented destructor-with-`out` form is valid in Mojo 1.x, so
  no fallback is needed. Callers transfer with `^` (e.g. `enc^.finish(out)`).
- **User-struct value as a value-parameter type — RESOLVED (works).** Phase 7/11
  compiled `[alphabet: Alphabet = …]` with user-defined `Alphabet`, `Padding`,
  `PaddingMode` and `Whitespace` values; the `UInt8`-id fallback is not needed.
- **`Span[UInt8]` spelling — implementation uses `Span[UInt8, _]`.** The exact
  documented signature `Span[UInt8]` is under-specified for Mojo 1.x, which
  requires an explicit origin; the implementation writes the idiomatic
  `Span[UInt8, _]` (wildcard origin). This is a syntax necessity, not an API
  change: the parameter is still a borrowed byte span. Documented signatures that
  read `Span[UInt8]` are to be understood as `Span[UInt8, _]`.
