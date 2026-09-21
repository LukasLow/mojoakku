# base64 research: C++

Scope: this file answers the standardized 12-question set from `.agents/workflows/NewLibPhase1Research.md` for the `base64` library in C++. Questions 5, 7 and 9 are the base64-adapted ones (buffer ownership, alphabets/padding, streaming) as fixed in `mojoakku/base64/.research/README.md`. RFC 4648 is the shared normative reference: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

## 1. Standard library support

**The C++ standard library provides no base64, base32 or base16 codec.** The authoritative header list at <https://en.cppreference.com/w/cpp/header> contains no `<base64>` header and no such function. The complete text-processing library is: `cctype`, `charconv`, `clocale`, `codecvt`, `cuchar`, `cwchar`, `cwctype`, `format`, `locale`, `regex`, `text_encoding` (source: <https://en.cppreference.com/w/cpp/header>). None of these encodes octets into base64.

Two near-misses worth recording because a reader may expect them:
- `std::codecvt` performs *character-set* conversion, not base-N encoding, and is `deprecated in C++17` / `removed in C++26`. Source: <https://en.cppreference.com/w/cpp/header>.
- `<text_encoding>` (C++26) is described as `Text encoding identifications` — i.e. IANA charset names, not an octet-to-text codec. Source: <https://en.cppreference.com/w/cpp/header>.

Consequence: **base64 in C++ is always a third-party or platform dependency.** The standard-library pieces every implementation builds on are only the string/byte vocabulary: `std::string`, `std::string_view` (C++17), `std::span` (C++20), `std::optional` (C++17), `std::expected` (C++23) and `std::stdexcept` types. All headers/since-versions from <https://en.cppreference.com/w/cpp/header>.

`GUESS:` no source was found for an open WG21 (C++ standard committee) proposal that would add base64 to the standard library. Searches only returned the WG21 mailing indexes (<https://wg21.org/mailing/>, <https://wg21.link/index.txt>); no numbered paper about base64 was located, so **no claim is made either way**, and this should be re-checked in the Phase-2 review if it matters for the API design.

## 2. Relevant community libraries

The C++ base64 space is split into three families: (a) header-only single-purpose codec libraries, (b) large general libraries that carry base64 as one filter, and (c) platform/OS APIs. The table lists the ones worth comparing.

| Library | Kind / language | Maintainer | License | Design centre | Source |
|---|---|---|---|---|---|
| cppcodec | header-only C++11 | tplgy (Topology LP) | MIT | one variant class per codec, compile-time alphabet, one shared API | <https://github.com/tplgy/cppcodec> |
| libbase64 | C99 + SIMD, linkable object | aklomp | BSD-2-Clause | raw performance, no allocation, stream + wrapper API | <https://github.com/aklomp/base64> |
| OpenSSL EVP / BIO | C library, de-facto platform reference | OpenSSL project | Apache-2.0 | block API + filter-BIO, PEM-flavoured leniency | <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/> |
| Chromium `base/base64.h` | C++ in-tree utility | Chromium authors | BSD-style | strict vs WHATWG-forgiving policy enum, modp_b64/simdutf backends | <https://github.com/chromium/chromium/blob/main/base/base64.h> |
| Abseil `absl/strings/escaping.h` | C++ (Apache) | Google / Abseil | Apache-2.0 | two families: padded standard and unpadded web-safe | <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h> |
| Poco `Base64Encoder/-Decoder` | C++ stream classes | Applied Informatics | BSL-1.0 | iostream integration, line length option | <https://docs.pocoproject.org/current/Poco.Base64Encoder.html>, <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h> |
| Crypto++ `base64.h` | C++ filter classes | Wei Dai et al. | public domain | filter graph + late-bound parameters (alphabet, padding, line breaks) | <https://github.com/weidai11/cryptopp/blob/master/base64.h> |
| tobi locker `base64` | header-only C++17 | Tobias Locker | (see repo) | modern C++, compile-time decode tables, bit_cast | <https://github.com/tobiaslocker/base64> |
| base64pp | C++20 header+source | Matheus Gomes | MIT | value semantics, `std::span` input, `std::optional` output | <https://github.com/matheusgomes28/base64pp>, <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h> |
| Boost.Beast `detail/base64` | header+ipp, **detail** | Boostorg / Vinnie Falco | Boost Software License 1.0 | private helpers for Beast, ported from Rene Nyffenegger | <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp> |
| Windows `CryptBinaryToString` | OS API (C) | Microsoft | OS API | flag-driven formats incl. PEM headers, two-call sizing | <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa> |

Maturity signals that came from the sources:
- cppcodec: `697 stars`, `124 forks`, `134 Commits`; self-description `Header-only C++11 library to encode/decode base64, base64url, base32, base32hex and hex (a.k.a. base16) as specified in RFC 4648, plus Crockford base32. MIT licensed with consistent, flexible API.` Its stated trade-off: `On release builds, depending on the C++ compiler, cppcodec runs in between (approx.) 100% and 300% of time compared to regular optimized base64 implementations`, and `Debug builds of cppcodec are slower by an order of magnitude due to the use of templates and abstractions`. Source: <https://github.com/tplgy/cppcodec>.
- libbase64: `1k` stars, `178` forks, `370 Commits`; `This library aims to be: FAST; easy to use; elegant.`; `Does not dynamically allocate memory`; `Re-entrant and threadsafe`. Source: <https://github.com/aklomp/base64>.
- OpenSSL is the C ecosystem reference that the base64 concept entry-point in `.research/README.md` names: `no stdlib codec; OpenSSL/glibc ecosystem is the de-facto reference for C` (`mojoakku/base64/.research/README.md:15`).
- `Boost.Beast`'s base64 lives in `boost::beast::detail` and is therefore **not public API** — its header declares the functions inside `namespace detail`. Source: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>.
- libb64 (<https://libb64.sourceforge.net/>, `a library of ANSI C routines ... C++ wrappers are included`) appeared in search results but was **not fetched**; no claim is made about it beyond its own one-line description.

## 3. Exposed APIs

### 3.1 cppcodec (header-only C++11)

The API is **one template, instantiated once per codec variant**. `cppcodec::base64_rfc4648`, `base64_url`, `base64_url_unpadded`, `base32_rfc4648`, `base32_crockford`, `base32_hex`, `hex_upper`, `hex_lower` are type aliases of `detail::codec<detail::base64<variant>>`. Source: <https://github.com/tplgy/cppcodec>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>.

The full surface, verbatim from the README (replace `<codec>` by an alias like `base64`):

```cpp
// Encoding
std::string <codec>::encode(const [uint8_t|char]* binary, size_t binary_size);
std::string <codec>::encode(const T& binary);
Result  <codec>::encode<Result>(const [uint8_t|char]* binary, size_t binary_size);
Result  <codec>::encode<Result>(const T& binary);
void    <codec>::encode(Result& encoded_result, const T& binary);
size_t  <codec>::encode(char* encoded_result, size_t encoded_buffer_size,
                        const [uint8_t|char]* binary, size_t binary_size) noexcept;

// Decoding
std::vector<uint8_t> <codec>::decode(const char* encoded, size_t encoded_size);
std::vector<uint8_t> <codec>::decode(const T& encoded);
Result <codec>::decode<Result>(const char* encoded, size_t encoded_size);
void   <codec>::decode(Result& binary_result, const char* encoded, size_t encoded_size);
size_t <codec>::decode([uint8_t|char]* binary_result, size_t binary_buffer_size,
                       const char* encoded, size_t encoded_size);

// Sizing
size_t <codec>::encoded_size(size_t binary_size) noexcept;
size_t <codec>::decoded_max_size(size_t encoded_size) noexcept;
```
Source: <https://github.com/tplgy/cppcodec> (README, API section).

Documented behaviours from the same source, important for API design:
- `Won't throw by itself, but the result type might throw on .resize()` (encode into a container).
- Buffer form: `Calls abort() if encoded_buffer_size is insufficient. (That way, the function can remain noexcept rather than throwing on an entirely avoidable error condition.)`
- Decode throws `cppcodec::parse_error` (`inheriting from std::domain_error`) on non-conforming input.
- `encoded_size()` is *exact* (`excluding null termination but including padding`), `decoded_max_size()` is an *upper bound*: `If the codec variant allows padding or whitespace / line breaks, the actual decoded size might be smaller.`
- `T` needs `.data()`/`.size()`; `Result` additionally `.reserve(size_t)`, `.resize(size_t)`, `.push_back([uint8_t|char])`.

Variant-level compile-time flags (each variant class implements these; they are what makes the shared template work) — from `base64_rfc4648.hpp`: `alphabet_size()`, `symbol(idx)`, `normalized_symbol(c)`, `generates_padding()`, `requires_padding()`, `padding_symbol()`, `is_padding_symbol(c)`, `is_eof_symbol(c)`, `should_ignore(c)`. All are `static CPPCODEC_ALWAYS_INLINE constexpr`. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>.

Padding is **compile-time constant per variant**, and `base64_url_unpadded` is defined purely by overriding two flags on top of `base64_url`:
```cpp
class base64_url_unpadded : public base64_url {
    static constexpr bool generates_padding() { return false; }
    static constexpr bool requires_padding()  { return false; }
};
```
Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>.

### 3.2 libbase64 (aklomp)

C API, pointer+length strings (deliberate: `Strings are represented as a pointer and a length; they are not zero-terminated. This was a conscious design decision.`):
```c
void base64_encode(const char *src, size_t srclen, char *out, size_t *outlen, int flags);
void base64_stream_encode_init(struct base64_state *state, int flags);
void base64_stream_encode(struct base64_state *state, const char *src, size_t srclen,
                          char *out, size_t *outlen);
void base64_stream_encode_final(struct base64_state *state, char *out, size_t *outlen);

int  base64_decode(const char *src, size_t srclen, char *out, size_t *outlen, int flags);
void base64_stream_decode_init(struct base64_state *state, int flags);
int  base64_stream_decode(struct base64_state *state, const char *src, size_t srclen,
                          char *out, size_t *outlen);
```
Sources: <https://github.com/aklomp/base64>, <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.

`struct base64_state { int eof; int bytes; int flags; unsigned char carry; }` — the whole streaming state is four integers, and the leftover byte is `carry`. Source: <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.

`flags` are **codec-forcing constants for tests**, not alphabet selection: `BASE64_FORCE_AVX2`, `BASE64_FORCE_AVX512`, `BASE64_FORCE_NEON32`, `BASE64_FORCE_NEON64`, `BASE64_FORCE_PLAIN`, `BASE64_FORCE_SSSE3`, `BASE64_FORCE_SSE41`, `BASE64_FORCE_SSE42`, `BASE64_FORCE_AVX`; docs: `Mainly there for testing purposes, this is also useful on ARM where the only way to do runtime NEON detection is to ask the OS if it's available.` Source: <https://github.com/aklomp/base64>.

### 3.3 OpenSSL (C)

Block API (one-shot) and context API (streaming), from `doc/man3/EVP_EncodeInit.pod`:
```c
EVP_ENCODE_CTX *EVP_ENCODE_CTX_new(void);
void EVP_ENCODE_CTX_free(EVP_ENCODE_CTX *ctx);
int  EVP_ENCODE_CTX_copy(EVP_ENCODE_CTX *dctx, EVP_ENCODE_CTX *sctx);
int  EVP_ENCODE_CTX_num(EVP_ENCODE_CTX *ctx);
void EVP_EncodeInit(EVP_ENCODE_CTX *ctx);
int  EVP_EncodeUpdate(EVP_ENCODE_CTX *ctx, unsigned char *out, int *outl,
                      const unsigned char *in, int inl);
void EVP_EncodeFinal(EVP_ENCODE_CTX *ctx, unsigned char *out, int *outl);
int  EVP_EncodeBlock(unsigned char *t, const unsigned char *f, int n);

void EVP_DecodeInit(EVP_ENCODE_CTX *ctx);
int  EVP_DecodeUpdate(EVP_ENCODE_CTX *ctx, unsigned char *out, int *outl,
                      const unsigned char *in, int inl);
int  EVP_DecodeFinal(EVP_ENCODE_CTX *ctx, unsigned char *out, int *outl);
int  EVP_DecodeBlock(unsigned char *t, const unsigned char *f, int n);
```
Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.

Filter API (BIO): `const BIO_METHOD *BIO_f_base64(void);` — `a filter BIO that base64 encodes any data written through it and decodes any data read through it`, with the flag `BIO_FLAGS_BASE64_NO_NL` to switch line-wrapping off. Source: <https://docs.openssl.org/3.5/man3/BIO_f_base64/>.

### 3.4 Chromium `base/base64.h`

```cpp
std::string Base64Encode(span<const uint8_t> input);
void        Base64EncodeAppend(span<const uint8_t> input, std::string* output);
std::string Base64Encode(std::string_view input);
std::string Base64EncodeEarlyStartup(span<const uint8_t> input);

enum class Base64DecodePolicy { kStrict, kForgiving };
bool Base64Decode(std::string_view input, std::string* output,
                  Base64DecodePolicy policy = Base64DecodePolicy::kStrict);
std::optional<std::vector<uint8_t>> Base64Decode(std::string_view input);
```
Source: <https://github.com/chromium/chromium/blob/main/base/base64.h>.

### 3.5 Abseil (`absl/strings/escaping.h`)

```cpp
std::string Base64Escape(absl::string_view src);                       // RFC 4648 §4 + RFC 2045, padded
std::string WebSafeBase64Escape(absl::string_view src);                // RFC 4648 §5, '-'/'_', unpadded
bool Base64Unescape(absl::string_view src, std::string* dest);
bool WebSafeBase64Unescape(absl::string_view src, std::string* dest);
// adjacent: BytesToHexString(), HexStringToBytes(), CEscape/CHexEscape, UrlEscape/UrlUnescape
```
The header also documents RFC alignment explicitly: `This function conforms with RFC 4648 section 4 (base64) and RFC 2045` and `... RFC 4648 section 5 (base64url)`. Source: <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>.

### 3.6 Poco (streams)

```cpp
enum Base64EncodingOptions {
    BASE64_URL_ENCODING = 0x01,
    BASE64_NO_PADDING   = 0x02
};
class Base64Encoder : public Base64EncoderIOS, public std::ostream;
class Base64Decoder : public Base64DecoderIOS, public std::istream;
// Base64EncoderBuf also exposes setLineLength(int), getLineLength(), close()
Base64Encoder(std::ostream& ostr, int options = 0);
Base64Decoder(std::istream& istr, int options = 0);
```
`BASE64_URL_ENCODING` is documented as `Use the URL and filename-safe alphabet, replacing '+' with '-' and '/' with '_'. Will also set line length to unlimited.` Sources: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>, <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Decoder.h>.

### 3.7 Crypto++

Four filter classes: `Base64Encoder`, `Base64Decoder`, `Base64URLEncoder`, `Base64URLDecoder`, all attached to a `BufferedTransformation`. Configuration is late-bound via `IsolatedInitialize(NameValuePairs)`: `AlgorithmParameters params = MakeParameters(Pad(), false)(InsertLineBreaks(), false); encoder.IsolatedInitialize(params);`. `Base64Encoder`'s constructor takes `(BufferedTransformation *attachment = NULLPTR, bool insertLineBreaks = true, int maxLineLength = 72)` — note the surprise defaults `insertLineBreaks = true` and `maxLineLength = 72`. The URL classes deliberately hard-disable padding and line breaks. A custom alphabet is set by swapping the lookup array (`Name::EncodingLookupArray`). Source: <https://github.com/weidai11/cryptopp/blob/master/base64.h>.

### 3.8 tobi locker `base64` (header-only C++17)

```cpp
std::string to_base64(std::string_view data);
std::string from_base64(std::string_view data);
template <class OutputBuffer, class InputIterator> OutputBuffer encode_into(InputIterator begin, InputIterator end);
template <class OutputBuffer> OutputBuffer encode_into(std::string_view data);
template <class OutputBuffer> OutputBuffer decode_into(std::string_view base64Text);
```
Source: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>. Implementation notes from the source: four `constexpr` decode tables and two `constexpr` encode tables, `bad_char{0x01FFFFFF}` sentinel, `padding_char{'='}`, endianness handled by separate table sets (`#error "UNKNOWN Platform / endianness..."` if unknown), `std::bit_cast` used for type punning when available with a `memcpy` fallback. Source: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>.

### 3.9 base64pp (C++20)

```cpp
std::string encode(std::span<std::uint8_t const> input);
std::string encode_str(std::string_view input);
std::optional<std::vector<std::uint8_t>> decode(std::string_view encoded_str);
```
Documented contract, verbatim: `Decodes a base64 encoded string, returning an optional blob. If the decoding fails, it returns std::nullopt` and `this function accepts unpadded strings, if they are valid otherwise. It rejects odd-sized unpadded strings.` Source: <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>.

### 3.10 Boost.Beast (detail namespace)

```cpp
char const* get_alphabet();
signed char const* get_inverse();
std::size_t constexpr encoded_size(std::size_t n) { return 4 * ((n + 2) / 3); }
std::size_t constexpr decoded_size(std::size_t n) { return n / 4 * 3; }
std::size_t encode(void* dest, void const* src, std::size_t len);
std::pair<std::size_t, std::size_t> decode(void* dest, char const* src, std::size_t len);
```
Explicitly documented precondition: `The memory pointed to by out points to valid memory of at least encoded_size(len) bytes`, and for decode `at least decoded_size(len) bytes`. `decode` returns `the number of octets written to out, and the number of characters read from the input string, expressed as a pair`. Sources: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>.

### 3.11 Windows `CryptBinaryToString`

```c
BOOL CryptBinaryToStringA(const BYTE *pbBinary, DWORD cbBinary, DWORD dwFlags,
                          LPSTR pszString, DWORD *pcchString);
```
Format flags: `CRYPT_STRING_BASE64HEADER` (0x0, `Base64, with certificate beginning and ending headers`), `CRYPT_STRING_BASE64` (0x1, `Base64, without headers`), `CRYPT_STRING_BASE64REQUESTHEADER`, `CRYPT_STRING_BASE64X509CRLHEADER`, `CRYPT_STRING_BASE64URI` (`0x0000000d`, `Base64, without headers, with "+" replaced by "-" and "/" replaced by "_" as defined in RFC 4648 Section 5`), plus `CRYPT_STRING_NOCRLF`/`CRYPT_STRING_NOCR` line-ending modifiers and `CRYPT_STRING_STRICT`. Two-call sizing: with `pszString = NULL` the function computes the required length including the terminating NULL. Source: <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>.

### 3.12 Shared shapes across all of the above

- Every library exposes `encode`/`decode` **or** an encoder/decoder **object**; none mixes the two in one entry point.
- All pointer-based APIs need a matching **size-query function** (`encoded_size`, `decoded_max_size`, `encoded_size(n)`, `modp_b64_decode_len`, or the NULL-probe of `CryptBinaryToString`).
- Only cppcodec makes padding a **compile-time** property of the codec type; Poco/Chromium/Abseil/OpenSSL make it a **runtime option or a separate function**; Crypto++ makes it a **parameter**.

## 4. Error representation

C++ has no single error idiom; base64 libraries split almost perfectly into three camps, and that split is the most interesting single observation in this section.

### 4.1 Exceptions (cppcodec, tobi locker)

cppcodec defines a small exception hierarchy in `cppcodec/parse_error.hpp`:
- `class parse_error : public std::domain_error` — the base for all malformed-input failures.
- `class symbol_error : public parse_error` — carries the offending character and is explicitly allocation-free: `Avoids memory allocation, so it can be used in constexpr functions.` Its message is built without `<sstream>`: `The only thing we want from them really is a char-to-string conversion.` It exposes `char symbol() const noexcept`.
- `class invalid_input_length : public parse_error` — used for tail-length errors (e.g. the base64 tail decoder throws `invalid_input_length("invalid number of symbols in last base64 block: found 1, expected 2 or 3")`).
- `class padding_error : public invalid_input_length` — message: `parse error: codec expects padded input string but padding was invalid`.
Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/parse_error.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/base64.hpp>.

tobi locker's header throws plain `std::runtime_error` with three distinct messages: `Invalid base64 encoded data - Size not divisible by 4`, `Invalid base64 encoded data - Found more than 2 padding signs`, `Invalid base64 encoded data - Invalid character` (thrown from the `temp >= detail::bad_char` sentinel check). Source: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>.

### 4.2 `bool` + out-parameter (Abseil, Chromium, OpenSSL)

- Abseil: `bool Base64Unescape(...)`, with the contract `If src contains invalid characters, dest is cleared and returns false. If padding is included ... it must be correct.` Source: <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>.
- Chromium: `bool Base64Decode(...)` with the state contract `Returns true if successful and false otherwise. The output string is only modified if successful. The decoding can be done in-place.`, plus an optional-returning overload: `Returns std::nullopt if unsuccessful.` Source: <https://github.com/chromium/chromium/blob/main/base/base64.h>.
- OpenSSL: integer tri-state — `EVP_DecodeUpdate` returns `-1` on error and `0` or `1` on success; `EVP_DecodeFinal() returns -1 on error or 1 on success`; `EVP_DecodeBlock() returns the length of the data decoded or -1 on error`. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.

### 4.3 Sentinel return / status code (libbase64)

`base64_decode` `Returns 1 for success, and 0 when a decode error has occurred due to invalid input. Returns -1 if the chosen codec is not included in the current build.` `base64_stream_decode` similarly `Returns 1 if all is well, and 0 if a decoding error was found, such as an invalid character. Returns -1 if the chosen codec is not included in the current build.` Source: <https://github.com/aklomp/base64>.

### 4.4 `std::optional` (base64pp, Chromium overload)

`std::optional<std::vector<std::uint8_t>> decode(std::string_view encoded_str)` — `If the decoding fails, it returns std::nullopt`. Sources: <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>, <https://github.com/chromium/chromium/blob/main/base/base64.h>.

### 4.5 The C++23 vocabulary type

`std::expected<T, E>` (`<expected>`, C++23) `provides a way to represent either of two values: an expected value of type T, or an unexpected value of type E. expected is never valueless.` It has `has_value()`, `value()` (`num.value() would throw std::bad_expected_access`), `error()`, `value_or()`, `error_or()` and the monadic operations `and_then`, `transform`, `or_else`, `transform_error`. Feature-test macro `__cpp_lib_expected` = `202202L`. Its `error_type` must be `Destructible`. Source: <https://en.cppreference.com/w/cpp/utility/expected>.

**No base64 library reviewed here uses `std::expected`** — base64pp (C++20) predates it, Chromium uses `bool`+out-param for historical reasons, and the header-only libraries use exceptions. The one codec-adjacent C++ idiom that *does* carry structured failure is Boost.Beast's `decode`, which returns `std::pair<std::size_t, std::size_t>` = (bytes written, characters read) and breaks on the first invalid symbol (the loop is `while(len-- && *in != '=') { auto const v = inverse[*in]; if(v == -1) break; ... }`). Source: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>.

### 4.6 Error-position reporting

Only two of the reviewed implementations expose *where* decoding failed:
- OpenSSL documents that an error means `EVP_DecodeUpdate() returns -1`, but exposes no offset. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- cppcodec reports the offending **symbol** (`symbol_error::symbol()`), not an offset. Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/parse_error.hpp>.
- Beast reports the **count of characters consumed** before failure, which is the closest thing to an offset in the whole set. Source: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>.

A numeric byte-offset error type does **not** appear in any C++ base64 API reviewed here. That is a gap, not a design choice backed by a source.

## 5. Ownership semantics (adapted Q5: buffer/ownership of encode input and output)

The C++ idiom is universal and simple: **the caller owns both buffers; the library never owns memory unless the signature returns a container by value.**

### 5.1 Returning containers vs. writing into caller storage

Every library offers both shapes, and cppcodec's README is the clearest statement:
- `std::string encode(const T& binary)` / `Result encode<Result>(const T& binary)` — allocate a new result, return by value (RVO/move).
- `void encode(Result& encoded_result, const T& binary)` — `Reused result container version. Resizes encoded_result before writing to it.`
- `size_t encode(char* encoded_result, size_t encoded_buffer_size, ...) noexcept` — raw buffer, **caller must size it**, `Calls abort()` if too small.
Sources: <https://github.com/tplgy/cppcodec>.

libbase64 takes only the raw-buffer form and states the buffer rule per function: encode output `must be at least 4/3 the size of the in-buffer, but take some margin`, decode output `must be at least 3/4 the size of the in-buffer, but take some margin`. Source: <https://github.com/aklomp/base64>.

Beast is the strictest — the size contract is a documented **precondition**, not a checked error: `Requires: The memory pointed to by out points to valid memory of at least encoded_size(len) bytes.` Source: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>.

### 5.2 Input is always read-only

No C++ base64 API in this review consumes or mutates its input buffer. Signatures use `const T&`, `absl::string_view`, `std::string_view`, `std::span<std::uint8_t const>`, or `const char*`/`const unsigned char*`. Chromium's decode is explicit that in-place is *allowed but optional*: `The decoding can be done in-place.` Source: <https://github.com/chromium/chromium/blob/main/base/base64.h>.

### 5.3 Non-owning views are the modern default

- Abseil: `absl::string_view` `points to a contiguous span of characters ... provides a read-only view of its associated string data`; `string_view objects are very lightweight, so you should always pass them by value within your methods and functions; don't pass a const absl::string_view &`. The guide also names the lifetime hazard: `Due to lifetime issues, a string_view is usually a poor choice for a return value and almost always a poor choice for a data member.` Source: <https://abseil.io/docs/cpp/guides/strings>.
- base64pp takes `std::span<std::uint8_t const>` (`Supports std::span<std::uint8_t>, meaning you can encode any blob of data`). Source: <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>.

### 5.4 Streaming state is caller-allocated too

libbase64's `struct base64_state` is a plain struct the caller declares (often on the stack); the leftover input is stored **inside it** as `unsigned char carry`, so cross-call state ownership stays with the caller. Source: <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.

OpenSSL is the counter-example: `EVP_ENCODE_CTX_new() allocates, initializes and returns a context`, and `EVP_ENCODE_CTX_free() cleans up an encode/decode context ctx and frees up the space allocated to it. If the argument is NULL, nothing is done.` This is heap-owned handle state with an explicit free — in C++ this is what RAII wrappers exist to hide. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.

### 5.5 Streams own their wrapped stream by reference, not by value

Poco: `Base64Encoder(std::ostream& ostr, int options = 0)` — the encoder borrows the ostream. Its Base64EncoderBuf holds `std::streambuf& _buf;` (a reference, from the header) and documents the consequence: `The characters are directly written to the ostream's streambuf, thus bypassing the ostream. The ostream's state is therefore not updated to match the buffer's state.` Sources: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>, <https://docs.pocoproject.org/current/Poco.Base64Encoder.html>.

Crypto++ likewise attaches to a `BufferedTransformation *attachment` instead of owning data. Source: <https://github.com/weidai11/cryptopp/blob/master/base64.h>.

### 5.6 Lifetime of derived values

- `Alphabet`-style configuration is a compile-time value in cppcodec: alphabet arrays are `static constexpr const char base64_rfc4648_alphabet[] = {...}` and `alphabet_size()` `static_assert(sizeof(base64_rfc4648_alphabet) == 64, "base64 alphabet must have 64 values")`. Nothing to own, nothing to free. Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>.
- Lookup tables are `static constexpr` inside function scope in cppcodec (`static constexpr const auto t = make_lookup_table<num_possible_symbols>(&index_at);`), i.e. one immortal table per codec variant. Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/stream_codec.hpp>.
- tobi locker's tables are namespace-scope `std::array<...> constexpr` with `inline constexpr size_t decidx0{0};` index selectors to paper over endianness (`// TODO fix decoding tables to avoid the need for different indices in big endian?`). Source: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>.

### 5.7 Ownership summary

| Question | Answer across the reviewed C++ libraries |
|---|---|
| Who owns the input buffer? | The caller, always; input is `const` / a view. |
| Who owns the output buffer? | The caller in every raw-pointer/buffer API; the return value in the by-value container APIs. |
| Who frees what? | Nothing is freed by the codec except OpenSSL's `EVP_ENCODE_CTX_free` for the heap context; Beast `decode` allocates nothing at all. |
| Is there hidden allocation? | Only when a by-value container is returned, or when `Base64EncodeAppend` resizes a caller string. |

## 6. Blocking / non-blocking

- **Every reviewed C++ base64 implementation is synchronous and blocking.** Encoding and decoding are pure CPU work; there is no coroutine, future, async or non-blocking variant in any of the fifteen-odd APIs examined. Nothing in the fetched sources mentions threads, `std::future`, `std::coroutine` or an event loop.
- **Concurrency is purely a property of the caller.** libbase64 states `Re-entrant and threadsafe` as a feature; the state object is passed in per call, so two threads just use two states. Source: <https://github.com/aklomp/base64>.
- **The only place "blocking" could arise is the wrapped stream**, and that is out of scope for a codec:
  - Poco's `Base64Encoder` writes through to a borrowed `std::ostream&`, so any blocking is the stream's. Source: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>.
  - OpenSSL's `BIO_f_base64` is a filter over another BIO; the docs even mention retry semantics leaking through — `a negative return value can also occur if the underlying BIO supports retries, see BIO_should_read(3) and BIO_set_mem_eof_return(3)`. Source: <https://docs.openssl.org/3.5/man3/BIO_f_base64/>.
- **Parallelism exists only as internal SIMD/OpenMP**, not as an async API: libbase64 offers `Can use OpenMP for even more parallel speedups` and SIMD codecs (`AVX2, AVX512, NEON, AArch64/NEON, SSSE3, SSE4.1, SSE4.2, AVX`). Its own benchmark table shows the OpenMP effect and its threshold: `lib_openmp.c defines OMP_THRESHOLD 20000, requiring at least a 20000 byte buffer to enable multithreading` and `note the performance degradation when the buffer size is less than 10 kB due to thread creation overhead`. Source: <https://github.com/aklomp/base64>.
- **Runtime CPU dispatch** is the one "dynamic" behaviour worth noting: `On x86, the library does runtime feature detection. The first time it's called, the library will determine the appropriate encoding/decoding routines for the machine. It then remembers them for the lifetime of the program.` and `NEON support can unfortunately not be portably detected at runtime from userland (the mrc instruction is privileged), so the default value for using the NEON codec is determined at compile-time.` Source: <https://github.com/aklomp/base64>.
- Chromium hides backend choice behind a feature flag: `Base64EncodeAppend` dispatches to either `Base64EncodeAppendSimdutf` or `Base64EncodeAppendModpB64` depending on `FeatureList::IsEnabled(features::kSimdutfBase64Encode)`, and there is a `Base64EncodeEarlyStartup` variant `Same as Base64Encode(), but does not access any base::Feature.` Source: <https://github.com/chromium/chromium/blob/main/base/base64.cc>.
- `GUESS:` no source was found for a standard-library or third-party async base64 adapter in C++. The absence is stated as an absence of evidence from the reviewed sources, not as a universal claim; a dedicated async-codec search was not performed.

## 7. Alphabet variants and padding (adapted Q7: standard/URL-safe/others, padding handling)

### 7.1 Alphabets

- RFC 4648 §4 standard alphabet ends with `+` (62) and `/` (63); RFC 4648 §5 URL/filename-safe alphabet uses `-` (62) and `_` (63), `technically identical to the previous one, except for the 62:nd and 63:rd alphabet character`. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.
- RFC 4648 warns not to conflate them: `This encoding should not be regarded as the same as the "base64" encoding and should not be referred to as only "base64".` Source: same RFC, §5.
- cppcodec models each variant as a **type**, not a parameter: `using base64_rfc4648 = detail::codec<detail::base64<detail::base64_rfc4648>>;`, `using base64_url = ...`, `using base64_url_unpadded = ...`, and each carries its own `static constexpr const char <variant>_alphabet[]` plus `symbol()`, `alphabet_size()` and `normalized_symbol(c)`. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url.hpp>.
  cppcodec's `normalized_symbol(c) { return c; }` for both base64 variants is the switch a *case-insensitive* codec would use (base32 variants override this behaviour). Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>.
- Abseil exposes exactly two families: `Base64Escape()` for RFC 4648 §4 `and RFC 2045` (padded), and `WebSafeBase64Escape()` for §5 which `outputs '-' instead of '+' and '_' instead of '/', and does not pad dest`. Sources: <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>.
- Poco makes the alphabet a bit in an options int: `BASE64_URL_ENCODING = 0x01` — `Use the URL and filename-safe alphabet, replacing '+' with '-' and '/' with '_'. Will also set line length to unlimited.` — i.e. choosing URL-safe silently changes a *second* behaviour. Source: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>.
- Crypto++ ships the alphabet as separate classes (`Base64Encoder`/`Base64Decoder` vs `Base64URLEncoder`/`Base64URLDecoder`) **and** allows overriding it at runtime through `Name::EncodingLookupArray` with a raw `const byte ALPHABET[] = "..."`; changing it requires also rebuilding the decode lookup: `If you change the encoding alphabet, then you will need to change the decoding alphabet and the decoder's lookup table.` Source: <https://github.com/weidai11/cryptopp/blob/master/base64.h>.
- Windows exposes the URL alphabet as a format flag: `CRYPT_STRING_BASE64URI` — `Base64, without headers, with "+" replaced by "-" and "/" replaced by "_" as defined in RFC 4648 Section 5`; note that here too URL-safe implies *no headers*, and headers are a separate flag family (`CRYPT_STRING_BASE64HEADER`, `...REQUESTHEADER`, `...X509CRLHEADER`). Source: <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>.
- Chromium's public header exposes **no alphabet choice at all** — only `Base64Encode`/`Base64Decode`. The URL-safe need is handled elsewhere in Chromium (outside this file). Source: <https://github.com/chromium/chromium/blob/main/base/base64.h>.
- Non-RFC alphabets exist but none of the reviewed C++ *base64* libraries ship more than the two RFC alphabets; among the sources fetched here the extra alphabets (bcrypt, crypt, IMAP) appear only in the Rust crate ecosystem, with one cross-language exception outside this file's scope: C's crypt_blowfish owns the `./A-Za-z0-9` bcrypt alphabet (`c.md:29`), though it is not a base64 library. (Observed absence across the reviewed C++ base64 libraries.)

### 7.2 Padding

RFC 4648 §3.2 is explicit: `Implementations MUST include appropriate pad characters at the end of encoded data unless the specification referring to this document explicitly states otherwise.` Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

How each library models it:
- **cppcodec**: two orthogonal compile-time predicates per variant, `generates_padding()` and `requires_padding()`. `base64_rfc4648` has both `true`; `base64_url_unpadded` overrides both to `false`, so its decoder `Decoding accepts either padded or unpadded strings` while its encoder `no padding will be appended`. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>, <https://github.com/tplgy/cppcodec>.
- **Abseil**: padding is a property of the function pair, documented per function: `Base64Escape()` `with padding characters`; `WebSafeBase64Escape()` `does not pad dest`; on the decode side both accept padding but `If padding is included ..., it must be correct`, and — a quirky extra — `In the padding, '=' and '.' are treated identically.` Source: <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>.
- **Poco**: `BASE64_NO_PADDING = 0x02` — `Do not append padding characters ('=') at end.` Source: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>.
- **Crypto++**: padding is a parameter (`MakeParameters(Pad(), false)`), default on for the standard class, hard-off for the URL classes: `The constructor also disables padding on the encoder for the same reason.` Source: <https://github.com/weidai11/cryptopp/blob/master/base64.h>.
- **base64pp**: asymmetrical and deliberately so — the encoder pads, the decoder `accepts unpadded strings, if they are valid otherwise. It rejects odd-sized unpadded strings.` Source: <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>.
- **libbase64**: no padding option at all in the public API; `base64_stream_encode_final` `Adds the required end-of-stream markers if appropriate.` Source: <https://github.com/aklomp/base64>.
- **OpenSSL**: padding is implicit in the format (`If the input data length is not a multiple of 3 then the output data will be padded at the end using the "=" character`); the decode side documents a sharp edge — `Padding bytes (=) (even if internal) are decoded to 6 zero bits, the caller is responsible for taking trailing padding into account, by ignoring as many bytes at the tail of the returned output.` Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- **Boost.Beast**: padding is unconditional in the encoder (literal `*out++ = '=';` cases) and the decoder stops at padding: the loop is `while(len-- && *in != '=')`. Sources: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>.
- **tobi locker**: encoder always pads; decoder requires `Size not divisible by 4` to be an error (`(base64Text.size() & 3) != 0` throws) and counts trailing `'='` with `std::count(base64Text.rbegin(), base64Text.rbegin() + 4, '=')` — `Found more than 2 padding signs` throws. Sources: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>.

### 7.3 Canonicality / trailing bits

RFC 4648 §3.5: `These pad bits MUST be set to zero by conforming encoders ... If this property do not hold, there is no canonical representation of base-encoded data ... decoders MAY chose to reject an encoding if the pad bits have not been set to zero.` Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

**No reviewed C++ library checks trailing bits.** cppcodec checks only *structure* (`SymbolIndex`/tail-length checks and `padding_error`), Beast computes the tail bytes without validating the unused bits, and tobi locker validates size/padding-count/character range only. This is a concrete difference from the Rust ecosystem (where `decode_allow_trailing_bits` is an explicit config knob) and is a decision point for MojoAkku. (Assessment based on the fetched sources for each library.)

### 7.4 Non-alphabet characters

RFC 4648 §3.3: `Implementations MUST reject the encoded data if it contains characters outside the base alphabet ... unless the specification referring to this document explicitly states otherwise`, with the covert-channel rationale repeated in §12. Sources: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

The C++ ecosystem splits three ways here, and the split is explicit in the docs:
- **Strict**: cppcodec's base64 variants hard-code `// RFC4648 does not specify any whitespace being allowed in base64 encodings.` with `static constexpr bool should_ignore(char) { return false; }`. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url.hpp>.
- **Named permissive mode**: Chromium `enum class Base64DecodePolicy { kStrict, kForgiving }` where `kForgiving` `Matches https://infra.spec.whatwg.org/#forgiving-base64-decode. - Removes all ascii whitespace - Maximum of 2 padding characters - Allows input length not divisible by 4 if no padding chars are added.` Sources: <https://github.com/chromium/chromium/blob/main/base/base64.h>, <https://infra.spec.whatwg.org/#forgiving-base64-decode>. The implementation is performance-driven: `Forgiving mode requires whitespace to be stripped prior to decoding. We don't do that in the above code to ensure that the "happy path" of input without whitespace is as fast as possible. Since whitespace in input will always cause modp_b64_decode to fail, just handle whitespace stripping on failure.` Source: <https://github.com/chromium/chromium/blob/main/base/base64.cc>.
- **Unconditionally lenient**: OpenSSL. `Any whitespace, newline or carriage return characters are ignored.` and `For compatibility with PEM, the - (hyphen) character is treated as a soft end-of-input` — with the honest caveat in the BIO man page: `The hyphen character (-) is treated as an ad hoc soft end-of-input character when it occurs at the start of a base64 group of 4 encoded characters. This heuristic works to detect the ends of base64 blocks in PEM or multi-part MIME ... But it is just a heuristic, and sufficiently unusual input could produce unexpected results.` Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/>.
- **MIME-flavoured leniency is a *mode*, not the default, in Chromium; it is the *only* mode in OpenSSL.** That contrast is directly relevant to a low-surprise API: strict as default, leniency as an explicit, named choice.

## 8. Timeouts

Not applicable in the literal sense: base64 encode/decode is pure computation and **none of the reviewed C++ libraries exposes a timeout, deadline, cancellation token or interrupt parameter.** There is no blocking resource of its own to time out.

Closest analogues, for completeness:

- **The only timeout-able resource is a wrapped stream.** Poco's encoder/decoder borrow an `std::ostream`/`std::istream`; OpenSSL's `BIO_f_base64` filters another BIO. Any deadline belongs to those layers. OpenSSL is the only one that even mentions retry semantics: `a negative return value can also occur if the underlying BIO supports retries, see BIO_should_read(3) and BIO_set_mem_eof_return(3)`. Sources: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/>.
- **Bounded work is expressed as buffer sizing, not as time.** Every API makes the caller pre-compute capacity (`encoded_size`, `decoded_max_size`, `encoded_size(n)`/`decoded_size(n)`, `modp_b64_decode_len`, or the `pszString = NULL` probe of `CryptBinaryToString`), which is how a caller bounds resource use. Sources: <https://github.com/tplgy/cppcodec>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>, <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>.
- **The streaming APIs have a completion step, not a cancel step.** libbase64: `base64_stream_encode_final(...)` `Finalizes the output begun by previous calls to base64_stream_encode(). Adds the required end-of-stream markers if appropriate.` OpenSSL: `EVP_EncodeFinal() must be called at the end of an encoding operation.` and `EVP_DecodeFinal() should be called at the end of a decoding operation, but it will never decode additional data.` Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- **State-inspection helpers exist as a proxy for progress**: OpenSSL `EVP_ENCODE_CTX_num() will return the number of as yet unprocessed bytes still to be encoded or decoded that are pending in the ctx object.` Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- **Failure modes for programming errors are abort/UB, not exceptions**: cppcodec's buffer form `Calls abort()`; Beast's too-small buffer is a violated *Requires* precondition (undefined behaviour); Chromium asserts sizing (`CHECK_LE(input.size(), MODP_B64_MAX_INPUT_LEN)` and `CHECK_EQ(written_size, write.size())`). Sources: <https://github.com/tplgy/cppcodec>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>, <https://github.com/chromium/chromium/blob/main/base/base64.cc>.
- `GUESS:` no source was found stating that a timeout/cancellation surface is planned for any of these libraries. The absence is reported as an observed absence in the reviewed sources.

## 9. Streaming (adapted Q9: incremental/chunked encode/decode with leftover bytes)

### 9.1 The three streaming designs in C++

**(a) Explicit state struct + init/update/final — libbase64.** The cleanest and smallest model:
```c
struct base64_state { int eof; int bytes; int flags; unsigned char carry; };
base64_stream_encode_init(&state, 0);
base64_stream_encode(&state, buf, nread, out, &nout);
base64_stream_encode_final(&state, out, &nout);
```
Leftover handling is documented: `Encodes the block of data of given length at src, into the buffer at out. Caller is responsible for allocating a large enough out-buffer; it must be at least 4/3 the size of the in-buffer, but take some margin. ... Does not zero-terminate or finalize the output.` and the final call `Adds the required end-of-stream markers if appropriate. outlen is modified and will contain the number of new bytes written at out (which will quite often be zero).` The leftover itself lives in the caller-owned `carry` field. Sources: <https://github.com/aklomp/base64>, <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.

**(b) Allocating context with an internal buffer — OpenSSL.** `EVP_EncodeUpdate()` `Only full blocks of data (48 bytes) will be immediately processed and output by this function. Any remainder is held in the ctx object and will be processed by a subsequent call to EVP_EncodeUpdate() or EVP_EncodeFinal().` The buffering amount is also documented as queryable: `EVP_ENCODE_CTX_num() will return the number of as yet unprocessed bytes still to be encoded or decoded that are pending in the ctx object.` On the decode side: `Residual input shorter than the internal chunk size will be buffered in ctx if its length is not a multiple of 4 (including any padding), to be processed in future calls to EVP_DecodeUpdate() or EVP_DecodeFinal(). If the final chunk length is a multiple of 4, it is decoded immediately and not buffered.` and `EVP_DecodeFinal() ... If there is residual data, its length is not a multiple of 4, i.e. it was not properly padded, -1 is returned in that case to indicate an error.` Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
   OpenSSL also documents the *unit* of buffering for encode very concretely: `Encoding of binary data is performed in blocks of 48 input bytes (or less for the final block). For each 48 byte input block encoded 64 bytes of base64 data is output plus an additional newline character (i.e. 65 bytes in total). ... Ensure the output buffer contains 65 bytes of storage for each block, plus an additional byte for a NUL terminator.` Source: same.

**(c) Stream wrappers (`std::ostream`/`std::istream` or BIO) — Poco, OpenSSL BIO, Crypto++.** Poco's encoder is an `std::ostream` subclass; the completion step is a named `close()`: `Always call close() when done writing data, to ensure proper completion of the encoding operation.` Sources: <https://docs.pocoproject.org/current/Poco.Base64Encoder.html>, <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>. OpenSSL BIO uses a flush as the finaliser: `BIO_flush() on a base64 BIO that is being written through is used to signal that no more data is to be encoded: this is used to flush the final block through the BIO.` Source: <https://docs.openssl.org/3.5/man3/BIO_f_base64/>. Poco's internal leftover model is visible in the header as three fields: `unsigned char _group[3]; int _groupLength; int _groupIndex;` in `Base64DecoderBuf`. Source: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Decoder.h>.

### 9.2 Leftover-byte semantics

- **Encode**: leftover is `len(input) % 3` bytes between calls. libbase64 stores exactly one `unsigned char carry` plus `int bytes`/`int eof`; OpenSSL holds up to a 48-byte partial block; Poco holds `_group[3]`/`_groupLength`. A finalisation call is *mandatory* in all three to emit the last symbols and the padding.
- **Decode**: leftover is an incomplete group of 4 symbols. cppcodec's *non-streaming* decoder shows the same invariant in miniature with `alphabet_indexes[Codec::encoded_block_size()]` and the comment `We're in here because we just read a (first) padding character. Try to read more. ... store in alphabet_index_ptr so we don't overflow the array in case the input data is too long.` Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/stream_codec.hpp>. OpenSSL's decode side is the same idea with the constraint named explicitly (`must occur after a multiple of 4 valid base64 input bytes`). Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- **No C++ API in this review exposes the leftover count as part of the public state** except OpenSSL's `EVP_ENCODE_CTX_num()`; libbase64's `carry` is public only because the struct is public, and C++ stream buffers hide it entirely.

### 9.3 Line wrapping

Line wrapping is *not* part of RFC 4648's default: `Implementations MUST NOT add line feeds to base-encoded data unless the specification referring to this document explicitly directs base encoders to add line feeds after a specific number of characters.` (§3.1) — and this is why the libraries keep it separate. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

The C++ ecosystem nonetheless has it built in more often than the Rust ecosystem does:
- **OpenSSL writes newlines by default**: `For every 3 bytes of binary data provided 4 bytes of base64 encoded data will be produced plus some occasional newlines`, and `For writing, by default output is divided to lines of length 64 characters and there is a newline at the end of output.` Opt-out via `BIO_FLAGS_BASE64_NO_NL`, which `For writing, ... causes all data to be written on one line without newline at the end.` Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/>.
- **Poco exposes a line-length setter**: `setLineLength(int lineLength)` — `After the given number of characters have been written, a newline character will be written. Specify 0 for an unlimited line length.` and the URL option `Will also set line length to unlimited.` Source: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>.
- **Crypto++ defaults to line breaks with 72 chars**: `Base64Encoder(BufferedTransformation *attachment = NULLPTR, bool insertLineBreaks = true, int maxLineLength = 72)`, configurable via `MakeParameters(Name::InsertLineBreaks(), ...)(Name::MaxLineLength(), ...)`. Source: <https://github.com/weidai11/cryptopp/blob/master/base64.h>.
- **Windows adds CR/LF by default too**: `With the exception of when CRYPT_STRING_BINARY encoding is used, all strings are appended with a new line sequence. By default, the new line sequence is a CR/LF pair (0x0D/0x0A).` Opt-outs are `CRYPT_STRING_NOCR` (LF only) and `CRYPT_STRING_NOCRLF` (none). Source: <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>.
- **The header-only libraries (cppcodec, tobi locker, base64pp, Beast) do not implement wrapping at all**; cppcodec's base64 variants explicitly refuse to ignore whitespace, which in a wrapped-input world is the same as refusing wrapped input. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>, <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>.

### 9.4 cppcodec's compile-time lookup table (relevant to streaming cost)

The decoder's reverse table is generated **at compile time** by recursive templates (`make_lookup_table`, `gen_seq`, `index_if_in_alphabet`), producing `static constexpr const auto t = make_lookup_table<num_possible_symbols>(&index_at);` with a `static_assert(t.size == num_possible_symbols, "lookup table must cover each possible (character) symbol")`. The header records the compiler cost honestly: `Clang up to 3.6 has a limit of 256 for template recursion, so pass a few more symbols at once to make it work`, and `MSVC prior to VS 2017 (for MinSizeRel or Release builds) chokes on this by compiling the project in 20 minutes instead of seconds.` Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/stream_codec.hpp>. **This is the concrete price of moving lookups into the type system.**

## 10. Interesting design decisions

1. **The alphabet is a type, not a parameter (cppcodec).** `using base64_url_unpadded = detail::codec<detail::base64<detail::base64_url_unpadded>>;` — the variant carries `generates_padding()`, `requires_padding()`, `symbol()`, `should_ignore()` as `constexpr` members, so padding, alphabet and whitespace policy are all compile-time and there is one shared implementation. Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>.
2. **Two orthogonal padding predicates beat a preset matrix (cppcodec).** `generates_padding()` (does *encoding* emit `=`?) and `requires_padding()` (does *decoding* demand `=`?) are separate, so "encode unpadded but accept padded" is expressible by mixing them. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>. (Assessment of the design, grounded in the sources.)
3. **Strictness as a named, explicit policy enum (Chromium).** `enum class Base64DecodePolicy { kStrict, kForgiving }` with the default `= Base64DecodePolicy::kStrict`; the forgiving mode binds to a written standard (`Matches https://infra.spec.whatwg.org/#forgiving-base64-decode`). Sources: <https://github.com/chromium/chromium/blob/main/base/base64.h>, <https://infra.spec.whatwg.org/#forgiving-base64-decode>.
4. **"The output string is only modified if successful" (Chromium).** An explicit transactional contract for the out-parameter, unusual among the reviewed libraries and very testable. Source: <https://github.com/chromium/chromium/blob/main/base/base64.h>.
5. **The encoder is allowed to assume the happy path and repair on failure (Chromium).** `We don't do that in the above code to ensure the "happy path" of input without whitespace is as fast as possible. Since whitespace in input will always cause modp_b64_decode to fail, just handle whitespace stripping on failure.` Source: <https://github.com/chromium/chromium/blob/main/base/base64.cc>.
6. **A tiny public state struct instead of an opaque handle (libbase64).** `struct base64_state { int eof; int bytes; int flags; unsigned char carry; }` lets the caller stack-allocate the streaming state and keeps the library allocation-free: `Does not dynamically allocate memory`. Source: <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.
7. **The completion step is explicit and separate from the update step (libbase64, OpenSSL, Poco).** `base64_stream_encode_final`, `EVP_EncodeFinal`, `close()`, `BIO_flush` — four implementations, four names, one idea: a chunked encoder cannot know it is done until told. Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/>.
8. **The decode state of a stream is deliberately undocumented (Poco).** `Note: For performance reasons, the characters are read directly from the given istream's underlying streambuf, so the state of the istream will not reflect that of its streambuf.` Source: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Decoder.h>.
9. **Lookup tables generated by the compiler, cost admitted in comments (cppcodec).** See 9.4. Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/stream_codec.hpp>.
10. **Type-punning hygiene as a feature (tobi locker).** `Use bit_cast instead of union and type punning to avoid undefined behaviour risk` with a `memcpy` fallback for pre-C++20, plus endianness split tables and an `#error` when endianness is unknown. Source: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>.
11. **Two sizes with clearly different meanings.** cppcodec: `encoded_size()` is exact, `decoded_max_size()` is a bound; Beast: `encoded_size` is exact (`4 * ((n + 2) / 3)`), `decoded_size` is documented `n / 4 * 3; // requires n&3==0, smaller`. Sources: <https://github.com/tplgy/cppcodec>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>.
12. **Beast returns a `pair` of (bytes written, characters consumed).** That single return value is the whole failure/pagination signal — no error enum, no exception — at the cost that a caller must inspect the consumed count to notice corruption. Source: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>.

## 11. Decisions NOT to copy

1. **Do not ship line wrapping on by default.** OpenSSL (`by default output is divided to lines of length 64 characters`), Crypto++ (`insertLineBreaks = true, int maxLineLength = 72`) and Windows (`all strings are appended with a new line sequence`) all change the encoded bytes silently unless the caller opts out. RFC 4648 §3.1 says the opposite default is correct: `Implementations MUST NOT add line feeds ... unless the specification referring to this document explicitly directs`. Sources: <https://docs.openssl.org/3.5/man3/BIO_f_base64/>, <https://github.com/weidai11/cryptopp/blob/master/base64.h>, <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>, <https://www.rfc-editor.org/rfc/rfc4648.txt>.
2. **Do not let one option silently change a second behaviour.** Poco's `BASE64_URL_ENCODING` documents `Will also set line length to unlimited.` and Windows' `CRYPT_STRING_BASE64URI` bundles "no headers" with the URL alphabet. One flag = one effect is the predictable rule. Sources: <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>, <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>.
3. **Do not decode padding bytes to zero bits and leave cleanup to the caller.** OpenSSL: `Padding bytes (=) (even if internal) are decoded to 6 zero bits, the caller is responsible for taking trailing padding into account, by ignoring as many bytes at the tail of the returned output.` That pushes a correctness-critical step onto every call site. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
4. **Do not return a success-looking value for a failure.** libbase64's `base64_decode` uses `0` for a decode error and `-1` for "codec not built in", with `1` for success — three states in one `int`, undocumented at the call site. Sources: <https://github.com/aklomp/base64>, <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.
5. **Do not use `abort()` as the reaction to a caller's buffer mistake.** cppcodec: `Calls abort() if encoded_buffer_size is insufficient. (That way, the function can remain noexcept rather than throwing on an entirely avoidable error condition.)` The intent (noexcept, no exception for a programming error) is respectable, but `abort()` is untestable and unhandleable. Source: <https://github.com/tplgy/cppcodec>.
6. **Do not make buffer overrun undefined behaviour in a public API.** Beast's `decode` takes `Requires: ... at least decoded_size(len) bytes` and, when the input is malformed, computes `c3[1]`/`c3[2]` from partially-initialised `c4` before writing; the too-small-buffer case is a precondition, not a returnable error. Sources: <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>.
7. **Do not report only "invalid character" with no position.** tobi locker's single generic `Invalid base64 encoded data - Invalid character` and OpenSSL's bare `-1` both tell the caller nothing about where decoding failed. Sources: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
8. **Do not conflate alphabet selection with whitespace toleration.** RFC 4648 explicitly lists them as different discrepancies (§3.3, §3.4) and warns about the covert channel; `data-encoding`-style separation is the model, not OpenSSL's blanket leniency. Sources: <https://www.rfc-editor.org/rfc/rfc4648.txt>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
9. **Do not require a heap-allocated opaque context for a 4-integer state.** OpenSSL's `EVP_ENCODE_CTX_new`/`EVP_ENCODE_CTX_free` pair is C API gravity; libbase64 proves the alternative (`struct base64_state` with `unsigned char carry`) is sufficient. Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://github.com/aklomp/base64/blob/master/include/libbase64.h>.
10. **Do not push compile-time lookup-table generation to the limits of the compiler.** cppcodec's own comments record template-recursion limits and a 20-minute MSVC compile; that cost is not worth paying for a 64-entry table. Source: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/stream_codec.hpp>.
11. **Do not document "only modified if successful" and then implement it the other way.** Chromium's header promises `The output string is only modified if successful`, while its forgiving path builds `decode_buf` first and assigns at the end — this is a good contract, but it is one a strict implementation must actually enforce for every early-exit path. Source: <https://github.com/chromium/chromium/blob/main/base/base64.h>.
12. **Do not grow the base64 library into base16/base32/Crockford.** cppcodec already does that (`base64, base64url, base32, base32hex and hex ... plus Crockford's base32`) and the extra variants multiply the compile-time surface; MojoAkku's sibling-library rule keeps those in their own libraries. Sources: <https://github.com/tplgy/cppcodec>, `mojoakku/AGENTS.md` (sibling library rule).
13. **Do not offer a runtime-swappable raw alphabet without also deriving the decode table.** Crypto++ requires the caller to do both steps by hand and states so: `If you change the encoding alphabet, then you will need to change the decoding alphabet and the decoder's lookup table.` A half-configured codec is a silent corruption bug. Source: <https://github.com/weidai11/cryptopp/blob/master/base64.h>.
14. **Do not leave endianness to the caller's machine.** tobi locker needs separate decode tables per endianness with `#error "UNKNOWN Platform / endianness. Configure endianness explicitly."`; a byte-oriented implementation avoids the whole class of problem. Source: <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>.
15. **Do not treat trailing-bit canonicality as nobody's problem.** No reviewed C++ library validates it even though RFC 4648 §3.5 says `decoders MAY chose to reject an encoding if the pad bits have not been set to zero` and calls non-canonical encodings a malleability concern. Sources: <https://www.rfc-editor.org/rfc/rfc4648.txt> (and §12 for the security framing); the absence is observed across all C++ sources listed in this file.

## 12. Ideas fitting Mojo

Mojo facts are **not** asserted here; per the project rule they must be looked up in the `mojov1` buch before use — the relevant page is `mojov1/stdlib/base64` (Mojo's own stdlib already has `b64encode`/`b64decode`/`b16encode`/`b16decode`, and they are **unstable by default**: `no @stable(since=...) marker`). Sources: `mojov1/stdlib/base64`; <https://mojolang.org/docs/std/base64/>; <https://mojolang.org/docs/api-docs/stability/>. Everything below is an **assessment** of how C++ properties could map onto Mojo, not a Mojo fact.

1. **Alphabet/padding policy as a compile-time property is the strongest C++ idea here.** cppcodec proves that `generates_padding()`/`requires_padding()`/`should_ignore()` as `constexpr` variant members produce one implementation with no runtime branching. Mojo's compile-time parameterisation (`comptime`/parameterised structs) is the natural counterpart. Source for the C++ half: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>. (Assessment for the Mojo half.)
2. **Keep padding as two orthogonal questions, not four presets.** "does encode pad?" and "does decode require padding?" fully determine the behaviour; Rust and cppcodec independently arrive at the same two axes. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>, <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>. (Assessment.)
3. **Make strictness an explicit, named policy with a strict default.** Chromium's `Base64DecodePolicy::kStrict`/`kForgiving` is the cleanest model seen in C++, and it binds the lenient mode to a citable standard (WHATWG forgiving-base64). Sources: <https://github.com/chromium/chromium/blob/main/base/base64.h>, <https://infra.spec.whatwg.org/#forgiving-base64-decode>. (Assessment.)
4. **Adopt Chromium's transactional output contract.** "The output string is only modified if successful" is a strong, testable guarantee that serves a low-vision/declarative API better than "the buffer is in an unspecified state" (Abseil says `dest is cleared`). Sources: <https://github.com/chromium/chromium/blob/main/base/base64.h>, <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>. (Assessment.)
5. **Expose two sizes with distinct, documented meanings.** `encoded_size(n)` exact vs `decoded_max_size(n)` an upper bound — and never call the second one "length". Sources: <https://github.com/tplgy/cppcodec>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>. (Assessment.)
6. **Small, fully-visible streaming state.** libbase64's four-integer `base64_state` with a named `carry` field is the model: no hidden allocation, the leftover count is inspectable, no opaque handle. OpenSSL's `EVP_ENCODE_CTX_num()` shows the value of a "bytes still pending" query. Sources: <https://github.com/aklomp/base64/blob/master/include/libbase64.h>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>. (Assessment.)
7. **An explicit finish step is non-negotiable.** Four independent C++ implementations (libbase64, OpenSSL, Poco `close()`, BIO `flush`) all need a named finaliser; encoding leftover bytes can never be flushed implicitly. Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://docs.pocoproject.org/current/Poco.Base64Encoder.html>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/>. (Assessment.)
8. **Errors should carry structure — the C++ ecosystem's weak spot.** cppcodec carries the offending `symbol()`; Beast carries the consumed-character count; nothing carries an offset and nothing carries a reason. A Mojo error type with `kind` + `offset` (+ offending byte) would be strictly better than every reviewed C++ API. Sources: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/parse_error.hpp>, <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>. (Assessment.)
9. **Separate `bool`/`optional`-style "value or nothing" from structured errors.** Abseil (`bool` + out-param) and base64pp (`std::optional`) show the C++ split; for Mojo the interesting mapping is error-carrying return types (analogous to `std::expected`) so that "invalid input" and "buffer too small" stay distinguishable. Sources: <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>, <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>, <https://en.cppreference.com/w/cpp/utility/expected>. (Assessment.)
10. **Read-only view inputs, owned outputs.** The whole C++ ecosystem converges on `const` views for input (`string_view`, `span<const uint8_t>`, `const char*`) and caller-owned or by-value outputs; Abseil warns explicitly that a `string_view` must not outlive its data. Mojo's ownership model can express the same split without the lifetime hazard. Sources: <https://abseil.io/docs/cpp/guides/strings>, <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>, <https://github.com/chromium/chromium/blob/main/base/base64.h>. (Assessment.)
11. **Do not inherit the C++ error-reporting diversity.** Exceptions, `bool`+out-param, `int` sentinels, `std::optional`, `std::pair` and `abort()` all appear in this one language. MojoAkku should pick exactly one and document it, because the C++ mess is what makes generic call sites impossible. Sources: sections 4.1-4.4 above. (Assessment.)
12. **Treat line wrapping as a separate, opt-in layer.** The C++ lesson is inverted from Rust's: three of the reviewed libraries wrap by default and RFC 4648 says not to. MojoAkku should follow the RFC default and offer wrapping explicitly. Sources: <https://www.rfc-editor.org/rfc/rfc4648.txt>, <https://docs.openssl.org/3.5/man3/BIO_f_base64/>, <https://github.com/weidai11/cryptopp/blob/master/base64.h>. (Assessment.)

## Sources

Normative standards
- RFC 4648, The Base16, Base32, and Base64 Data Encodings (esp. §3.1 line feeds, §3.2 padding, §3.3 non-alphabet characters, §3.4 alphabet choice, §3.5 canonical encoding, §4/§5 alphabets, §12 security): <https://www.rfc-editor.org/rfc/rfc4648.txt>
- WHATWG Infra Standard, §7 Forgiving base64 (referenced by Chromium's `kForgiving` policy): <https://infra.spec.whatwg.org/#forgiving-base64-decode>

Language and standard-library facts
- C++ standard library header index (evidence there is no `<base64>`; `codecvt` deprecation/removal; `<text_encoding>`): <https://en.cppreference.com/w/cpp/header>
- `std::expected` (C++23): <https://en.cppreference.com/w/cpp/utility/expected>
- WG21 mailing index (used only to establish that no base64 paper was found): <https://wg21.org/mailing/>, <https://wg21.link/index.txt>

cppcodec (header-only C++11, MIT)
- README, API, philosophy/trade-offs, stars/forks/commits: <https://github.com/tplgy/cppcodec>
- `cppcodec/base64_rfc4648.hpp` (alphabet, padding predicates, `should_ignore`): <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_rfc4648.hpp>
- `cppcodec/base64_url.hpp`: <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url.hpp>
- `cppcodec/base64_url_unpadded.hpp` (padding overridden to false): <https://github.com/tplgy/cppcodec/blob/master/cppcodec/base64_url_unpadded.hpp>
- `cppcodec/parse_error.hpp` (`parse_error`/`symbol_error`/`invalid_input_length`/`padding_error`): <https://github.com/tplgy/cppcodec/blob/master/cppcodec/parse_error.hpp>
- `cppcodec/detail/base64.hpp` (tail errors, `index_last`): <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/base64.hpp>
- `cppcodec/detail/stream_codec.hpp` (compile-time lookup tables, padding logic, compiler-cost comments, size functions): <https://github.com/tplgy/cppcodec/blob/master/cppcodec/detail/stream_codec.hpp>

libbase64 / aklomp (C99, BSD-2-Clause)
- README: API reference, flags, streaming, SIMD/OpenMP, benchmarks, license, stars/forks/commits: <https://github.com/aklomp/base64>
- `include/libbase64.h` (`base64_state`, flags, all signatures): <https://github.com/aklomp/base64/blob/master/include/libbase64.h>

OpenSSL (C, Apache-2.0)
- `doc/man3/EVP_EncodeInit.pod` (EVP_* signatures, 48/64-byte block model, residual buffering, `-` soft end-of-input, whitespace ignoring, padding-to-zero-bits caveat, return values): <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>
- `BIO_f_base64` man page (64-char wrapping, `BIO_FLAGS_BASE64_NO_NL`, flush-as-finaliser, hyphen heuristic caveat): <https://docs.openssl.org/3.5/man3/BIO_f_base64/>

Chromium
- `base/base64.h` (policy enum, contracts, optional overload): <https://github.com/chromium/chromium/blob/main/base/base64.h>
- `base/base64.cc` (modp_b64/simdutf dispatch, forgiving-on-failure, CHECKs): <https://github.com/chromium/chromium/blob/main/base/base64.cc>

Abseil
- `absl/strings/escaping.h` (Base64Escape/WebSafeBase64Escape/Unescape contracts, '.' padding quirk): <https://github.com/abseil/abseil-cpp/blob/master/absl/strings/escaping.h>
- Abseil Strings guide (`string_view` semantics and lifetime warnings): <https://abseil.io/docs/cpp/guides/strings>

Poco (BSL-1.0)
- `Base64Encoder` class reference: <https://docs.pocoproject.org/current/Poco.Base64Encoder.html>
- `Foundation/include/Poco/Base64Encoder.h` (options enum, line-length API, streambuf reference): <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Encoder.h>
- `Foundation/include/Poco/Base64Decoder.h` (decoder buffer fields, bypass note): <https://github.com/pocoproject/poco/blob/master/Foundation/include/Poco/Base64Decoder.h>

Crypto++ (public domain)
- `base64.h` (four classes, `IsolatedInitialize`, unexpected defaults, custom alphabet): <https://github.com/weidai11/cryptopp/blob/master/base64.h>

Boost.Beast (Boost Software License 1.0)
- `core/detail/base64.hpp` (signatures, preconditions, size helpers, Nyffenegger attribution): <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.hpp>
- `core/detail/base64.ipp` (tables, encode/decode implementation, padding writes, pair return): <https://github.com/boostorg/beast/blob/develop/include/boost/beast/core/detail/base64.ipp>

tobi locker `base64` (header-only C++17)
- README: <https://github.com/tobiaslocker/base64>
- `include/base64.hpp` (tables, bit_cast, error messages, endianness handling): <https://github.com/tobiaslocker/base64/blob/master/include/base64.hpp>

base64pp (C++20, MIT)
- README: <https://github.com/matheusgomes28/base64pp>
- `base64pp/include/base64pp/base64pp.h` (span/optional API): <https://github.com/matheusgomes28/base64pp/blob/main/base64pp/include/base64pp/base64pp.h>

Windows platform API
- `CryptBinaryToStringA` (format flags incl. `CRYPT_STRING_BASE64URI`, CR/LF defaults, two-call sizing): <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>

Repo-internal references
- `mojoakku/base64/.research/README.md:15` (frozen selection reason for C++)
- `mojoakku/AGENTS.md` (sibling libraries; no implementation before research)
- `mojov1/stdlib/base64` buch page (Mojo's own four functions, unstable by default)

Not fetched / deliberately unclaimed
- libb64: <https://libb64.sourceforge.net/> (appeared in search; not fetched, no claims made)
- Rene Nyffenegger's `cpp-base64`: <https://github.com/ReneNyffenegger/cpp-base64> (listed as Beast's origin; not fetched directly)
- No WG21 paper on base64 was found: `GUESS:` (see §1) — the negative result rests on the WG21 indexes only.
