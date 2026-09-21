# base64 research: C++

## 1. Standard library support

C++ has **no standard-library base64/base32/base16 codec**. The C++ standard
library interface is defined by a fixed header list — the general utilities,
containers, strings, text-processing and (in C++26) `<text_encoding>` headers —
and no header provides base-N encoding. Source:
<https://en.cppreference.com/w/cpp/header>.

The closest facility is integer formatting: `std::to_chars` in `<charconv>`
"converts value to a string of digits in the given base", but the base is
restricted: "integer base to use: a value between 2 and 36 (inclusive)". Base64 is
not that (it is a bit-packing over 64 symbols, not a positional integer base), and
there is no byte-oriented codec at all. Source:
<https://en.cppreference.com/w/cpp/utility/to_chars>.

Base16 is only reachable via `std::to_chars`/`std::format` per integer, or via the
hex floating-point `chars_format::hex` for numbers — not as a byte-string codec.
The absence follows from the standard header list itself: no header in
<https://en.cppreference.com/w/cpp/header> provides base-N encoding. The
alternatives are therefore third-party: OpenSSL and Boost.Beast, as
surveyed in section 2 below.

(Assessment: derived from the header list and `std::to_chars` pages: C++ inherits
C's absence of a codec and, unlike Go/Rust, did not add one in C++17/20/23/26; the
`<charconv>` base parameter is a numeric-radix facility, not a byte codec.)

**Proposal status.** A search for a `std::base64` standardization paper returned no
located paper; the only `P2592` in WG21 numbering found in this pass is
"P2592R3 Hashing support for std::chrono", i.e. unrelated. Sources:
DuckDuckGo results for `"std::base64" C++26 proposal paper open-std wg21` (no hits)
and <https://www.mail-archive.com/gcc-bugs@gcc.gnu.org/msg783523.html>. GUESS: I
could not locate any accepted or active base64 standardization paper; absence of
evidence is not proof of absence.

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | Variants |
| --- | --- | --- | --- | --- |
| cppcodec (tplgy) | Topology LP / efidler | header-only C++11, actively cited | MIT | base64, base64url, base64url-unpadded, base32, base32hex, Crockford, hex up/low |
| Boost.Beast base64 | Boost (Vinnie Falco) | part of Boost, but **detail/** namespace | Boost Software License 1.0 | base64 standard only |
| OpenSSL `EVP_*` via C API | OpenSSL Foundation | ubiquitous | Apache-2.0 | base64 standard only |
| tobiaslocker/base64 | Tobias Locker | header-only C++17/C++20 | MIT | base64 standard only |
| base64pp | Matheus Gomes | C++20, CMake | MIT | base64 standard only |
| cpp-base64 (ReneNyffenegger) | René Nyffenegger | long-lived snippet library | zlib-like custom | base64 standard only |
| aklomp/base64 | Alfred Klomp | C99 with SIMD; usable from C++ | BSD-2-Clause | base64 standard only |

Sources:
- cppcodec "Header-only C++11 library to encode/decode base64, base64url, base32,
  base32hex and hex (a.k.a. base16) as specified in RFC 4648, plus Crockford's
  base32. MIT licensed": <https://raw.githubusercontent.com/tplgy/cppcodec/master/README.md>.
- Boost.Beast's codec lives under `boost/beast/core/detail/base64.hpp` with the
  comment "HTTP and WebSocket built on Boost.Asio"; a Boost mailing-list reply from
  the maintainers states: "From our point of view as maintainers of a single-purpose
  library, it would not make sense to extend our public API into general-purpose
  base64 encoding/decoding at this time." Sources:
  <https://raw.githubusercontent.com/boostorg/beast/develop/include/boost/beast/core/detail/base64.hpp>,
  <https://listarchives.boost.org/boost-users/2020/12/90714.php>.
- tobiaslocker/base64 "A simple, header-only C++17 library ... Uses modern C++
  features when available (e.g., std::bit_cast in C++20)"; MIT LICENSE file.
  Sources: <https://github.com/tobiaslocker/base64>,
  <https://raw.githubusercontent.com/tobiaslocker/base64/master/LICENSE>.
- base64pp "A C++ library ... Supports `std::span<std::uint8_t>`", "licensed under
  the MIT license": <https://matheusgomes28.github.io/base64pp/>.
- cpp-base64 license text: "Permission is granted to anyone to use this software for
  any purpose ... subject to the following restrictions" (zlib-style).
  Source: <https://raw.githubusercontent.com/ReneNyffenegger/cpp-base64/master/LICENSE>.
- aklomp/base64 BSD-2-Clause: <https://raw.githubusercontent.com/aklomp/base64/master/README.md>.

(Assessment: derived from the sources above: C++'s community answer to the missing
stdlib codec is cppcodec for *breadth of variants* and Boost.Beast/OpenSSL for
convenience; only cppcodec offers base32 and base16 in the same API.)

## 3. Exposed APIs

### cppcodec (the variant-rich reference)

The design is **one class per variant**, "with classes and their associated header
files named verbatim after the codec variants", all exposing the same static API
through a shared `detail::codec<...>` template. Source: its README.

Available variant aliases and their headers (`cppcodec/…`):
`base64_rfc4648`, `base64_url`, `base64_url_unpadded`, `base32_rfc4648`,
`base32_crockford`, `base32_hex`, `hex_upper`, `hex_lower`. Source: README and
`cppcodec/base64_rfc4648.hpp`, `cppcodec/base64_url.hpp`,
`cppcodec/base64_url_unpadded.hpp`.

Encoding API (`codec<CodecImpl>` in `cppcodec/detail/codec.hpp`):

```cpp
std::string             encode(const uint8_t* binary, size_t binary_size);
std::string             encode(const char* binary, size_t binary_size);
template <typename Result> Result encode(const uint8_t* binary, size_t binary_size);
template <typename Result> void   encode(Result& encoded_result, const uint8_t* binary, size_t binary_size);
size_t                  encode(char* encoded_result, size_t encoded_buffer_size,
                               const uint8_t* binary, size_t binary_size) noexcept;
static constexpr size_t encoded_size(size_t binary_size) noexcept;
```

Decoding API:

```cpp
std::vector<uint8_t>     decode(const char* encoded, size_t encoded_size);
template <typename Result> Result decode(const char* encoded, size_t encoded_size);
template <typename Result> void   decode(Result& binary_result, const char* encoded, size_t encoded_size);
size_t                   decode(uint8_t* binary_result, size_t binary_buffer_size,
                                const char* encoded, size_t encoded_size);
static constexpr size_t  decoded_max_size(size_t encoded_size) noexcept;
```

Source: <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/codec.hpp>.
Templated `Result` types must support `.data()`/`.size()` and, for output,
`.reserve(size_t)`, `.resize(size_t)`, `.push_back(...)` — i.e. `std::vector<uint8_t>`,
`std::string`, or a custom container. Source: README.

Per-variant contract methods live on the variant class:
`alphabet_size()`, `symbol(idx)`, `normalized_symbol(c)`, `generates_padding()`,
`requires_padding()`, `padding_symbol()`, `is_padding_symbol(c)`, `is_eof_symbol(c)`,
`should_ignore(c)`. E.g. `base64_rfc4648`:
"RFC4648 does not specify any whitespace being allowed in base64 encodings", hence
`should_ignore(char) { return false; }`. Source:
<https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base64_rfc4648.hpp>.

### Boost.Beast (`boost::beast::detail::base64`)

```cpp
char const*         get_alphabet();
signed char const*  get_inverse();
std::size_t constexpr encoded_size(std::size_t n);   // 4 * ((n + 2) / 3)
std::size_t constexpr decoded_size(std::size_t n);   // n / 4 * 3, requires n&3==0
std::size_t         encode(void* dest, void const* src, std::size_t len);
std::pair<std::size_t, std::size_t> decode(void* dest, char const* src, std::size_t len);
```

Source: <https://raw.githubusercontent.com/boostorg/beast/develop/include/boost/beast/core/detail/base64.hpp>.
Note the `detail` namespace and the maintainers' statement that it will not become
public API.

### tobiaslocker/base64

```cpp
template <class OutputBuffer, class InputIterator>
OutputBuffer encode_into(InputIterator begin, InputIterator end);

template <class OutputBuffer>
OutputBuffer encode_into(std::string_view data);

inline std::string to_base64(std::string_view data);

template <class OutputBuffer>
OutputBuffer decode_into(std::string_view base64Text);

inline std::string from_base64(std::string_view data);
```

Source: <https://raw.githubusercontent.com/tobiaslocker/base64/master/include/base64.hpp>.
`OutputBuffer` may be `std::string`, `std::vector<char>` or `std::vector<std::byte>`;
input element types are constrained by `static_assert` to the byte-like types.

### base64pp

```cpp
std::string encode(std::span<std::uint8_t const> input);
std::string encode_str(std::string_view input);
std::optional<std::vector<std::uint8_t>> decode(std::string_view encoded_str);
```

Source: <https://raw.githubusercontent.com/matheusgomes28/base64pp/main/base64pp/include/base64pp/base64pp.h>.
Its doc comment is explicit about unpadded input: "this function accepts unpadded
strings, if they are valid otherwise. It rejects odd-sized unpadded strings."

### OpenSSL / BoringSSL from C++

C++ code links the C `EVP_EncodeBlock`/`EVP_DecodeBlock`/streaming API unchanged
(see the C file `c.md` for the full surface). The `EVP_ENCODE_CTX` can be stack
allocated in C++ or wrapped in a RAII holder.

## 4. Error representation

Three coexisting C++ styles, none of which is the language default:

1. **Exception hierarchy rooted at a standard exception** (cppcodec). "Throws a
   `cppcodec::parse_error` exception (inheriting from `std::domain_error`) if the
   input data does not conform to the codec variant specification." The hierarchy is
   `parse_error : std::domain_error`, with derived `symbol_error`,
   `invalid_input_length`, `padding_error : invalid_input_length`. `symbol_error`
   carries the offending character (`char symbol() const noexcept`), and its message
   is built without allocation so the type stays cheap. Source:
   <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/parse_error.hpp>.
2. **`std::runtime_error` with a prose message** (tobiaslocker). Distinct messages:
   `"Invalid base64 encoded data - Size not divisible by 4"`,
   `"Invalid base64 encoded data - Found more than 2 padding signs"`,
   `"Invalid base64 encoded data - Invalid character"`,
   `"Invalid base64 encoded data - Invalid padding number"`. Source:
   <https://raw.githubusercontent.com/tobiaslocker/base64/master/include/base64.hpp>.
3. **`std::optional` as the error channel** (base64pp). `decode` "returning an
   optional blob. If the decoding fails, it returns `std::nullopt`" — no exception,
   no error code, no diagnostic detail. Source: its header.

`std::expected` (C++23, `<expected>`) is the modern vocabulary type for this shape
but is not used by any surveyed library. Source:
<https://en.cppreference.com/w/cpp/header>.

A distinct, non-throwing contract also exists: cppcodec's raw-pointer overloads are
declared `noexcept` and "Calls `abort()` if `encoded_buffer_size` is insufficient.
(That way, the function can remain `noexcept` rather than throwing on an entirely
avoidable error condition.)" Source: cppcodec README.

## 5. Ownership semantics (buffer/ownership of encode input and produced output)

C++ layers three ownership contracts on the same algorithm; the choice is explicit
in the signature:

- **Return-by-value, caller owns the result.** `encode()` "returns an `std::string`";
  `decode()` "returns an `std::vector<uint8_t>`". The input is borrowed (pointer +
  size or `const T&`); nothing is claimed. Source: cppcodec README.
- **Caller-supplied output container, reused.** The `Result&` overloads take an
  existing container and "Resizes `encoded_result` before writing to it" — so the
  caller controls the allocator and can reuse the buffer across calls. Source:
  cppcodec README/`detail/codec.hpp`.
- **Caller-owned raw buffer.** The `char*` overloads take `encoded_buffer_size` and
  return the byte count; on success a `'\0'` is appended only if the buffer is
  larger than needed ("If `encoded_buffer_size` is larger than required, a single
  null termination character (`'\0'`) is written after the last encoded character").
  Source: cppcodec README.
- **Templated output via a trait-ish `ResultState`.** Internally `data::create_state`,
  `data::init`, `data::put`, `data::finish` abstract container mutation, so a custom
  buffer only needs `.reserve/.resize/.push_back`. Sources:
  `cppcodec/detail/stream_codec.hpp`, `cppcodec/detail/codec.hpp`; the raw
  `data::raw_result_buffer binary(binary_result, binary_buffer_size)` wrapper turns a
  raw pointer into the same interface.
- **`noexcept` + `abort()` for the raw path**: no exception can escape, so a
  wrongly-sized buffer is a process abort, not an error — a deliberate trade of
  safety for a throw-free signature. Source: cppcodec README and
  `detail/stream_codec.hpp` (`abort()` on impossible tail lengths).
- **base64pp borrows via `std::span`**: `encode(std::span<std::uint8_t const>)`
  cannot take ownership, and `decode` returns a fresh `std::optional<std::vector<std::uint8_t>>`.
  Source: its header.

(Assessment: derived from the sources above: C++ makes the ownership contract
*selectable* — value-returning, container-refilling, and raw-`noexcept`. C is not
single-form either: its mainstream APIs are caller-allocated-output (OpenSSL, glibc,
aklomp, mbedTLS, Windows) plus the gnulib explicit `_alloc` form (`c.md` §5). Java
likewise exposes more than one value form — allocate-and-return `byte[] encode(byte[]
src)`, caller-buffer `int encode(byte[] src, byte[] dst)` and the `String
encodeToString(byte[] src)` convenience (`java.md:96-101`). The cost is a three-way
API surface and a buffer-sizing contract that the type system still does not enforce.)

## 6. Blocking / non-blocking

Not applicable at the codec level: every surveyed codec is a synchronous in-memory
transform with no I/O. The only I/O-adjacent element is OpenSSL's `BIO_f_base64()`
filter (reached from C++ through the C API), which inherits the blocking/retry
semantics of the underlying `BIO`, and the OpenSSL `ASYNC_*` machinery, which does
not cover the base64 functions. No C++ base64 library in this survey exposes a
coroutine, future or async API. Sources: OpenSSL `evp.h`,
<https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/encode.c>.

(Assessment: derived from the API shapes above — every function is
buffer-in/buffer-out.)

## 7. Alphabet variants and padding

This is where C++ is clearly richer than C: **the variant is a type, not a runtime
flag.**

- **cppcodec ships one class per variant** and makes the padding policy a
  `constexpr` property of that class:

  | Variant | Alphabet | generates padding | requires padding |
  | --- | --- | --- | --- |
  | `base64_rfc4648` | `A-Z a-z 0-9 + /` | `true` | `true` |
  | `base64_url` | `A-Z a-z 0-9 - _` | `true` | `true` |
  | `base64_url_unpadded` | same as `base64_url` | `false` | `false` |
  | `base32_rfc4648` | `A-Z 2-7` | `true` | `true` |
  | `base32_hex` | `0-9 A-V` | `true` | `true` |
  | `base32_crockford` | Crockford alphabet | `false` | `false` |
  | `hex_upper` | `0-9 A-F` | n/a | n/a |
  | `hex_lower` | `0-9 a-f` | n/a | n/a |

  Sources: cppcodec README; `cppcodec/base64_rfc4648.hpp`, `base64_url.hpp`,
  `base64_url_unpadded.hpp`.
- `base64_rfc4648` documents "requires padding ('=') but no line breaks. Whitespace
  and other out-of-alphabet symbols are regarded as a parse error", while
  `base64_url_unpadded` "is the same as `base64_url`, but '=' padding characters are
  optional. When encoding, no padding will be appended ... Decoding accepts either
  padded or unpadded strings." Source: cppcodec README.
- `base32_crockford` documents a subtlety absent from C: "the specification is
  ambiguous about whether to pad bit quintets to the left or to the right ... This
  codec variant picks the streaming interpretation and thus zero-pads on the right."
  It also normalizes confusable input: `I`/`i`/`L`/`l` → `1`, `O`/`o` → `0`, via
  `normalized_symbol()`. Source: cppcodec README and
  `detail/base64.hpp`/`stream_codec.hpp` (`normalized_symbol`).
- `hex_upper` "outputs upper-case letters and accepts lower-case as well"; `hex_lower`
  the reverse. Both are strictly octet-streaming: "requires an even number of input
  symbols", and neither handles a `0x` prefix. Source: cppcodec README.
- **Boost.Beast exposes exactly one variant** (standard `+/` with padding), with
  `get_alphabet()`/`get_inverse()` returning fixed tables. Source: Beast `base64.hpp`.
- **tobiaslocker** is standard-alphabet, padded only, but its decoder tolerates
  unpadded-but-size-divisible-by-4? No — it *requires* `(base64Text.size() & 3) == 0`
  and rejects more than two `=` in the last quad. Source: its header.
- **base64pp** is standard-alphabet and explicitly accepts *unpadded* input as long
  as it is otherwise valid. Source: its header.
- The reference for all of this is RFC 4648: §4 Table 1 (base64), §5 Table 2
  (base64url `-`/`_`), §6 Table 3 (base32 `A-Z2-7`), §7 Table 4 (base32hex
  `0-9A-V`), §8 Table 5 (base16); §3.2 requires padding unless the referring spec
  says otherwise, §3.3 requires rejecting non-alphabet characters unless explicitly
  overridden, §3.5 explains canonical encoding. Source:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>.

(Assessment: derived from the sources above: cppcodec's `generates_padding()` /
`requires_padding()` / `should_ignore()` triple is the most precise variant contract
found in either language — it separates *what the encoder emits* from *what the
decoder demands*, which C conflates and libsodium approximates only with enum
values.)

## 8. Timeouts

Not applicable. No C++ base64 library in this survey accepts a timeout, deadline or
cancellation token; none performs I/O. Cancellation would be a caller-side concern
around a synchronous function that is bounded by its input size.

(Assessment: derived from the signatures above; no timeout parameter appears in any
cited prototype.)

## 9. Streaming / incremental encode+decode and leftover-byte carry

C++ is **weaker than C here**, because the community libraries chose whole-buffer
algorithms:

- **cppcodec is not incremental despite the name `stream_codec`.** The class
  `detail::stream_codec<Codec, CodecVariant>` processes one complete input buffer
  and emits one complete output; there is no `update`/`final` pair and no carried
  state object in the public API. Its `encode` walks full blocks then a tail:
  `if (src_size >= Codec::binary_block_size()) { ... for (; src <= src_end; src += Codec::binary_block_size()) ... }`,
  and the tail is emitted with padding in the same call. Source:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/stream_codec.hpp>.
  The leftover-block logic exists only *inside* one call, not across calls.
- **tobiaslocker/base64 is whole-buffer** (`decode_into(std::string_view)`); the only
  requirement it enforces is `size & 3 == 0`, i.e. it cannot accept a partial trailing
  quantum at all. Source: its header.
- **base64pp is whole-buffer** (`encode(std::span<...>)`, `decode(std::string_view)`).
  Source: its header.
- **Boost.Beast's codec is whole-buffer too** (`encode(void*, void const*, len)`),
  even though Beast's *HTTP parser* is incremental. Source: Beast `base64.hpp`.
- **Incremental streaming must therefore come from the C layer**: OpenSSL's
  init/update/final triad (leftover carried in `ctx->enc_data`, with `EVP_ENCODE_CTX_num`
  reporting pending bytes) and aklomp/base64's
  `base64_stream_encode_init`/`_encode`/`_encode_final` triad. Sources:
  `openssl/crypto/evp/encode.c`,
  <https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>,
  <https://raw.githubusercontent.com/aklomp/base64/master/README.md>.

(Assessment: derived from the sources above: C++'s own libraries optimized for the
common whole-buffer case and left chunked encoding to C. A C++ "streaming" base64
that wants leftover-byte carry currently has to wrap the OpenSSL context or write
its own state machine.)

## 10. Interesting design decisions

- **Variant-as-type through a shared CRTP template.** All cppcodec codecs are
  `detail::codec<detail::base64<detail::base64_rfc4648>>`, where the inner class
  provides only alphabet/padding policy and the outer provides the API. This removes
  all per-variant branching at runtime and is the single most transferable idea in
  this survey. Sources: `cppcodec/base64_rfc4648.hpp`, `detail/codec.hpp`.
- **Compile-time lookup tables.** Decoding builds the inverse table as a `constexpr`
  array via recursive templates (`make_lookup_table`, `index_if_in_alphabet`,
  `padding_searcher`) so "the lookup table must cover each possible (character)
  symbol" is a `static_assert`. Source: `detail/stream_codec.hpp`.
- **Splitting `generates_padding()` from `requires_padding()`.** The encoder asks
  the first, the decoder the second — so `base64_url_unpadded` can encode without
  padding yet still accept padded input. Source: `base64_url_unpadded.hpp`,
  `base64_url.hpp`.
- **A typed, allocation-free exception.** `symbol_error` stores only the offending
  `char` and builds its message with a hand-rolled `uctoa` "to avoid memory
  allocation, so it can be used in constexpr functions" — a small but sharp
  example of keeping error types cheap. Source: `parse_error.hpp`.
- **`noexcept` + `abort()` instead of a buffer-too-small exception.** cppcodec's
  raw-buffer overloads make "you sized the buffer wrong" a programming error
  (abort) rather than a recoverable one (throw), which keeps the noexcept contract
  intact. Source: cppcodec README.
- **`std::optional` vs exception vs `expected`.** base64pp's `std::optional` decode
  is the simplest possible API shape but discards the *reason* for failure that
  cppcodec's exception hierarchy preserves; `std::expected` (C++23) would reconcile
  both but is unused by these libraries. Sources: base64pp header, `parse_error.hpp`,
  <https://en.cppreference.com/w/cpp/header>.
- **`std::span` as the input type** (base64pp, C++20): a borrowed view with an
  explicit length, which is C++'s analogue of Mojo's `Span` and removes the
  `(ptr, len)` pairing mistake. Source: base64pp header.
- **`std::bit_cast` for type punning.** tobiaslocker replaces the classic
  `union`-based punning with `std::bit_cast<std::array<char,4>, uint32_t>` and
  cites the UB risk: "Use bit_cast instead of union and type punning to avoid
  undefined behaviour risk". Source: its header.
- **Boost.Beast returning a pair from decode** — `std::pair<std::size_t, std::size_t>`
  = (octets written, characters read) — so a caller can resume after a partial
  decode. It is the only C++ library here whose decode result supports continuation.
  Source: Beast `base64.hpp`.

## 11. Decisions NOT to copy

- **Three overlapping encoding overloads that differ only in ownership** (`std::string`
  return, `Result&` refill, raw `char*` + `abort`). It triples the API surface and
  the test matrix; a language with value semantics and slices needs at most two
  (allocating and in-place). Source: cppcodec README.
- **`abort()` on a caller buffer-sizing mistake.** Silently terminating the process
  to preserve a `noexcept` signature is the wrong trade for a library API; a
  diagnosable error is better. Source: cppcodec README.
- **Exception-per-failure-mode hierarchies for a pure codec.** `parse_error` /
  `symbol_error` / `invalid_input_length` / `padding_error` is four types for one
  decoder; a single typed error with a discriminant is easier to handle exhaustively.
  Source: `parse_error.hpp`.
- **Returning `std::optional` with no failure reason** (base64pp). The caller cannot
  distinguish "wrong length" from "invalid character" from "bad padding". Source:
  base64pp header.
- **Putting the codec under an internal/`detail` namespace and calling it
  unsupported** (Boost.Beast). If the implementation is good enough to ship in an
  HTTP library, exposing it is better than forcing users to depend on `detail::`.
  Sources: Beast `base64.hpp`, the Boost mailing-list reply.
- **Whole-buffer-only APIs with no incremental path.** C proves the streaming API is
  needed for pipes and sockets; copying the C++ convenience-only design would force
  MojoAkku users to reimplement the state machine. Sources: the streaming section above.
- **Requiring the output size to be computed by a template parameter that must
  satisfy undocumented structural requirements** (`.reserve`, `.resize`,
  `.push_back`). The README has to describe the concept in prose instead of naming
  it. Source: cppcodec README.
- **Alphabet selection by choosing a differently-named class per variant**
  (`base64_url` vs `base64_url_unpadded`). It works, but as a naming scheme it does
  not scale past a handful of variants; an explicit alphabet+padding value is more
  composable. Source: cppcodec README.
- **Silent whitespace leniency / no `should_ignore` documentation of consequences.**
  cppcodec correctly disables it for RFC 4648 variants, but any variant that enables
  it must document the RFC 4648 §3.3 covert-channel risk. Source: RFC 4648.

## 12. Ideas fitting Mojo

- **Variant-as-type is directly expressible with Mojo generics/`comptime`.** cppcodec
  makes the alphabet a class parameter and the padding policy a `constexpr` method;
  in Mojo the same is an `alias`/parameterized type where `generates_padding` and
  `requires_padding` become `comptime` constants. This matches the direction the
  stdlib already implies but does not yet offer: the buch records that Mojo's
  `base64` package "exposes the standard functions; there is no exposed alphabet
  parameter on these four" (`mojov1/stdlib/base64`).
- **`std::span` ↔ Mojo `Span` is a one-to-one concept.** base64pp's
  `encode(std::span<std::uint8_t const>)` borrows input exactly as Mojo's
  `def b64encode(input_bytes: Span[UInt8]) -> String` does, and Mojo's `Span` adds
  compiler-checked origins ("`Span` is a non-owning view of contiguous data",
  `mojov1/types/collections`). Mojo should keep the borrowed-in / owned-out split.
- **The `Result&` refill overload has already been adopted by Mojo's stdlib** as
  `def b64encode(input_bytes: Span[UInt8], mut result: String)` ("This method
  reserves the necessary capacity. `result` can be a 0 capacity string",
  `mojov1/stdlib/base64`) — the right subset of cppcodec's three-way surface.
- **Use Mojo typed errors where cppcodec uses an exception hierarchy.** A single
  `raises Base64Error` with a discriminant (bad length / bad symbol / bad padding)
  gives exhaustive, allocation-free handling; the buch's error model shows the
  compiler enforcing `raises` on every caller (`mojov1/errors/error-model`). This is
  strictly better than `std::optional` (no reason) and than four exception types
  (too many).
- **Keep the `should_ignore` decision in the signature, not implicit.** cppcodec's
  per-variant `should_ignore(char)` is the compile-time analogue of libsodium's
  runtime `ignore` string; Mojo can expose it as a `comptime` policy so strictness
  is visible at the call site. The Mojo stdlib's current choice — ignore whitespace
  only, reject everything else — is the right default to encode there.
- **`std::bit_cast`'s lesson applies to Mojo's pointer casts.** tobiaslocker's
  comment on avoiding type punning maps onto Mojo's explicit
  `unsafe_bitcast`/`unsafe_ptr` split: the safe path should never require punning.
  Sources: tobiaslocker header, `mojov1/interop/calling-c`.
- **cppcodec's `decoded_max_size`/`encoded_size` as `constexpr` functions translate
  to Mojo `comptime`-callable pure functions**, which is exactly the improvement over
  C's `dlen = 0` size-query protocol noted in `c.md`. Source: `detail/codec.hpp`.
- **Beast's `pair<written, read>` decode result is worth keeping** if Mojo ever
  exposes a resumable decoder: it is the minimal interface for "decode from a stream
  where more bytes may follow". Source: Beast `base64.hpp`.

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
- cppcodec `cppcodec/detail/stream_codec.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/stream_codec.hpp>
- cppcodec `cppcodec/detail/base64.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/detail/base64.hpp>
- cppcodec `cppcodec/base64_rfc4648.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base64_rfc4648.hpp>
- cppcodec `cppcodec/base64_url.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base64_url.hpp>
- cppcodec `cppcodec/base64_url_unpadded.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/base64_url_unpadded.hpp>
- cppcodec `cppcodec/parse_error.hpp`:
  <https://raw.githubusercontent.com/tplgy/cppcodec/master/cppcodec/parse_error.hpp>
- Boost.Beast `include/boost/beast/core/detail/base64.hpp`:
  <https://raw.githubusercontent.com/boostorg/beast/develop/include/boost/beast/core/detail/base64.hpp>
- Boost mailing list: Beast will not expose base64 publicly:
  <https://listarchives.boost.org/boost-users/2020/12/90714.php>
- tobiaslocker/base64 header:
  <https://raw.githubusercontent.com/tobiaslocker/base64/master/include/base64.hpp>
- tobiaslocker/base64 LICENSE (MIT):
  <https://raw.githubusercontent.com/tobiaslocker/base64/master/LICENSE>
- base64pp public header:
  <https://raw.githubusercontent.com/matheusgomes28/base64pp/main/base64pp/include/base64pp/base64pp.h>
- base64pp documentation (MIT, `std::span` input):
  <https://matheusgomes28.github.io/base64pp/>
- cpp-base64 LICENSE:
  <https://raw.githubusercontent.com/ReneNyffenegger/cpp-base64/master/LICENSE>
- aklomp/base64 README (streaming C API usable from C++):
  <https://raw.githubusercontent.com/aklomp/base64/master/README.md>
- OpenSSL `crypto/evp/encode.c`:
  <https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/encode.c>
- OpenSSL `EVP_EncodeInit(3ssl)` man page:
  <https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>
- OpenSSL `evp.h`:
  <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>
- `P2592R3` is "Hashing support for std::chrono" (not base64):
  <https://www.mail-archive.com/gcc-bugs@gcc.gnu.org/msg783523.html>
- Mojo `mojov1` buch, `stdlib/base64` (Mojo-side reference for section 12)
- Mojo `mojov1` buch, `stdlib/collections` (`Span`, ownership)
- Mojo `mojov1` buch, `errors/error-model` (`raises`, typed errors)
- Mojo `mojov1` buch, `interop/calling-c` (`unsafe_bitcast`, `unsafe_ptr`)
