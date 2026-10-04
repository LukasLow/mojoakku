# base32 research: Rust

## 1. Standard library support

Rust's standard library has **no** base32, base64 or base16 module. The `std`
crate index lists the modules and contains none of the three
(`https://doc.rust-lang.org/std/index.html`). Base32 is therefore always a
third-party crate dependency. Three crates matter: **`base32`** (a dedicated,
no_std base32 codec), **`data-encoding`** (a general base-2/4/8/16/32/64 engine)
and **`base64ct`** (constant-time base64; useful contrast, no base32). Hex has
`hex`; base64 has `base64`.

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page records only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

- **`base32`** — author andreasots, "MIT OR Apache-2.0", `#![no_std]`,
  `#![deny(missing_docs)]`; "Encoders and decoders for various Base32 variants"
  (`andreasots/base32`, `src/lib.rs:1-5`). This is the dedicated reference for
  base32 alphabets, including Crockford, z-base-32 and Nix's reversed base32.
  **Revision note:** the published **0.5.1** docs expose an `Alphabet` **enum**
  (`Rfc4648`, `Rfc4648Lower`, `Rfc4648Hex`, `Rfc4648HexLower`, `Crockford`, `Z`)
  and free `encode`/`decode` functions
  (`https://docs.rs/base32/latest/base32/enum.Alphabet.html`,
  `https://docs.rs/base32/latest/base32/`). The **master branch** (which §3 below
  documents) has been rewritten as an `Encoding` **struct** with builder methods
  (`const fn new`, `with_symbol`, `with_ignore_case`, `with_padding`,
  `with_reversed`) and the `RFC4648*`/`CROCKFORD`/`Z`/`NIX` constants
  (`andreasots/base32`, `src/lib.rs`). The two API shapes are not the same release;
  the master rewrite is not in 0.5.1. (Assessment: derived from comparing the two
  sources.)
- **`data-encoding` 2.11.1** — author ia0, MIT, 100% documented; "Efficient and
  customizable data-encoding functions like base64, base32, and hex", supporting
  "bases of size 2, 4, 8, 16, 32, and 64" (`https://docs.rs/data-encoding/latest/data_encoding/`).
- **`base64ct` 1.8.3** — RustCrypto (tarcieri), "Apache-2.0 OR MIT"; constant-time
  base64 only, no base32 (`https://docs.rs/base64ct/latest/base64ct/`).
- **`base64` 0.23.1** — Marshall Pierce, "Correct, fast, and configurable";
  base64 only, but its Engine/alphabet/padding design is the family template
  (`marshallpierce/rust-base64`).
- **`hex` 0.4.3** — base16 only (`https://docs.rs/hex/latest/hex/`).

(Assessment: derived from the crates' docs/source above: unlike base64, where
the `base64` crate dominates, base32 in Rust splits between a small dedicated
`base32` crate and the general `data-encoding` engine.)

## 3. Exposed APIs

`base32` (andreasots/base32, **master branch** — an `Encoding`-struct API that is
not the shape published in 0.5.1; see §2, revision note):

- `struct Encoding { alphabet: [u8; 32], inv_alphabet: [u8; 128], padding:
  Option<u8>, reversed: bool }`.
- `const fn new(alphabet: [u8; 32]) -> Self`; builder-style `const fn
  with_symbol(self, symbol: u8, value: u8)`, `with_ignore_case(self)`,
  `with_padding(self, padding: u8)`, `with_reversed(self)`; `alphabet()`.
- `encoded_length(&self, length: usize) -> usize` and
  `decoded_length(&self, data: &str) -> Result<usize, Error>`.
- `encode(&self, data: &[u8]) -> String` (alloc) and
  `encode_buf<'a>(&self, data: &[u8], buf: &'a mut [u8]) -> Result<&'a mut
  [u8], Error>`.
- `decode(&self, data: &str) -> Result<Vec<u8>, Error>` (alloc) and
  `decode_buf<'a>(&self, data: &str, buf: &'a mut [u8]) -> Result<&'a mut
  [u8], Error>`.
- Predefined constants: `CROCKFORD`, `RFC4648`, `RFC4648_NOPAD`,
  `RFC4648_LOWER`, `RFC4648_LOWER_NOPAD`, `RFC4648_HEX`, `RFC4648_HEX_NOPAD`,
  `RFC4648_HEX_LOWER`, `RFC4648_HEX_LOWER_NOPAD`, `Z` (z-base-32), `NIX`
  (Nix's reversed base32).

`data-encoding` (`https://docs.rs/data-encoding/latest/data_encoding/`):
constants `BASE32`, `BASE32_NOPAD`, `BASE32HEX`, `BASE32HEX_NOPAD`,
`BASE32_DNSSEC`, `BASE32_DNSCURVE`, `BASE32_NOPAD_NOCASE`,
`BASE32_NOPAD_VISUAL`; type `Encoding` with `encode`, `encode_mut`,
`encode_mut_str`, `encode_append`, `encode_len`, `encode_align`, `decode`,
`decode_mut`, `decode_len`, `decode_append`; `Specification` builder with
`symbols`, `bit_order`, `check_trailing_bits`, `padding: Option<char>`, `ignore`,
`wrap`, `translate`; streaming `Encoder` (`append`/`finalize`);
`DecodeError {position, kind}` and `DecodePartial {read, written, error}`.

(Assessment: base32-specific point — `data-encoding` models the two RFC 4648
alphabets plus DNSSEC and DNSCurve, and makes case-insensitivity an optional
character translation, whereas the `base32` crate makes it a per-encoding
`with_ignore_case()` builder step.)

## 4. Error representation

Rust uses `Result<T, E>` with explicit error enums; no exceptions, no sentinels.

- `base32::Error` has four variants: `InvalidSymbol { offset: usize, symbol:
  u8 }` ("Index of the invalid symbol"; display "invalid symbol {c} (0xXX) at
  offset {offset}"), `InvalidLength`, `InvalidPadding`, and `BufferTooSmall {
  expected: usize }` ("passed buffer is too small, expected at least {expected}
  bytes") (`andreasots/base32`, `src/lib.rs`). The offset-carrying
  `InvalidSymbol` and the separate buffer-too-small case are both notable.
- `data-encoding::DecodeError { position: usize, kind: DecodeKind }` with
  `DecodeKind { Length, Symbol, Trailing, Padding }`; `position` "is always a
  valid input position and represents the first encountered error"
  (`https://docs.rs/data-encoding/latest/data_encoding/struct.DecodeError.html`).
  It also offers `DecodePartial { read, written, error }` for error recovery.
- `base32`'s `decoded_length` returns `InvalidPadding` when the padding run is
  not one of `[0, 6, 4, 3, 1]` and `InvalidLength` for a length not divisible by
  8 (padded mode) — the base32 quantum made explicit in the error type.
- `data-encoding` distinguishes `Trailing` (non-zero trailing bits) from
  `Padding`, and its `check_trailing_bits` specification flag controls it; the
  crate docs explicitly call non-canonical encodings "an attack vector as
  described in Base64 Malleability in Practice".
  (https://docs.rs/data-encoding/latest/data_encoding/)

## 5. Ownership semantics

Rust's borrow checker makes the ownership split explicit in every signature.

- Input is **borrowed**: `encode(&self, data: &[u8])`, `decode(&self, data:
  &str)`; the encoding is passed by shared reference `&self`
  (`andreasots/base32`, `src/lib.rs`).
- Three output modes: the alloc variants return owned `String`/`Vec<u8>`; the
  `_buf` variants write into a caller-provided `&mut [u8]` and return a
  sub-slice `&'a mut [u8]` (or `BufferTooSmall` if it cannot fit)
  (`andreasots/base32`, `src/lib.rs`). This is exactly the "borrowed in, count
  out" model.
- `data-encoding` adds `encode_mut`/`decode_mut` (in-place over the same buffer,
  so the caller's slice holds the result) alongside `encode`/`decode` (alloc)
  and `encode_append`/`decode_append` (`https://docs.rs/data-encoding/latest/data_encoding/`).
- `base32`'s `encode_buf`/`decode_buf` "will not write any bytes past exactly
  what is decoded (no stray garbage bytes at the end)"; `decode_buf` may reverse
  the buffer in place for reversed encodings (`NIX`) (`andreasots/base32`,
  `src/lib.rs`).

## 6. Blocking / non-blocking

In-memory encode/decode is not I/O and neither blocking nor async.
`data-encoding` is `#![no_std]` and allocation-free in its core, so it has no
runtime model at all. Neither base32 crate exposes an `io::Read`/`io::Write`
adapter (unlike `base64`, which ships `read::DecoderReader`/`write::EncoderWriter`)
and neither has an `async fn` or `Future`. An async caller must chunk at the
5-byte boundary itself. (Assessment: derived from the `andreasots/base32` API
surface, which has no I/O module, and the `data-encoding` no_std design.)

## 7. Alphabet variants, case and padding

This is the base32-specific heart, and Rust is the most explicit of all surveyed
languages.

- **`base32` crate variants** (`andreasots/base32`, master `src/lib.rs`; see §2
  revision note):
  - `RFC4648` = `ABCDEFGHIJKLMNOPQRSTUVWXYZ234567` + `=` padding.
  - `RFC4648_NOPAD` = same alphabet, no padding.
  - `RFC4648_LOWER` / `RFC4648_LOWER_NOPAD` = lowercased alphabet.
  - `RFC4648_HEX` = `0123456789ABCDEFGHIJKLMNOPQRSTUV` + `=`.
  - `RFC4648_HEX_NOPAD`, `RFC4648_HEX_LOWER`, `RFC4648_HEX_LOWER_NOPAD`.
  - `CROCKFORD` = `0123456789ABCDEFGHJKMNPQRSTVWXYZ`, plus `I`/`L`→1 and `O`→0
    aliases and `with_ignore_case()`; **no padding**.
  - `Z` = z-base-32 `ybndrfg8ejkmcpqxot1uwisza345h769` (no padding).
  - `NIX` = `0123456789abcdfghijklmnpqrsvwxyz` with `with_reversed()` (Nix's
    right-to-left base32).
- **Custom alphabets** are first-class: `Encoding::new(*b"…32 bytes…")` plus
  `with_symbol`, `with_padding`, `with_ignore_case`, `with_reversed`.
- **Padding** is `Option<u8>` per encoding; `decoded_length` enforces the valid
  base32 padding runs `[0, 6, 4, 3, 1]` and returns `InvalidPadding` otherwise.
- **Canonicality**: the `base32` crate does not expose a trailing-bit check
  (its decode reads whole 8-symbol quanta and ignores the low bits of the final
  symbol); `data-encoding` does, via `Specification::check_trailing_bits` and
  reports `DecodeKind::Trailing`. (Assessment: derived from both sources.)
- **Case handling**: `base32` makes it opt-in via `with_ignore_case()`, whose doc
  warns "symbols added after this function is called will still be
  case-sensitive"; `data-encoding` expresses it as character `translate`,
  with the ready-made `BASE32_NOPAD_NOCASE` constant. Default is
  case-sensitive in both — matching RFC 4648 §12's security warning.
  (Sources: `andreasots/base32`, `src/lib.rs`;
  https://docs.rs/data-encoding/latest/data_encoding/;
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **RFC 4648 reference**: §6 Table 3 (base32 `A-Z2-7`), §7 Table 4 (base32hex
  `0-9A-V`), §3.2 padding, §3.5 canonical encoding.
  (https://www.rfc-editor.org/rfc/rfc4648.txt)

## 8. Timeouts

Not applicable. No crate exposes a timeout or deadline; there is no
`Duration`/deadline parameter anywhere, and neither base32 crate performs I/O.
Cancellation for base64's streaming adapters is expressed through the I/O trait
contract (`base64` crate), but base32 has no such adapter. Async timeouts belong
to the async runtime wrapping any caller-built stream, not to the codec.
(Assessment: derived from the API surfaces above.)

## 9. Streaming / incremental encode and decode

- **`base32` is whole-buffer, not incremental.** `encode`/`decode` and their
  `_buf` forms take a complete input; `Chunker` is a private iterator that pads a
  partial final quantum *within one call* (`andreasots/base32`, `src/lib.rs`).
  There is no public `feed`/`finish` or `Encoder` type. So a streaming caller
  must hold the 0–4 byte / 0–7 symbol remainder itself. (Assessment: derived
  from the absence of any incremental API in the source.)
- **`data-encoding` has the streaming type**: `Encoding::new_encoder(&mut
  output)` returns `Encoder` with `append(&[u8])` and `finalize()`; "It is
  equivalent to use an Encoder with multiple calls to Encoder::append() than to
  first concatenate all the input … In particular, this function will not
  introduce padding or wrapping between inputs", and `finalize` "is required for
  correctness, otherwise some encoded data may be missing at the end"
  (`https://docs.rs/data-encoding/latest/data_encoding/struct.Encoder.html`).
- **In-place `_mut` variants** enable caller-managed buffers without a separate
  streaming state (`https://docs.rs/data-encoding/latest/data_encoding/`).
- Leftover-byte carry in `data-encoding`'s `Encoder` is internal state; the
  caller's contract is simply "append fragments, then finalize". For a
  hand-rolled base32 stream the carry is 0–4 input bytes on encode and 0–7
  symbols on decode until a full 8-symbol quantum exists.

## 10. Interesting design decisions

- **One `Encoding` value with a builder of const fns.** `base32`'s
  `Encoding::new(..).with_padding(..).with_ignore_case().with_reversed()` is
  fully `const fn`, so every variant is a compile-time constant with no runtime
  setup (`andreasots/base32`, `src/lib.rs`).
- **Alphabet *and* aliases as separate concepts.** `with_symbol` adds an extra
  symbol the *decoder* accepts (e.g. `I`/`L`→1 for Crockford) without changing
  the encoder's output — a precise way to model confusable input.
  (`andreasots/base32`, `src/lib.rs`)
- **`with_ignore_case` as a builder step with an ordering caveat.** Making
  case-insensitivity explicit, and documenting that symbols added afterward are
  still case-sensitive, is a sharp, honest contract.
- **Separate `encoded_length` and fallible `decoded_length`.** The decode length
  depends on padding validity, so it returns `Result<usize, Error>` — a good
  split from the total encode length (`andreasots/base32`, `src/lib.rs`).
- **`error { offset, symbol }`** carries the exact failing position and byte, so
  callers can point at the bad character (`andreasots/base32`, `src/lib.rs`).
- **Canonicality as a spec flag with a documented attack rationale.**
  `data-encoding` lets the user turn trailing-bit checking off but documents the
  malleability risk, and its docs include a concrete decode-difference table
  versus the `base64` crate and GNU `base64`
  (`https://docs.rs/data-encoding/latest/data_encoding/`).
- **DNSSEC / DNSCurve as named constants**, not as user assemblies: the real
  base32 dialects are shipped (`data-encoding`).
- **Exotic alphabets are real, not hypothetical**: z-base-32 (`Z`) and Nix's
  reversed base32 (`NIX`) are predefined, showing how far the variant space
  extends beyond RFC 4648 (`andreasots/base32`, `src/lib.rs`).

## 11. Decisions NOT to copy

- **`BufferTooSmall` as a first-class public error that encodes a size.**
  Returning "the buffer you gave me is too small, I needed N" is fine in Rust;
  in Mojo the cleaner contract is a pure `encoded_length`/`decoded_length`
  function the caller uses to size the buffer, with a `raises` only for invalid
  data. (Assessment: derived from `andreasots/base32` and Mojo's explicit sizing
  in `mojov1/stdlib/base64`.)
- **An unbounded variant matrix** (nine RFC4648 constants + Crockford + z-base-32
  + Nix). A first Mojo pass should ship standard base32 + base32hex (+ padding
  toggle) and relegate Crockford/z-base-32/Nix to the backlog.
- **`with_reversed()` and `with_symbol()` in the general API.** These are
  niche-dialect features; they multiply test surface. Keep them out of the core
  and record them as backlog candidates.
- **No canonicality check** in the dedicated `base32` crate: copying it would
  reproduce the RFC 4648 §3.5 malleability gap that `data-encoding` explicitly
  warns about. (Sources: `andreasots/base32`; https://docs.rs/data-encoding/latest/data_encoding/;
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **No streaming API** in the dedicated `base32` crate: the caller re-implements
  the carry. Mojo should ship the incremental type. (Assessment: derived from
  the absence of a public encoder/decoder state type.)
- **`no_std`/feature-matrix complexity** is a Rust-ecosystem necessity, not
  something MojoAkku needs to replicate.
- **Silent error suppression in `Drop`** (`data-encoding`'s `Encoder` has a
  `Drop` impl alongside the explicit `finalize`): convenient but a footgun; a
  Mojo API should make the final flush explicit and non-silent.
  (https://docs.rs/data-encoding/latest/data_encoding/struct.Encoder.html)

## 12. Ideas fitting Mojo

- **Preset encodings as compile-time constants**: the `base32` constants and the
  `data-encoding` `BASE32`/`BASE32HEX` pair translate directly to Mojo
  `alias`/`comptime` values — no runtime setup.
- **Borrowed buffer in, count out**: `encode_buf(&self, data, &mut [u8]) ->
  Result<&mut [u8], Error>` and `decode_buf` are exactly the ownership model
  Mojo can express with `borrowed` input and a mutable destination buffer
  (`andreasots/base32`, `src/lib.rs`).
- **Typed error enum with offsets**: `Error::InvalidSymbol { offset, symbol }` /
  `InvalidLength` / `InvalidPadding` is the minimal, machine-usable error set a
  Mojo `Error` payload should carry. `data-encoding`'s `DecodeError { position,
  kind }` adds the "first error position" guarantee worth copying.
- **Separate "encoded length" (total) from "decoded length" (fallible)**: matches
  Mojo's explicit buffer sizing and makes the padding-validity check part of the
  length query (`andreasots/base32`, `src/lib.rs`).
- **Explicit `comptime` alphabet + padding + case**: model standard/base32hex as
  values and `padded`/`ignore_case` as `comptime` parameters, matching
  `base32`'s `with_padding`/`with_ignore_case` without the builder churn.
- **Aliases as a decode-only concept**: `with_symbol`'s split between encoder
  output and decoder acceptance is the right way to model Crockford's
  `I`/`L`/`O` confusables if that variant is ever added.
- **Mandatory finalize for correctness**: `data-encoding`'s `Encoder::finalize`
  ("required for correctness, otherwise some encoded data may be missing at the
  end") argues for a Mojo streaming encoder whose final flush is an explicit,
  non-silent step.
- **A trailing-bit/canonicality option with a documented warning**: adopt
  `data-encoding`'s `check_trailing_bits` choice, not the dedicated crate's
  silence. (Sources: https://docs.rs/data-encoding/latest/data_encoding/;
  https://www.rfc-editor.org/rfc/rfc4648.txt)

## Sources

- `base32` crate source (andreasots/base32, **master branch** — `Encoding`-struct
  API, distinct from the 0.5.1 release):
  https://raw.githubusercontent.com/andreasots/base32/master/src/lib.rs
- `base32` **0.5.1** docs (enum-based `Alphabet` API, the published release):
  https://docs.rs/base32/latest/base32/ and
  `Alphabet` enum: https://docs.rs/base32/latest/base32/enum.Alphabet.html
- `data-encoding` 2.11.1:
  https://docs.rs/data-encoding/latest/data_encoding/ ;
  `Encoder`: https://docs.rs/data-encoding/latest/data_encoding/struct.Encoder.html ;
  `DecodeError`: https://docs.rs/data-encoding/latest/data_encoding/struct.DecodeError.html ;
  source https://raw.githubusercontent.com/ia0/data-encoding/main/lib/src/lib.rs
- `base64ct` 1.8.3: https://docs.rs/base64ct/latest/base64ct/
- `base64` crate (marshallpierce/rust-base64, family template):
  https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/lib.rs
- `hex` 0.4.3: https://docs.rs/hex/latest/hex/
- Rust standard library index (no base32 module): https://doc.rust-lang.org/std/index.html
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  https://www.rfc-editor.org/rfc/rfc4648.txt
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
