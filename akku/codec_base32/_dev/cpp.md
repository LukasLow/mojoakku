# base32 research: C++

## 1. Standard library support

C++ has **no standard-library base32 (or base64/base16) codec**. The C++
standard library header list contains general utilities, containers, strings,
text-processing and (in C++26) `<text_encoding>`, and no header provides
base-N encoding. The closest facility, `std::to_chars`, is a numeric-radix
formatter limited to "a value between 2 and 36"; base32 is a bit-packing over 32
symbols, not a positional integer base. (Sources:
https://en.cppreference.com/w/cpp/header,
https://en.cppreference.com/w/cpp/utility/to_chars)

Base32 is therefore third-party. The standout is **cppcodec**, the only
**C-family** library that ships the RFC 4648 base32 and base32hex variants
**and** Crockford's base32 behind one templated API (Crockford is also shipped
by the Rust `base32` crate — `rust.md` §7 — and by npm `base32-encode` —
`js-ts.md` §7). (Assessment: derived from the cppcodec README/source below.)

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page records only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | base32 variants |
| --- | --- | --- | --- | --- |
| cppcodec (tplgy) | Topology LP / efidler | header-only C++11, actively cited | MIT | base32, base32hex, Crockford + hex |
| Boost.Beast base64 | Boost (Vinnie Falco) | part of Boost, but `detail/` namespace | Boost Software License 1.0 | **base64 only** |
| OpenSSL `EVP_*` via C API | OpenSSL Foundation | ubiquitous | Apache-2.0 | **base64 only** |
| tobiaslocker/base64 | Tobias Locker | header-only C++17/C++20 | MIT | **base64 only** |
| base64pp | Matheus Gomes | C++20, CMake | MIT | **base64 only** |
| aklomp/base64 | Alfred Klomp | C99 with SIMD; usable from C++ | BSD-2-Clause | **base64 only** |

Sources:
- cppcodec "Header-only C++11 library to encode/decode base64, base64url, base32,
  base32hex and hex (a.k.a. base16) as specified in RFC 4648, plus Crockford's
  base32. MIT licensed": <https://raw.githubusercontent.com/tplgy/cppcodec/master/README.md>.
- Boost.Beast's codec lives under `boost/beast/core/detail/base64.hpp`; the
  maintainers stated it will not become general-purpose base64 API:
  <https://listarchives.boost.org/boost-users/2020/12/90714.php>.
- tobiaslocker/base64, base64pp: <https://github.com/tobiaslocker/base64>,
  <https://matheusgomes28.github.io/base64pp/>.
- aklomp/base64: <https://raw.githubusercontent.com/aklomp/base64/master/README.md>.

(Assessment: derived from the sources above: for base32, C++ is effectively
"cppcodec or write your own". Boost.Beast/OpenSSL/tobiaslocker/base64pp are
base64-only, so the C++ base32 signal is a single, rich library rather than the
C ecosystem's multiple thin ones.)

## 3. Exposed APIs

### cppcodec (the variant-rich base32 reference)

One class per variant, all exposing the same static API through a shared
`detail::codec<...>` template. Base32-relevant aliases and their headers
(`cppcodec/…`): `base32_rfc4648`, `base32_crockford`, `base32_hex`
(source: `cppcodec/base32_rfc4648.hpp`, `cppcodec/base32_crockford.hpp`,
`cppcodec/base32_hex.hpp`, README).

Encoding API (`codec<CodecImpl>` in `cppcodec/detail/codec.hpp`):

```cpp
std::string             encode(const uint8_t* binary, size_t binary_size);
template <typename Result> Result encode(const uint8_t* binary, size_t binary_size);
template <typename Result> void   encode(Result& encoded_result, const uint8_t* binary, size_t binary_size);
size_t                  encode(char* encoded_result, size_t encoded_buffer_size,
                               const uint8_t* binary, size_t binary_size) noexcept;
static constexpr size_t encoded_size(size_t binary_size) noexcept;
```

Decoding API: `std::vector<uint8_t> decode(const char* encoded, size_t
encoded_size);` plus templated `Result` and raw-buffer overloads, and `static
constexpr size_t decoded_max_size(size_t encoded_size) noexcept;`. (Source:
<https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/codec.hpp>.)

Per-variant contract methods live on the variant class: `alphabet_size()`,
`symbol(idx)`, `normalized_symbol(c)`, `generates_padding()`,
`requires_padding()`, `padding_symbol()`, `is_padding_symbol(c)`,
`is_eof_symbol(c)`, `should_ignore(c)`. (Sources:
`cppcodec/base32_rfc4648.hpp`, `cppcodec/base32_hex.hpp`,
`cppcodec/base32_crockford.hpp`.)

The base32 detail class encodes the 5-byte→8-symbol quantum explicitly:
`binary_block_size() == 5`, `encoded_block_size() == 8`, and
`num_encoded_tail_symbols(num_bytes)` returns 2, 4, 5, 7 for 1–4 tail bytes
(`cppcodec/detail/base32.hpp`).

### Boost.Beast, tobiaslocker, base64pp, OpenSSL

All base64-only (see §2); their base64 APIs are documented in `cpp.md` of the
sibling base64 run and are not repeated here. A C++ program needing base32 uses
cppcodec or links a C base32 library (gnulib, see `c.md` §3).

## 4. Error representation

Three coexisting C++ styles; for base32 specifically, cppcodec is the one to
study (it is the only base32 library here):

1. **Exception hierarchy rooted at a standard exception** (cppcodec). "Throws a
   `cppcodec::parse_error` exception (inheriting from `std::domain_error`) if the
   input data does not conform to the codec variant specification." The
   hierarchy is `parse_error : std::domain_error`, with derived `symbol_error`,
   `invalid_input_length`, `padding_error : invalid_input_length`. For base32,
   `decode_tail` throws `invalid_input_length` with messages such as "invalid
   number of symbols in last base32 block: found 1, expected 2, 4, 5 or 7"
   (`cppcodec/detail/base32.hpp`). Source:
   <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/parse_error.hpp>.
2. **`noexcept` + `abort()`** for the raw-pointer overloads: cppcodec's README
   states the raw-buffer `encode`/`decode` "Calls `abort()` if
   `encoded_buffer_size` is insufficient. (That way, the function can remain
   `noexcept` rather than throwing on an entirely avoidable error condition.)"
3. `std::expected` (C++23, `<expected>`) is the modern vocabulary type for this
   shape but is not used by cppcodec.

(Assessment: cppcodec carries one exception type per failure mode; for base32
the `invalid_input_length` case is specifically about the last-block symbol
count, so the 2/4/5/7 tail lengths are validated at the type level of the
exception message.)

## 5. Ownership semantics

C++ layers three ownership contracts on the same algorithm; the choice is
explicit in the signature:

- **Return-by-value, caller owns the result.** `encode(...)` "returns an
  `std::string`"; `decode(...)` "returns an `std::vector<uint8_t>`". The input is
  borrowed (pointer + size or `const T&`); nothing is claimed. Source: cppcodec
  README.
- **Caller-supplied output container, reused.** The `Result&` overloads take an
  existing container and "Resizes `encoded_result` before writing to it" — the
  caller controls the allocator and can reuse the buffer across calls.
- **Caller-owned raw buffer.** The `char*` overloads take `encoded_buffer_size`
  and return the byte count; on success a `'\0'` is appended only if the buffer
  is larger than needed. On under-size, `abort()` (see §4).
- Internally, a `data::ResultState` trait abstracts container mutation
  (`create_state`, `init`, `put`, `finish`), so a custom buffer only needs
  `.reserve/.resize/.push_back`. Sources: `cppcodec/detail/stream_codec.hpp`,
  `cppcodec/detail/codec.hpp`.

(Assessment: derived from the sources above: C++ makes the ownership contract
*selectable* — value-returning, container-refilling, and raw-`noexcept`. For
base32 the only concrete implementation is cppcodec, so this three-way surface
is exactly what a C++ base32 user sees.)

## 6. Blocking / non-blocking

Not applicable at the codec level: cppcodec is a synchronous in-memory transform
with no I/O. Any base32 I/O would have to come from the C layer (gnulib's decode
context), which is also synchronous. No C++ base32 library exposes a coroutine,
future or async API. (Assessment: derived from cppcodec's API shapes — every
function is buffer-in/buffer-out.)

## 7. Alphabet variants, case and padding

This is where C++ is clearly richer than C, and cppcodec is the **only C-family
library that ships Crockford base32** (Crockford is also shipped by the Rust
`base32` crate — `rust.md` §7 — and by npm `base32-encode` — `js-ts.md` §7):

- **cppcodec ships one class per base32 variant** and makes the padding policy a
  `constexpr` property of that class:

  | Variant | Alphabet | generates padding | requires padding | extra |
  | --- | --- | --- | --- | --- |
  | `base32_rfc4648` | `A-Z 2-7` | `true` | `true` | accepts lower case via `normalized_symbol` |
  | `base32_hex` | `0-9 A-V` | `true` | `true` | accepts lower case `a-v` |
  | `base32_crockford` | Crockford `0-9 A-Z` minus I,L,O,U | `false` | `false` | `O`/`o`→`0`, `I`/`i`/`L`/`l`→`1`, ignores `-` |

  Sources: `cppcodec/base32_rfc4648.hpp`, `cppcodec/base32_hex.hpp`,
  `cppcodec/base32_crockford.hpp`.
- **Lower-case input is accepted** by both RFC 4648 base32 variants, even though
  the comment says "Lower-case letters are accepted, though not generally
  expected." `base32_rfc4648::normalized_symbol` maps `a`–`z`→`A`–`Z`;
  `base32_hex` maps `a`–`v`→`A`–`V`. This is a lenient default, unlike Go.
  Sources: `base32_rfc4648.hpp`, `base32_hex.hpp`.
- **`base32_crockford` documents a subtlety absent from C**: "the specification
  is ambiguous about whether to pad bit quintets to the left or to the right …
  This codec variant picks the streaming interpretation and thus zero-pads on
  the right." It normalizes confusable input (`O`→`0`, `I`/`L`→`1`) and its
  `should_ignore('-')` returns true because "Hyphens (-) can be inserted into
  strings [for readability]." Source: `base32_crockford.hpp`.
- **`should_ignore` is always false for the RFC 4648 variants**: "RFC4648 does
  not specify any whitespace being allowed in base32 encodings." Sources:
  `base32_rfc4648.hpp`, `base32_hex.hpp`.
- **Padding is always `=` for RFC 4648 and absent for Crockford**;
  `generates_padding()` (encoder emits) is split from `requires_padding()`
  (decoder demands). Sources: the three variant headers.
- **RFC 4648 reference**: §6 Table 3 (base32 `A-Z2-7`), §7 Table 4 (base32hex
  `0-9A-V`), §3.2 padding, §3.4 the default non-decoding of `0/O` and `1/I/L`,
  §3.5 canonical encoding. (https://www.rfc-editor.org/rfc/rfc4648.txt)

(Assessment: derived from the sources above: cppcodec's `generates_padding()` /
`requires_padding()` / `should_ignore()` triple is the most precise variant
contract found in either C-family language, and it is the only **C-family**
place where Crockford base32 is implemented next to RFC 4648 base32 in one API.
Crockford is not unique to cppcodec overall: the Rust `base32` crate
(`rust.md` §7) and npm `base32-encode` (`js-ts.md` §7) also ship it.)

## 8. Timeouts

Not applicable. cppcodec accepts no timeout, deadline or cancellation token and
performs no I/O. Cancellation would be a caller-side concern around a synchronous
function bounded by its input size. (Assessment: derived from the signatures
above; no timeout parameter appears in any cited prototype.)

## 9. Streaming / incremental encode and decode

C++ is **weak here**: cppcodec is whole-buffer despite the name `stream_codec`.

- **cppcodec is not incremental.** `detail::stream_codec<Codec, CodecVariant>`
  processes one complete input buffer and emits one complete output; there is no
  `update`/`final` pair and no public carried-state object. Its encode walks full
  5-byte blocks then a tail emitted with padding in the same call (see
  `detail/stream_codec.hpp` and `detail/base32.hpp`'s
  `num_encoded_tail_symbols`). Source:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/stream_codec.hpp>.
- The leftover-block logic exists only *inside* one call, not across calls:
  `decode_tail` takes the `idx_len` of the final block and rejects 1/3/6 symbols
  as `invalid_input_length` (`cppcodec/detail/base32.hpp`).
- **Incremental streaming must therefore come from the C layer**: gnulib's
  `base32_decode_ctx` with its `char buf[8]` carry (see `c.md` §9). There is no
  C++ base32 streaming type in this survey.

(Assessment: derived from the sources above: a C++ program wanting chunked
base32 has to wrap gnulib's decode context or write its own 5-byte/8-symbol
state machine.)

## 10. Interesting design decisions

- **Variant-as-type through a shared CRTP template.** All cppcodec codecs are
  `detail::codec<detail::base32<detail::base32_rfc4648>>`, where the inner class
  provides only alphabet/padding policy and the outer provides the API. This
  removes all per-variant branching at runtime — the single most transferable
  idea in this survey. Sources: `cppcodec/base32_rfc4648.hpp`,
  `cppcodec/detail/codec.hpp`.
- **The 5↔8 quantum is a first-class constant in the detail class.**
  `binary_block_size() == 5`, `encoded_block_size() == 8`, and
  `num_encoded_tail_symbols` enumerates the only legal tail symbol counts
  (2/4/5/7). Source: `cppcodec/detail/base32.hpp`.
- **Compile-time lookup tables.** Decoding builds the inverse table as a
  `constexpr` array via recursive templates so "the lookup table must cover each
  possible (character) symbol" is a `static_assert`. Source:
  `cppcodec/detail/stream_codec.hpp`.
- **Splitting `generates_padding()` from `requires_padding()`.** The encoder asks
  the first, the decoder the second — so a variant can encode without padding yet
  accept padded input. Sources: `base32_rfc4648.hpp`, `base32_hex.hpp`.
- **Crockford's left/right-padding ambiguity made explicit.** cppcodec chooses
  "zero-pads on the right" for streaming and says so, rather than silently
  picking one. Source: `base32_crockford.hpp`.
- **`normalized_symbol` as the single place case-insensitivity and confusable
  mapping live.** For RFC 4648 base32 it is a simple `a`–`z`→`A`–`Z`; for
  Crockford it is `O→0`, `I/L→1`. Sources: the three variant headers.
- **`noexcept` + `abort()` instead of a buffer-too-small exception.** cppcodec's
  raw-buffer overloads make "you sized the buffer wrong" a programming error
  rather than a recoverable one. Source: cppcodec README.
- **A typed, allocation-free exception.** `symbol_error` stores only the
  offending `char` and builds its message without allocation. Source:
  `cppcodec/parse_error.hpp`.

## 11. Decisions NOT to copy

- **Three overlapping encoding overloads that differ only in ownership**
  (`std::string` return, `Result&` refill, raw `char*` + `abort`). It triples the
  API surface and the test matrix; a language with value semantics and slices
  needs at most two (allocating and in-place). Source: cppcodec README.
- **`abort()` on a caller buffer-sizing mistake.** Silently terminating the
  process to preserve a `noexcept` signature is the wrong trade for a library
  API; a diagnosable error is better. Source: cppcodec README.
- **Exception-per-failure-mode hierarchies for a pure codec.** `parse_error` /
  `symbol_error` / `invalid_input_length` / `padding_error` is four types for one
  decoder; a single typed error with a discriminant is easier to handle
  exhaustively. Source: `cppcodec/parse_error.hpp`.
- **Implicit lower-case acceptance on decode.** `normalized_symbol` silently
  case-folds even though RFC 4648 §12 warns that case-insensitive base32 can
  "leak information or make string equality comparisons fail". Make case policy
  an explicit option. (Sources: `base32_rfc4648.hpp`,
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **Whole-buffer-only APIs with no incremental path.** C proves the streaming
  API is needed for pipes and sockets; copying cppcodec's convenience-only design
  would force MojoAkku users to reimplement the state machine. (Source: the
  streaming section above.)
- **Alphabet selection by choosing a differently-named class per variant**
  (`base32_rfc4648` vs `base32_hex` vs `base32_crockford`). It works, but as a
  naming scheme it does not scale; an explicit alphabet+padding value is more
  composable. Source: cppcodec README.
- **Crockford's `should_ignore('-')` as an always-on default** and its
  left/right-padding ambiguity: Crockford is a real, useful variant (ULID), but
  its quirks should be opt-in and documented, not merged into the RFC 4648
  behavior. Source: `base32_crockford.hpp`.
- **Requiring the output size to be computed by a template parameter with
  undocumented structural requirements** (`.reserve`, `.resize`, `.push_back`).
  Source: cppcodec README.

## 12. Ideas fitting Mojo

- **Variant-as-type is directly expressible with Mojo generics/`comptime`.**
  cppcodec makes the alphabet a class parameter and the padding policy a
  `constexpr` method; in Mojo the same is an `alias`/parameterized type where
  `generates_padding` and `requires_padding` become `comptime` constants. This
  matches the direction the stdlib already implies but does not yet offer: the
  buch records that Mojo's `base64` package "exposes the standard functions;
  there is no exposed alphabet parameter on these four" (`mojov1/stdlib/base64`).
- **The 5↔8 quantum as named compile-time constants.** `binary_block_size()` /
  `encoded_block_size()` / `num_encoded_tail_symbols` translate directly to Mojo
  `alias` values, making the base32 (as opposed to base64) geometry explicit and
  testable (`cppcodec/detail/base32.hpp`).
- **Borrowed-span input plus fresh output is the right default.** Mojo already
  takes `StringSpan`/`Span[UInt8]` by immutable reference and returns a new
  `List[UInt8]` (buch, `mojov1/stdlib/base64`) — the same stance as cppcodec's
  value-returning form, minus the extra overloads.
- **Use Mojo typed errors where cppcodec uses an exception hierarchy.** A single
  `raises Base32Error` with a discriminant (bad length / bad symbol / bad
  padding) gives exhaustive, allocation-free handling; the buch's error model
  shows the compiler enforcing `raises` on every caller
  (`mojov1/errors/error-model`). For base32 the `invalid_input_length` case maps
  to "last block has an impossible symbol count (1, 3 or 6)".
- **`std::span` ↔ Mojo `Span` is a one-to-one concept**, and base32pp/base64pp
  show the borrowed view with an explicit length; Mojo's `Span` adds
  compiler-checked origins ("`Span` is a non-owning view of contiguous data",
  `mojov1/types/collections`). Keep the borrowed-in / owned-out split.
- **`generates_padding` / `requires_padding` / `should_ignore` as `comptime`
  policy flags.** cppcodec's per-variant methods are the compile-time analogue of
  Python's runtime options; Mojo can expose them so strictness, padding and
  Crockford-style aliasing are visible at the call site
  (`cppcodec/base32_rfc4648.hpp`).
- **Crockford is worth a first-class variant**, since ULID and Crockford IDs use
  it and cppcodec proves it fits next to RFC 4648 base32; but its confusable
  normalization (`O→0`, `I/L→1`) and optional hyphens must be opt-in. (Sources:
  `cppcodec/base32_crockford.hpp`, https://github.com/ulid/spec.)
- **`encoded_size`/`decoded_max_size` as `comptime`-callable pure functions**
  translate C++'s `constexpr` sizing helpers into the improvement over C's macro;
  for base32 the exact formula is `8*ceil(n/5)` and the decode estimate is
  `n/8*5`. Source: `cppcodec/detail/codec.hpp`; RFC 4648 §6.

## Sources

- C++ standard library header list (no base-N codec):
  <https://en.cppreference.com/w/cpp/header>
- `std::to_chars` (base 2..36, not a byte codec):
  <https://en.cppreference.com/w/cpp/utility/to_chars>
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- cppcodec README (variants, philosophy, API):
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/README.md>
- cppcodec `cppcodec/detail/codec.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/codec.hpp>
- cppcodec `cppcodec/detail/base32.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/base32.hpp>
- cppcodec `cppcodec/detail/stream_codec.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/stream_codec.hpp>
- cppcodec `cppcodec/base32_rfc4648.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base32_rfc4648.hpp>
- cppcodec `cppcodec/base32_hex.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base32_hex.hpp>
- cppcodec `cppcodec/base32_crockford.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base32_crockford.hpp>
- cppcodec `cppcodec/parse_error.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/parse_error.hpp>
- Boost mailing list: Beast will not expose base64 publicly:
  <https://listarchives.boost.org/boost-users/2020/12/90714.php>
- tobiaslocker/base64: <https://github.com/tobiaslocker/base64>
- base64pp documentation: <https://matheusgomes28.github.io/base64pp/>
- aklomp/base64 README: <https://raw.githubusercontent.com/aklomp/base64/master/README.md>
- ULID spec (Crockford base32 use case): <https://github.com/ulid/spec>
- Mojo `mojov1` buch, `stdlib/base64` (Mojo-side reference for section 12)
- Mojo `mojov1` buch, `types/collections` (`Span`, ownership)
- Mojo `mojov1` buch, `errors/error-model` (`raises`, typed errors)
