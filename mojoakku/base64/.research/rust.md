# base64 research: Rust

## 1. Standard library support

Rust's standard library has **no** base64, base32 or base16 module. The
`std` crate index lists the modules (`alloc`, `ascii`, `borrow`, `cmp`,
`collections`, `convert`, `ffi`, `fmt`, `hash`, `io`, `iter`, `net`, `ops`,
`str`, `string`, `sync`, `thread`, `time`, ...) and contains none of the
three (`https://doc.rust-lang.org/std/index.html`). Hex formatting exists only
as a formatter (`format!("{:x}", b)`); there is no codec API.

The de-facto standard is the community crate **`base64`** (current 0.23.1),
described as "Correct, fast, and configurable [base64] decoding and encoding"
(`marshallpierce/rust-base64`, `src/lib.rs:1-4`). Its sibling crates cover the
other radices: **`hex`** for base16 and **`base32`** for base32. All three are
third-party crate dependencies, not std.

## 2. Relevant community libraries

- **`base64` 0.23.1** — author Marshall Pierce, "MIT OR Apache-2.0", edition
  2021, MSRV 1.71, features `std` (default), `alloc`, `simd-unsafe` (default,
  the only `unsafe`; crate is `#![forbid(unsafe_code)]` otherwise)
  (`Cargo.toml` in marshallpierce/rust-base64). This is the reference
  implementation for the whole design (Engine/alphabet/padding).
- **`data-encoding` 2.11.1** — author ia0, MIT, 100% documented; "Efficient and
  customizable data-encoding functions like base64, base32, and hex",
  supporting "bases of size 2, 4, 8, 16, 32, and 64", in-place encode/decode,
  partial decoding, character translation, bit-order, ignored characters and
  wrapping (`https://docs.rs/data-encoding/latest/data_encoding/`).
- **`base64ct` 1.8.3** — RustCrypto (tarcieri), "Apache-2.0 OR MIT"; "Pure Rust
  implementation of Base64 (RFC 4648) ... without data-dependent branches or
  lookup tables, thereby providing portable 'best effort' constant-time
  operation" (`https://docs.rs/base64ct/latest/base64ct/`). Aimed at PEM/private
  keys; supports no_std and avoids heap allocation in the core API.
- **`base64-simd` 0.8.0** — author Nugine, MIT; "SIMD-accelerated base64
  encoding and decoding" with runtime CPU feature detection by default
  (`https://docs.rs/base64-simd/latest/base64_simd/`).
- **`hex` 0.4.3** — authors incl. KokaKiwi, "MIT OR Apache-2.0";
  "Encoding and decoding hex strings", also offers `ToHex`/`FromHex` traits
  (`https://docs.rs/hex/latest/hex/`).
- **`base32` 0.5.1** — author andreasots, "MIT OR Apache-2.0"; tiny API:
  `Alphabet` enum + `encode`/`decode` functions (`https://docs.rs/base32/latest/base32/`).
(Assessment: derived from the crates' docs/Cargo.toml above.)

## 3. Exposed APIs

`base64` (`marshallpierce/rust-base64`):

- Trait **`Engine`**: `encode` -> `String`, `encode_string(&mut String)`,
  `encode_slice(&mut [u8]) -> Result<usize, EncodeSliceError>`, `decode` ->
  `Result<Vec<u8>, DecodeError>`, `decode_vec(&mut Vec<u8>)`,
  `decode_slice(&mut [u8]) -> Result<usize, DecodeSliceError>`,
  `decode_slice_unchecked`, `padding() -> Symbol`
  (`src/engine/mod.rs`, trait body). Plus `Config` (`encode_padding() -> bool`),
  `DecodeEstimate`, `DecodeMetadata`, and `enum DecodePaddingMode { Indifferent,
  RequireCanonical, RequireNone }` (`src/engine/mod.rs`).
- Engines: `GeneralPurpose` (alias `Scalar`), built with
  `GeneralPurpose::new(&Alphabet, GeneralPurposeConfig)`; config builders
  `with_encode_padding`, `with_decode_allow_trailing_bits`,
  `with_decode_padding_mode` (`src/engine/general_purpose/mod.rs`).
- Presets: `STANDARD`, `STANDARD_NO_PAD`, `URL_SAFE`, `URL_SAFE_NO_PAD` plus
  `_PAD_INDIFFERENT`/`_NO_PAD_INDIFFERENT` variants, and the config constants
  `PAD`, `NO_PAD`, `PAD_INDIFFERENT`, `NO_PAD_INDIFFERENT`
  (`src/engine/general_purpose/mod.rs`). `prelude` re-exports
  `BASE64_STANDARD`, `BASE64_STANDARD_NO_PAD`, `BASE64_URL_SAFE`,
  `BASE64_URL_SAFE_NO_PAD` (`src/prelude.rs`).
- `alphabet::Alphabet` with `new(&str)` (const fn), `new_with_padding(&str,
  Symbol)`, `as_str()`, `symbols()`, `padding()`; `Symbol`; error
  `ParseAlphabetError` (`src/alphabet.rs`).
- Free helpers: `encoded_len(bytes_len, padding) -> Option<usize>`,
  `decoded_len_estimate(encoded_len) -> usize` (`src/encode.rs`,
  `src/decode.rs`). The legacy free functions `encode`, `decode`,
  `encode_engine*`, `decode_engine*` are `#[deprecated(since = "0.21.0",
  note = "Use Engine::encode")]` (`src/encode.rs`, `src/decode.rs`).
- I/O adapters: `read::DecoderReader::new(R, &E)` implementing `io::Read`;
  `write::EncoderWriter::new(W, &E)` implementing `io::Write` with `finish()`
  (`src/read/decoder.rs`, `src/write/encoder.rs`). `display::Base64Display`.
- `chunked_encoder::ChunkedEncoder` + `Sink` trait, BUF_SIZE 1024,
  CHUNK_SIZE = BUF_SIZE/4*3 (`src/chunked_encoder.rs`).

`data-encoding`: constants `BASE64`, `BASE64_NOPAD`, `BASE64URL`,
`BASE64URL_NOPAD`, `BASE32`, `BASE32_NOPAD`, `BASE32HEX`, `BASE32HEX_NOPAD`,
`BASE32_DNSSEC`, `BASE32_DNSCURVE`, `BASE64_MIME`, `HEXLOWER`, `HEXUPPER`
(and permissive variants); type `Encoding` with `encode`, `encode_mut`,
`encode_mut_str`, `encode_append`, `encode_len`, `encode_align`,
`decode`, `decode_mut`, `decode_len`, `decode_append`; `Specification` builder;
`Encoder` (streaming, `append`/`finalize`); `DecodeError {position, kind}` and
`DecodePartial {read, written, error}` (`https://docs.rs/data-encoding/latest/data_encoding/`,
`lib/src/lib.rs`).

`base64ct`: traits/types `Base64`, `Base64Url`, `Base64Unpadded`,
`Base64UrlUnpadded`, `Base64Bcrypt`, `Base64Crypt`, `Base64Pbkdf2`,
`Encoding` trait, `Encoder`/`Decoder` (buffered incremental), `LineEnding`,
`InvalidEncodingError`, `InvalidLengthError`
(`https://docs.rs/base64ct/latest/base64ct/`).

`hex`: `decode`, `decode_to_slice`, `encode`, `encode_to_slice`,
`encode_upper`, traits `ToHex`/`FromHex`, error `FromHexError`
(`https://docs.rs/hex/latest/hex/`).

## 4. Error representation

Rust uses `Result<T, E>` with explicit error enums; no exceptions, no sentinels.

- `base64::DecodeError`: `InvalidByte(usize, u8)`, `InvalidLength(usize)`,
  `InvalidLastSymbol { offset, symbol, symbol_value }`, `InvalidPadding`
  (`src/decode.rs:9-42`). `InvalidLastSymbol` is "for symbols that are in the
  alphabet but represent nonsensical encodings", controlled by
  `with_decode_allow_trailing_bits` (`src/decode.rs:24-34`).
- `DecodeSliceError { DecodeError(DecodeError), OutputSliceTooSmall }` — the
  buffer-too-small case is a *separate* error because a caller-sized slice is the
  one thing the typed decode helpers cannot fix by reallocating
  (`src/decode.rs:88-101`).
- `EncodeSliceError::OutputSliceTooSmall` (`src/encode.rs`, enum definition).
- `ParseAlphabetError`: `InvalidLength`, `DuplicatedByte(u8)`,
  `UnprintableByte(u8)`, `ReservedByte(u8)` (`src/alphabet.rs`).
- I/O adapters map decode failures onto `io::Error::new(io::ErrorKind::InvalidData, e)`
  and re-base the offsets onto the whole-stream position via
  `input_consumed_len` (`src/read/decoder.rs`).
- `data-encoding` uses `DecodeError { position: usize, kind: DecodeKind }` with
  `DecodeKind { Length, Symbol, Trailing, Padding }`, and a *partial* result type
  `DecodePartial { read, written, error }` with invariants documented
  (`read <= error.position`, `written <= decode_len(read)`) (`lib/src/lib.rs`).
- `hex` returns `FromHexError` (`https://docs.rs/hex/latest/hex/`).

## 5. Ownership semantics (buffer/ownership of encode input and produced output)

Rust's borrow checker makes the ownership split explicit in every signature.

- Input is **borrowed**: `encode<T: AsRef<[u8]>>(&self, input: T)` and
  `decode<T: AsRef<[u8]>>(&self, input: T)`; the engine itself is passed by
  shared reference `&self` (`src/engine/mod.rs`). `EncoderWriter<'e, E, W>` and
  `DecoderReader<'e, E, R>` hold `engine: &'e E` — the engine outlives the
  adapter (`src/write/encoder.rs`, `src/read/decoder.rs`).
- Three output ownership modes per direction are documented as a table: `encode`
  "always" allocates a new `String`; `encode_string` "appends to provided
  `String`", allocating only if capacity is lacking; `encode_slice` "writes to
  provided `&[u8]`" and "never" allocates. Same for `decode` (new `Vec<u8>`),
  `decode_vec` (appends to a `Vec<u8>`), `decode_slice` (writes to a provided
  `&[u8]`) (`src/lib.rs`, "Memory allocation" section).
- `decode_vec` preserves any pre-existing prefix and only truncates back to
  `starting_output_len + bytes_written` (`src/engine/mod.rs`, `decode_vec`);
  tests `decode_into_nonempty_vec_doesnt_clobber_existing_prefix` and
  `decode_slice_doesnt_clobber_existing_prefix_or_suffix` assert it
  (`src/decode.rs`).
- `encode_slice`/`decode_slice` "will not write any bytes past exactly what is
  decoded (no stray garbage bytes at the end)" (`src/engine/mod.rs`,
  `decode_slice` docs).
- `EncoderWriter` owns the delegate writer as `Option<W>` so `finish()` can
  return it, and buffers leftovers in `extra_input: [u8; 3]` and
  `output: [u8; 1024]` (`src/write/encoder.rs`).

## 6. Blocking / non-blocking

In-memory encode/decode is not I/O and neither blocking nor async. The
`io::Read`/`io::Write` adapters are **synchronous** and inherit the underlying
stream's blocking behaviour. Notably the core trait carries a thread-safety
bound: `pub trait Engine: Send + Sync`, so engines may be shared across threads
and used concurrently without locking (`src/engine/mod.rs`). There is no
`async fn` or `Future` in the crate; an async ecosystem wraps the synchronous
adapter. `data-encoding` is `#![no_std]` and allocation-free in its core, so it
has no runtime model at all (`lib/src/lib.rs`).

## 7. Alphabet variants and padding

- `base64` ships six named alphabets: `STANDARD` (`+/`), `URL_SAFE` (`-_`),
  `CRYPT` (crypt(3), `.` and `/` *first*), `BCRYPT`, `IMAP_MUTF7` (`+` and `,`,
  RFC 3501) and `BIN_HEX` (BinHex 4.0) (`src/alphabet.rs`). Custom alphabets via
  `Alphabet::new` must be 64 unique printable ASCII bytes (`32..=126`) and must
  not contain the padding symbol (`src/alphabet.rs`).
- Padding is a *decode-mode* enum, not just a flag: `DecodePaddingMode {
  Indifferent, RequireCanonical, RequireNone }` (`src/engine/mod.rs`). Encode
  padding is the separate boolean `encode_padding` (`src/engine/mod.rs`,
  `Config`).
- Defaults: `GeneralPurposeConfig::new` is padding=true,
  `decode_allow_trailing_bits=false`,
  `decode_padding_mode=RequireCanonical`; `with_encode_padding(false)` +
  `RequireNone` gives `NO_PAD` (`src/engine/general_purpose/mod.rs`). The docs
  argue "Padding serves no practical purpose, so where possible, encode without
  padding" (`src/lib.rs`).
- `data-encoding` is even broader: it generates all bases of size 2/4/8/16/32/64
  from a `Specification` with `symbols`, `bit_order`
  (`MostSignificantFirst`/`LeastSignificantFirst`), `check_trailing_bits`,
  `padding: Option<char>`, `ignore`, `wrap` and `translate` (`lib/src/lib.rs`).
  Its constant set includes base64url, MIME, base32hex, DNSSEC, DNSCurve and
  hex — plus a documented decode-difference table versus the `base64` crate and
  GNU `base64` (`https://docs.rs/data-encoding/latest/data_encoding/`).
- `base64ct` chooses correctness over customisability: "The padded variants
  require (=) padding. Unpadded variants expressly reject such padding.
  Whitespace is expressly disallowed" (`https://docs.rs/base64ct/latest/base64ct/`).
- Hex casing is a function-level choice in the `hex` crate (`encode` lowercase,
  `encode_upper` uppercase) (`https://docs.rs/hex/latest/hex/`); `data-encoding`
  models it as two constants `HEXLOWER`/`HEXUPPER` (`lib/src/lib.rs`).

## 8. Timeouts

Not applicable. No crate exposes a timeout or deadline; there is no
`Duration`/deadline parameter anywhere. Cancellation for the streaming adapters
is expressed through the I/O trait contract: `DecoderReader::read` returns
`io::Error` (including errors from the delegate reader), and `EncoderWriter`
returns the delegate's `io::Error` and treats `ErrorKind::Interrupted`
specially by retrying (`src/read/decoder.rs`, `src/write/encoder.rs`). Async
timeouts belong to the async runtime wrapping the synchronous `Read`/`Write`,
not to the codec (Assessment: derived from the two adapter implementations).

## 9. Streaming / incremental encode+decode and leftover-byte carry

- **Write side** — `write::EncoderWriter` implements `io::Write`. It carries
  leftover input in `extra_input: [u8; 3]` + `extra_input_occupied_len`, encodes
  only complete triples, and buffers output in `output: [u8; 1024]` plus
  `output_occupied_len` for a slow delegate. `MIN_ENCODE_CHUNK_SIZE = 3`,
  `MAX_INPUT_LEN = BUF_SIZE/4*3` (`src/write/encoder.rs`). Finalisation is
  `finish()`, which writes the last partial triple **with padding if
  configured**; a `Drop` impl calls it automatically but "any error that occurs
  when invoking the underlying writer will be suppressed", so explicit
  `finish()` is the error-checked path (`src/write/encoder.rs`). Calling
  `write`/`finish` after a successful `finish` panics.
- **Read side** — `read::DecoderReader` implements `io::Read` with
  `b64_buffer: [u8; 1024]` (`b64_offset`, `b64_len`) and a
  `decoded_chunk_buffer: [u8; 3]` (`decoded_offset`, `decoded_len`) so it can
  serve callers whose read buffer is smaller than one decoded chunk
  (`src/read/decoder.rs`). It tracks `input_consumed_len` and `padding_offset`
  and **rejects data after padding**, reporting the error at the *first* padding
  byte (`src/read/decoder.rs`).
- **In-memory chunking** — `ChunkedEncoder` + the `Sink` trait encode into a
  fixed `[u8; 1024]` stack buffer with `bytes.chunks(CHUNK_SIZE)`; padding is
  only added on the "Final, potentially partial, chunk"
  (`src/chunked_encoder.rs`). This is what `encode_string` uses under the hood
  (`src/engine/mod.rs`, `encode_string`).
- **`data-encoding`** exposes an explicit fragmented encoder:
  `Encoding::new_encoder(&mut output)` returning `Encoder` with
  `append(&[u8])` and `finalize()`; "It is equivalent to use an Encoder with
  multiple calls to Encoder::append() than to first concatenate all the input
  and then use Encoding::encode_append(). In particular, this function will not
  introduce padding or wrapping between inputs"
  (`https://docs.rs/data-encoding/latest/data_encoding/struct.Encoder.html`).
- **`base64ct`** offers `Encoder`/`Decoder` "Stateful Base64 ... with support
  for buffered, incremental decoding/encoding"
  (`https://docs.rs/base64ct/latest/base64ct/`).
- Leftover-byte carry is thus an explicit, countable field in every streaming
  implementation (`extra_input_occupied_len`, `b64_len`/`decoded_len`,
  `Encoder`'s internal state) rather than being hidden.

## 10. Interesting design decisions

- **Engine as a trait, not a free function**: all functionality hangs off
  `trait Engine`, with `internal_encode`/`internal_decode` hidden from users
  (`#[doc(hidden)]`) so alternative engines (scalar, AVX2, NEON, SIMD, future
  constant-time) are drop-in (`src/engine/mod.rs`). `Simd`, `Avx2`, `Neon` are
  feature-gated (`Cargo.toml`, `simd-unsafe`).
- **Config split from alphabet**: `Alphabet` (symbols+padding symbol) and
  `GeneralPurposeConfig` (encode padding, trailing bits, decode padding mode)
  are orthogonal value types, so all four padding combinations come from the
  same engine code (`src/alphabet.rs`, `src/engine/general_purpose/mod.rs`).
- **Conservative decode estimate as its own trait**: `DecodeEstimate` lets an
  engine pre-compute a "no larger than the next largest complete triple" output
  size once, avoiding recomputation on short inputs (`src/engine/mod.rs`).
- **Padding mode as a three-way enum**: `Indifferent` vs `RequireCanonical` vs
  `RequireNone` captures the real-world compatibility matrix that a boolean
  cannot (`src/engine/mod.rs`).
- **Explicit partial-result contract**: `data-encoding`'s `DecodePartial`
  documents `read <= error.position` and `written <= decode_len(read)`, making
  error recovery a first-class, specified behaviour rather than an accident
  (`lib/src/lib.rs`).
- **Canonicality as a user choice**: `data-encoding` documents that it *can*
  check trailing bits, ignore characters, translate and wrap, and lists exactly
  how its decode differs from `base64` and GNU `base64` in a table (including
  "Support concatenated input" = Yes for data-encoding/GNU, No for `base64`)
  (`lib/src/lib.rs`).
- **Constant-time as a separate crate, not a flag**: `base64ct` uses "integer
  arithmetic alone without any lookup tables or data-dependent branches", citing
  the SGX RSA-key-extraction attack paper
  (`https://docs.rs/base64ct/latest/base64ct/`) — a sharp separation of security
  concerns from the general engine.
- **SIMD in-crate behind a feature**: `base64` itself supplies SIMD engines when
  `simd-unsafe` is on, keeping `unsafe` in one module and the crate
  `#![forbid(unsafe_code)]` otherwise (`Cargo.toml`, `src/lib.rs`).

## 11. Decisions NOT to copy

- **Deprecated free functions kept for compatibility**: `encode`, `decode`,
  `encode_engine*`, `decode_engine*` are deprecated shims since 0.21.0
  (`src/encode.rs`, `src/decode.rs`). A new library should start with the clean
  Engine-style API and never grow two parallel surfaces.
- **Panic on arithmetic overflow**: "If length calculations result in
  overflowing `usize`, a panic will result" (`src/lib.rs`, "Panics").
  `decode_slice_unchecked` likewise "Panics if the provided output buffer is too
  small" (`src/engine/mod.rs`). A predictable API should return an error, or use
  Mojo's `raises`, instead of panicking.
- **`decode_slice_unchecked` as a public unchecked entry**: an API whose only
  documented behaviour on mis-sizing is a panic invites bugs; the checked
  variant plus an explicit estimate function is enough.
- **Alphabet with arbitrary padding symbols**: `Alphabet::new_with_padding`
  exists "for strange alphabets that don't use `=`"
  (`src/alphabet.rs`). That is legitimate for BIN_HEX etc. but multiplies test
  surface; MojoAkku should support the RFC 4648 alphabet plus URL-safe first,
  and treat exotic alphabets as optional.
- **`#[doc(hidden)]` trait methods in a public trait**: `Engine` requires users
  see (and could implement) `internal_encode`/`internal_decode`, which is a
  leaky abstraction (`src/engine/mod.rs`).
- **`unsafe` in encoders/decoders**: both `data-encoding`
  (`safety_assert!`/`from_raw_parts`, `lib/src/lib.rs`) and `base64ct`'s stated
  "best effort constant-time" rely on unsafe/low-level arithmetic; MojoAkku
  should not need `unsafe` at all.
- **Huge feature matrix**: `base64` has `std`/`alloc`/`simd-unsafe` with doc
  examples that must be `ignore`d when a feature is off (`src/lib.rs`), and
  `data-encoding` has alloc/no-alloc/no-std branches. That complexity is a
  Rust-ecosystem necessity (no_std, embedded), not something MojoAkku needs to
  replicate.
- **Silent error suppression in `Drop`**: `EncoderWriter::drop` ignores write
  errors (`src/write/encoder.rs`); convenient for Rust, but a footgun that a
  Mojo API should make explicit with a mandatory `finish`-equivalent.

## 12. Ideas fitting Mojo

- **Trait/interface for engines**: `Engine` as the single abstraction that all
  helpers call maps to a Mojo trait with implementations for scalar and (later)
  SIMD engines; the trait/impl split is the same idea (`src/engine/mod.rs`).
- **Preset engines as compile-time constants**: the `prelude` constants
  (`BASE64_STANDARD`, `BASE64_URL_SAFE`, ...) and `const` engine construction
  (`GeneralPurpose::new` is a `const fn`, `src/engine/general_purpose/mod.rs`)
  translate directly to Mojo `alias`/`comptime` constants — no runtime setup.
- **Borrowed buffer in, count out**: `encode_slice(&self, input, &mut [u8]) ->
  Result<usize, ...>` and `decode_slice` are exactly the ownership model Mojo
  can express with `borrowed` input and a mutable destination buffer
  (`src/engine/mod.rs`).
- **Three-way padding mode**: `DecodePaddingMode { Indifferent,
  RequireCanonical, RequireNone }` is a better model than Go's boolean and fits
  a Mojo enum/alias parameter (`src/engine/mod.rs`).
- **Typed error enum with offsets**: `DecodeError::InvalidByte(usize, u8)` /
  `InvalidLastSymbol { offset, symbol, symbol_value }` / `InvalidPadding` shows
  the minimal, machine-usable error set a Mojo `Error` payload should carry
  (`src/decode.rs`).
- **Separate "estimate" from "decode"**: the `DecodeEstimate` trait and
  `decoded_len_estimate`/`encoded_len` functions let the caller size a buffer
  without doing the work twice — a direct fit for Mojo's explicit buffer
  sizing (`src/engine/mod.rs`, `src/decode.rs`, `src/encode.rs`).
- **Leftover carry as explicit struct fields**: `extra_input: [u8; 3]` with a
  separate length, and `DecoderReader`'s two buffers, are the minimal streaming
  state; Mojo structs with fixed arrays plus an occupied-count field translate
  one-to-one (`src/write/encoder.rs`, `src/read/decoder.rs`).
- **Mandatory finalize for correctness**: `EncoderWriter::finish` /
  `data-encoding` `Encoder::finalize` ("required for correctness, otherwise some
  encoded data may be missing at the end",
  `https://docs.rs/data-encoding/latest/data_encoding/struct.Encoder.html`)
  argues for a Mojo streaming encoder whose final flush is an explicit,
  non-silent step.
- **Constant-time as a first-class goal**: `base64ct`'s table-free,
  branch-free approach is a strong signal for a future MojoAkku "secure" engine
  variant, and its no-lookup-table design may suite Mojo's compile-time
  flexibility (`https://docs.rs/base64ct/latest/base64ct/`).

## Sources

- `base64` crate source (marshallpierce/rust-base64, master):
  - `src/lib.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/lib.rs
  - `src/alphabet.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/alphabet.rs
  - `src/engine/mod.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/engine/mod.rs
  - `src/engine/general_purpose/mod.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/engine/general_purpose/mod.rs
  - `src/decode.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/decode.rs
  - `src/encode.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/encode.rs
  - `src/chunked_encoder.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/chunked_encoder.rs
  - `src/read/decoder.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/read/decoder.rs
  - `src/write/encoder.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/write/encoder.rs
  - `src/prelude.rs`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/src/prelude.rs
  - `Cargo.toml`: https://raw.githubusercontent.com/marshallpierce/rust-base64/master/Cargo.toml
- `data-encoding` 2.11.1: docs https://docs.rs/data-encoding/latest/data_encoding/ ; source https://raw.githubusercontent.com/ia0/data-encoding/main/lib/src/lib.rs ; Encoder https://docs.rs/data-encoding/latest/data_encoding/struct.Encoder.html ; README https://raw.githubusercontent.com/ia0/data-encoding/main/README.md
- `base64ct` 1.8.3: https://docs.rs/base64ct/latest/base64ct/
- `base64-simd` 0.8.0: https://docs.rs/base64-simd/latest/base64_simd/
- `hex` 0.4.3: https://docs.rs/hex/latest/hex/
- `base32` 0.5.1: https://docs.rs/base32/latest/base32/
- Rust standard library index (no base64/base32/base16 module): https://doc.rust-lang.org/std/index.html
- RFC 4648 (referenced by all crates): https://datatracker.ietf.org/doc/html/rfc4648
