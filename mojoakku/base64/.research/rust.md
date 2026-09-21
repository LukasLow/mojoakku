# base64 research: Rust

Scope: this file answers the standardized 12-question set from
`.agents/workflows/NewLibPhase1Research.md` for the `base64` library in Rust.
Questions 5, 7 and 9 were adapted to the base64/base32 domain (buffer ownership,
alphabets/padding, streaming) as the task requires. RFC 4648 is the shared
normative reference.

## 1. Standard library support

**Rust's standard library provides nothing for base64/base32/base16.** The module
list at <https://doc.rust-lang.org/std/index.html> (std 1.98.1) contains no
`base64`, `base32` or `hex` module, and the same page lists no such functions. This
is an absence-of-evidence fact taken from the complete module index: the modules
present are `alloc`, `any`, `arch`, `array`, `ascii`, `backtrace`, `borrow`,
`boxed`, `cell`, `char`, `clone`, `cmp`, `collections`, `convert`, `default`,
`env`, `error`, `f32`, `f64`, `ffi`, `fmt`, `fs`, `future`, `hash`, `hint`, `io`,
`iter`, `marker`, `mem`, `net`, `num`, `ops`, `option`, `os`, `panic`, `path`,
`pin`, `prelude`, `primitive`, `process`, `ptr`, `range`, `rc`, `result`, `slice`,
`str`, `string`, `sync`, `task`, `thread`, `time`, `u8`...`usize`, `vec`, plus
nightly-only modules. Source: <https://doc.rust-lang.org/std/index.html>.

Consequence: base64 is **always** a third-party dependency in Rust. Two design
implications follow and are visible throughout this file:
- the crate must declare its own traits/types (there is no std type to extend),
- and `no_std` support is a first-class concern because there is no std to lean on
  in embedded targets (see sections 2 and 5).

One std-adjacent building block exists and is relevant: `std::fmt::Display` is used
by the `base64` crate to offer zero-allocation formatting via `Base64Display`
(section 3), and `std::io::{Read, Write}` is the streaming interface it targets.
Sources: <https://doc.rust-lang.org/std/index.html>,
<https://docs.rs/base64/latest/base64/display/struct.Base64Display.html>.

## 2. Relevant community libraries

Rust has a small but mature base64 ecosystem; the four crates below are the ones
worth comparing, and they occupy three different design philosophies (ergonomic
general purpose, constant-time crypto, and specification-driven).

| Crate | Version | Maintainer / owner | License | Design centre | Source |
|---|---|---|---|---|---|
| `base64` | 0.23.1 (04 Aug 2026) | marshallpierce, alicemaz | MIT OR Apache-2.0 | "correct and fast", multi-level API, SIMD | <https://docs.rs/base64/latest/base64/>, <https://github.com/marshallpierce/rust-base64> |
| `data-encoding` | 2.11.1 (03 Aug 2026) | ia0 | MIT | bases 2/4/8/16/32/64 from one `Specification`, canonicality as a choice | <https://docs.rs/data-encoding/latest/data_encoding/> |
| `base64ct` | 1.8.3 (12 Sep 2026) | RustCrypto (tarcieri, rustcrypto:formats) | Apache-2.0 OR MIT | constant-time, side-channel resistant, PEM/PKCS use | <https://docs.rs/base64ct/latest/base64ct/> |
| `base64-simd` | 0.8.0 (28 Dec 2022) | Nugine | MIT | SIMD-accelerated encode/decode only, based on `vsimd` | <https://docs.rs/base64-simd/latest/base64_simd/> |

Maturity and API-compatibility signals from the sources:
- `base64` crate: 737 stars, 146 forks, 560 commits (master); "This library's
  goals are to be *correct* and *fast*. It's thoroughly tested and widely used."
  It documents per-method throughput (`decode_engine_slice` "2.6GiB/s for a 3 KiB
  input" vs `decode_engine` "2.1 GiB/s"). Source:
  <https://github.com/marshallpierce/rust-base64>.
- `data-encoding`: published by a single owner, no dependencies ("Dependencies"
  section is empty on docs.rs). Source:
  <https://docs.rs/data-encoding/latest/data_encoding/>.
- `base64ct`: explicitly aimed at "encoding/decoding the 'PEM' format used to store
  things like cryptographic private keys (i.e. in the `pem-rfc7468` crate)", with
  the security rationale spelled out: "The paper Util::Lookup: Exploiting key
  decoding in cryptographic libraries demonstrates how the leakage from
  non-constant-time Base64 parsers can be used to practically extract RSA private
  keys from SGX enclaves." Source: <https://docs.rs/base64ct/latest/base64ct/>.
- `base64-simd` is the oldest of the four (Dec 2022) and a pure performance crate;
  it recommends profile settings (`opt-level = 3`, `lto = "fat"`,
  `codegen-units = 1`) to reach maximum speed. Source:
  <https://docs.rs/base64-simd/latest/base64_simd/>.

The `base64` crate's own README points to two further crates for adjacent needs
rather than growing its own feature set:
- `line-wrap` — "does just that" for MIME/PEM line wrapping. Source:
  <https://github.com/marshallpierce/rust-base64> (FAQ).
- `iter-read` — suggested together with `Read`'s `bytes()` to strip unwanted input
  characters. Source: <https://github.com/marshallpierce/rust-base64> (FAQ).

That FAQ also states the project's explicit refusal to be lenient: "I need to
decode base64 with whitespace/null bytes/other random things interspersed in it.
What should I do? Remove non-base64 characters from your input before decoding."
Source: <https://github.com/marshallpierce/rust-base64>.

## 3. Exposed APIs

### 3.1 `base64` crate 0.23.1

Core abstraction: one trait, `Engine`.
```
pub trait Engine: Send + Sync {
    type Config: Config;
    type DecodeEstimate: DecodeEstimate;
    fn config(&self) -> &Self::Config;
    fn padding(&self) -> Symbol;
    // all provided:
    fn encode<T: AsRef<[u8]>>(&self, input: T) -> String
    fn encode_string<T: AsRef<[u8]>>(&self, input: T, output_buf: &mut String)
    fn encode_slice<T: AsRef<[u8]>>(&self, input: T, output_buf: &mut [u8]) -> Result<usize, EncodeSliceError>
    fn decode<T: AsRef<[u8]>>(&self, input: T) -> Result<Vec<u8>, DecodeError>
    fn decode_vec<T: AsRef<[u8]>>(&self, input: T, buffer: &mut Vec<u8>) -> Result<(), DecodeError>
    fn decode_slice<T: AsRef<[u8]>>(&self, input: T, output: &mut [u8]) -> Result<usize, DecodeSliceError>
    fn decode_slice_unchecked<T: AsRef<[u8]>>(&self, input: T, output: &mut [u8]) -> Result<usize, DecodeError>
}
```
The trait is **not** dyn compatible. `Engine` is re-exported at the crate root.
Source: <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>, and
<https://docs.rs/base64/latest/base64/> (Re-exports).

Implementors: `GeneralPurpose`, `Simd` (crate feature `std` and AArch64/x86-64),
`Avx2` (x86-64 only), `Neon`. Sources:
<https://docs.rs/base64/latest/base64/engine/trait.Engine.html> (Implementors),
<https://docs.rs/base64/latest/base64/>.

Alphabet type (`base64::alphabet::Alphabet`) — the design centre of the crate:
- `pub const fn new(alphabet: &str) -> Result<Self, ParseAlphabetError>` — "Create
  an `Alphabet` from a string of 64 unique printable ASCII bytes with `=` as the
  padding symbol. The padding symbol `=` is not allowed in the alphabet."
- `pub const fn new_with_padding(alphabet: &str, padding: Symbol) -> Result<Self, ParseAlphabetError>`
  — "This is meant for strange alphabets that don't use `=` as the padding
  symbol."
- `pub fn as_str(&self) -> &str`, `pub fn symbols(&self) -> [Symbol; 64]`,
  `pub fn padding(&self) -> Symbol`
- `impl TryFrom<&str> for Alphabet`
- `enum ParseAlphabetError`
- Constants: `STANDARD`, `URL_SAFE`, `BCRYPT`, `BIN_HEX`, `CRYPT`, `IMAP_MUTF7`.
Sources: <https://docs.rs/base64/latest/base64/alphabet/struct.Alphabet.html>,
<https://docs.rs/base64/latest/base64/alphabet/index.html>.

Config and padding:
- `GeneralPurposeConfig::new()` — "Create a new config with `padding` = `true`,
  `decode_allow_trailing_bits` = `false`, and `decode_padding_mode =
  DecodePaddingMode::RequireCanonicalPadding`."
- `with_encode_padding(bool)`, `with_decode_allow_trailing_bits(bool)`,
  `with_decode_padding_mode(DecodePaddingMode)` — all `pub const fn`.
- `enum DecodePaddingMode { Indifferent, RequireCanonical, RequireNone }` —
  "Each `Engine` must support at least the behavior indicated by
  `DecodePaddingMode::RequireCanonical`, and may support other modes."
Sources:
<https://docs.rs/base64/latest/base64/engine/general_purpose/struct.GeneralPurposeConfig.html>,
<https://docs.rs/base64/latest/base64/engine/enum.DecodePaddingMode.html>.

Preconfigured engines (`base64::engine::general_purpose`): `PAD`, `NO_PAD`,
`PAD_INDIFFERENT`, `NO_PAD_INDIFFERENT`, `STANDARD`, `STANDARD_NO_PAD`,
`STANDARD_PAD_INDIFFERENT`, `STANDARD_NO_PAD_INDIFFERENT`, `URL_SAFE`,
`URL_SAFE_NO_PAD`, `URL_SAFE_PAD_INDIFFERENT`, `URL_SAFE_NO_PAD_INDIFFERENT`, plus
the type alias `Scalar`. Source:
<https://docs.rs/base64/latest/base64/engine/general_purpose/index.html>.

Prelude (`base64::prelude`): re-exports `Engine`, and renames four presets with a
`BASE64_` prefix: `BASE64_STANDARD`, `BASE64_STANDARD_NO_PAD`, `BASE64_URL_SAFE`,
`BASE64_URL_SAFE_NO_PAD`. "All of these engine presets enforce no trailing bits
when decoding." Source: <https://docs.rs/base64/latest/base64/prelude/index.html>.

Other modules: `display` (`Base64Display`), `read` (`DecoderReader`), `write`
(`EncoderWriter`). Sources: <https://docs.rs/base64/latest/base64/> (Modules).

Free functions still present but **deprecated**: `decode`, `decode_engine`,
`decode_engine_slice`, `decode_engine_vec`, `encode`, `encode_engine`,
`encode_engine_slice`, `encode_engine_string`. Non-deprecated free functions:
`decoded_len_estimate(encoded_len) -> usize` ("conservative estimate ... rounded up
to the next group of 3 decoded bytes") and `encoded_len(input_len, padding) ->
Option<usize>`. Source: <https://docs.rs/base64/latest/base64/> (Functions).

Errors: `enum DecodeError`, `enum DecodeSliceError`, `enum EncodeSliceError`
(section 4). Sources: <https://docs.rs/base64/latest/base64/enum.DecodeError.html>,
<https://docs.rs/base64/latest/base64/enum.DecodeSliceError.html>,
<https://docs.rs/base64/latest/base64/enum.EncodeSliceError.html>.

Crate features: `std` (default; enables `std::io`, `std::error::Error`, heap),
`alloc` (allocating APIs in a no_std build), `simd-unsafe` (default on; "the only
feature that introduces `unsafe` code; with it disabled the crate is
`#![forbid(unsafe_code)]`"). MSRV stated as 1.71.0. Sources:
<https://docs.rs/base64/latest/base64/>, <https://github.com/marshallpierce/rust-base64>.

### 3.2 `data-encoding` 2.11.1

- `struct Encoding` (opaque) with: `encode_len`, `encode_align`, `encode_mut`,
  `encode_mut_str`, `encode_append`, `new_encoder`, `encode_write`,
  `encode_write_buffer`, `encode_display`, `encode`, `decode_len`, `decode_mut`,
  `decode`, `bit_width`, `interpret_byte`, `is_canonical`, `specification`.
- `struct Specification` (fields `padding`, `check_trailing_bits`, `translate`,
  `bit_order`, `ignore`, `wrap`; `alloc` feature) and `SpecificationError`.
- `struct Encoder` ("Encodes fragmented input to an output", `alloc`),
  `struct Display`.
- `enum DecodeError` (with `DecodePartial` for error recovery), `enum DecodeKind
  { Length, Symbol, Trailing, Padding }`, `enum BitOrder`, `enum Character`,
  `enum Translate`, `struct Wrap`.
- Constants: `BASE64`, `BASE64_NOPAD`, `BASE64URL`, `BASE64URL_NOPAD`,
  `BASE64_MIME`, `BASE64_MIME_PERMISSIVE`, `BASE32`, `BASE32_NOPAD`, `BASE32HEX`,
  `BASE32HEX_NOPAD`, `BASE32_DNSCURVE`, `BASE32_DNSSEC`, `BASE32_NOPAD_NOCASE`,
  `BASE32_NOPAD_VISUAL`, `HEXUPPER`, `HEXLOWER`, `HEXUPPER_PERMISSIVE`,
  `HEXLOWER_PERMISSIVE`.
Source: <https://docs.rs/data-encoding/latest/data_encoding/>.

### 3.3 `base64ct` 1.8.3

- `trait Encoding: Alphabet` with: `decode(src, dst) -> Result<&[u8], Error>`,
  `decode_in_place(buf) -> Result<&[u8], InvalidEncodingError>`,
  `decode_vec(input: &str) -> Result<Vec<u8>, Error>` (alloc),
  `encode(src, dst) -> Result<&str, InvalidLengthError>`,
  `encode_string(input) -> String` (alloc), `encoded_len(bytes) -> usize`.
  Not dyn compatible. Implemented for any `T: Alphabet`.
- Types: `Base64`, `Base64Unpadded`, `Base64Url`, `Base64UrlUnpadded`,
  `Base64Bcrypt`, `Base64Pbkdf2`, `Base64ShaCrypt`, `Base64Crypt` (deprecated).
- Stateful I/O: `Decoder<'i, E>` (`new`, `new_wrapped(input, line_width)`,
  `decode`, `decode_to_end`, `remaining_len`, `is_finished`, impl `Read` on `std`),
  `Encoder<'o, E>` (`new`, `new_wrapped(output, width, LineEnding)`, `encode`,
  `position`, `finish`, `finish_with_remaining`, impl `Write` on `std`).
- `enum Error` (union of `InvalidLengthError` and `InvalidEncodingError`),
  `struct InvalidEncodingError`, `struct InvalidLengthError`, `enum LineEnding`.
Sources: <https://docs.rs/base64ct/latest/base64ct/>,
<https://docs.rs/base64ct/latest/base64ct/trait.Encoding.html>,
<https://docs.rs/base64ct/latest/base64ct/struct.Decoder.html>,
<https://docs.rs/base64ct/latest/base64ct/struct.Encoder.html>.

Supported alphabets (from the crate docs): Standard (`A-Za-z0-9+/`), URL-safe
(`A-Za-z0-9-_`), bcrypt (`. /` first), `crypt(3)` (`. -` first), PBKDF2
(`.` instead of `+`). Source: <https://docs.rs/base64ct/latest/base64ct/>.

### 3.4 `base64-simd` 0.8.0

- `struct Base64` (variant), `struct Error`, `struct Out`.
- Constants: `STANDARD`, `STANDARD_NO_PAD`, `URL_SAFE`, `URL_SAFE_NO_PAD`.
- Traits: `AppendBase64Decode`, `AppendBase64Encode`, `AsOut`,
  `FromBase64Decode`, `FromBase64Encode`.
- Functions: `forgiving_decode`, `forgiving_decode_inplace`,
  `forgiving_decode_to_vec` (alloc).
- Features: `detect` (default; runtime CPU-feature detection), `alloc`,
  `unstable` (requires nightly). Source:
  <https://docs.rs/base64-simd/latest/base64_simd/>.

## 4. Error representation

Rust represents base64 failures as **typed values in `Result`**, never as
exceptions and never as sentinels. The data and the error are mutually exclusive,
which is the key contrast with Go.

`base64` crate:
```
pub enum DecodeError {
    InvalidByte(usize, u8),                      // offset + offending byte
    InvalidLength(usize),
    InvalidLastSymbol { offset: usize, symbol: u8, symbol_value: u8 },
    InvalidPadding,
}
```
Meanings quoted from the docs: `InvalidByte` — "An invalid byte was found in the
input. The offset and offending byte are provided. Padding characters (`=`)
interspersed in the encoded form are invalid, as they may only be present as the
last 0-2 bytes of input."; `InvalidLength` — "The length of the input, as measured
in valid base64 symbols, is invalid. There must be 2-4 symbols in the last input
quad."; `InvalidLastSymbol` — "The last non-padding input symbol's encoded 6 bits
have nonzero bits that will be discarded. This is indicative of corrupted or
truncated Base64."; `InvalidPadding` — "The nature of the padding was not as
configured: absent or incorrect when it must be canonical, or present when it must
be absent, etc." Source:
<https://docs.rs/base64/latest/base64/enum.DecodeError.html>.

Two further error enums exist because buffer-size failure is a *different* failure
from input invalidity:
```
pub enum DecodeSliceError { DecodeError(DecodeError), OutputSliceTooSmall }
pub enum EncodeSliceError { OutputSliceTooSmall }
```
Sources: <https://docs.rs/base64/latest/base64/enum.DecodeSliceError.html>,
<https://docs.rs/base64/latest/base64/enum.EncodeSliceError.html>.

`data-encoding` splits kind from position and keeps partial progress separately:
```
pub struct DecodeError { pub position: usize, pub kind: DecodeKind }
pub enum DecodeKind { Length, Symbol, Trailing, Padding }
```
"Position is always a valid input position and represents the first encountered
error." `decode_mut` returns `Err(DecodePartial)` whose `read` and `written` fields
say how much was consumed and produced, enabling error recovery.
Sources: <https://docs.rs/data-encoding/latest/data_encoding/struct.DecodeError.html>,
<https://docs.rs/data-encoding/latest/data_encoding/enum.DecodeKind.html>,
<https://docs.rs/data-encoding/latest/data_encoding/struct.Encoding.html>.

`base64ct` distinguishes length failure from encoding failure:
`enum Error` is "union of `InvalidLengthError` and `InvalidEncodingError`". Its
`decode_in_place` carries an explicit caveat: "NOTE: this method does not (yet)
validate that padding is well-formed, if the given Base64 encoding is padded."
Sources: <https://docs.rs/base64ct/latest/base64ct/trait.Encoding.html>,
<https://docs.rs/base64ct/latest/base64ct/>.

Design consequence, and the reason this matters for the API design phase: Rust can
express "decoded value XOR error" in the type system, but the cost is that a caller
who wants the prefix (as Go hands out) must use a crate that models it
(`data-encoding::DecodePartial`) or write their own recovery. The `base64` crate
chose the strict XOR model. (Assessment.)

## 5. Ownership semantics (adapted Q5: buffer/ownership of encode input and output)

Rust makes allocation behaviour explicit in the method name, and the `base64` crate
documents it as a table — the clearest statement of this in any of the researched
languages.

From the crate docs, verbatim structure:

Decoding:
| Method | Output | Allocates memory |
|---|---|---|
| `Engine::decode` | returns a new `Vec<u8>` | always |
| `Engine::decode_vec` | appends to provided `Vec<u8>` | if `Vec` lacks capacity |
| `Engine::decode_slice` | writes to provided `&[u8]` | never |

Encoding:
| Method | Output | Allocates memory |
|---|---|---|
| `Engine::encode` | returns a new `String` | always |
| `Engine::encode_string` | appends to provided `String` | if `String` lacks capacity |
| `Engine::encode_slice` | writes to provided `&[u8]` | never |

Source: <https://docs.rs/base64/latest/base64/> (Memory allocation).

Other ownership facts:
- **Input is borrowed, not consumed**: every method takes `input: T where T:
  AsRef<[u8]>`, so `&[u8]`, `Vec<u8>` and `&str` are all accepted by reference; the
  caller keeps ownership. Source:
  <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
- **The caller owns the output buffer in the `_slice`/`_vec`/`_string` forms**, and
  the return value is a `usize` byte count (not a slice) — so no borrow of the
  output is handed back. Source:
  <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
- **`decode_slice` guarantees bounds discipline**: "Returns the number of bytes
  written to the slice, or an error if `output` is smaller than the estimated
  decoded length. This will not write any bytes past exactly what is decoded (no
  stray garbage bytes at the end)." The `_unchecked` variant documents
  "Panics if the provided output buffer is too small". Sources:
  <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
- **Engines are shared references, usually `const`.** "when possible, it's
  recommended to store the engine in a `const` so that references to it won't pose
  any lifetime issues, and to avoid repeating the cost of engine setup." Engines
  are `Send + Sync` and stateless, so `&'static Engine` can be shared freely across
  threads. Sources:
  <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
- **Streaming wrappers borrow both the engine and the inner I/O object**:
  `DecoderReader<'e, E: Engine, R: Read>` and `EncoderWriter<'e, E: Engine, W:
  Write>` carry an `'e` lifetime for the `&'e E` engine reference. `DecoderReader`
  also owns internal buffering: "Because `DecoderReader` performs internal
  buffering, the state of the inner reader is unspecified" (`into_inner`).
  Sources: <https://docs.rs/base64/latest/base64/read/struct.DecoderReader.html>,
  <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
- **`EncoderWriter` hands the inner writer back**: `finish(&mut self) ->
  Result<W>` "Returns the writer that this was constructed around." `into_inner`
  exists but explicitly does *not* flush: "That will also ensure all data has been
  flushed, which the `into_inner()` function does *not* do." Source:
  <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
- **`Alphabet` is a plain owned value derived at compile time.** `Alphabet::new` is
  a `const fn`, and the docs show how to build one in a `static` using a `match`
  that panics on `Err` — "Result::unwrap() isn't const yet, but panic!() is OK".
  Source: <https://docs.rs/base64/latest/base64/alphabet/struct.Alphabet.html>.
- **`base64ct` splits input and output lifetimes explicitly**: `Decoder<'i, E>`
  holds `&'i [u8]` input ("Create a new decoder for a byte slice containing
  contiguous (non-newline-delimited) Base64-encoded data"), while `Encoder<'o, E>`
  borrows `&'o mut [u8]` output and writes in place, with `position()` reporting the
  write cursor and `finish_with_remaining()` returning both the produced `&str` and
  the unused remainder of the buffer. Sources:
  <https://docs.rs/base64ct/latest/base64ct/struct.Decoder.html>,
  <https://docs.rs/base64ct/latest/base64ct/struct.Encoder.html>.
- **`base64ct` supports in-place decoding**: `decode_in_place(buf: &mut [u8]) ->
  Result<&[u8], InvalidEncodingError>`, returning a slice into the caller's own
  buffer. Source: <https://docs.rs/base64ct/latest/base64ct/trait.Encoding.html>.
- **`no_std` / no-alloc is a real ownership constraint**, not a footnote: the
  `base64` crate loses "all the functionality revolving around `std::io`,
  `std::error::Error`, and heap allocations" when `default-features` is off, with
  `alloc` restoring heap APIs. `base64ct` states "Supports `no_std` environments and
  avoids heap allocations in the core API (but also provides optional `alloc`
  support for convenience)." Sources:
  <https://github.com/marshallpierce/rust-base64>, <https://docs.rs/base64ct/latest/base64ct/>.

## 6. Blocking / non-blocking

- **All four crates are synchronous and blocking.** The in-memory API is pure CPU
  work; the I/O-integrated API is `std::io::Read`/`std::io::Write`:
  `DecoderReader` "is a `Read` implementation that decodes base64 data read from an
  underlying reader"; `EncoderWriter` is "a `Write` implementation that base64
  encodes data before delegating to the wrapped writer". Sources:
  <https://docs.rs/base64/latest/base64/read/struct.DecoderReader.html>,
  <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
- **There is no async or non-blocking variant in any of the four crates.** The
  `base64` crate's streaming types are `std::io` based only; `base64ct` gates its
  `Read`/`Write` impls on the `std` feature. Sources:
  <https://docs.rs/base64/latest/base64/>, <https://docs.rs/base64ct/latest/base64ct/>.
- **`DecoderReader::read` documents its error mapping for I/O**: "Any errors
  emitted by the delegate reader are returned. Decoding errors due to invalid
  base64 are also possible, and will have `io::ErrorKind::InvalidData`." Source:
  <https://docs.rs/base64/latest/base64/read/struct.DecoderReader.html>.
- **`EncoderWriter` documents a `Write`-contract limitation** rather than papering
  over it: "Owing to the specification of the `write` and `flush` methods on the
  `Write` trait and their implications for a buffering implementation, these
  methods may not behave as expected. In particular, calling `write_all` on this
  interface may fail with `io::ErrorKind::WriteZero`." It also notes
  performance characteristics bluntly: "It has some minor performance loss compared
  to encoding slices (a couple percent). It does not do any heap allocation."
  Source: <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
- **Concurrency is caller-side.** Engines are `Send + Sync` and shared by
  reference, so parallel encoding is "give each thread the same `&ENGINE`", not an
  internal thread pool. `base64-simd` likewise stays single-threaded and only adds
  run-time CPU-feature detection (`detect` feature). Sources:
  <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>,
  <https://docs.rs/base64-simd/latest/base64_simd/>.
- `GUESS:` no source found for an official async base64 adapter. The tokio
  ecosystem is known to carry a `Base64` codec in `tokio-util`, but this research
  did not fetch a page for it and therefore makes no claim about its API; if async
  support matters, that page should be fetched in a follow-up rather than assumed.

## 7. Alphabet variants and padding (adapted Q7: std vs URL-safe, padding handling)

### 7.1 Alphabets

The `base64` crate makes the alphabet a **type-level value**, not a parameter:
- `alphabet::STANDARD` — "The standard alphabet (with `+` and `/`) specified in
  RFC 4648 §4."
- `alphabet::URL_SAFE` — "The URL-safe alphabet (with `-` and `_`) specified in
  RFC 4648 §5."
- Plus `BCRYPT`, `BIN_HEX`, `CRYPT`, `IMAP_MUTF7` for "alphabets commonly used in
  the wild".
Sources: <https://docs.rs/base64/latest/base64/alphabet/index.html>.

The rationale for URL-safe is stated with the concrete failure mode: "The standard
alphabet uses `+` and `/` as its two non-alphanumeric symbols, which cannot be
safely used in URL's without encoding them as `%2B` and `%2F`." Source:
<https://docs.rs/base64/latest/base64/> (URL-safe alphabet).

The alphabet itself carries the padding symbol: `Alphabet::new` assumes `=`, and
`Alphabet::new_with_padding(alphabet, padding)` exists "for strange alphabets that
don't use `=` as the padding symbol". `Alphabet::padding()` exposes it, and
`Engine::padding()` returns `Symbol`. Sources:
<https://docs.rs/base64/latest/base64/alphabet/struct.Alphabet.html>,
<https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.

RFC 4648 warns that the variants must not be conflated: "This encoding should not
be regarded as the same as the 'base64' encoding and should not be referred to as
only 'base64'." Source: <https://www.rfc-editor.org/rfc/rfc4648.txt> §5.

### 7.2 Padding: the three-way decode policy

This is the crate's most interesting design decision, and it is a genuine
improvement over Go's four-preset matrix. Encoding padding and decoding padding
are **separate settings**:

- Encoding side: `with_encode_padding(bool)` — "If `padding` is `true`, encoding
  will append either 1 or 2 `=` padding characters as needed to produce an output
  whose length is a multiple of 4."
- Decoding side: `with_decode_padding_mode(DecodePaddingMode)` with
  - `Indifferent` — "Canonical padding is allowed, but any fewer padding bytes than
    that is also allowed."
  - `RequireCanonical` — "Padding must be canonical (0, 1, or 2 `=` as needed to
    produce a 4 byte suffix)." This is the default.
  - `RequireNone` — "Padding must be absent – for when you want predictable
    padding, without any wasted bytes."
Sources:
<https://docs.rs/base64/latest/base64/engine/general_purpose/struct.GeneralPurposeConfig.html>,
<https://docs.rs/base64/latest/base64/engine/enum.DecodePaddingMode.html>.

The composition is shown with a worked example: "The pre-configured `NO_PAD` engines
will reject inputs containing padding `=` characters. To encode without padding and
still accept padding while decoding, create an engine with that padding mode."
Source: <https://docs.rs/base64/latest/base64/> (Padding characters). So the
otherwise-missing combination (encode unpadded, decode permissively) is reachable
without adding a fifth preset.

The docs take a position on padding rather than being neutral: "Each base64
character represents 6 bits ... Canonical encoding ensures that base64 encodings
will be exactly the same, byte-for-byte, regardless of input length. But the `=`
padding characters aren't necessary for decoding ... Padding serves no practical
purpose, so where possible, encode without padding." Source:
<https://docs.rs/base64/latest/base64/>.

RFC 4648 still mandates padding by default — "Implementations MUST include
appropriate pad characters at the end of encoded data unless the specification
referring to this document explicitly states otherwise." (§3.2) — so the crate's
"encode without padding" advice is a deliberate deviation the caller must choose.
Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

### 7.3 Trailing bits / canonicality

- Default config: `decode_allow_trailing_bits = false`, so `InvalidLastSymbol` is
  emitted; setting it `true` "silently ignore[s]" bad trailing bits, "useful if you
  need to decode base64 produced by a buggy encoder that has bits set in the unused
  space on the last base64 character as per forgiving-base64 decode". Source:
  <https://docs.rs/base64/latest/base64/engine/general_purpose/struct.GeneralPurposeConfig.html>.
  The referenced forgiving algorithm is the WHATWG Infra Standard's "forgiving
  base64" section: <https://infra.spec.whatwg.org/#forgiving-base64-decode>.
- All prelude presets "enforce no trailing bits when decoding". Source:
  <https://docs.rs/base64/latest/base64/prelude/index.html>.
- RFC 4648 §3.5 is the normative reason: trailing pad bits MUST be zero, otherwise
  "there is no canonical representation of base-encoded data, and multiple
  base-encoded strings can be decoded to the same binary data. ... decoders MAY
  chose to reject an encoding if the pad bits have not been set to zero." Source:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>.

### 7.4 Non-alphabet input characters

The `base64` crate is deliberately **strict and refuses to grow a lenient mode**.
Its FAQ answers the whitespace question with "Remove non-base64 characters from
your input before decoding" and then shows three ways for the caller to do it
(`Vec::retain`, `iter-read` + `bytes()`, or a filtering `Read` impl). Source:
<https://github.com/marshallpierce/rust-base64>. This lines up with RFC 4648 §3.3:
"Implementations MUST reject the encoded data if it contains characters outside the
base alphabet ... unless the specification ... explicitly states otherwise", with
the covert-channel warning repeated in §12. Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>.

Two crates take the opposite, opt-in approach for the cases where leniency is
required:
- `data-encoding`'s `Specification.ignore` exists for "skipping newlines", and
  `translate` for "case-insensitivity". Its docs even publish a
  cross-implementation divergence table (section 10) rather than hiding the choice.
  Source: <https://docs.rs/data-encoding/latest/data_encoding/>.
- `base64-simd` exposes `forgiving_decode`, `forgiving_decode_inplace`,
  `forgiving_decode_to_vec` as named entry points, so leniency is visible in the
  function name. Source: <https://docs.rs/base64-simd/latest/base64_simd/>.
- `base64ct` goes the other way and is *stricter*: "Whitespace is expressly
  disallowed, with the exception of the `Decoder::new_wrapped` and
  `Encoder::new_wrapped` modes which provide fixed-width line wrapping." Source:
  <https://docs.rs/base64ct/latest/base64ct/>.

## 8. Timeouts

Not applicable in the literal sense: base64 encode/decode is pure computation, and
none of the four crates exposes a timeout, deadline, cancellation token or
interrupt parameter. There is no blocking resource of its own to time out.

Closest analogues, for completeness:

- **The only blocking point is the inner `Read`/`Write`.** `DecoderReader::read`
  delegates to the wrapped reader, so timeouts belong to whatever that reader is
  (a socket, a file, an `async` adapter). The base64 crate documents only the error
  mapping (`io::ErrorKind::InvalidData` for decoding errors), not any deadline
  behaviour. Source:
  <https://docs.rs/base64/latest/base64/read/struct.DecoderReader.html>.
- **`EncoderWriter` has an explicit finalisation step instead of a cancel step.**
  `finish()` "Encode[s] all remaining buffered data and write[s] it, including any
  trailing incomplete input triples and associated padding." Once it succeeds, "no
  further writes or calls to this method are allowed", and calling `write()` or
  `finish()` again panics. The `Drop` impl finalises automatically, but "any error
  that occurs when invoking the underlying writer will be suppressed". Sources:
  <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
- **`base64ct::Decoder` offers an explicit termination query** which is the nearest
  thing to a completion/abort check: `remaining_len()` ("Decreases every time data
  is decoded") and `is_finished()` ("Has all of the input data been decoded?").
  Source: <https://docs.rs/base64ct/latest/base64ct/struct.Decoder.html>.
- **Panic is the failure mode for programming errors, not for input.** Length
  overflow panics the crate: "If length calculations result in overflowing `usize`,
  a panic will result." `decode_slice_unchecked` panics on a too-small output
  buffer. Sources: <https://docs.rs/base64/latest/base64/> (Panics),
  <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
- `GUESS:` no timeout/cancellation surface exists beyond the above, and no source
  was found stating that one is planned; the absence should be re-checked against
  the issue tracker at implementation time if it matters.

## 9. Streaming (adapted Q9: incremental/chunked encode/decode with leftover bytes)

### 9.1 Decode streaming

`DecoderReader<'e, E, R>` is an `io::Read` adapter. Its leftover handling is
documented behaviour, not an implementation detail:
- "Where possible, this function buffers base64 to minimize the number of `read()`
  calls to the delegate reader." (on `read`)
- Buffer state is not exposed: "Because `DecoderReader` performs internal buffering,
  the state of the inner reader is unspecified." (on `into_inner`)
- Constant-space validity checking is a documented use case: the crate shows a 128
  byte stack buffer used to validate a stream without ever materialising the decoded
  output.
Source: <https://docs.rs/base64/latest/base64/read/struct.DecoderReader.html>.

### 9.2 Encode streaming

`EncoderWriter<'e, E, W>` is an `io::Write` adapter with an explicit finaliser.
Leftover bytes are unavoidable here because base64 groups 3 input bytes into 4
output characters, and the crate says so directly: "Because base64 has special
handling for the end of the input data (padding, etc), there's a `finish()` method
on this type that encodes any leftover input bytes and adds padding if
appropriate."
Source: <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.

Three details that make this a good model for MojoAkku:
1. **`finish()` is explicit and returns the inner writer**: `finish(&mut self) ->
   Result<W>`. "If you don't care about error handling, it is not necessary to call
   this function, as the equivalent finalization is done by the Drop impl" — but
   `Drop` suppresses the underlying writer's error, so error-conscious callers must
   call `finish()` themselves. Source:
   <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
2. **`flush()` deliberately does not finalise**: "Because this is usually treated as
   OK to call multiple times, it will *not* flush any incomplete chunks of input or
   write padding." Source:
   <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
3. **The partial-write contract is documented instead of hidden**: "If the previous
   call to `write` provided more (encoded) data than the delegate writer could
   accept in a single call to its `write`, the remaining data is buffered. As long
   as buffered data is present, subsequent calls to `write` will try to write the
   remaining buffered data to the delegate and return either `Ok(0)` – and therefore
   not consume any of `input` – or an error." Source:
   <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.

Performance note for the record: the crate states the streaming encoder costs
"a couple percent" versus slice encoding and does **no heap allocation**. Source:
<https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.

### 9.3 Line wrapping

Line wrapping is not a base64 concern in this ecosystem; it is layered.
- `base64` crate: delegated to the external `line-wrap` crate. Source:
  <https://github.com/marshallpierce/rust-base64> (FAQ).
- `base64ct`: built in, precisely because PEM needs it. `Decoder::new_wrapped(input,
  line_width)` and `Encoder::new_wrapped(output, width, LineEnding)`; "Trailing
  newlines are not supported and must be removed in advance"; newlines are handled
  per "roughly RFC7468 conventions" where `eol = CRLF / CR / LF` and "parsers MUST
  handle different newline conventions"; "Minimum allowed line width is 4". Sources:
  <https://docs.rs/base64ct/latest/base64ct/struct.Decoder.html>,
  <https://docs.rs/base64ct/latest/base64ct/struct.Encoder.html>.
- `data-encoding`: expressed as a `Specification.wrap` field ("wrapping the output
  when encoding"). Source: <https://docs.rs/data-encoding/latest/data_encoding/>.

RFC 4648's position on this is that encoders must not add line feeds unless the
referring spec says so (§3.1) — which is exactly why these libraries keep wrapping
outside the core encoder. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

### 9.4 Fragmented input in `data-encoding`

`data-encoding` offers two distinct answers instead of a `Read`/`Write` adapter:
- `Encoding::new_encoder(output) -> Encoder` — "Returns an object to encode a
  fragmented input and append it to `output`" (alloc feature).
- `Specification.padding` is documented as existing "for streaming", and
  `decode_len`'s docs specify the exact chunking protocol, including the
  `DecodePartial { read, written, .. }` recovery contract.
Source: <https://docs.rs/data-encoding/latest/data_encoding/struct.Encoding.html>,
<https://docs.rs/data-encoding/latest/data_encoding/>.

## 10. Interesting design decisions

1. **One `Engine` trait is the single abstraction; alphabets and config are values
   it borrows.** Everything — encode, decode, into-slice, into-Vec, into-String —
   flows through `Engine`, while `Alphabet` and `GeneralPurposeConfig` are plain
   data. Sources:
   <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>,
   <https://docs.rs/base64/latest/base64/engine/general_purpose/struct.GeneralPurposeConfig.html>.
2. **Engines are meant to be `const` and stateless.** "When possible, it's
   recommended to store the engine in a `const` so that references to it won't pose
   any lifetime issues, and to avoid repeating the cost of engine setup." Combined
   with `Engine: Send + Sync`, this makes an engine a shareable immutable value.
   Source: <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
3. **Alphabet construction is a `const fn` returning `Result`.** `Alphabet::new` is
   `pub const fn`, and the docs show the const-`match`-with-`panic!` idiom needed
   until `Result::unwrap` is const: "Result::unwrap() isn't const yet, but panic!()
   is OK". Source:
   <https://docs.rs/base64/latest/base64/alphabet/struct.Alphabet.html>.
4. **Padding is modelled as two orthogonal axes plus a three-value decode policy**
   (section 7.2) instead of a combinatorial preset list. Sources:
   <https://docs.rs/base64/latest/base64/engine/general_purpose/struct.GeneralPurposeConfig.html>,
   <https://docs.rs/base64/latest/base64/engine/enum.DecodePaddingMode.html>.
5. **Allocation behaviour is published as a table** (section 5): "Memory
   allocation" is a named heading in the crate docs. This is unusually
   user-centred documentation and directly serves a low-vision/declarative API.
   Source: <https://docs.rs/base64/latest/base64/>.
6. **Two distinct error enums separate "bad input" from "buffer too small".**
   `DecodeSliceError::OutputSliceTooSmall` and `EncodeSliceError` prevent callers
   from treating a size mistake as corrupt data. Sources:
   <https://docs.rs/base64/latest/base64/enum.DecodeSliceError.html>,
   <https://docs.rs/base64/latest/base64/enum.EncodeSliceError.html>.
7. **`unsafe` is quarantined behind one default-on feature.** "`simd-unsafe` ...
   is the only feature that introduces `unsafe` code; with it disabled the crate is
   `#![forbid(unsafe_code)]`." Source: <https://docs.rs/base64/latest/base64/>.
8. **Finalisation is explicit and returns owned resources**, with `Drop` only as a
   best-effort fallback that suppresses errors (section 9.2). Source:
   <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
9. **`data-encoding` turns permissiveness into named, inspectable configuration**
   (`Specification` with `padding`, `check_trailing_bits`, `translate`,
   `bit_order`, `ignore`, `wrap`) and publishes a divergence table against two other
   implementations. Source: <https://docs.rs/data-encoding/latest/data_encoding/>.
10. **`data-encoding` treats canonicality as a first-class, queryable property**:
    `Encoding::is_canonical()` — "An encoding is not canonical if one of the
    following conditions holds: trailing bits are not checked; padding is used;
    characters are ignored; characters are translated." That definition is a
    precise and testable statement of what "canonical" means, and it is tied to a
    published attack: "non-canonical encodings may be an attack vector as described
    in Base64 Malleability in Practice" (eprint 2022/361). Sources:
    <https://docs.rs/data-encoding/latest/data_encoding/struct.Encoding.html>,
    <https://docs.rs/data-encoding/latest/data_encoding/>.
11. **`base64ct` proves that constant-time is a legitimate base64 requirement.**
    "Implemented using integer arithmetic alone without any lookup tables or
    data-dependent branches, thereby providing portable 'best effort' constant-time
    operation. Not constant-time with respect to message length (only data)."
    Source: <https://docs.rs/base64ct/latest/base64ct/>.
12. **`base64ct` distinguishes padded from unpadded by *rejecting*, not by
    ignoring**: "The padded variants require (`=`) padding. Unpadded variants
    expressly reject such padding." Source: <https://docs.rs/base64ct/latest/base64ct/>.

## 11. Decisions NOT to copy

1. **Do not ship two overlapping APIs and deprecate one later.** The `base64` crate
   still carries eight deprecated free functions (`encode`, `decode`,
   `encode_engine`, `decode_engine`, `encode_engine_slice`, `decode_engine_slice`,
   `encode_engine_vec`, `encode_engine_string`) alongside the `Engine` methods. The
   deprecation exists because the trait came later; a new library should start with
   one surface. Source: <https://docs.rs/base64/latest/base64/> (Functions).
2. **Do not require a generic trait with associated types for four fixed codecs.**
   `Engine`'s shape (`type Config`, `type DecodeEstimate`, seven provided methods,
   not dyn compatible) is heavy machinery for what is, at MojoAkku's scope, a small
   set of operations. Source:
   <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
3. **Do not default to shipping `unsafe` SIMD.** `simd-unsafe` is on by default, so
   the default dependency graph contains `unsafe`; safety requires opting out.
   Sources: <https://docs.rs/base64/latest/base64/>,
   <https://github.com/marshallpierce/rust-base64>.
4. **Do not use a prefixed alias set as the primary naming scheme.** `prelude`
   renames `STANDARD` to `BASE64_STANDARD`, `STANDARD_NO_PAD` to
   `BASE64_STANDARD_NO_PAD`, etc., so the same constant has two names depending on
   import style. Predictability favours one name. Source:
   <https://docs.rs/base64/latest/base64/prelude/index.html>.
5. **Do not copy `base64ct::encoded_len`'s silent overflow behaviour.** Its doc
   says: "WARNING: this function will return `0` for lengths greater than
   `usize::MAX/4`!" — a valid-looking return value for an impossible input. Source:
   <https://docs.rs/base64ct/latest/base64ct/trait.Encoding.html>.
6. **Do not leave a documented validation hole in a decode path.** `base64ct`'s
   `decode_in_place` states: "NOTE: this method does not (yet) validate that padding
   is well-formed, if the given Base64 encoding is padded." A predictable API should
   not have a "decode" that skips a validity check for certain inputs. Source:
   <https://docs.rs/base64ct/latest/base64ct/trait.Encoding.html>.
7. **Do not make `Drop` the documented finalisation path for encoders.** `Drop`
   swallows the underlying writer's error by design; relying on it silently loses
   data-write failures. Source:
   <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
8. **Do not expose both an error-returning and a panicking variant of the same
   operation without a very clear name.** `decode_slice` vs `decode_slice_unchecked`
   differ only in "too-small buffer" behaviour, which is easy to miss. Source:
   <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
9. **Do not adopt `data-encoding`'s full generality inside MojoAkku base64.** Bases
   2/4/8/16/32/64 with `bit_order`, `translate`, `ignore`, `wrap` and a visual
   error-correction mode (`BASE32_NOPAD_VISUAL`) is a different, much larger
   library; copying the abstraction would over-scope MojoAkku's base64/base32
   library. Sources: <https://docs.rs/data-encoding/latest/data_encoding/>.
10. **Do not keep `DecodedLen`-style "maximum" semantics and call it a length.**
    Both ecosystems have this trap: Go's `DecodedLen` is documented as a maximum,
    and `data-encoding`'s `decode_len` "returns the maximum decoded length ... the
    actual decoded length might be smaller if the actual input contains padding or
    ignored characters." The distinction between capacity and actual length should
    be explicit in the name or the type. Sources:
    <https://docs.rs/data-encoding/latest/data_encoding/struct.Encoding.html>,
    <https://pkg.go.dev/encoding/base64#Encoding.DecodedLen>.
11. **Do not let a strictness default be implicit.** The `base64` crate's strictness
    is a config field, `data-encoding`'s is a `Specification` field, and
    `base64ct`'s is encoded in the type. Whichever MojoAkku chooses, it must be
    stated at the call site, not inferred from the alphabet. (Assessment grounded
    in sections 7.2–7.4.)

## 12. Ideas fitting Mojo

Mojo facts are **not** asserted here; per project rule they must be looked up in the
`mojov1` buch (page `stdlib/base64`) before use. The points below name *properties
of the Rust design* and how they could map onto Mojo features, and are explicitly
assessments.

1. **`Alphabet::new` being a `const fn` is directly portable to a compile-time
   alphabet.** Rust already proves the viability of validating an alphabet at
   compile time (it only falls short of `unwrap` in const context). In Mojo the
   equivalent should make an invalid alphabet a compile-time error, eliminating the
   panic path Go takes. Source for the Rust half:
   <https://docs.rs/base64/latest/base64/alphabet/struct.Alphabet.html>. (Assessment
   for the Mojo half.)
2. **Engines as stateless values shared by reference map onto immutable value
   semantics.** `const` engines plus `Send + Sync` plus no mutation is exactly a
   value type with no ownership ambiguity; Mojo's value semantics fit it directly.
   Source: <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>.
3. **The allocation-behaviour table is a documentation pattern worth adopting
   literally** — one row per entry point, one column for "allocates?". It serves a
   low-vision reader better than prose. Source:
   <https://docs.rs/base64/latest/base64/> (Memory allocation).
4. **Model padding as orthogonal policy, and prefer a three-value decode policy
   over four presets.** `DecodePaddingMode { Indifferent, RequireCanonical,
   RequireNone }` plus a separate "encode with padding?" flag covers every
   combination without a preset explosion. Source:
   <https://docs.rs/base64/latest/base64/engine/enum.DecodePaddingMode.html>.
   (Assessment for Mojo.)
5. **Separate "bad input" from "buffer too small" in the error type.** The Rust
   split (`DecodeError` vs `DecodeSliceError::OutputSliceTooSmall`) prevents callers
   from blaming their data for their own capacity mistake. Sources:
   <https://docs.rs/base64/latest/base64/enum.DecodeSliceError.html>,
   <https://docs.rs/base64/latest/base64/enum.EncodeSliceError.html>. (Assessment.)
6. **Carry offsets and structure in decode errors** — `InvalidByte(offset, byte)`
   and `InvalidLastSymbol { offset, symbol, symbol_value }` — and, if partial
   results are useful, adopt `data-encoding`'s explicit `DecodePartial { read,
   written }` rather than Go's implicit "bytes plus error". Sources:
   <https://docs.rs/base64/latest/base64/enum.DecodeError.html>,
   <https://docs.rs/data-encoding/latest/data_encoding/struct.Encoding.html>.
   (Assessment.)
7. **Streaming finalisation should be an explicit `finish`-like step, not a hidden
   destructor.** Rust's `Drop` fallback is documented as lossy; MojoAkku should make
   finalisation required and return/report the remaining state. Source:
   <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>.
   `base64ct`'s `finish_with_remaining()` — returning both the produced string and
   the unused buffer — is the richer form to study. Source:
   <https://docs.rs/base64ct/latest/base64ct/struct.Encoder.html>. (Assessment.)
8. **Keep the leftover-byte model identical to the Rust one**: encode buffers
   `input.len() % 3` bytes until `finish`; decode buffers incomplete 4-symbol groups
   and must accept both `RequireCanonical` and unpadded tails. Rust's separation of
   buffer-vs-finish makes the invariant testable. (Assessment, grounded in section
   9.2.)
9. **Make line wrapping a separate, opt-in concern.** Rust's default is to refuse
   to wrap and tell the caller to layer it (`base64` → `line-wrap`; `base64ct` →
   `new_wrapped`); RFC 4648 §3.1 backs the "no automatic line feeds" default.
   Sources: <https://github.com/marshallpierce/rust-base64>,
   <https://docs.rs/base64ct/latest/base64ct/struct.Encoder.html>,
   <https://www.rfc-editor.org/rfc/rfc4648.txt>. (Assessment.)
10. **Do not treat constant-time as irrelevant, but do treat it as a separate
    mode.** `base64ct`'s existence proves the requirement is real for
    key/PEM-adjacent data; the design lesson is to keep it out of the default path
    (`base64ct` is a distinct crate, not a flag on `base64`). Source:
    <https://docs.rs/base64ct/latest/base64ct/>. (Assessment.)

## Sources

- Rust `std` module index (evidence for the absence of a std base64 module):
  <https://doc.rust-lang.org/std/index.html>
- `base64` crate root docs (overview, engine setup, alphabets, padding, memory
  allocation table, features, panics): <https://docs.rs/base64/latest/base64/>
- `base64::engine::Engine` trait: <https://docs.rs/base64/latest/base64/engine/trait.Engine.html>
- `base64::engine::general_purpose` module (presets): <https://docs.rs/base64/latest/base64/engine/general_purpose/index.html>
- `base64::engine::general_purpose::GeneralPurposeConfig`:
  <https://docs.rs/base64/latest/base64/engine/general_purpose/struct.GeneralPurposeConfig.html>
- `base64::engine::DecodePaddingMode`:
  <https://docs.rs/base64/latest/base64/engine/enum.DecodePaddingMode.html>
- `base64::alphabet` module and `Alphabet`:
  <https://docs.rs/base64/latest/base64/alphabet/index.html>,
  <https://docs.rs/base64/latest/base64/alphabet/struct.Alphabet.html>
- `base64::prelude`: <https://docs.rs/base64/latest/base64/prelude/index.html>
- `base64::read::DecoderReader`: <https://docs.rs/base64/latest/base64/read/struct.DecoderReader.html>
- `base64::write::EncoderWriter`: <https://docs.rs/base64/latest/base64/write/struct.EncoderWriter.html>
- `base64::display::Base64Display` reference via crate root Modules:
  <https://docs.rs/base64/latest/base64/>
- `base64::DecodeError`: <https://docs.rs/base64/latest/base64/enum.DecodeError.html>
- `base64::DecodeSliceError`: <https://docs.rs/base64/latest/base64/enum.DecodeSliceError.html>
- `base64::EncodeSliceError`: <https://docs.rs/base64/latest/base64/enum.EncodeSliceError.html>
- `rust-base64` repository README (goals, throughput, FAQ on whitespace and line
  wrapping, `no_std`, `simd-unsafe`, MSRV 1.71.0, stars/forks/commits):
  <https://github.com/marshallpierce/rust-base64>
- `data-encoding` crate root (design goals, canonicality, divergence table,
  constants): <https://docs.rs/data-encoding/latest/data_encoding/>
- `data_encoding::Encoding`: <https://docs.rs/data-encoding/latest/data_encoding/struct.Encoding.html>
- `data_encoding::DecodeError`: <https://docs.rs/data-encoding/latest/data_encoding/struct.DecodeError.html>
- `data_encoding::DecodeKind`: <https://docs.rs/data-encoding/latest/data_encoding/enum.DecodeKind.html>
- `base64ct` crate root (constant-time rationale, alphabets, no_std, whitespace
  policy, padding policy): <https://docs.rs/base64ct/latest/base64ct/>
- `base64ct::Encoding` trait: <https://docs.rs/base64ct/latest/base64ct/trait.Encoding.html>
- `base64ct::Decoder`: <https://docs.rs/base64ct/latest/base64ct/struct.Decoder.html>
- `base64ct::Encoder`: <https://docs.rs/base64ct/latest/base64ct/struct.Encoder.html>
- `base64-simd` crate root (entry points, features, CPU detection):
  <https://docs.rs/base64-simd/latest/base64_simd/>
- RFC 4648, "The Base16, Base32, and Base64 Data Encodings":
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
  (used for §3.1 line feeds, §3.2 padding MUST, §3.3 non-alphabet characters,
  §3.5 canonical encoding, §5 URL-safe alphabet, §8 base16, §12 security)
- WHATWG Infra Standard, "Forgiving base64":
  <https://infra.spec.whatwg.org/#forgiving-base64-decode>
- `Base64 Malleability in Practice` (cited by `data-encoding` as the non-canonical
  attack vector): <https://eprint.iacr.org/2022/361>
- Mojo side is covered by the `mojov1` buch page `stdlib/base64`, not by this file.
