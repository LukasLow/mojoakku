# BASE64_DOCS

## Overview

MojoAkku `base64` is a pure, in-process data-encoding library that covers the
RFC 4648 family — base64 (standard), base64url, base32 (standard), base32hex and
base16/hex — through **one uniform API shape**. It is the Phase-3 API design; it
contains no implementation and no tests.

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
   option model, so learning one teaches the rest. (`MojoAkku uses a single
   `encode`/`decode` surface because Go's base64/base32 naming symmetry and
   `data-encoding`'s per-constant API show that a uniform radix API is the most
   learnable, and Go's separate `hex` package for base16 shows the cost of
   inconsistency (`go.md` §10, §12; `rust.md` §3).`)

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
   `position` so callers can distinguish bad symbol, bad length, bad padding and
   incomplete input.

7. **Explicit streaming.** A stateful encoder and decoder carry the sub-quantum
   remainder; the final flush is mandatory and cannot be silently skipped.

8. **Readability for a low-vision user.** Stable names, one option model, one
   error type, identical field names in every documented entry.

9. **Pure Mojo.** No hidden global state, no Python dependency, no `unsafe`
   requirement in the public surface.

## Non-Goals

Decisions from the research that this library deliberately does **not** copy.
Each is a `MojoAkku rejects … because …` statement naming the reference.

- **Implicit newline/whitespace ignoring.** `MojoAkku rejects Go's implicit CR/LF
  skipping because `encoding/base64` strips newlines even under `Strict()`, which
  makes the accepted input set unknowable from the signature (`go.md` §7, §11);
  whitespace tolerance is offered only as an explicit `Whitespace.IGNORE`
  policy.**
- **Panic on bad configuration.** `MojoAkku rejects Go's `NewEncoding`/`WithPadding`
  panics because a wrong alphabet is a programming error the compiler can reject
  and a wrong call-site option is a compile-time error, not a process abort
  (`go.md` §11).**
- **Negative padding sentinels.** `MojoAkku rejects Go's `NoPadding = -1` rune
  because a magic negative value hides the policy from the reader; padding is a
  named `Padding` value (`go.md` §11).**
- **Mutable global encoding variables.** `MojoAkku rejects Go's package-level
  `StdEncoding`/`RawStdEncoding` vars because a codec must have no hidden global
  state; the presets are compile-time constants, not variables (`go.md` §11).**
- **Lax cross-alphabet decode.** `MojoAkku rejects Node's `'base64'` accepting
  the URL-safe alphabet (and js-base64's mixed-alphabet `isValid`) because it
  blurs which encoding was validated; the alphabet is chosen explicitly
  (`js-ts.md` §7, §11).**
- **Python's legacy file-object API and two Base16 spellings.** `MojoAkku rejects
  `base64.encode`/`decode(input, output)` and the `hexlify`/`b16encode`
  duplication because two overlapping surfaces with different container types
  are unlearnable; streaming is its own typed abstraction and base16 has one
  name (`python.md` §11).**
- **Python's `map01` confusable mapping.** `MojoAkku rejects `b32decode(map01=…)`
  because mapping `0/O` and `1/I/L` by default is a documented security footgun
  and the default must stay strict (`python.md` §7, §11).**
- **Java's `Object`-erased bridge and checked exceptions in a pure codec.**
  `MojoAkku rejects `encode(Object)`/`DecoderException` because Mojo is statically
  typed and a malformed string is a data error, not an I/O condition
  (`java.md` §11.1, §11.2, §11.9).**
- **MIME/line-wrapping options.** `MojoAkku rejects OpenSSL's default 64-column
  wrapping, Perl's 76-char `$eol` default and Java's `getMimeEncoder` because
  wrapping is a mail-transfer concern, not a codec concern (`c.md` §11;
  `perl.md` §11; `java.md` §1).** (A future library may layer wrapping on top.)
- **`abort()` or panic on a mis-sized output buffer.** `MojoAkku rejects
  cppcodec's `noexcept`+`abort()` raw path and Rust's overflow panic because
  aborting the process is the wrong trade for a recoverable caller mistake; the
  in-place overloads return a count and the length functions make sizing total
  (`cpp.md` §11; `rust.md` §11).**
- **Unchecked public decode entry points.** `MojoAkku rejects
  `decode_slice_unchecked` because an API whose documented failure mode is a
  panic invites bugs; the checked form plus `decoded_len` is enough
  (`rust.md` §11).**
- **Per-variant class names / factory-per-alphabet.** `MojoAkku rejects
  cppcodec's `base64_url_unpadded` class and Java's `getUrlEncoder()` factory
  because a differently-named entry point per variant does not scale and hides
  the two orthogonal choices; an alphabet value plus a padding value composes
  (`cpp.md` §11; `java.md` §7, §10).**
- **Arbitrary custom alphabets and exotic variants.** `MojoAkku rejects
  `Alphabet::new`-style custom tables (Rust), Crockford base32, BIN_HEX, BCRYPT
  and IMAP-MUTF7 because the RFC 4648 alphabets plus case choices cover the real
  use cases and exotic alphabets multiply the test surface (`rust.md` §11;
  `cpp.md` §7; `elixir.md` §11).**
- **Bare `:error` with no reason.** `MojoAkku rejects Elixir's lossy plain
  decoder because collapsing bad-symbol, bad-length and bad-padding into one atom
  destroys the diagnostic; the typed error keeps the reason (`elixir.md` §11).**
- **Silent-ignore decoding.** `MojoAkku rejects Perl `MIME::Base64`'s
  "any character not part of the subset is silently ignored" because it makes
  malformed input indistinguishable from valid input and opens the RFC 4648 §3.3
  covert channel (`perl.md` §11; `c.md` §11).**
- **Timeouts, cancellation and async.** `MojoAkku rejects any timeout/cancellation
  parameter because a pure memory transform has no I/O, no blocking resource and
  no await point; the research for every language records this as structurally
  not applicable (`c.md` §6,§8; `cpp.md` §6,§8; `go.md` §6,§8; `rust.md` §6,§8;
  `python.md` §6,§8; `perl.md` §6,§8; `js-ts.md` §6,§8; `java.md` §6,§8;
  `elixir.md` §6,§8).**
- **A constant-time "secure" engine and a SIMD engine.** `MojoAkku rejects adding
  `base64ct`-style branch-free engines and `base64-simd` engines to the first
  public API because they are implementation variants that must not shape the
  surface; they can arrive later behind the same signatures (`rust.md` §11).**
- **I/O stream adapters.** `MojoAkku rejects `io::Read`/`io::Write` wrappers
  (`DecoderReader`/`EncoderWriter`, JDK `wrap`, Go `NewDecoder`) in this library
  because the codec should stay a pure transform; a consumer can build adapters
  on `Encoder`/`Decoder` without a dependency edge here (`rust.md` §5;
  `java.md` §9).**

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
   `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING`, `INCOMPLETE`.
6. `Base64Error` — the one typed error carrying `kind: ErrorKind` and
   `position: Int`.

**One-shot encode/decode**

7. `encode` — encode borrowed bytes/text to an owned `String`; two overloads
   (`Span[UInt8]`, `StringSpan`).
8. `encode_into` — encode borrowed bytes into a caller-owned `mut result: String`
   and return the number of characters written.
9. `decode` — decode borrowed encoded text/bytes to an owned `List[UInt8]`,
   raising `Base64Error`; two overloads (`StringSpan`, `Span[UInt8]`).
10. `decode_into` — decode borrowed encoded text into a caller-owned
    `mut result: List[UInt8]` and return the number of bytes written, raising
    `Base64Error`.

**Buffer sizing and validation**

11. `encoded_len` — pure function returning the exact encoded length for `n`
    input bytes under an alphabet and padding policy.
12. `decoded_len` — pure function returning the maximum decoded byte count for
    `n` encoded symbols under an alphabet.
13. `is_valid` — allocation-free predicate returning `Bool` for whether input
    conforms to an alphabet and the decode policies; never raises.

**Streaming**

14. `Encoder` — stateful encode value type owning the sub-quantum byte carry;
    `feed` + mandatory `finish` (and `discard`).
15. `Decoder` — stateful decode value type owning the sub-quantum character
    carry; `feed` + mandatory `finish` (and `discard`), raising `Base64Error`.

## Semantics

### Terminology

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

```mojo
@fieldwise_init
struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    comptime B64_STANDARD = Alphabet(0)   # RFC 4648 §4,  A-Z a-z 0-9 + /
    comptime B64_URL      = Alphabet(1)   # RFC 4648 §5,  A-Z a-z 0-9 - _
    comptime B32_STANDARD = Alphabet(2)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(3)   # RFC 4648 §7,  0-9 A-V
    comptime HEX_LOWER    = Alphabet(4)   # RFC 4648 §8,  0-9 a-f
    comptime HEX_UPPER    = Alphabet(5)   # RFC 4648 §8,  0-9 A-F
```

- **Parameters / preconditions:** none; the value is a compile-time constant
  used as a function/struct **value parameter** (`[alphabet: Alphabet]`). The
  `_id` field is an implementation discriminant and is not part of the public
  contract; callers use the named constants.
- **Return / meaning:** identifies the symbol table, the symbols-per-quantum
  ratio and whether padding exists. `B64_URL` is only the alphabet; its padding
  is chosen by the separate `Padding`/`PaddingMode` parameter, so URL-safe
  padded and URL-safe unpadded are both expressible (contrast Go's
  `RawURLEncoding` preset, `go.md` §3).
- **Ownership:** value type; copied by value at compile time only. No heap, no
  lifetime.
- **Errors:** none. Passing an invalid alphabet is impossible because only the
  named constants exist (go.md §11 rejects the runtime `NewEncoding` panic).
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply because the type is a
  compile-time constant and performs no I/O.
- **Justification:** `MojoAkku uses a compile-time Alphabet value parameter
  because Go's runtime `variant` integer and Rust's `Alphabet::new` pay per-call
  branching/validation, while cppcodec's variant-as-type and Mojo's documented
  value-parameter specialization remove all runtime alphabet dispatch
  (`go.md` §7,§10; `rust.md` §12; `cpp.md` §10,§12;
  `mojov1/functions/parameters-and-generics` "value parameters for compile-time
  specialization").`

---

### `Padding` (encode policy)

```mojo
@fieldwise_init
struct Padding(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    comptime REQUIRED = Padding(0)   # emit '=' to complete the final quantum
    comptime OMITTED  = Padding(1)   # never emit '='
```

- **Parameters / preconditions:** used as `[padding: Padding = Padding.REQUIRED]`
  on `encode`/`encode_into`/`Encoder`. `REQUIRED` is only meaningful for
  base64 and base32; for `HEX_LOWER`/`HEX_UPPER` both values produce identical
  output because base16 has no padding (`cpp.md` §7 hex_upper/hex_lower "n/a").
- **Return / meaning:** controls only what the encoder **emits**. Decode is
  governed separately by `PaddingMode`, mirroring cppcodec's split of
  `generates_padding()` from `requires_padding()` (`cpp.md` §10).
- **Ownership:** value type; compile-time only.
- **Errors:** none.
- **Stream I/O:** not applicable (compile-time value, no I/O).
- **Justification:** `MojoAkku uses an explicit Padding value instead of an
  implicit lax mode because Python's `validate=False` default, Java's
  `withoutPadding()`, Go's `WithPadding`/`NoPadding` and Rust's `encode_padding`
  all show users expect padding to be a deliberate, visible choice
  (`python.md` §12; `java.md` §12.5; `go.md` §7; `rust.md` §7).`

---

### `PaddingMode` (decode policy)

```mojo
@fieldwise_init
struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    comptime STRICT   = PaddingMode(0)   # require canonical padding / no padding
    comptime TOLERANT = PaddingMode(1)   # padding optional, but consistent if present
```

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
    `rust.md` §7 `Indifferent`).
- **Ownership:** value type; compile-time only.
- **Errors:** invalid padding under either mode raises `INVALID_PADDING` (or
  `INVALID_LENGTH` for a structurally impossible remainder); the error is a data
  error and is recoverable.
- **Stream I/O:** not applicable (compile-time value, no I/O).
- **Justification:** `MojoAkku uses a three-state-compatible two-value
  PaddingMode because Rust's `Indifferent`/`RequireCanonical`/`RequireNone` and
  Commons Codec's `CodecPolicy` show that "padding present/absent" is a decode
  policy distinct from the encode policy, while Java shows the tolerant mode is
  useful for real-world interop (`rust.md` §12; `java.md` §10.6,§12.5).`

---

### `Whitespace` (decode policy)

```mojo
@fieldwise_init
struct Whitespace(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    comptime REJECT = Whitespace(0)   # default: any whitespace is INVALID_SYMBOL
    comptime IGNORE = Whitespace(1)   # skip space, tab, CR, LF, FF, VT
```

- **Parameters / preconditions:** used as
  `[whitespace: Whitespace = Whitespace.REJECT]` on `decode`/`decode_into`/
  `Decoder`/`is_valid`. With `IGNORE`, skipped bytes neither count toward the
  quantum length nor appear in `position` arithmetic except as the reported
  offending index for other errors.
- **Return / meaning:** makes whitespace tolerance explicit. `REJECT` differs
  from the Mojo stdlib, which ignores whitespace in `b64decode`; `IGNORE`
  preserves that behaviour as an opt-in (`mojov1/stdlib/base64`).
- **Ownership:** value type; compile-time only.
- **Errors:** under `REJECT`, a whitespace byte raises `INVALID_SYMBOL`; under
  `IGNORE` whitespace never fails.
- **Stream I/O:** not applicable (compile-time value, no I/O).
- **Justification:** `MojoAkku uses an explicit Whitespace value because
  libsodium's `ignore` string with `NULL` meaning strict is the cleanest
  precedent for caller-chosen skipping, while Go silently ignores CR/LF even
  under `Strict()` and is explicitly rejected as a non-copy (`c.md` §10,§12;
  `go.md` §11).`

---

### `ErrorKind`

```mojo
@fieldwise_init
struct ErrorKind(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    comptime INVALID_SYMBOL  = ErrorKind(0)   # byte not in alphabet / not padding
    comptime INVALID_LENGTH  = ErrorKind(1)   # impossible remainder for the alphabet
    comptime INVALID_PADDING = ErrorKind(2)   # wrong count/placement of '='
    comptime INCOMPLETE      = ErrorKind(3)   # streaming finish on a partial quantum
```

- **Parameters / preconditions:** read from `Base64Error.kind`; never passed by a
  caller to a codec.
- **Return / meaning:** the machine-testable reason for a decode failure.
  `INVALID_LENGTH` is a whole-input structural error (base64 remainder 1, base16
  odd length, base32 remainder 1/3/6); `INVALID_PADDING` is a placement/count
  error; `INVALID_SYMBOL` is a bad byte; `INCOMPLETE` is raised only by a
  streaming `finish` when a non-empty sub-quantum remains and cannot be a valid
  final quantum. The four kinds mirror Rust's `DecodeError` variants and
  `data-encoding`'s `DecodeKind{Length, Symbol, Trailing, Padding}`, and keep
  Python's `binascii.Error` vs `binascii.Incomplete` distinction (`rust.md` §4;
  `python.md` §4).
- **Ownership:** value type; compile-time constants copied into the error value.
- **Errors:** none.
- **Stream I/O:** not applicable.
- **Justification:** `MojoAkku uses a four-value discriminant because Rust and
  data-encoding both carry a machine-usable kind plus an offset, and Elixir's
  bare `:error` and Perl's "silently ignored" are the documented failure modes of
  collapsing reasons (`rust.md` §4,§12; `elixir.md` §11; `perl.md` §11).`

---

### `Base64Error`

```mojo
@fieldwise_init
struct Base64Error(Copyable, Deinitable, Writable):
    var kind: ErrorKind
    var position: Int
```

- **Parameters / preconditions:** constructed by the library; callers read the
  two fields in an `except`/`try` block. `position` is the zero-based index into
  the **original input** at which the failure was detected. For
  `INVALID_LENGTH` it is the index of the first symbol of the structurally
  impossible remainder; for `INVALID_PADDING`/`INVALID_SYMBOL` it is the index of
  the offending symbol; for `INCOMPLETE` it is the index at which the partial
  quantum begins. `position` never points past `len(input)`.
- **Return / meaning:** the single typed error every decoder declares via
  `raises Base64Error`. Implemented as a plain struct and `Writable`, following
  Mojo's typed-error model (`mojov1/errors/error-model`).
- **Ownership:** value type; `Copyable` and `Deinitable`, so it can be bound,
  inspected and re-raised (`raise e^` transfers, `raise e` copies).
- **Errors:** it **is** the error. All decode failures are data errors and are
  recoverable: the caller may fix the input, truncate at `position`, or switch
  policy and retry. No decoder error is fatal or unrecoverable.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: a pure codec has no file
  descriptor, no blocking call and no external handle, so none of those
  conditions can arise. This is itself evidence that the codec sits above the
  I/O layer (research §6/§8 for every language; `c.md` §6, `go.md` §6).
- **Justification:** `MojoAkku uses a struct with `kind`+`position` because
  Rust's `DecodeError` offsets and cppcodec's `symbol_error` show that a codec
  must report *where* and *why*, and Java's checked `IOException` and Commons
  Codec's `Object`-bridge show how not to type the failure (`rust.md` §4,§12;
  `cpp.md` §4,§12; `java.md` §11.1,§11.2).`

---

### `encode`

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
- **Errors:** none for any `Span[UInt8]`/`StringSpan`; encode cannot fail. (This
  matches libsodium's "encoding cannot fail except by programming error",
  `c.md` §4.)
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply; encode is a pure
  in-memory transform with no descriptor and no blocking point.
- **Justification:** `MojoAkku uses borrowed-bytes-in / owned-String-out
  because the Mojo stdlib's `b64encode` and C++ base64pp's
  `encode(std::span<uint8_t const>)` both borrow input while returning a fresh
  value, and ES 2027's byte-first `Uint8Array` API confirms the direction
  (`mojov1/stdlib/base64`; `cpp.md` §12; `js-ts.md` §12).`

---

### `encode_into`

```mojo
def encode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8], mut result: String) -> Int
```

- **Parameters / preconditions:** `input` is borrowed bytes; `result` is a
  caller-owned, mutable `String`. The implementation must `reserve` capacity
  itself; `result` may have zero capacity on entry. The existing contents of
  `result` are appended to, not overwritten (append semantics, like Go's
  `AppendEncode`, `go.md` §3).
- **Return / meaning:** the number of encoded characters appended to `result`.
  No new heap allocation is required beyond `result`'s own growth.
- **Ownership:** caller owns `result` and controls its allocator. On return,
  `result` is valid and contains its prior contents plus the encoded text.
  `input` stays borrowed. The function never retains a reference to either.
- **Errors:** none; encode cannot fail.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply (pure transform).
- **Justification:** `MojoAkku uses an in-place `mut result` overload because the
  Mojo stdlib already ships `b64encode(input_bytes, mut result: String)` with a
  documented capacity reservation, and Go's `Encode(dst, src)` and Java's
  `encode(src, dst) -> int` show the same caller-buffer contract
  (`mojov1/stdlib/base64`; `go.md` §12; `java.md` §12.1).`

---

### `decode`

```mojo
def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) -> List[UInt8] raises Base64Error

def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8]) -> List[UInt8] raises Base64Error
```

- **Parameters / preconditions:** `input` is the encoded text (`StringSpan`) or
  the same bytes (`Span[UInt8]`); it is borrowed and may be empty (an empty
  input decodes to an empty `List[UInt8]`). The defaults are strict RFC 4648
  canonical input with whitespace rejected.
- **Return / meaning:** a newly allocated `List[UInt8]` of the decoded bytes.
  On success the result length is at most `decoded_len` of the input length;
  with canonical input it is exact.
- **Ownership:** `input` is borrowed; the returned `List[UInt8]` is owned by the
  caller. The library holds no reference after return.
- **Errors:** `raises Base64Error`. `INVALID_LENGTH` for an impossible quantum
  remainder; `INVALID_PADDING` for missing/excess/misplaced `=`; `INVALID_SYMBOL`
  for a byte outside the alphabet (including whitespace under `REJECT`) or for a
  non-zero trailing bit under `STRICT` canonical checking; never `INCOMPLETE`
  (that kind is reserved for streaming `finish`). All are recoverable data
  errors. On failure no `List[UInt8]` value is produced — the allocating form is
  atomic (contrast Go's partial output, which is available through
  `decode_into`/`Decoder` instead; `go.md` §10).
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: there is no stream, no
  descriptor and no partial-read concept; "short input" is a data-length error,
  not an I/O condition.
- **Justification:** `MojoAkku uses a `raises Base64Error` decoder returning an
  owned `List[UInt8]` because the Mojo stdlib's `b64decode` already raises and
  returns fresh bytes, and Rust's typed `DecodeError` plus Python's
  `binascii.Error` show the failure must carry a reason (`mojov1/stdlib/base64`;
  `rust.md` §12; `python.md` §12).`

---

### `decode_into`

```mojo
def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan, mut result: List[UInt8]) -> Int raises Base64Error
```

- **Parameters / preconditions:** `input` is borrowed encoded text; `result` is
  a caller-owned, mutable `List[UInt8]`, possibly empty. The implementation
  reserves capacity itself. Existing contents are appended to (append
  semantics).
- **Return / meaning:** the number of decoded bytes appended. On error, the
  complete quanta decoded before the first invalid quantum remain appended and
  the count of bytes appended is not returned (the error propagates instead);
  callers who need the partial progress can compare `len(result)` before and
  after. This mirrors Go's documented "number of bytes successfully written and
  CorruptInputError" (`go.md` §4,§10) and `data-encoding`'s `DecodePartial{
  read, written, error }` (`rust.md` §4), while keeping the return type simple.
- **Ownership:** caller owns `result`; on both success and error `result` is
  valid. `input` stays borrowed.
- **Errors:** same `Base64Error` kinds as `decode`, all recoverable. A partial
  prefix may already be appended when the error is raised; the appended prefix
  is always a whole number of bytes (complete quanta only), never a partial
  byte.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply (pure transform).
- **Justification:** `MojoAkku uses a partial-commit in-place decoder because
  Go returns partial output alongside its error and data-encoding documents
  `DecodePartial`, which makes error recovery first-class, whereas cppcodec's
  `abort()` and base64pp's reasonless `optional` are rejected
  (`go.md` §10; `rust.md` §4; `cpp.md` §11).`

---

### `encoded_len`

```mojo
def encoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](n: Int) -> Int
```

- **Parameters / preconditions:** `n` is the number of raw input bytes and must
  be `>= 0` (a negative argument is a caller programming error; the function is
  total for `n >= 0`). Compile-time-callable: it is a pure, non-raising `def`
  with no FFI, so it may be used inside `comptime(...)` and in buffer sizing.
- **Return / meaning:** the exact encoded length:
  - base64 (`REQUIRED`): `4 * ((n + 2) // 3)`; base64 (`OMITTED`): that minus
    the padding count `(3 - n % 3) % 3`... expressed as
    `ceil(n / 3) * 4 - ((3 - n % 3) % 3)`, with the empty input returning `0`.
  - base32 (`REQUIRED`): `8 * ((n + 4) // 5)`; base32 (`OMITTED`): minus the
    RFC 4648 §6 padding count for the final quantum.
  - base16: `2 * n` for both padding values.
  `n = 0` returns `0` in every case.
- **Ownership:** pure function; no allocation, no state, no lifetime.
- **Errors:** none. Passing a negative `n` is a documented precondition
  violation; use `decoded_len`/`encoded_len` with non-negative lengths only.
- **Stream I/O:** not applicable; the function performs no I/O.
- **Justification:** `MojoAkku uses a pure exact `encoded_len` because Perl's
  `encoded_base64_length`, Go's `EncodedLen`, Commons Codec's
  `getEncodedLength` and cppcodec's `encoded_size` all exist to pre-size a
  buffer, and a total function is strictly better than C's two-call `dlen = 0`
  size query (`perl.md` §12; `go.md` §12; `java.md` §12.9; `cpp.md` §12;
  `c.md` §10).`

---

### `decoded_len`

```mojo
def decoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
](n: Int) -> Int
```

- **Parameters / preconditions:** `n` is the number of encoded symbols
  (`>= 0`). Compile-time-callable (pure, non-raising, no FFI).
- **Return / meaning:** the **maximum** number of decoded bytes for `n` symbols:
  - base64: `(n // 4) * 3` plus the contribution of a partial final quantum
    (`n % 4` of 2 → 1, of 3 → 2, of 1 → 0 with strict validation rejecting it).
  - base32: `(n // 8) * 5` plus the partial-quantum contribution.
  - base16: `n // 2`.
  With padding symbols present this is an upper bound; the exact value is
  obtained from `decode`/`decode_into`. `n = 0` returns `0`.
- **Ownership:** pure function; no allocation, no state.
- **Errors:** none.
- **Stream I/O:** not applicable.
- **Justification:** `MojoAkku uses a maximum-size `decoded_len` because Rust's
  `decoded_len_estimate`, Boost.Beast's `decoded_size` and Java's caller-buffer
  contract all need a conservative output bound before decoding, and Mojo's
  explicit buffer sizing benefits from a total function (`rust.md` §3,§12;
  `cpp.md` §3; `java.md` §12.9).`

---

### `is_valid`

```mojo
def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) -> Bool
```

- **Parameters / preconditions:** `input` is the encoded text to check, borrowed
  and possibly empty (an empty input is valid under every policy). The policy
  parameters have the same meaning as in `decode`.
- **Return / meaning:** `True` iff `decode` with the same parameters would
  succeed, without allocating the decoded output. It performs only symbol-table
  and quantum-structure checks.
- **Ownership:** `input` borrowed; returns a scalar `Bool`; the function
  allocates nothing and retains nothing.
- **Errors:** never raises. Every malformed condition is reported as `False`,
  never as `Base64Error`.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply; no I/O occurs.
- **Justification:** `MojoAkku uses an allocation-free validity predicate because
  Elixir's `valid64?`/`valid32?`/`valid16?` exist precisely to validate "without
  allocating the decoded output", and the docs justify them as more efficient
  than decode-then-discard (`elixir.md` §10,§12).`

---

### `Encoder` (streaming encode)

```mojo
@explicit_destroy("call finish() or discard() before this encoder leaves scope")
struct Encoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
]:
    def __init__(out self)

    def feed(mut self, chunk: Span[UInt8], mut out: String) -> Int

    def finish(deinit self, mut out: String) -> Int

    def discard(deinit self)
```

- **Parameters / preconditions:** `feed` accepts successive borrowed byte chunks
  of any length, including empty. `out` is a caller-owned mutable `String`
  appended to. `finish`/`discard` consume the encoder. The carry size is
  `quantum_bytes - 1` (base64: 0–2 bytes; base32: 0–4 bytes; base16: none),
  stored in a small fixed `Array[UInt8, 4]` plus a count; it is never exposed.
- **Return / meaning:** `feed` returns the number of encoded characters appended
  for this chunk, encoding only complete quanta and holding the remainder.
  `finish` encodes the final partial quantum (with padding if
  `Padding.REQUIRED`), appends it, and returns the number appended. `finish` is
  the **only** place padding is emitted, so no padding can appear mid-stream.
- **Ownership:** the encoder owns its carry; `out` is caller-owned. `feed`
  borrows the chunk, which may be freed by the caller immediately after `feed`
  returns. `finish`/`discard` consume `self` (`deinit self`), so calling
  `finish` after `discard` or vice versa is impossible by construction.
- **Errors:** none; encode cannot fail. `discard(deinit self)` drops the
  remainder without emitting it — the explicit, non-silent way to abandon a
  stream.
- **Stream I/O / flush contract:** EOF is not an I/O event here: it is the
  caller's call to `finish`. EINTR/EAGAIN and close do not apply. Because
  automatic destruction is disabled with `@explicit_destroy`, an abandoned
  `Encoder` is a compile-time error, so the final flush can never be silently
  skipped — which is exactly the guarantee Rust's `Drop` deliberately does not
  give (`rust.md` §9,§12; `mojov1/decorators/explicit-destroy`).
- **Justification:** `MojoAkku uses a `feed`/`finish` value type with a
  mandatory `finish` because Rust's `EncoderWriter::finish` and data-encoding's
  `Encoder::finalize` are documented as "required for correctness", while Rust's
  `Drop` suppresses write errors and is a rejected footgun (`rust.md` §9,§11,
  §12); `@explicit_destroy` enforces the same contract with a compile-time
  diagnostic.`

---

### `Decoder` (streaming decode)

```mojo
@explicit_destroy("call finish() or discard() before this decoder leaves scope")
struct Decoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
]:
    def __init__(out self)

    def feed(mut self, chunk: StringSpan, mut out: List[UInt8]) -> Int raises Base64Error

    def finish(deinit self, mut out: List[UInt8]) -> Int raises Base64Error

    def discard(deinit self)
```

- **Parameters / preconditions:** `feed` accepts successive borrowed encoded-text
  chunks of any length; `out` is a caller-owned mutable `List[UInt8]` appended
  to. `finish`/`discard` consume the decoder. The carry size is
  `quantum_symbols - 1` (base64: 0–3 characters; base32: 0–7; base16: 0–1),
  stored in a small fixed `Array[UInt8, 8]` plus a count; it is never exposed.
- **Return / meaning:** `feed` decodes only complete quanta, holds back the
  remainder, and returns the number of bytes appended. `finish` validates the
  final partial quantum: with `PaddingMode.STRICT` a non-empty partial quantum
  must be canonically padded or `INCOMPLETE` is raised; with `TOLERANT` an
  unpadded partial quantum is completed. `finish` returns the bytes appended.
- **Ownership:** the decoder owns its carry; `out` is caller-owned. The chunk is
  borrowed for the duration of the call only. `finish`/`discard` consume `self`.
- **Errors:** `raises Base64Error`. `INVALID_SYMBOL`, `INVALID_LENGTH`,
  `INVALID_PADDING` as in `decode`, plus `INCOMPLETE` when `finish` sees a
  partial quantum that cannot be completed (the streaming-only kind). All are
  recoverable data errors. Complete quanta decoded before an error remain
  appended (partial-commit semantics, as in `decode_into`). After an error the
  decoder is consumed/poisoned: `finish`/`discard` should be used to end its
  lifetime, and the caller starts a fresh `Decoder` to continue.
- **Stream I/O / flush contract:** EOF is the caller's call to `finish`, not an
  I/O event; EINTR/EAGAIN and close do not apply. `@explicit_destroy` makes the
  final flush mandatory.
- **Justification:** `MojoAkku uses a streaming decoder carrying ≤(quantum-1)
  symbols because Rust's `DecoderReader` carries leftovers in fixed buffers and
  JS's `setFromBase64 -> {read,written}` with `stop-before-partial` is the
  documented userland pattern for exactly this carry, while Elixir/Python leave
  it to the caller and are the gap this closes (`rust.md` §9,§12; `js-ts.md` §9,
  §12; `elixir.md` §9,§11; `python.md` §12).`

## Error Surface

There is exactly **one** error type: `Base64Error`, declared with
`raises Base64Error` on every decoder. It carries:

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | `ErrorKind` | `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING` or `INCOMPLETE`. |
| `position` | `Int` | Zero-based index into the original input where the failure was detected. |

Which API can raise which kind:

| API | Raises | Kinds |
| --- | --- | --- |
| `encode`, `encode_into` | no | — |
| `encoded_len`, `decoded_len` | no | — |
| `is_valid` | no | — (returns `Bool`) |
| `decode`, `decode_into` | yes | `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING` |
| `Decoder.feed` | yes | `INVALID_SYMBOL`, `INVALID_LENGTH`, `INVALID_PADDING` |
| `Decoder.finish` | yes | adds `INCOMPLETE` |
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
*mandatory*, not to manage memory. `feed` borrows its chunk; `finish`/`discard`
take `deinit self` and consume the value. Mojo's ASAP destruction frees the
carry deterministically (`mojov1/lifecycle/death`); the C burden of
`EVP_ENCODE_CTX_free` and the Rust `Drop`-suppresses-errors footgun both
disappear (`c.md` §5,§9; `rust.md` §11,§12).

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

None. Every decision above is closed against the reviewed research and the
`mojov1` buch:

- The alphabet is a compile-time value parameter; Mojo's documented
  value-parameter idiom with struct-typed constants (e.g. `String`,
  `SIMD`, and the `comptime`-member enumeration pattern) covers it
  (`mojov1/functions/parameters-and-generics`; `mojov1/keywords/comptime`).
- Padding and whitespace are explicit `comptime` policies with named constants,
  not booleans or sentinels.
- The error surface is a single typed struct with a `kind` discriminant and a
  `position`, which Mojo supports directly (`mojov1/errors/error-model`).
- Streaming uses `@explicit_destroy` with named `finish`/`discard` methods
  taking `deinit self`, which Mojo 1.x documents and enforces
  (`mojov1/decorators/explicit-destroy`).
- There is no I/O, so EOF/EINTR/EAGAIN/close are structurally not applicable.

