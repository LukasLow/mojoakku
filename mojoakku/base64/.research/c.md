# base64 research: C

## 1. Standard library support

C has **no standard-library base64/base32/base16 codec**. The ISO C standard
library interface is defined by a fixed header list — `<assert.h>`, `<complex.h>`,
`<ctype.h>`, `<errno.h>`, `<fenv.h>`, `<float.h>`, `<inttypes.h>`, `<iso646.h>`,
`<limits.h>`, `<locale.h>`, `<math.h>`, `<setjmp.h>`, `<signal.h>`, `<stdalign.h>`,
`<stdarg.h>`, `<stdatomic.h>`, `<stdbit.h>`, `<stdbool.h>`, `<stdckdint.h>`,
`<stddef.h>`, `<stdint.h>`, `<stdio.h>`, `<stdlib.h>`, `<stdmchar.h>`,
`<stdnoreturn.h>`, `<string.h>`, `<tgmath.h>`, `<threads.h>`, `<time.h>`,
`<uchar.h>`, `<wchar.h>`, `<wctype.h>` — and none of them covers base-N encoding.
Source: <https://en.cppreference.com/w/c/header>.

C users therefore get their codec from one of four places, all non-standard:

$%$ Provider $%$ Function family $%$ Header $%$
$%$ --- $%$ --- $%$ --- $%$
$%$ OpenSSL / BoringSSL $%$ `EVP_Encode*` / `EVP_Decode*` $%$ `<openssl/evp.h>` $%$
$%$ glibc libresolv $%$ `b64_ntop` / `b64_pton` $%$ `<resolv.h>` (historically) $%$
$%$ BSD libc $%$ `b64_ntop` / `b64_pton` $%$ `<resolv.h>` $%$
$%$ gnulib / coreutils $%$ `base64_encode*` / `base64_decode*` $%$ `"base64.h"` $%$

- OpenSSL exposes the block and streaming entry points in `<openssl/evp.h>`:
  `EVP_ENCODE_CTX_new/free/copy/num`, `EVP_EncodeInit/Update/Final/Block`,
  `EVP_DecodeInit/Update/Final/Block`, and `EVP_ENCODE_LENGTH`/`EVP_DECODE_LENGTH`.
  Sources: <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>,
  <https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>.
- gnulib ships a portable base64 with explicit streaming context: `base64_encode`,
  `base64_encode_alloc`, `base64_decode_ctx_init`, `base64_decode_ctx`,
  `base64_decode_alloc_ctx`, plus macros `base64_decode`/`base64_decode_alloc`,
  and the length macro `BASE64_LENGTH(inlen) ((((inlen) + 2) / 3) * 4)`.
  Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>.
- glibc historically carried `b64_ntop`/`b64_pton` in `resolv/base64.c`
  ("skips all whitespace anywhere", returns -1 on error), but they were never
  public API; a glibc bug asks for them to be exported. Sources:
  <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>,
  <https://sourceware.org/bugzilla/show_bug.cgi?id=14118>.
- libsodium ships base64 `sodium_bin2base64`/`sodium_base642bin` and hex
  `sodium_bin2hex`/`sodium_hex2bin` in `<sodium/utils.h>`; Base32 is absent.
  Sources: <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/utils.h>,
  <https://doc.libsodium.org/helpers>.
- Windows (not ISO C, but the C-family platform API) has
  `CryptBinaryToStringA` (`CRYPT_STRING_BASE64`, `CRYPT_STRING_BASE64URI`,
  `CRYPT_STRING_HEX*`) and `CryptStringToBinaryA`. Sources:
  <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>,
  <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptstringtobinarya>.

Base32 and base16 are even less covered: no ISO C, no OpenSSL `EVP_*` base32; the
coreutils `base32`/`base16` commands exist, but their library entry point is the
gnulib base32 module, which mirrors gnulib's base64 API (GUESS: gnulib's base32.h
was not fetched in this pass; the `base32`/`base16` CLI commands are documented
at <https://www.man7.org/linux/man-pages/man1/base32.1.html>).

## 2. Relevant community libraries

$%$ Library $%$ Maintainer $%$ Maturity $%$ License $%$ Variants $%$
$%$ --- $%$ --- $%$ --- $%$ --- $%$ --- $%$
$%$ OpenSSL $%$ OpenSSL Foundation $%$ ubiquitous, current master $%$ Apache-2.0 $%$ base64 only $%$
$%$ BoringSSL $%$ Google $%$ widely used (Chromium) $%$ ISC-style/OpenSSL $%$ base64 only $%$
$%$ gnulib $%$ GNU/FSF $%$ coreutils dependency $%$ LGPL-2.1-or-later $%$ base64 (+base32 module) $%$
$%$ libsodium $%$ Frank Denis $%$ 1.x, stable $%$ ISC $%$ base64 + hex; no base32 $%$
$%$ libb64 $%$ libb64 project $%$ small, public domain $%$ public domain $%$ base64 only $%$
$%$ aklomp/base64 $%$ Alfred Klomp $%$ active, SIMD-focused $%$ BSD-2-Clause $%$ base64 only $%$
$%$ mbedTLS $%$ TrustedFirmware $%$ LTS crypto library $%$ Apache-2.0 (dual) $%$ base64 only $%$

Sources:
- OpenSSL license "Apache License 2.0":
  <https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/encode.c> (file header).
- BoringSSL base64 header and its explicit note that OpenSSL's streaming base64 is
  "very specific to PEM. It is also very lenient of invalid input. Use of any of
  these functions is thus deprecated":
  <https://raw.githubusercontent.com/google/boringssl/master/include/openssl/base64.h>.
- gnulib license "GNU Lesser General Public License ... version 2.1 or later":
  <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>.
- libsodium ISC license: <https://raw.githubusercontent.com/jedisct1/libsodium/master/LICENSE>.
- libb64 "placed in the public domain":
  <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>.
- aklomp/base64 "BSD 2-clause":
  <https://raw.githubusercontent.com/aklomp/base64/master/README.md>.
- mbedTLS header "SPDX-License-Identifier: Apache-2.0 OR GPL-2.0-or-later":
  <https://raw.githubusercontent.com/Mbed-TLS/mbedtls/master/include/mbedtls/base64.h>.

(Assessment: derived from the sources above: the C ecosystem is split between
*crypto-library* base64 (OpenSSL, BoringSSL, mbedTLS, libsodium), *resolver/legacy*
base64 (`b64_ntop`), *portability/CLI* base64 (gnulib) and *performance* base64
(aklomp, libb64). No single library covers base32+base16 the way cppcodec does for
C++.)

## 3. Exposed APIs

**OpenSSL** (`<openssl/evp.h>`; sources `.../include/openssl/evp.h`,
<https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>):

- One-shot: `int EVP_EncodeBlock(unsigned char *t, const unsigned char *f, int dlen)`
  — "encodes a full block of input data in `f` ... stores it in `t` ... a NUL
  terminator character will be added"; returns bytes written minus NUL. Not
  streaming; always pads to a multiple of 4.
- One-shot decode: `int EVP_DecodeBlock(unsigned char *t, const unsigned char *f, int n)`
  — trims leading/trailing whitespace, requires `n % 4 == 0`, "output will be
  padded with 0 bits if necessary to ensure that the output is always 3 bytes for
  every 4 input bytes", returns decoded length or -1. This means a padded input
  yields **too many** output bytes; callers must subtract padding themselves.
- Streaming context: `EVP_ENCODE_CTX *EVP_ENCODE_CTX_new(void)`, `void EVP_ENCODE_CTX_free(ctx)`,
  `int EVP_ENCODE_CTX_copy(dctx, sctx)`, `int EVP_ENCODE_CTX_num(ctx)`,
  `void EVP_EncodeInit(ctx)`, `int EVP_EncodeUpdate(ctx, out, int *outl, in, int inl)`,
  `void EVP_EncodeFinal(ctx, out, int *outl)`, and the decode mirrors
  `EVP_DecodeInit/Update/Final`.
- Length macros: `EVP_ENCODE_LENGTH(l)` and `EVP_DECODE_LENGTH(l)` (`evp.h`).
- Output wrapping is 64 chars per line by default: "Encoding of binary data is
  performed in blocks of 48 input bytes ... each 48 byte input block encoded 64
  bytes of base 64 data is output plus an additional newline character (i.e. 65
  bytes in total)".
- No alphabet parameter, no URL-safe variant, no base32/hex in `EVP_*`. A second,
  SRP-specific decode alphabet exists internally (flag `EVP_ENCODE_CTX_USE_SRP_ALPHABET`,
  table `srpdata_ascii2bin` in `crypto/evp/encode.c`), not exposed in the public API.

**BoringSSL** (`<openssl/base64.h>`) deliberately slims this down:

- `size_t EVP_EncodeBlock(uint8_t *dst, const uint8_t *src, size_t src_len)` — writes
  a trailing NUL, returns bytes excluding it.
- `int EVP_EncodedLength(size_t *out_len, size_t len)` — size including NUL.
- `int EVP_DecodedLength(size_t *out_len, size_t len)` — maximum decoded size.
- `int EVP_DecodeBase64(uint8_t *out, size_t *out_len, size_t max_out, const uint8_t *in, size_t in_len)`.
- `EVP_EncodeInit/Update/Final`, `EVP_DecodeInit/Update/Final`, `EVP_DecodeBlock`,
  `EVP_ENCODE_CTX_new/free`, plus the (opaque here) `struct evp_encode_ctx_st`
  with `data_used`, `uint8_t data[48]`, `eof_seen`, `error_encountered`.

**gnulib** (`"base64.h"`):

- `void base64_encode(const char *restrict in, idx_t inlen, char *restrict out, idx_t outlen)` —
  "If OUTLEN is less than BASE64_LENGTH(INLEN), write as many bytes as possible.
  If OUTLEN is larger than BASE64_LENGTH(INLEN), also zero terminate the output
  buffer."
- `idx_t base64_encode_alloc(const char *in, idx_t inlen, char **out)` — allocating
  variant, returns length excluding NUL; overflow → `0`/NULL, OOM → NULL + needed size.
- `bool base64_decode_ctx(struct base64_decode_context *ctx, const char *restrict in, idx_t inlen, char *restrict out, idx_t *outlen)` —
  newline-tolerant, streaming; `base64_decode` macro passes `ctx = NULL` so newlines
  become garbage.
- `bool base64_decode_alloc_ctx(...)`; `struct base64_decode_context { int i; char buf[4]; }`.
- `signed char const base64_to_int[256]`, `isbase64`/`isubase64` inline helpers.

**glibc / BSD** (`<resolv.h>`):

- `int b64_ntop(u_char const *src, size_t srclength, char *target, size_t targsize)` —
  returns encoded length (excluding NUL) or -1 when the target is too small.
- `int b64_pton(char const *src, u_char *target, size_t targsize)` — returns decoded
  bytes or -1. Skips whitespace anywhere; accepts `=` only as terminator; rejects
  non-zero trailing bits (the "subliminal channel" check `if (target && target[tarindex] != 0) return -1;`).
  Source: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.

**libsodium** (`<sodium/utils.h>`):

- `char *sodium_bin2base64(char *b64, size_t b64_maxlen, const unsigned char *bin, size_t bin_len, int variant)`.
- `int sodium_base642bin(unsigned char *bin, size_t bin_maxlen, const char *b64, size_t b64_len, const char *ignore, size_t *bin_len, const char **b64_end, int variant)`.
- `size_t sodium_base64_encoded_len(size_t bin_len, int variant)` and the
  `sodium_base64_ENCODED_LEN(BIN_LEN, VARIANT)` macro.
- Hex: `char *sodium_bin2hex(char *hex, size_t hex_maxlen, const unsigned char *bin, size_t bin_len)`,
  `int sodium_hex2bin(bin, bin_maxlen, hex, hex_len, const char *ignore, size_t *bin_len, const char **hex_end)`.
- Variant constants: `sodium_base64_VARIANT_ORIGINAL`, `..._ORIGINAL_NO_PADDING`,
  `..._URLSAFE`, `..._URLSAFE_NO_PADDING` (values 1, 3, 5, 7).

**mbedTLS** (`<mbedtls/base64.h>`):

- `int mbedtls_base64_encode(unsigned char *dst, size_t dlen, size_t *olen, const unsigned char *src, size_t slen)` —
  "Call this function with dlen = 0 to obtain the required buffer size in *olen".
- `int mbedtls_base64_decode(...)` — "Call this function with *dst = NULL or dlen = 0
  to obtain the required buffer size in *olen".
- Errors as negative macros: `MBEDTLS_ERR_BASE64_BUFFER_TOO_SMALL (-0x002A)`,
  `MBEDTLS_ERR_BASE64_INVALID_CHARACTER (-0x002C)`.

**libb64** (`<b64/cencode.h>`, `<b64/cdecode.h>`):

- `void base64_init_encodestate(base64_encodestate*)`,
  `size_t base64_encode_length(size_t plain_len, base64_encodestate*)`,
  `size_t base64_encode_block(const void *plaintext_in, size_t length_in, char *code_out, base64_encodestate*)`,
  `size_t base64_encode_blockend(char *code_out, base64_encodestate*)` — the state
  struct is public and includes `chars_per_line`, i.e. line-wrapping is caller-configurable.
  Decode mirror: `base64_init_decodestate`, `base64_decode_maxlength`,
  `base64_decode_block`, with `base64_decodestate { step; plainchar; }`.

**aklomp/base64** (`<libbase64.h>`): a flat, length-delimited API with explicit
streaming state — `base64_encode(src, srclen, out, size_t *outlen, int flags)`,
`base64_decode(...) -> int`, `base64_stream_encode_init(&state, flags)`,
`base64_stream_encode(&state, src, srclen, out, &outlen)`,
`base64_stream_encode_final(&state, out, &outlen)`, plus decode init/stream.
The `flags` argument selects/forces a codec (`BASE64_FORCE_AVX2`, `..._PLAIN`, etc.).
Source: <https://raw.githubusercontent.com/aklomp/base64/master/README.md>.

**Windows CryptoAPI**: `BOOL CryptBinaryToStringA(pbBinary, cbBinary, dwFlags, pszString, DWORD *pcchString)`
and `BOOL CryptStringToBinaryA(pszString, cchString, dwFlags, pbBinary, DWORD *pcbBinary, pdwSkip, pdwFlags)`.
Flags include `CRYPT_STRING_BASE64`, `CRYPT_STRING_BASE64URI` (RFC 4648 §5 alphabet),
`CRYPT_STRING_HEX`, `CRYPT_STRING_HEXRAW`, `CRYPT_STRING_NOCRLF`, `CRYPT_STRING_STRICT`.

## 4. Error representation

Error signalling across the C family is inconsistent — four distinct styles:

1. **Negative integer return, output size unknown on error** (OpenSSL):
   `EVP_DecodeBlock` "returns the length of the data decoded or -1 on error";
   `EVP_DecodeUpdate` "returns -1 on error and 0 or 1 on success. If 0 is returned
   then no more non-padding base 64 characters are expected";
   `EVP_EncodeUpdate` "returns 0 on error or 1 on success". Source:
   <https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>.
2. **Negative integer return of the same type as the length** (glibc `b64_pton`/`b64_ntop`):
   `-1` is ambiguous with a legitimate length only because lengths are non-negative;
   `b64_ntop` additionally returns -1 for "target too small", conflating *buffer
   too small* and *invalid input*. Source: `glibc/resolv/base64.c`.
3. **`bool` plus an out-parameter length** (gnulib): `base64_decode_ctx` returns
   `true`/`false` and writes the produced length through `size_t *outlen`; the
   allocating variants return `bool` and signal *allocation failure* separately
   via `*out == NULL`, with the needed size still in `*outlen`. Source:
   <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
4. **Dedicated negative error constants** (mbedTLS):
   `MBEDTLS_ERR_BASE64_BUFFER_TOO_SMALL`, `MBEDTLS_ERR_BASE64_INVALID_CHARACTER`;
   `*olen` "is always updated to reflect the amount of data that has (or would
   have) been written". Source: `mbedtls/include/mbedtls/base64.h`.

libsodium uses the POSIX-style `int` 0/-1 split: `sodium_base642bin` "returns 0 on
success", "-1 if more than `bin_maxlen` bytes would be required ... or the string
couldn't be fully parsed". `sodium_bin2base64` returns the buffer pointer (always
non-NULL) instead of a status, so encoding cannot fail except by programming error.
Source: <https://doc.libsodium.org/helpers>.

aklomp/base64 returns **three-state ints** on decode: "Returns `1` for success, and
`0` when a decode error has occured due to invalid input. Returns `-1` if the chosen
codec is not included in the current build." Source: its README.

RFC 4648 §12 makes the security point that drives strictness: a decoder should not
break on invalid input "including, e.g. embedded NUL characters", and ignoring
non-alphabet characters opens a covert channel. Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>.

## 5. Ownership semantics (buffer/ownership of encode input and produced output)

The C rule is uniform and blunt: **the caller owns every buffer, on both sides.**

- **Caller-allocated output is the default everywhere.** OpenSSL's `EVP_EncodeUpdate`
  doc: "It is the caller's responsibility to ensure that the buffer at `out` is
  sufficiently large to accommodate the output data." glibc `b64_ntop` takes
  `char *target, size_t targsize` and returns -1 on overflow. aklomp requires the
  out-buffer to be "at least 4/3 the size of the input". mbedTLS takes `dlen` and
  returns `BUFFER_TOO_SMALL`. Windows uses the `pszString == NULL → size query`
  convention. Sources: the respective citations above.
- **The encode input is borrowed `const` (or `restrict`) and never freed by the
  codec**: OpenSSL `const unsigned char *f`; gnulib `const char *restrict in`;
  libsodium `const unsigned char *const bin`; aklomp `const char *src`.
- **Allocation is an explicit, separate API**, never implicit: gnulib's
  `base64_encode_alloc(in, inlen, &out)` and `base64_decode_alloc_ctx(...)`, where
  "the OUT variable will hold a pointer to newly allocated memory that must be
  deallocated by the caller"; on OOM it returns NULL and reports the requested
  length. OpenSSL's streaming context is likewise heap-allocated
  (`EVP_ENCODE_CTX_new`) and must be released with `EVP_ENCODE_CTX_free`; BoringSSL
  notes the context "is typically stack allocated" for the deprecated streaming API.
  Source: gnulib `base64.c`, evp.h.
- **Output is not NUL-terminated by default.** aklomp states the decision
  explicitly: "Strings are represented as a pointer and a length; they are not
  zero-terminated. This was a conscious design decision. In the decoding step,
  relying on zero-termination would make no sense since the output could contain
  legitimate zero bytes." OpenSSL and glibc *do* NUL-terminate (`EVP_EncodeBlock`
  "a NUL terminator character will be added"; `b64_ntop` writes `target[datalength] = '\0'`),
  and gnulib terminates only if the output buffer had room.
- **Aliasing is handled with `restrict`** in gnulib's API, i.e. in/out may not overlap.

(Assessment: derived from the sources above: C cannot express ownership in the type
system, so ownership lives in documentation. The two recurring contracts are
"caller provides output buffer, codec never allocates" (OpenSSL, glibc, aklomp,
mbedTLS, Windows) and "separate explicit `_alloc` function returns a
caller-freed pointer plus actual length" (gnulib).)

## 6. Blocking / non-blocking

Not applicable: all C base64 codecs are pure, in-process memory transforms with no
I/O and no waiting. The one place I/O appears is OpenSSL's `BIO_f_base64()` filter
(<https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>),
which wraps a `BIO` and therefore inherits the blocking-or-retry semantics of that
BIO; the base64 layer itself neither blocks nor supports async. No C base64 API in
this survey offers a non-blocking or async variant.

(Assessment: derived from the API shapes above; every function is
input-buffer → output-buffer with no fd, callback or poll argument.)

## 7. Alphabet variants and padding

C support is **alphabet-poor and padding-rigid**:

- **OpenSSL `EVP_*`: standard `+/` alphabet only, padding always.** `EVP_EncodeBlock`
  "the output is padded such that it is always divisible by 4"; `EVP_DecodeBlock`
  "the output will be padded with 0 bits if necessary" and cannot be told to reject
  or omit padding. There is no public URL-safe switch; the only alphabet variation
  is an SRP-specific decode table selected by the internal flag
  `EVP_ENCODE_CTX_USE_SRP_ALPHABET` (`srpdata_ascii2bin`, where `+`→62 is replaced
  by `,`→63 handling), documented only in the source. Source:
  `openssl/crypto/evp/encode.c`.
- **BoringSSL keeps exactly the standard alphabet**, no variant parameter, and
  deprecates the streaming API for being PEM-specific and lenient. Source:
  `boringssl/include/openssl/base64.h`.
- **gnulib: standard alphabet only**, `b64c[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"`,
  padding `=` emitted unconditionally at the tail; its decoder *rejects non-canonical
  padding bits*: `if (base64_to_int[in[1]] & 0x0f) return_false;` and
  `if (base64_to_int[in[2]] & 0x03) return_false;` (comments: "Reject non-canonical
  encodings"). Sources: gnulib `base64.c`.
- **libsodium has the richest C variant set but only for base64**: four constants —
  original, original-no-padding, urlsafe, urlsafe-no-padding — and the
  `sodium_base64_ENCODED_LEN` macro encodes the padding difference in its
  bit-twiddling arithmetic. The URL-safe alphabet is `-_` (RFC 4648 §5). Its `ignore`
  parameter additionally allows caller-chosen characters to be skipped during decode.
  Sources: libsodium `utils.h`, <https://doc.libsodium.org/helpers>.
- **Windows has a URL-safe flag** (`CRYPT_STRING_BASE64URI`: "Base64, without headers,
  with `+` replaced by `-` and `/` replaced by `_`") and a strict flag
  (`CRYPT_STRING_STRICT`). Source: `CryptBinaryToStringA` doc.
- **glibc/BSD `b64_ntop`: standard alphabet only** (`"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"`,
  `Pad64 = '='`), padding always written; `b64_pton` requires and validates the
  padding. Source: `glibc/resolv/base64.c`.

**base32 and base16 in C**: base16 has no alphabet ambiguity beyond case; OpenSSL
offers no hex helper at all in `EVP_*` (callers use `BIO_dump`/`OPENSSL_buf2hexstr`
from `<openssl/crypto.h>`, GUESS: not fetched this pass). libsodium's
`sodium_bin2hex` is the clean example: lowercase hex, always NUL-terminated,
`hex_maxlen >= bin_len * 2 + 1`. Source: <https://doc.libsodium.org/helpers>.

RFC 4648 is the reference for what the alphabets/padding *are*: §4 Table 1 base64,
§5 Table 2 base64url (`-`/`_`), §6 Table 3 base32 (`A-Z2-7`), §7 Table 4 base32hex
(`0-9A-V`), §8 Table 5 base16 (`0-9A-F`, no padding needed). §3.2 mandates padding
"unless the specification referring to this document explicitly states otherwise";
§3.3 says implementations MUST reject non-alphabet characters unless the referring
spec explicitly allows ignoring them. Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>.

## 8. Timeouts

Not applicable. No C base64 function in this survey takes a timeout, a deadline or a
cancellation token; none performs I/O that could time out. The only asynchronous
element in the family is OpenSSL's `ASYNC_*` machinery for *crypto operations*, and
it does not cover `EVP_Encode*`/`EVP_Decode*`.

(Assessment: derived from the signatures above; no timeout parameter appears in any
cited prototype.)

## 9. Streaming / incremental encode+decode and leftover-byte carry

This is the strongest C design axis, with three clearly different answers:

**(a) OpenSSL — explicit heap/stack context, leftover carried in `ctx->enc_data`.**
`EVP_EncodeUpdate` processes "Only full blocks of data (48 bytes) ... Any remainder
is held in the ctx object and will be processed by a subsequent call to
`EVP_EncodeUpdate()` or `EVP_EncodeFinal()`." The source shows the carry directly:
`ctx->num` counts pending bytes, and the tail is stored with
`memcpy(&(ctx->enc_data[0]), in, inl); ctx->num = inl;`. `EVP_EncodeFinal` flushes
`ctx->enc_data` via `evp_encodeblock_int(ctx, out, ctx->enc_data, ctx->num, ...)`.
Decoding carries *characters*, not bytes: `EVP_DecodeUpdate` keeps `ctx->num`
un-decoded base64 characters in `ctx->enc_data`, and its own doc for
`EVP_ENCODE_CTX_num` says it "will return the number of as yet unprocessed bytes
still to be encoded or decoded that are pending in the ctx object". Sources:
`openssl/crypto/evp/encode.c`,
<https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>.

Two OpenSSL streaming quirks are visible in the source and worth recording:

- Encoding **wraps lines by default**: `EVP_EncodeUpdate` appends `'\n'` after every
  64 output characters unless the context carries `EVP_ENCODE_CTX_NO_NEWLINES`; the
  file comment states "64 char lines".
- Decoding **accepts and strips whitespace anywhere** (`data_ascii2bin` maps space,
  tab, `\r`, `\n` to `B64_WS`/`B64_EOLN`/`B64_CR`) and it "attempts to detect and
  report end of content, [but] the context doesn't currently remember it and will
  accept more data in the next call. Therefore, the caller is responsible for
  checking and rejecting a 0 return value in the middle of content." Also, an empty
  input chunk is treated as end of input ("Legacy behaviour").

**(b) gnulib — explicit decode context, newline-aware carry of up to 4 bytes.**
`struct base64_decode_context { int i; char buf[4]; }` is the leftover buffer;
`get_4()` copies "up to 4 - CTX->i non-newline bytes" into `ctx->buf`, and the doc
explains "It is necessary for when a quadruple of base64 input bytes spans two input
buffers." The decode function is newline-tolerant only when `ctx != NULL`; with
`ctx == NULL` "newlines are treated as garbage and the input buffer is processed as
a unit". Note gnulib offers **no streaming encode context** — `base64_encode` is
one-shot; only decode is incremental. Source:
<https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.

**(c) aklomp/base64 — separate init/stream/final triad on both sides.**
`base64_stream_encode_init`, repeated `base64_stream_encode`, then
`base64_stream_encode_final` which "Adds the required end-of-stream markers if
appropriate"; the same triad exists for decode. The docs explicitly warn "Does not
zero-terminate or finalize the output" for the intermediate steps. Source: its README.

**libb64** is the fourth flavour: it exposes the encoder state machine itself
(`step_A/step_B/step_C` on encode, `step_a..step_d` on decode) plus a public
`chars_per_line` field, so the caller drives block-by-block; `base64_encode_blockend`
is the finalisation call. Sources: `b64/cencode.h`, `b64/cdecode.h`.

**BoringSSL** keeps the streaming API but marks it deprecated and documents its
state publicly (`struct evp_encode_ctx_st { unsigned data_used; uint8_t data[48]; char eof_seen; char error_encountered; }`),
i.e. it chose to *expose* the bug-prone state rather than keep it opaque. Source:
`boringssl/include/openssl/base64.h`.

**BIO-based streaming** exists only in OpenSSL: `BIO_f_base64()` wraps a BIO so that
`BIO_write`/`BIO_read` transparently encode/decode, and the filter's implementation
(`crypto/evp/bio_b64.c`) reuses `EVP_EncodeBlock` on `ctx->tmp` once `tmp_len`
reaches 3 bytes when `BIO_FLAGS_BASE64_NO_NL` is set. Source:
<https://github.com/openssl/openssl/blob/master/crypto/evp/bio_b64.c>.

(Assessment: derived from the three sources above: the C streaming designs differ on
three axes — *what is carried* (raw bytes on encode, alphabet characters or an
unfinished 4-tuple on decode), *whether the carry lives in an opaque heap context or
a public struct*, and *whether the one-shot API also exists*. OpenSSL answers
"heap context, both APIs"; gnulib "public 4-byte buffer, decode only"; aklomp
"caller-owned state struct, both APIs".)

## 10. Interesting design decisions

- **The `dlen = 0` / `dst = NULL` size-query convention** (mbedTLS, Windows). The
  codec is called twice: once to learn the needed size, once to fill. This is the
  classic C answer to "we cannot return a vector", and it makes `*olen` "always
  updated to reflect the amount of data that has (or would have) been written" — a
  genuinely useful contract. Sources: mbedTLS `base64.h`, `CryptBinaryToStringA` doc.
- **`base64_encode_alloc` returning *length* while signalling OOM through NULL**
  (gnulib). It splits three outcomes — invalid input, overlong input, OOM — across
  the return value and the out-pointer, with the doc spelling out the exact
  caller-side test. Source: gnulib `base64.c` header comment.
- **Decoding canonicality is checked, not assumed.** gnulib rejects non-zero
  trailing bits (`base64_to_int[in[1]] & 0x0f`), glibc `b64_pton` rejects them too,
  and RFC 4648 §3.5 explains why (otherwise "multiple base-encoded strings can be
  decoded to the same binary data"). Sources: gnulib `base64.c`, `glibc/resolv/base64.c`,
  RFC 4648.
- **`EVP_DecodeBlock`'s output length ignores padding.** The API returns
  `3 * (n/4)` bytes always, "padded with 0 bits if necessary", so callers must
  subtract the implied padding themselves; this is a well-known footgun. Sources:
  the OpenSSL man page, and BoringSSL's warning: "EVP_DecodeBlock's return value
  does not take padding into account."
- **Explicitly separating the deprecated streaming API from a clean block API**
  (BoringSSL). The comment on `EVP_EncodeBlock` — "Use EVP_EncodeBlock to encode raw
  base64" versus the streaming functions' "very lenient of invalid input" — is a
  good example of deprecating by *narrowing the recommended surface* rather than
  removing it.
- **The `ignore` string** (libsodium `sodium_base642bin`/`sodium_hex2bin`): instead
  of hardcoding whitespace tolerance, the caller passes the set of characters to
  skip (`": "` for hex), and can pass `NULL` to forbid any skipping. This makes
  strictness explicit and per-call. Source: <https://doc.libsodium.org/helpers>.
- **Constant-time encoding for secret data** (libsodium, BoringSSL): libsodium's
  helpers "evaluate in constant time for a given size" and BoringSSL warns its base64
  functions "are implemented with side channel protections, at a performance cost".
  Sources: libsodium docs, BoringSSL `base64.h`.
- **Public state structs** (libb64, BoringSSL) versus opaque ones (OpenSSL
  `EVP_ENCODE_CTX_new`). Making the state public lets callers stack-allocate and
  inspect it, but freezes the layout into the ABI.
- **Length macros as part of the API** (`EVP_ENCODE_LENGTH`, `EVP_DECODE_LENGTH`,
  `BASE64_LENGTH`, `sodium_base64_ENCODED_LEN`). Because callers must size buffers,
  the sizing formula is promoted to a public macro — but OpenSSL's is deliberately
  an over-estimate (adds `((l/48)+1)*2 + 80`), while gnulib's is exact.

## 11. Decisions NOT to copy

- **Returning `-1` for both "invalid input" and "buffer too small"** (glibc
  `b64_ntop`). Two very different caller responses — fix the data vs. grow the
  buffer — collapse into one signal. Source: `glibc/resolv/base64.c`.
- **`EVP_DecodeBlock`'s padding-ignoring return length.** Requiring every caller to
  recompute the true length is a defect, not a design. Sources: OpenSSL man page,
  BoringSSL warning.
- **Carrying decode state as *characters* with implicit whitespace stripping**
  (OpenSSL). The "empty chunk means EOF" legacy behaviour and the "context doesn't
  remember EOF" caveat make the contract impossible to reason about statically.
  Source: `openssl/crypto/evp/encode.c` comments.
- **Line-wrapping as a default** (OpenSSL 64-column PEM lines). For a modern codec
  the default must be no wrapping; wrapping belongs to an explicit option.
- **Public, layout-frozen context structs** (libb64, BoringSSL's
  `struct evp_encode_ctx_st`). Exposing `data[48]`, `eof_seen`, `error_encountered`
  in a public header makes the internal buffer size an ABI promise.
- **`restrict`-based non-overlap requirements** and raw `char*`/`size_t` APIs in
  general: they cannot express "output must have capacity `encoded_len(n)`", so
  every mistake is a buffer overflow rather than a compile error.
- **Caller-allocated-output as the *only* API.** Having just the mbedTLS/Windows
  style forces every caller to duplicate the sizing formula; a safe language should
  also offer the allocating form.
- **Returning a pointer as the only channel** (`sodium_bin2base64` returns `char *`
  and has no error return): size errors have nowhere to go except truncation or UB.
- **Silent leniency** (glibc/OpenSSL accepting whitespace and ignoring trailing
  garbage). RFC 4648 §3.3 recommends rejection; leniency must be opt-in, not the
  default.

## 12. Ideas fitting Mojo

- **The C size-query convention translates directly to Mojo's `mut` out-parameter
  style.** Mojo's own stdlib base64 already has the allocating-in-place overload
  `def b64encode(input_bytes: Span[UInt8], mut result: String)` where "This method
  reserves the necessary capacity" (`mojov1/stdlib/base64`). Mojo can express the
  mbedTLS `dlen = 0` query as a *documented length function* instead — `encoded_len(n)`
  as a pure `def` — which is strictly better than a two-call protocol because it is
  total and cannot fail.
- **`Span[T]` is the C `(ptr, len)` pair with a compiler-checked lifetime.**
  `mojov1/types/collections`: "`Span` is a non-owning view of contiguous data",
  parameterized on `origin`; `def b64encode(input_bytes: Span[UInt8]) -> String`
  borrows input exactly like OpenSSL's `const unsigned char *` but the borrow is
  checked. The C lesson "input is borrowed, output is owned by the caller" is
  expressible directly: `Span[UInt8]` in, `String`/`List[UInt8]` out.
- **Use typed errors where C uses negative ints.** Mojo's `raises YourErrorType`
  model (`mojov1/errors/error-model`) can make the distinction C conflates explicit
  — e.g. a `Base64Error` with separate cases for invalid character, bad length and
  non-canonical padding — and the compiler forces callers of the decoder to either
  handle it or declare `raises`, which matches the Mojo stdlib's current design
  ("`b64decode` raises on a length not divisible by 4 or on a character outside the
  alphabet").
- **Explicit alphabet selection as a `comptime` parameter, not a runtime flag.**
  libsodium's four variant constants and cppcodec's per-variant classes both point
  the same way; in Mojo an `alias`/`comptime` alphabet parameter lets the padding
  and table lookups be resolved at compile time, avoiding the runtime `variant`
  branch that libsodium must execute per call. (Assessment: derived from libsodium
  `utils.h` and cppcodec's variant model.)
- **The `ignore`-string idea maps to an optional policy argument.** libsodium's
  explicit `const char *ignore` with `NULL` meaning "strict" is exactly the kind of
  explicit strictness the Mojo stdlib already chose ("ignores whitespace only and
  still rejects other invalid characters"); keeping that choice visible in the
  signature is worth copying.
- **A `with`-scoped streaming context is a natural Mojo shape.** C's init/update/final
  triad (aklomp, OpenSSL) can become a Mojo struct with `deinit` plus a `with`
  block — `mojov1/keywords/with` guarantees release even on error paths, which is
  the C caller's manual burden made automatic.
- **Canonicality as a named check.** gnulib/glibc's trailing-bit rejection deserves
  a first-class, documented option (e.g. `strict=True`) rather than being either
  always-on or absent.
- **Borrowing a C buffer directly is expressible.** `Span` "works with both Mojo and
  C memory" and Mojo's FFI page shows wrapping a `malloc`ed buffer with
  `Span(unsafe_ptr=ptr.unsafe_bitcast[Byte](), length=Int(length))` — so a Mojo
  base64 can consume a C buffer without a copy, matching the zero-copy spirit of the
  C APIs while keeping the safety check.

## Sources

- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- ISO C standard library header list (no base-N codec):
  <https://en.cppreference.com/w/c/header>
- OpenSSL `evp.h` (encode/decode prototypes):
  <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>
- OpenSSL `crypto/evp/encode.c` (tables, carry, line wrapping, canonicality):
  <https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/encode.c>
- OpenSSL `crypto/evp/bio_b64.c`:
  <https://github.com/openssl/openssl/blob/master/crypto/evp/bio_b64.c>
- OpenSSL `EVP_EncodeInit(3ssl)` man page:
  <https://manpages.debian.org/bookworm/libssl-doc/EVP_EncodeInit.3ssl.en.html>
- BoringSSL `include/openssl/base64.h`:
  <https://raw.githubusercontent.com/google/boringssl/master/include/openssl/base64.h>
- gnulib `lib/base64.h`:
  <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>
- gnulib `lib/base64.c`:
  <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>
- glibc `resolv/base64.c`:
  <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>
- glibc bug 14118, "b64_ntop function not in public API":
  <https://sourceware.org/bugzilla/show_bug.cgi?id=14118>
- libsodium `sodium/utils.h`:
  <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/utils.h>
- libsodium helpers documentation:
  <https://doc.libsodium.org/helpers>
- libsodium LICENSE (ISC):
  <https://raw.githubusercontent.com/jedisct1/libsodium/master/LICENSE>
- libb64 `b64/cencode.h`:
  <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>
- libb64 `b64/cdecode.h`:
  <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cdecode.h>
- aklomp/base64 README (API + design notes):
  <https://raw.githubusercontent.com/aklomp/base64/master/README.md>
- mbedTLS `include/mbedtls/base64.h`:
  <https://raw.githubusercontent.com/Mbed-TLS/mbedtls/master/include/mbedtls/base64.h>
- Microsoft `CryptBinaryToStringA`:
  <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptbinarytostringa>
- Microsoft `CryptStringToBinaryA`:
  <https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-cryptstringtobinarya>
- Mojo `mojov1` buch, `stdlib/base64` (Mojo-side reference for section 12)
- Mojo `mojov1` buch, `stdlib/collections` (`Span`, `String` ownership)
- Mojo `mojov1` buch, `errors/error-model` (`raises`, typed errors)
