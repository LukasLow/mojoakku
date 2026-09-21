# base64 research: C

Scope: the standardized 12-question set from `.agents/workflows/NewLibPhase1Research.md`, answered for `base64` in **C**. Questions 5, 7 and 9 are the base64-adapted variants (buffer ownership, alphabets/padding, streaming). RFC 4648 is the shared normative reference. C has no standard codec; the C column is therefore a study of *library-shaped* APIs (OpenSSL, glibc/resolv, gnulib/coreutils, libsodium, libbase64, libb64, crypt_blowfish).

## 1. Standard library support

**ISO C provides nothing.** The complete C standard header list contains no base64/base32/base16 header and no such functions:
`<assert.h>`, `<complex.h>`, `<ctype.h>`, `<errno.h>`, `<fenv.h>`, `<float.h>`, `<inttypes.h>`, `<iso646.h>`, `<limits.h>`, `<locale.h>`, `<math.h>`, `<setjmp.h>`, `<signal.h>`, `<stdalign.h>`, `<stdarg.h>`, `<stdatomic.h>`, `<stdbit.h>`, `<stdbool.h>`, `<stdckdint.h>`, `<stddef.h>`, `<stdint.h>`, `<stdio.h>`, `<stdlib.h>`, `<stdnoreturn.h>`, `<string.h>`, `<tgmath.h>`, `<threads.h>`, `<time.h>`, `<uchar.h>`, `<wchar.h>`, `<wctype.h>`. Source: <https://en.cppreference.com/w/c/header> (absence-of-evidence fact taken from the full header list).

RFC 4648 confirms this indirectly: its own §11 says an "ISO C99 implementation of Base64 encoding and decoding that is believed to follow all recommendations in this RFC is available from: http://josefsson.org/base-encoding/" and adds "This code is not normative. The code could not be included in this RFC for procedural reasons" (§11). Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>. That page is Simon Josefsson's `base-encoding` page, which states the implementation was contributed to **gnulib** and the CLI to **GNU coreutils**: "I have put together a free base64 implementation in portable C available in gnulib from Savannah: base64.h / base64.c" and "My tool has now been adopted by the GNU project, and is integrated into GNU CoreUtils as 'base64'." Source: <https://josefsson.org/base-encoding/>.

**Only three C-ecosystem names look like "standard library" but are not:**
- `b64_ntop` / `b64_pton` — declared in glibc's `<resolv.h>` and implemented in `resolv/base64.c`. Their origin is BIND/the resolver, not ISO C or POSIX. Source: `resolv/resolv.h` and `resolv/base64.c` in <https://github.com/bminor/glibc> (raw: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/resolv.h>).
- `EVP_EncodeInit`/`EVP_EncodeUpdate`/`EVP_EncodeFinal`/`EVP_EncodeBlock` and the `EVP_Decode*` family — OpenSSL libcrypto, declared in `<openssl/evp.h>`. Source: <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>.
- gnulib's `base64_encode`/`base64_decode_ctx` — a portable LGPL library, not libc. Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>.

Consequences for this research: every C answer below is a *library* answer, and C shows the widest spread of API philosophies of any language in this run — from `void base64_encode(...)` (gnulib) over state-struct codecs (libb64, libbase64) to a BIO filter chain (OpenSSL) and a variant-parameter codec (libsodium).

## 2. Relevant community libraries

| Library | Maintainer / origin | License | Size / shape | Source |
| --- | --- | --- | --- | --- |
| OpenSSL libcrypto (`EVP_Encode*`, `EVP_Decode*`, `BIO_f_base64`) | OpenSSL Project | Apache-2.0 | de-facto C reference; two independent APIs (block/stream + BIO filter) | <https://docs.openssl.org/master/man3/EVP_EncodeInit/>, <https://docs.openssl.org/master/man3/BIO_f_base64/> |
| glibc resolver (`b64_ntop`, `b64_pton`) | ISC/BIND heritage, glibc | LGPL-2.1+ (glibc) | 2 functions, ~300 lines; the "hidden" API everyone links against | <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c> |
| gnulib (`base64_encode`, `base64_decode_ctx`) | Simon Josefsson / GNU, adapted from GNU MailUtils | LGPL-2.1+ | used by GNU coreutils `base64`; streaming decode ctx, stateless encode | <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c> |
| libsodium (`sodium_bin2base64`, `sodium_base642bin`) | Frank Denis | ISC | 4 variants, constant-time, `ignore` + `b64_end` out-params | <https://doc.libsodium.org/helpers>, <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/sodium/codecs.c> |
| libbase64 (`aklomp/base64`) | Alfred Klomp | BSD-2-Clause | SIMD (AVX2/AVX512/SSSE3/SSE4/NEON), optional OpenMP, "Does not dynamically allocate memory", "Re-entrant and threadsafe" | <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h> |
| libb64 | SourceForge, forked to GitHub | Public Domain | minimal state-struct + coroutine implementation, C++ wrappers included | <https://raw.githubusercontent.com/libb64/libb64/master/README.md> |
| crypt_blowfish (bcrypt base64) | Solar Designer / Openwall | Public domain (no copyright claimed) | not a base64 library; owns the `./A-Za-z0-9` bcrypt alphabet | <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c> |

Maturity signals from the sources:
- OpenSSL documents its own historical fixes: "The EVP_DecodeUpdate() function was fixed in OpenSSL 3.5, so now it produces the number of bytes specified in outl* and does not decode padding bytes (=) to 6 zero bits." Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- gnulib's `base64.c` is the code RFC 4648 §11 points at, and its header comments document the intended usage pattern explicitly (see section 4). Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
- libsodium documents the codec as part of its "Helpers" page alongside hex and IP codecs (`sodium_bin2hex`, `sodium_bin2ip`), i.e. base64 is treated as one codec among several, not as a standalone library. Source: <https://doc.libsodium.org/helpers>.
- libbase64 states its own feature set and non-features bluntly: "FAST; easy to use; elegant", "Does not dynamically allocate memory", "Valid C99 that compiles with pedantic options on", "Uses Duff's Device". Source: <https://github.com/aklomp/base64>.
- libb64 explains its fork history and motivation: "As development there seems to have stopped in 2010 we forked the source to GitHub", and states why it exists at all: "I did this because I need an implementation of base64 encoding and decoding, without any licensing problems. Most OS implementations are released under either the GNU/GPL, or a BSD-variant, which is not what I require." Source: <https://raw.githubusercontent.com/libb64/libb64/master/README.md>.
- crypt_blowfish is included only as alphabet evidence: it hardcodes `static unsigned char BF_itoa64[64 + 1] = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"` and a matching `BF_atoi64` table, and its own comment says the output must be "bug-compatible with the original implementation, so only encode 23 of the 24 bytes". Source: <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c>.

## 3. Exposed APIs

### 3.1 OpenSSL libcrypto — block/stream API (`<openssl/evp.h>`)

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
Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod> and <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>.

Behavioural details that matter for API design:
- Line wrapping at **64 characters** is built into the encoder: the internal step is `#define EVP_ENCODE_B64_LENGTH 48` and a `'\n'` is appended per processed block; the docs say "For each 48 byte input block encoded 64 bytes of base64 data is output plus an additional newline character (i.e. 65 bytes in total)." Sources: `crypto/evp/evp_local.h`, `crypto/evp/encode.c`, `doc/man3/EVP_EncodeInit.pod` — all in <https://github.com/openssl/openssl>.
- `EVP_EncodeUpdate` buffers the remainder itself: "Only full blocks of data (48 bytes) will be immediately processed and output by this function. Any remainder is held in the ctx object"; `EVP_ENCODE_CTX_num()` "will return the number of as yet unprocessed bytes still to be encoded or decoded that are pending in the ctx object." Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- Decoding is lenient by default and treats `-` as a PEM terminator: "Any whitespace, newline or carriage return characters are ignored. For compatibility with PEM, the - (hyphen) character is treated as a soft end-of-input, subsequent bytes are not buffered, and the return value will be 0"; for `EVP_DecodeUpdate` specifically, invalid characters or a mid-stream `=` return -1. Source: same.
- `EVP_DecodeBlock` has a documented caller obligation: "Padding bytes (=) (even if internal) are decoded to 6 zero bits, the caller is responsible for taking trailing padding into account, by ignoring as many bytes at the tail of the returned output." Source: same. So this API returns a length that is always `3 * n/4` and never corrects for `=`.
- The context struct is public but opaque via typedef: `struct evp_Encode_Ctx_st { int num; unsigned char enc_data[80]; int line_num; unsigned int flags; };`. Source: `crypto/evp/evp_local.h`.

### 3.2 OpenSSL — BIO filter API (`BIO_f_base64`)

```c
const BIO_METHOD *BIO_f_base64(void);
```
"BIO_f_base64() returns the base64 BIO method. This is a filter BIO that base64 encodes any data written through it and decodes any data read through it." Usage is a chain: `BIO_push(b64, bio)`, then `BIO_write`/`BIO_read`; `BIO_flush()` "is used to signal that no more data is to be encoded: this is used to flush the final block through the BIO." Flag `BIO_FLAGS_BASE64_NO_NL` switches off line splitting/joining. Sources: <https://docs.openssl.org/master/man3/BIO_f_base64/>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man7/bio.pod>.

### 3.3 glibc / BIND resolver (`<resolv.h>`)

```c
int b64_ntop (const unsigned char *, size_t, char *, size_t) __THROW;
int b64_pton (char const *, unsigned char *, size_t) __THROW;
```
Source: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/resolv.h> (the header also `#define`s these to `__b64_ntop`/`__b64_pton`).

Semantics from the implementation (`resolv/base64.c`):
- `b64_ntop` returns the string length excluding the NUL it appends, or -1 if the target would overflow: `if (datalength + 4 > targsize) return (-1);` and a final `if (datalength >= targsize) return (-1);` before `target[datalength] = '\0';`.
- `b64_pton` **skips all whitespace anywhere** (`if (isspace(ch)) continue;`), stops at the first `=` and then validates the tail; it rejects non-zero trailing bits explicitly with the comment "Now make sure for cases 2 and 3 that the 'extra' bits that slopped past the last full byte were zeros. If we don't check them, they become a subliminal channel." It returns the decoded byte count or -1.
Sources: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.

### 3.4 gnulib / GNU coreutils

```c
#define BASE64_LENGTH(inlen) ((((inlen) + 2) / 3) * 4)
struct base64_decode_context { int i; char buf[4]; };
extern signed char const base64_to_int[256];
BASE64_INLINE bool isubase64 (unsigned char ch);
BASE64_INLINE bool isbase64 (char ch);
extern void base64_encode (const char *restrict in, idx_t inlen,
                           char *restrict out, idx_t outlen);
extern idx_t base64_encode_alloc (const char *in, idx_t inlen, char **out);
BASE64_INLINE void base64_decode_ctx_init (struct base64_decode_context *ctx);
extern bool base64_decode_ctx (struct base64_decode_context *ctx,
                               const char *restrict in, idx_t inlen,
                               char *restrict out, idx_t *outlen);
extern bool base64_decode_alloc_ctx (struct base64_decode_context *ctx,
                                     const char *in, idx_t inlen,
                                     char **out, idx_t *outlen);
/* convenience macros that pass ctx == NULL */
#define base64_decode(in, inlen, out, outlen) base64_decode_ctx (NULL, ...)
#define base64_decode_alloc(in, inlen, out, outlen) base64_decode_alloc_ctx (NULL, ...)
```
Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>.

Two documented design choices in the header are directly relevant:
- It is the **decode context that carries stream state**, not the encoder: `base64_decode_ctx` documents "It is necessary for when a quadruple of base64 input bytes spans two input buffers." while `base64_encode` is stateless because the coreutils caller guarantees `ENC_BLOCKSIZE % 12 == 0` so no padding can appear mid-stream. Sources: `lib/base64.h` and `src/base64.c` in <https://github.com/coreutils/coreutils> (mirror <https://github.com/projectgnu/coreutils/blob/master/src/base64.c>).
- It is one of very few C codecs that **rejects non-canonical trailing bits**: `if (base64_to_int[to_uchar (in[1])] & 0x0f) return_false;` and `if (base64_to_int[to_uchar (in[2])] & 0x03) return_false;` with the comment "Reject non-canonical encodings." Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.

The CLI in `src/base64.c` adds line wrapping and a leniency flag: `-w, --wrap=COLS wrap encoded lines after COLS character (default 76). Use 0 to disable line wrapping`, `-i, --ignore-garbage when decoding, ignore non-alphabet characters`, `-d, --decode`. Sources: <https://raw.githubusercontent.com/projectgnu/coreutils/master/src/base64.c>, <https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html>.

### 3.5 libsodium

```c
#define sodium_base64_VARIANT_ORIGINAL            1
#define sodium_base64_VARIANT_ORIGINAL_NO_PADDING 3
#define sodium_base64_VARIANT_URLSAFE             5
#define sodium_base64_VARIANT_URLSAFE_NO_PADDING  7

#define sodium_base64_ENCODED_LEN(BIN_LEN, VARIANT) /* macro, see header */
size_t sodium_base64_encoded_len(const size_t bin_len, const int variant);

char *sodium_bin2base64(char * const b64, const size_t b64_maxlen,
                        const unsigned char * const bin, const size_t bin_len,
                        const int variant);
int sodium_base642bin(unsigned char * const bin, const size_t bin_maxlen,
                      const char * const b64, const size_t b64_len,
                      const char * const ignore, size_t * const bin_len,
                      const char ** const b64_end, const int variant);
```
Sources: <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/utils.h>, <https://doc.libsodium.org/helpers>.

Documented contract: "The sodium_bin2base64() function encodes bin as a Base64 string. variant must be one of: …", "Computing a correct size for b64_maxlen is not straightforward and depends on the chosen variant", "If b64_end is not NULL, it will be set to the address of the first byte after the last valid parsed character", "Base64 encodes 3 bytes as 4 characters, so the result of decoding a b64_len string will always be at most b64_len / 4 * 3 bytes long", and both functions "return 0 on success" / "-1" on failure. On violation of the size contract the code calls `sodium_misuse()`, which is declared `void sodium_misuse(void) __attribute__ ((noreturn));`. Sources: <https://doc.libsodium.org/helpers>, `src/libsodium/sodium/codecs.c`, `src/libsodium/include/sodium/core.h` in <https://github.com/jedisct1/libsodium>.

### 3.6 libbase64 (aklomp) — wrapper + streaming, plus codec-forcing flags

```c
struct base64_state { int eof; int bytes; int flags; unsigned char carry; };
void base64_encode (const char *src, size_t srclen, char *out, size_t *outlen, int flags);
void base64_stream_encode_init (struct base64_state *state, int flags);
void base64_stream_encode (struct base64_state *state, const char *src, size_t srclen,
                           char *out, size_t *outlen);
void base64_stream_encode_final (struct base64_state *state, char *out, size_t *outlen);
int  base64_decode (const char *src, size_t srclen, char *out, size_t *outlen, int flags);
void base64_stream_decode_init (struct base64_state *state, int flags);
int  base64_stream_decode (struct base64_state *state, const char *src, size_t srclen,
                           char *out, size_t *outlen);
#define BASE64_FORCE_AVX2 (1 << 0) /* … NEON32, NEON64, PLAIN, SSSE3, SSE41, SSE42, AVX, AVX512 */
```
Source: <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h> and <https://github.com/aklomp/base64> (README documents the same signatures).

### 3.7 libb64 — state struct + coroutines

```c
typedef enum { step_A, step_B, step_C } base64_encodestep;
typedef struct { size_t stepcount; size_t chars_per_line; base64_encodestep step;
                 int cflags; char result; } base64_encodestate;
void   base64_init_encodestate(base64_encodestate* state_in);
size_t base64_encode_length(size_t plain_len, base64_encodestate* state_in);
char   base64_encode_value(signed char value_in);
size_t base64_encode_block(const void* plaintext_in, const size_t length_in,
                           char* code_out, base64_encodestate* state_in);
size_t base64_encode_blockend(char* code_out, base64_encodestate* state_in);

typedef enum { step_a, step_b, step_c, step_d } base64_decodestep;
typedef struct { base64_decodestep step; char plainchar; } base64_decodestate;
void   base64_init_decodestate(base64_decodestate* state_in);
size_t base64_decode_maxlength(size_t encode_len);
int    base64_decode_value(signed char value_in);
size_t base64_decode_block(const char* code_in, const size_t length_in,
                           void* plaintext_out, base64_decodestate* state_in);
```
Sources: <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cdecode.h>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>.

Note the asymmetry: the encoder exposes `base64_encode_blockend()` for finalisation, but the decoder has **no end function at all** — it is silent about truncated input (section 4).

### 3.8 crypt_blowfish — the bcrypt alphabet, not an API to copy

`BF_encode` / `BF_decode` are internal (`static`) and use `BF_itoa64`/`BF_atoi64`; `BF_safe_atoi64` is a macro that `return -1`s out of a decode on any byte outside `' '..'\x7f'` (`if ((unsigned int)(tmp -= 0x20) >= 0x60) return -1;`). Source: <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c>.

## 4. Error representation

C has no exceptions and no `Result` type, so every implementation in this survey encodes failure in one of **four** mechanisms, and they are not equivalent:

| Library | Failure encoding | Success encoding |
|---|---|---|
| OpenSSL EVP encode (`EVP_EncodeUpdate`) | `int` return: 1 = ok, 0 = error; `*outl` = bytes written | out-param length |
| OpenSSL EVP decode (`EVP_DecodeUpdate`) | `int` return: 0 = "no more non-padding base64 characters are expected" (end of payload), -1 = error, 1 = ok; `*outl` = bytes written | out-param length |
| OpenSSL `EVP_DecodeBlock` | `-1` return | return value = decoded length, always `3 * n/4` and never corrected for trailing `=` padding |
| OpenSSL BIO | `BIO_read` returns <= 0; distinction via `BIO_should_retry()` / error queue | positive byte count |
| glibc `b64_ntop`/`b64_pton` | `-1` return | return value = length (ntop excludes NUL, pton = decoded bytes) |
| gnulib | `bool` return (`true`/`false`) + `*outlen` | `bool` |
| libsodium | `int` 0 = success, -1 = error; **size-contract violations are fatal `sodium_misuse()`** | 0 |
| libbase64 | `int`: 1 = ok, 0 = decode error, -1 = "codec not built in" | 1 |
| libb64 | **no error path at all for decode**; encode returns byte counts | `size_t` counts |

Details and quotes:
- OpenSSL's tri-state is documented as such: "EVP_EncodeUpdate() returns 0 on error or 1 on success"; "EVP_DecodeUpdate() returns -1 on error and 0 or 1 on success. If 0 is returned then no more non-padding base64 characters are expected"; "EVP_DecodeBlock() returns the length of the data decoded or -1 on error." Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- OpenSSL's own source carries an explicit warning that the "end of input" signal is not remembered in the context: "Note: even though EVP_DecodeUpdate attempts to detect and report end of content, the context doesn't currently remember it and will accept more data in the next call. Therefore, the caller is responsible for checking and rejecting a 0 return value in the middle of content." Source: `crypto/evp/encode.c` in <https://github.com/openssl/openssl>.
- gnulib makes the two failure modes explicit in a comment block rather than in the type system: "bool ok = base64_decode_alloc (in, inlen, &out, &outlen); if (!ok) FAIL: input was not valid base64; if (out == NULL) FAIL: memory allocation error" and "if (out == NULL && outlen == 0 && inlen != 0) FAIL: input too long". Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>. This is the closest C comes to separating "bad input" from "bad buffer".
- libsodium separates invalid input (`-1` + `errno = EINVAL`) from insufficient output (`-1` + `errno = ERANGE`): `errno = ERANGE; ret = -1;`, `errno = EINVAL; ret = -1;`. But a *caller contract* violation (output buffer not large enough for encoding, or bad variant) is not an error return at all: `sodium_misuse(); /* LCOV_EXCL_LINE */` with its own comment "Some macros for constant-time comparisons" nearby — `sodium_misuse` is `__attribute__ ((noreturn))`. Sources: `src/libsodium/sodium/codecs.c`, `src/libsodium/include/sodium/core.h` in <https://github.com/jedisct1/libsodium>. The documented variant check is "sodium_base64_check_variant", and libsodium's public contract is only "returns 0 on success", "-1" on failure — `errno` is the hidden channel. Source for the doc side: <https://doc.libsodium.org/helpers>.
- **glibc's `errno` convention is the general C one**, and it has the classic caveat: "The value in errno is significant only when the return value of the call indicated an error … a function that succeeds is allowed to change errno" and "errno is thread-local". Neither `b64_ntop`/`b64_pton` nor the OpenSSL EVP base64 functions set `errno`; libsodium does. Source for the convention: <https://man7.org/linux/man-pages/man3/errno.3.html>.
- **The strongest anti-pattern in the C column is libb64's silent decoder.** `base64_decode_value` returns `-1` for a non-alphabet byte, and `base64_decode_block` simply loops while `fragment < 0` — it *skips* invalid input: `do { if (codechar == code_in+length_in) {...} fragment = base64_decode_value(*codechar++); } while (fragment < 0);`. There is no way for the caller to learn that the input was invalid, and there is no finalisation call, so a truncated input is indistinguishable from a valid one. Sources: <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cdecode.h>.
- **libbase64 adds a third return value that is not an input verdict**: "Returns 1 if all is well, and 0 if a decoding error was found, such as an invalid character. Returns -1 if the chosen codec is not included in the current build." Source: <https://github.com/aklomp/base64> (README API reference) and the header comment in <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.
- `GUESS:` no C implementation in this survey exposes a structured error *value* (offset + kind) the way Rust's `DecodeError::InvalidByte(usize, u8)` does. The nearest thing is glibc's `b64_pton`, which returns -1 with no position information, and libsodium's `b64_end` out-parameter, which reports *where parsing stopped* but not the error kind. Reason for the GUESS: no source found that documents an offset-carrying C error type; the claim is about absence in the surveyed set, not about all C code.

## 5. Ownership semantics (adapted Q5: buffer/ownership of encode input and output)

C's model is uniform and explicit: **the caller owns every buffer, and no implementation in this survey allocates on the caller's behalf in its core API.** The differences are in which buffer-size contract is documented.

- **OpenSSL EVP:** "It is the caller's responsibility to ensure that the buffer at out is sufficiently large to accommodate the output data." The exact size rule is spelled out for the streaming encoder: "To calculate the required size of the output buffer add together the value of inl with the amount of unprocessed data held in ctx and divide the result by 48 (ignore any remainder). … Ensure the output buffer contains 65 bytes of storage for each block, plus an additional byte for a NUL terminator" — i.e. **the library writes a NUL terminator into the caller's buffer** and the buffer must account for it. `EVP_EncodeFinal` needs at most "65 bytes plus an additional NUL terminator (i.e. 66 bytes in total)". The context itself is heap-owned but must be created/freed: "EVP_ENCODE_CTX_new() allocates, initializes and returns a context"; "EVP_ENCODE_CTX_free() cleans up an encode/decode context ctx and frees up the space allocated to it. If the argument is NULL, nothing is done." Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>.
- **glibc `b64_ntop`:** input borrowed (`u_char const *src`), output caller-owned with an explicit size, and the function **appends a NUL** while excluding it from the return value: `target[datalength] = '\0'; /* Returned value doesn't count \0. */`. Overflow is detected *before* writing (`if (datalength + 4 > targsize) return (-1);`). `b64_pton` takes a NUL-terminated input and a target plus `targsize`, and guards each write: `if ((size_t)tarindex >= targsize) return (-1);`. Sources: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.
- **gnulib:** the strictest documented contract in the survey. `base64_encode` says: "If OUTLEN is less than BASE64_LENGTH(INLEN), write as many bytes as possible. If OUTLEN is larger than BASE64_LENGTH(INLEN), also zero terminate the output buffer." — i.e. truncation is silent, zero-termination is conditional on spare room. `restrict` on both in and out documents non-aliasing. The `_alloc` variants transfer ownership to the caller: "On return, the OUT variable will hold a pointer to newly allocated memory that must be deallocated by the caller", and they distinguish overflow from OOM by the return value: "If output string length would overflow, 0 is returned and OUT is set to NULL. If memory allocation failed, OUT is set to NULL, and the return value indicates length of the requested memory block." The overflow check is explicit rather than assumed: `if (ckd_mul (&outlen, in_over_3, 4) || inlen < 0)` using `<stdckdint.h>`. Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
- **gnulib decode side carries the leftover bytes in a caller-owned struct:** `struct base64_decode_context { int i; char buf[4]; };` with `base64_decode_ctx_init` setting `ctx->i = 0`. There is no hidden allocation and no hidden state; the caller may also pass `ctx == NULL` to treat input "as a unit" ("If CTX is NULL then newlines are treated as garbage and the input buffer is processed as a unit."). Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h> and <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
- **libsodium:** output buffer max length must be computed by the caller using a provided helper, and the function refuses to guess: "Computing a correct size for b64_maxlen is not straightforward and depends on the chosen variant. The sodium_base64_ENCODED_LEN(BIN_LEN, VARIANT) macro returns the minimum number of bytes required… The returned length includes a trailing \0 byte." The implementation enforces it fatally: `if (b64_maxlen <= b64_len) { sodium_misuse(); }`. On the decode side the API returns a **pointer into the caller's own input** telling where parsing stopped: "If b64_end is not NULL, it will be set to the address of the first byte after the last valid parsed character." Sources: <https://doc.libsodium.org/helpers>, `src/libsodium/sodium/codecs.c` in <https://github.com/jedisct1/libsodium>.
- **libbase64:** zero allocation as a stated design property — "Does not dynamically allocate memory" — with a documented size contract that is *advisory*: "The buffer in out has been allocated by the caller and is at least 4/3 the size of the input" / "at least 3/4 the size of the input"; the streaming variants say "it must be at least 4/3 the size of the in-buffer, but take some margin". Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>. The stream state is a caller-owned by-value struct: `struct base64_state { int eof; int bytes; int flags; unsigned char carry; };` — `carry` is literally the leftover byte.
- **libb64:** the state struct is caller-owned and carries the leftover explicitly: `base64_encodestate` has `size_t stepcount` and `int cflags`, `base64_decodestate` has `base64_decodestep step; char plainchar;`. Sizing helpers are provided but documented as *upper bounds*: `base64_decode_maxlength(size_t encode_len) { return encode_len / 4 * 3 + 2; }` and `base64_encode_length()` returns "encoded length, or 0 if encoded length + one additional null byte would exceed range of size_t". Sources: <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>.
- **Where C lets the caller down is the "wrote nothing" case, not ownership.** gnulib documents silent truncation ("write as many bytes as possible"), libbase64 documents "take some margin" instead of a formula, and OpenSSL's `EVP_ENCODE_LENGTH(l)` macro is explicitly padded with slack: `#define EVP_ENCODE_LENGTH(l) (((((size_t)(l)) + 2) / 3 * 4) + (((size_t)(l)) / 48 + 1) * 2 + 80)`. Source: <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>. GUESS: the "lets the caller down" framing is an assessment of these sources, not a sourced claim.

## 6. Blocking / non-blocking

- **The in-memory codecs are pure CPU work and therefore have no blocking concept at all.** gnulib (`base64_encode`, `base64_decode_ctx`), glibc (`b64_ntop`, `b64_pton`), libsodium (`sodium_bin2base64`, `sodium_base642bin`), libbase64's wrapper functions and libb64's block functions all take a buffer and a length and return; none of them takes a file descriptor, a lock, or a callback. Sources: the respective headers/implementations listed in section 3.
- **Where C gets an I/O model, it comes from layering, and the only real example in this survey is OpenSSL's BIO.** A BIO is the abstraction: "A BIO is an I/O abstraction, it hides many of the underlying I/O details from an application … There are two types of BIO, a source/sink BIO and a filter BIO … A chain normally consists of one source/sink BIO and one or more filter BIOs." `BIO_f_base64()` is a filter BIO, so the blocking behaviour is whatever the *source/sink* BIO at the end of the chain does. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man7/bio.pod>, <https://docs.openssl.org/master/man3/BIO_f_base64/>.
- **OpenSSL has an explicit non-blocking protocol rather than an async model.** "These functions determine why a BIO is not able to read or write data. They will typically be called after a failed BIO_read_ex() or BIO_write_ex() call. BIO_should_retry() is true if the call that produced this condition should then be retried at a later time." The docs then spell out that the caller builds the event loop: "if the cause is ultimately a socket and BIO_should_read() is true then a call to select() may be made to wait until data is available and then retry the BIO operation … It is possible for a BIO to block indefinitely if the underlying I/O structure cannot process or return any data … one solution is to use non blocking I/O and use a timeout on the select() (or equivalent) call." Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/BIO_should_retry.pod>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man7/bio.pod>.
- **The base64 BIO has a documented retry-related failure mode.** "If decoding stops as a result of an error, the first BIO_read() that returns no decoded data will typically return a negative result, rather than 0 (which indicates normal end of input). However, a negative return value can also occur if the underlying BIO supports retries, see BIO_should_read() and BIO_set_mem_eof_return()." Source: <https://docs.openssl.org/master/man3/BIO_f_base64/>. In other words: in the filter chain, "no data yet" and "corrupt base64" are distinguishable only by consulting the BIO retry state.
- **Concurrency is caller-side in every implementation.** libbase64 states it as a property: "Re-entrant and threadsafe" and "Does not dynamically allocate memory", which is why it needs no locks. OpenSSL's codec state is per-context (`EVP_ENCODE_CTX`), so two threads need two contexts. libb64 deliberately replaced `static` coroutine variables with a caller-passed struct for exactly this reason: "The obvious problem with any such routine is the static keyword. Any static variables in a function spell doom for multithreaded applications… This allows for a fast, multithreading-enabled implementation." libsodium's `errno` channel is thread-local per the errno convention ("errno is thread-local; setting it in one thread does not affect its value in any other thread"). Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/libb64/libb64/master/README.md>, <https://man7.org/linux/man-pages/man3/errno.3.html>, <https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/evp_local.h>.
- **Parallelism exists only as an implementation detail inside one library.** libbase64 can use OpenMP: "Can use OpenMP for even more parallel speedups" and its README shows `OPENMP=1 make`; `OMP_THRESHOLD 20000` is described as requiring "at least a 20000 byte buffer to enable multithreading", and the README warns "performance degradation when the buffer size is less than 10 kB due to thread creation overhead". This is not an API contract — no function exposes or accepts a thread count. Sources: <https://github.com/aklomp/base64>.
- **`GUESS:`** no C base64 library in this survey offers an async/coroutine/future interface, and none is known to the author from memory; no source was fetched for such a library, so no claim is made. The BIO + `BIO_should_retry()` + `select()` pattern is the only concurrency story this survey can source.

## 7. Alphabet variants and padding (adapted Q7: std vs URL-safe, padding handling)

### 7.1 The standard alphabet

The standard 64-character alphabet is identical everywhere in this survey:
- glibc: `static const char Base64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";` and `static const char Pad64 = '=';`. Source: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.
- gnulib: `static const char b64c[64] _GL_ATTRIBUTE_NONSTRING = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";`. Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
- libb64: `static const char* encoding = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";`. Source: <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>.
- OpenSSL encodes the alphabet as a 128-entry lookup table `data_ascii2bin` with sentinel values, not as a string: `0xFF` = B64_ERROR, `0xE0` = B64_WS, `0xF0` = B64_EOLN, `0xF1` = B64_CR, `0xF2` = B64_EOF (`'-'` maps to `0xF2`), `'='` maps to `0x00`. Source: `crypto/evp/encode.c` in <https://github.com/openssl/openssl>. This table design is what makes OpenSSL's decoder lenient by construction.
- RFC 4648 is the normative source for the alphabet: Table 1 (§4) lists `A-Z` = 0..25, `a-z` = 26..51, `0-9` = 52..61, `+` = 62, `/` = 63, `=` = pad. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt> §4.

### 7.2 URL-safe and other variants

- **libsodium is the only surveyed C library that treats variants as a first-class parameter.** It exposes exactly four as `#define`s: `sodium_base64_VARIANT_ORIGINAL` (1), `sodium_base64_VARIANT_ORIGINAL_NO_PADDING` (3), `sodium_base64_VARIANT_URLSAFE` (5), `sodium_base64_VARIANT_URLSAFE_NO_PADDING` (7), documented as "variant must be one of: …". The implementation maps them through `sodium_base64_check_variant` and switches on `VARIANT_NO_PADDING_MASK 0x2U` / `VARIANT_URLSAFE_MASK 0x4U`. Sources: `src/libsodium/include/sodium/utils.h`, `src/libsodium/sodium/codecs.c`, <https://doc.libsodium.org/helpers>.
- **libsodium's alphabet is built arithmetically rather than as a second string** — a constant-time choice: `b64_byte_to_urlsafe_char` computes `(LT(x, 26) & (x + 'A')) | (GE(x, 26) & LT(x, 52) & (x + ('a' - 26))) | (GE(x, 52) & LT(x, 62) & (x + ('0' - 52))) | (EQ(x, 62) & '-') | (EQ(x, 63) & '_')`, with the `+`/`/` version differing only in the last two terms. Source: `src/libsodium/sodium/codecs.c`.
- **The RFC is explicit that URL-safe is a different encoding, not a display option:** "This encoding may be referred to as 'base64url'. This encoding should not be regarded as the same as the 'base64' encoding and should not be referred to as only 'base64'." (§5). The rationale for the variant is in §3.4: "For base 64, the non-alphanumeric characters (in particular, '/') may be problematic in file names and URLs" and "Certain characters, notably '+' and '/' in the base 64 alphabet, are treated as word-breaks by legacy text search/index tools." Sources: <https://www.rfc-editor.org/rfc/rfc4648.txt>.
- **Non-RFC alphabets seen in the wild, in C:**
  - bcrypt, `./A-Za-z0-9` — `static unsigned char BF_itoa64[64 + 1] = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";` in crypt_blowfish. Source: <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c>.
  - OpenSSL has a second built-in table for SRP: `srpdata_ascii2bin`, in which `'+'` does **not** map to 62 and `'='` is not the pad — the alphabet is `0-9 A-Z a-z . /`-shaped with `0x3E` for `.` and `0x3F` for `/`. Selected by the flag `EVP_ENCODE_CTX_USE_SRP_ALPHABET`. Source: `crypto/evp/encode.c`.
  - glibc/OpenSSL/libbase64/gnulib have no variant support at all: one hardcoded alphabet each. Sources as listed in 7.1.

### 7.3 Padding handling

RFC 4648's default is mandatory padding: "Implementations MUST include appropriate pad characters at the end of encoded data unless the specification referring to this document explicitly states otherwise." (§3.2). The three cases are enumerated with exact outputs: 24-bit multiple → no `=`; 8 bits → "two characters followed by two '=' padding characters"; 16 bits → "three characters followed by one '=' padding character" (§4). Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

How each C implementation treats padding:
- **gnulib encodes padding always** and handles it in the same loop (`*out++ = inlen ? b64c[to_uchar (in[2]) & 0x3f] : '=';`), while its decoder **rejects non-canonical padding**: it requires `in[3] == '='` when `in[2] == '='` (`if (in[3] != '=') return_false;`) and checks the dangling bits (`if (base64_to_int[to_uchar (in[1])] & 0x0f) return_false;`). Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
- **glibc `b64_pton` requires canonical padding structurally** — it breaks on the first `=`, then re-validates: `case 0: case 1: return (-1);` (a `=` in the first or second position is invalid), `case 2:` demands "Make sure there is another trailing = sign" and then falls through, `case 3:` verifies non-zero trailing bits. Source: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.
- **OpenSSL is padding-lenient and lets the caller clean up.** In `EVP_DecodeUpdate`, `=` is accepted wherever it appears without breaking the character loop, the decoder tracks `eof` counts, and `EVP_DecodeBlock` docs say padding bytes "are decoded to 6 zero bits, the caller is responsible for taking trailing padding into account". `EVP_DecodeUpdate` additionally allows an unpadded tail: "Residual input shorter than the internal chunk size will be buffered in ctx if its length is not a multiple of 4 (including any padding)", and `EVP_DecodeFinal` errors when the remainder is unpadded: "If there is residual data, its length is not a multiple of 4, i.e. it was not properly padded, -1 is returned". Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, `crypto/evp/encode.c`.
- **libsodium enforces padding only for the padded variants:** `sodium_base642bin` calls `_sodium_base642bin_skip_padding(...)` only when `(variant & VARIANT_NO_PADDING_MASK) == 0U`, and that helper accepts `=` mixed with ignored characters but returns `ERANGE`/`EINVAL` on malformed tails (`if (*b64_pos_p >= b64_len) { errno = ERANGE; return -1; }`). Source: `src/libsodium/sodium/codecs.c`.
- **libbase64 ignores padding entirely** — it is a stream codec: `base64_encode` writes `=` only at a real end because the wrapper knows the full length, but the streaming API "Does not zero-terminate or finalize the output" and finalisation is a separate call. Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.
- **libb64's padding is spread across calls**: `base64_encode_block` never emits `=`, and `base64_encode_blockend` emits them based on the carried step: `case step_B: … *codechar++ = '='; *codechar++ = '=';` / `case step_C: … *codechar++ = '=';`. Source: <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>.

### 7.4 Trailing bits / canonicality

RFC 4648 §3.5 is the normative statement: pad bits "MUST be set to zero by conforming encoders" and "If this property do not hold, there is no canonical representation of base-encoded data, and multiple base-encoded strings can be decoded to the same binary data… decoders MAY chose to reject an encoding if the pad bits have not been set to zero." §12 adds the attack framing: "When padding is used, there are some non-significant bits that warrant security concerns, as they may be abused to leak information or used to bypass string equality comparisons or to trigger implementation problems." Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

The security framing is not theoretical — it has a paper: "Base64 Malleability in Practice" documents that "multiple different encodings can successfully decode into the same data, effectively breaking string uniqueness guarantees" and found that "most of today's base64 decoder libraries are not 100% compatible in their default settings." Source: <https://eprint.iacr.org/2022/361>.

Who checks canonicality in C:
- **gnulib: yes, hard-rejects** (see 7.3). This is the strongest stance in the survey.
- **glibc `b64_pton`: yes**, with the explicit subliminal-channel comment; but note it only checks the *last* partial byte (`if (target && target[tarindex] != 0) return (-1);`).
- **libsodium: yes, always** — independent of variant: `if (acc_len > 4U || (acc & ((1U << acc_len) - 1U)) != 0U) { ret = -1; }`. Source: `src/libsodium/sodium/codecs.c`.
- **OpenSSL: no.** There is no trailing-bit check anywhere in `evp_decodeblock_int`; it just shifts and masks. Source: `crypto/evp/encode.c`.
- **libb64: no.** `base64_decode_value` masks (`*plainchar++ |= (fragment & 0x03f);`) without validating the discarded bits. Source: <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>.
- **libbase64: no trailing-bit check documented**, and its leniency is a stated design goal elsewhere (it offers codec-forcing flags, not strictness flags). Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.

### 7.5 Non-alphabet input characters

RFC 4648 takes the strict line by default: "Implementations MUST reject the encoded data if it contains characters outside the base alphabet when interpreting base-encoded data, unless the specification referring to this document explicitly states otherwise", with the MIME-style ignore approach named as the alternative and the covert-channel warning attached (§3.3, repeated in §12). Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

C implementations split three ways:
- **Lenient by default:** OpenSSL EVP (whitespace/LF/CR ignored; `-` = PEM soft end-of-input), OpenSSL BIO ("initial lines that contain non-base64 content (whitespace is tolerated and ignored) are skipped"), glibc `b64_pton` ("Skip whitespace anywhere."), libb64 (skips *any* invalid byte silently). Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://docs.openssl.org/master/man3/BIO_f_base64/>, <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>.
- **Strict by default, leniency opt-in:** gnulib's `base64_decode_ctx` rejects any "non-alphabet, non-newline character" (newlines are always allowed in the ctx path — `get_4` filters `'\n'`); the CLI adds `-i, --ignore-garbage`. libsodium has no default leniency but takes an explicit whitelist: `ignore` is "an optional set of characters to ignore (typically: whitespaces and newlines)", implemented as `strchr(ignore, c) != NULL`; RFC 4648 §3.3's "MUST reject" is the default when `ignore == NULL`. Sources: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://doc.libsodium.org/helpers>, `src/libsodium/sodium/codecs.c`.
- **Libbase64's `flags` argument is about SIMD codecs, not leniency** — the only per-call switch is which implementation to force (`BASE64_FORCE_PLAIN` etc.). Source: <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>. Corrupted input handling is reported, not repaired: `Returns 1 if all is well, and 0 if a decoding error was found`. Source: <https://github.com/aklomp/base64>.

## 8. Timeouts

Not applicable in the literal sense: base64 encode/decode is pure computation. **No C implementation in this survey exposes a timeout, deadline, cancellation token or interrupt parameter.** There is no blocking resource of its own to time out (section 6).

Closest analogues, for completeness:
- **Timeouts belong to the underlying I/O, not to the codec.** OpenSSL says so directly: "It is possible for a BIO to block indefinitely if the underlying I/O structure cannot process or return any data… one solution is to use non blocking I/O and use a timeout on the select() (or equivalent) call." So the base64 filter BIO inherits whatever timeout the socket/file BIO has, and the recommended mechanism is `select()` with a timeout plus `BIO_should_retry()`. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/BIO_should_retry.pod>.
- **OpenSSL's retry protocol is the nearest thing to cancellation:** the caller decides when to retry or give up based on `BIO_should_read()`, `BIO_should_write()`, `BIO_should_io_special()`. There is no "abort" entry point that unwinds a partially encoded stream. Source: same.
- **OpenSSL's finalisation is a flush, not a cancel:** "BIO_flush() on a base64 BIO that is being written through is used to signal that no more data is to be encoded: this is used to flush the final block through the BIO." Source: <https://docs.openssl.org/master/man3/BIO_f_base64/>. The equivalent in the EVP API is `EVP_EncodeFinal`/`EVP_DecodeFinal`, both of which are mandatory-in-practice but return no partial-result object (section 9).
- **`EVP_ENCODE_CTX_copy` is the only "checkpoint" primitive in the survey:** "EVP_ENCODE_CTX_copy() can be used to copy a context sctx to a context dctx. dctx must be initialized before calling this function." A caller could snapshot and abandon a stream, but this is a copy, not a cancellation. Source: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
- **libbase64 exposes only a completion flag, not a deadline:** `struct base64_state { int eof; int bytes; int flags; unsigned char carry; };` — the `eof` flag plus the `bytes`/`carry` leftovers are the whole progress state, and "Finalizes the output begun by previous calls to base64_stream_encode(). Adds the required end-of-stream markers if appropriate." Source: <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.
- **Panic/abort is the failure mode for programming errors, not for input, in libsodium:** `sodium_misuse()` is `__attribute__ ((noreturn))` and is invoked when the caller violates the buffer-size or variant contract. That is the only "uncancellable" path in the survey. Sources: `src/libsodium/include/sodium/core.h`, `src/libsodium/sodium/codecs.c` in <https://github.com/jedisct1/libsodium>.
- **`assert`/`abort` appears inside glibc's encoder:** `#define Assert(Cond) if (!(Cond)) abort()` guards `Assert(output[0] < 64)` etc. after the bit shifts — also an internal-consistency check, not an input verdict. Source: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.
- **`GUESS:`** no timeout/cancellation surface exists beyond the above, and no source was found stating that one is planned; the absence should be re-checked at implementation time if it matters.

## 9. Streaming (adapted Q9: incremental/chunked encode/decode with leftover bytes)

### 9.1 Why C needs streaming at all

Base64 groups 3 input bytes into 4 output characters, so any chunked encoder must carry 0-2 leftover input bytes, and any chunked decoder must carry 0-3 leftover symbols (or 0-1 partial output byte). RFC 4648's own test vectors (`BASE64("f") = "Zg=="`, `BASE64("fo") = "Zm8="`, `BASE64("foo") = "Zm9v"`, …, §10) are the round-trip corpus that fixes the boundary cases; the MIME/PEM line rules come from §3.1 ("MIME enforces a limit on line length of base 64-encoded data to 76 characters… PEM uses a line length of 64 characters"). Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>.

### 9.2 OpenSSL EVP — explicit init/update/final with internal buffering

- Encode: `EVP_EncodeInit` → N× `EVP_EncodeUpdate` → `EVP_EncodeFinal`. Leftovers are the library's problem: "Only full blocks of data (48 bytes) will be immediately processed and output by this function. Any remainder is held in the ctx object and will be processed by a subsequent call to EVP_EncodeUpdate() or EVP_EncodeFinal()." The context size is fixed and public: `unsigned char enc_data[80]`.
- The leftover count is queryable: `EVP_ENCODE_CTX_num()` "will return the number of as yet unprocessed bytes still to be encoded or decoded that are pending in the ctx object."
- `EVP_EncodeFinal` "must be called at the end of an encoding operation. It will process any partial block of data remaining in the ctx object", and its output bound is documented ("never more than 65 bytes plus an additional NUL terminator").
- Decode: `EVP_DecodeUpdate` buffers "Residual input shorter than the internal chunk size… if its length is not a multiple of 4 (including any padding)"; a residual that *is* a multiple of 4 is decoded immediately ("legacy behaviour: if the current line is a full base64-block, it is processed immediately. We keep this behaviour as applications may not be calling EVP_DecodeFinal properly" — source comment in `crypto/evp/encode.c`). `EVP_DecodeFinal` "will never decode additional data" but errors (-1) if the residue is unpadded.
- The return code of `EVP_DecodeUpdate` is the streaming signal: `-1` = error, `0` = "no more non-padding base64 characters are expected", `1` = ordinary progress. The docs require the caller to enforce this: "the caller is responsible for checking and rejecting a 0 return value in the middle of content."
Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, `crypto/evp/encode.c` and `crypto/evp/evp_local.h` in <https://github.com/openssl/openssl>.

### 9.3 OpenSSL BIO — streaming without a final call

"For writing, by default output is divided to lines of length 64 characters and there is a newline at the end of output. This behavior can be changed with BIO_FLAGS_BASE64_NO_NL flag." Finalisation is a flush: "BIO_flush() on a base64 BIO that is being written through is used to signal that no more data is to be encoded: this is used to flush the final block through the BIO." On read, the BIO skips junk until it finds plausible base64 (a 1024-byte first-line rule) and stops on padding or `-`; the man page itself calls the `-` heuristic a bug: "It is just a heuristic, and sufficiently unusual input could produce unexpected results." Sources: <https://docs.openssl.org/master/man3/BIO_f_base64/>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/BIO_should_retry.pod>.

### 9.4 gnulib — asymmetric by design: streaming decode only

- `struct base64_decode_context { int i; char buf[4]; };` is exactly the leftover mechanism: "If CTX->i is 0 or 4, there are four or more bytes in [*IN..IN_END), and none of those four is a newline, then return *IN. Otherwise, copy up to 4 - CTX->i non-newline bytes from that range into CTX->buf, starting at index CTX->i… and return CTX->buf." The docs name the purpose: "It is necessary for when a quadruple of base64 input bytes spans two input buffers." Passing `inlen == 0` flushes the context (`flush_ctx = inlen == 0`).
- Newlines are handled as a special case rather than by filtering: "Handle the common case of 72-byte wrapped lines. This also handles any other multiple-of-4-byte wrapping." (`if (inlen && *in == '\n' && ignore_newlines)`).
- **The encoder is stateless in the library**, and the caller guarantees why that is safe: `#define ENC_BLOCKSIZE (1024*3*10)`, `verify (ENC_BLOCKSIZE % 12 == 0);` with the comment "Process input one block at a time. Note that ENC_BLOCKSIZE % 3 == 0, so that no base64 pads will appear in output." The CLI keeps the leftover *state* (the current column) itself: `static void wrap_write (const char * buffer, size_t len, uintmax_t wrap_column, size_t *current_column, FILE *out)`.
- Line wrapping is a CLI feature, not a codec feature, with `wrap_column = 76` by default (`--wrap=COLS`, 0 disables).
Sources: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>, <https://raw.githubusercontent.com/projectgnu/coreutils/master/src/base64.c>, <https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html>.

### 9.5 libbase64 — init / encode / final, with the leftover byte explicit

```c
base64_stream_encode_init(&state, 0);
while ((nread = fread(buf, 1, sizeof(buf), stdin)) > 0) {
    base64_stream_encode(&state, buf, nread, out, &nout);
    if (nout) fwrite(out, nout, 1, stdout);
}
base64_stream_encode_final(&state, out, &nout);
```
That loop is verbatim from the project README's example. The state "does not zero-terminate or finalize the output", and the leftover is stored in `unsigned char carry` with a `int bytes` counter; the decoder is the same shape (`base64_stream_decode_init` → `base64_stream_decode`, no final call) and reports `Returns 1 if all is well, and 0 if a decoding error was found`. Decoding is done "in massive 64-byte chunks" for NEON, which is why the API cannot be line-oriented. Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.

### 9.6 libb64 — coroutine-style state machine, asymmetry in finalisation

`base64_encode_block` returns the bytes written and stores the partial step in the state (`state_in->result`, `state_in->step`); the caller then calls `base64_encode_blockend(code_out, state_in)` once, which emits the remaining symbol plus `=` as needed. The decoder mirrors the state machine (`step_a`…`step_d`, `state_in->plainchar`) but has **no `blockend` counterpart** — a truncated stream simply returns fewer bytes. The README explains the implementation technique and its cost: "The C code uses a little trick which has been used to implement coroutines… The obvious problem with any such routine is the static keyword… What is needed is a structure for storing these variables, which is passed to the routine separately. This obviously breaks the modularity of the function, since now the caller has to worry about and care for the internal state of the routine." Line wrapping is built into the encoder as `size_t chars_per_line` (default `BASE64_CENC_DEFCPL 0` = off) with a `CHECK_BREAK()` macro that inserts `\n` mid-state-machine. Sources: <https://raw.githubusercontent.com/libb64/libb64/master/README.md>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>.

### 9.7 libsodium — deliberately NOT streaming

libsodium has no incremental API: one call per buffer, with the caller computing the exact output size via `sodium_base64_encoded_len`/`sodium_base64_ENCODED_LEN`. Its stated rationale for the helper is that guessing is unsafe: "Computing a correct size for b64_maxlen is not straightforward and depends on the chosen variant." Sources: <https://doc.libsodium.org/helpers>, `src/libsodium/include/sodium/utils.h`.

### 9.8 Line wrapping summary

Line wrapping is a *policy* in C, not part of the codec's identity: OpenSSL EVP hardcodes 64 + `\n` unless you avoid the block API; libb64 makes it a state field (`chars_per_line`, `CHECK_BREAK()`); coreutils makes it a CLI column counter (`--wrap=COLS`, default 76); libsodium and libbase64 do not wrap at all (libbase64's README documents no wrapping and its benchmark harness feeds 10 MB buffers). RFC 4648 forbids automatic wrapping in the default case: "Implementations MUST NOT add line feeds to base-encoded data unless the specification referring to this document explicitly directs base encoders to add line feeds after a specific number of characters." (§3.1). Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>, <https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html>, <https://github.com/aklomp/base64>, <https://www.rfc-editor.org/rfc/rfc4648.txt>.

## 10. Interesting design decisions

1. **OpenSSL ships two unrelated APIs for the same job, and they teach different lessons.** The EVP API (`EVP_Encode*`/`EVP_Decode*`) is a stateful init/update/final codec with a caller-owned output buffer; the BIO API (`BIO_f_base64`) is a *filter in a pipeline* where base64 is invisible to the caller. The BIO model is the only C design in this survey that makes the codec composable with arbitrary I/O (socket, file, memory) without changing the base64 calls. Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man7/bio.pod>, <https://docs.openssl.org/master/man3/BIO_f_base64/>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
2. **OpenSSL's sentinel-table decoder is a single artefact that encodes alphabet, whitespace policy and PEM behaviour at once.** `data_ascii2bin[128]` maps `'\n'`→`0xF0`, `'\r'`→`0xF1`, `'-'`→`0xF2`, space/TAB→`0xE0`, `'='`→`0x00`, every other non-alphabet byte→`0xFF`; the decode loop then only needs to branch on the sentinel. A second table (`srpdata_ascii2bin`) swaps the alphabet without touching the algorithm. Source: `crypto/evp/encode.c` in <https://github.com/openssl/openssl>.
3. **gnulib's split between `base64_encode` (stateless) and `base64_decode_ctx` (stateful) is a deliberate asymmetry with a stated precondition.** The encoder can be stateless because the caller feeds multiples of 12 bytes (`ENC_BLOCKSIZE % 12 == 0`), so no padding can ever appear mid-stream; the decoder cannot have that guarantee, so it gets a 4-byte context. This is the cleanest "state only where it is unavoidable" argument in the survey. Sources: <https://raw.githubusercontent.com/projectgnu/coreutils/master/src/base64.c>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
4. **gnulib is the only surveyed C codec that rejects non-canonical trailing bits in its default decoder** ("Reject non-canonical encodings."), and it does so with two cheap mask tests (`& 0x0f`, `& 0x03`). This is the C implementation of RFC 4648 §3.5's MAY-reject option. Source: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
5. **glibc's `b64_pton` documents the security reason for that check inline**: "If we don't check them, they become a subliminal channel" — and it is the only C code in the survey that names the covert-channel issue in the source. Source: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>.
6. **libsodium makes the variant an explicit integer, not an alphabet string.** Four `#define`s (1/3/5/7), a mask-based check (`VARIANT_NO_PADDING_MASK 0x2U`, `VARIANT_URLSAFE_MASK 0x4U`) and a caller-computed size helper (`sodium_base64_encoded_len`, `sodium_base64_ENCODED_LEN`) keep the API to two functions while still covering four codecs. Sources: `src/libsodium/include/sodium/utils.h`, `src/libsodium/sodium/codecs.c`, <https://doc.libsodium.org/helpers>.
7. **libsodium separates "my data is bad" from "my buffer is bad" by mechanism, not by return code.** Buffer/variant violations call `sodium_misuse()` (`noreturn`); data violations return -1 with `errno` set (`EINVAL` vs `ERANGE`). It is the only surveyed library that refuses to let a size mistake look like a data mistake. Sources: `src/libsodium/sodium/codecs.c`, `src/libsodium/include/sodium/core.h`.
8. **libsodium is constant-time on purpose, and says how.** The byte⇄char conversion is arithmetic, not table lookup: `static int b64_byte_to_char(unsigned int x)` is a chain of `LT`/`GE`/`EQ` masks with no data-dependent branch, and the same technique is used for hex (`sodium_hex2bin`) and IP address parsing. Sources: `src/libsodium/sodium/codecs.c`, <https://doc.libsodium.org/helpers>. This is a design axis no other C library in the survey exposes at all.
9. **libbase64 turns "which implementation runs" into a parameter rather than a build-time secret.** `#define BASE64_FORCE_AVX2 (1 << 0)` … `BASE64_FORCE_PLAIN (1 << 3)`, with "Set flags to 0 for the default behavior, which is runtime feature detection on x86, a compile-time fixed codec on ARM, and the plain codec on other platforms." It also reports *why* it could not decode at the codec level: `Returns -1 if the chosen codec is not included in the current build.` Sources: <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>, <https://github.com/aklomp/base64>.
10. **libbase64 documents its SIMD/portability trade-off honestly, including the one place where runtime detection is impossible.** "NEON support is hardcoded to on or off at compile time, because portable runtime feature detection is unavailable on ARM" and "NEON support can unfortunately not be portably detected at runtime from userland (the mrc instruction is privileged)", with `BASE64_FORCE_PLAIN` offered as the manual downgrade. Sources: <https://github.com/aklomp/base64>.
11. **libb64's coroutine state machine is a cautionary design study, not a model.** It makes the encoder resumable at any byte boundary with no buffering, but the README admits the cost: "This obviously breaks the modularity of the function, since now the caller has to worry about and care for the internal state of the routine." The decoder has no finaliser, so truncation is silent. Sources: <https://raw.githubusercontent.com/libb64/libb64/master/README.md>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>.
12. **The bcrypt alphabet is a reminder that base64 is a family of codecs with incompatible alphabets, and that C pays for it with separate tables.** crypt_blowfish hardcodes `./A-Za-z0-9` in `BF_itoa64`/`BF_atoi64` and even keeps a compatibility bug: "This has to be bug-compatible with the original implementation, so only encode 23 of the 24 bytes." Source: <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c>.
13. **Coreutils moves wrapping and leniency out of the codec and into flags, with an explicit default.** `-w, --wrap=COLS wrap encoded lines after COLS character (default 76). Use 0 to disable line wrapping`, `-i, --ignore-garbage`. The codec library itself stays policy-free; the policy lives in the tool. Sources: <https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html>, <https://raw.githubusercontent.com/projectgnu/coreutils/master/src/base64.c>.

## 11. Decisions NOT to copy

1. **Do not copy libb64's silent decoder.** `base64_decode_block` skips every invalid byte (`while (fragment < 0)`) and has no finaliser, so corrupt and truncated input are indistinguishable from valid input. A predictable library must have an error path and an explicit end-of-stream call. Sources: <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cdecode.h>.
2. **Do not copy OpenSSL's "return 0 means end of input" as a *success* signal.** It is a tri-state `int` where -1, 0 and 1 all occur, the context does not remember the end-of-input state, and the documentation pushes the check onto the caller: "the caller is responsible for checking and rejecting a 0 return value in the middle of content." Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, `crypto/evp/encode.c`.
3. **Do not copy libsodium's `sodium_misuse()` for buffer-size mistakes.** Aborting the process because a caller passed a short output buffer is unacceptable in a library that advertises predictability; a size error should be a returned error (Rust's `OutputSliceTooSmall` is the reference for that). Sources: `src/libsodium/sodium/codecs.c`, `src/libsodium/include/sodium/core.h` in <https://github.com/jedisct1/libsodium>.
4. **Do not copy libsodium's hidden `errno` channel.** The public docs promise only "returns 0 on success" / "-1"; the `EINVAL`/`ERANGE` distinction is only visible in the source. A predictable API should carry the distinction in its documented return type. Sources: <https://doc.libsodium.org/helpers>, `src/libsodium/sodium/codecs.c`.
5. **Do not copy OpenSSL's implicit line wrapping in the encoder.** `EVP_EncodeUpdate` inserts `\n` unconditionally unless the caller avoids the block path, and RFC 4648 §3.1 says the default must be *no* line feeds. Wrapping belongs behind an explicit option. Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://www.rfc-editor.org/rfc/rfc4648.txt>.
6. **Do not copy the "NUL terminator written into the caller's buffer" convention.** glibc's `b64_ntop` appends `'\0'` ("Returned value doesn't count \0"), OpenSSL reserves a byte for it, and gnulib zero-terminates only "If OUTLEN is larger than BASE64_LENGTH(INLEN)". A length-carrying API needs no terminator, and the requirement silently inflates buffer-size math. Sources: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>.
7. **Do not copy the PEM `-` heuristic.** OpenSSL treats a hyphen as "soft end-of-input", and its own man page flags it as a bug: "The hyphen character (-) is treated as an ad hoc soft end-of-input character… It is just a heuristic, and sufficiently unusual input could produce unexpected results. There should perhaps be some way of specifying a test that the BIO can perform to reliably determine EOF (for example a MIME boundary)." Sources: <https://docs.openssl.org/master/man3/BIO_f_base64/>.
8. **Do not copy the "write as many bytes as possible" truncation contract.** gnulib documents it explicitly ("If OUTLEN is less than BASE64_LENGTH(INLEN), write as many bytes as possible"), and libbase64 pushes the sizing onto prose ("take some margin"). Silent partial output is exactly the kind of surprise a low-vision caller cannot debug. Sources: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.
9. **Do not copy a per-call "which implementation" flag into the public API.** `flags` exists in libbase64 "Mainly there for testing purposes" and encodes CPU features (`BASE64_FORCE_AVX2`, …). MojoAkku should not expose a caller-visible switch over dispatch internals. Source: <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.
10. **Do not copy libbase64's "-1 = codec not compiled in" return value.** It overloads the error channel with a build-configuration fact: `Returns -1 if the chosen codec is not included in the current build. Used by the test harness to check whether a codec is available for testing.` Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>.
11. **Do not copy the "caller must strip padding from the returned length" contract.** `EVP_DecodeBlock` returns `3 * n/4` and tells the caller to ignore trailing bytes ("the caller is responsible for taking trailing padding into account"); this is the C version of Go's `DecodedLen` trap. Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>.
12. **Do not make strictness a build-time or hidden property.** C's strictest decoder (gnulib) and its most lenient (OpenSSL, libb64) both *look* like "the base64 decoder"; the difference is only discoverable by reading source or man pages. RFC 4648 §3.3 makes leniency the explicit exception, so the strictness choice must be visible at the call site. Sources: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>, <https://www.rfc-editor.org/rfc/rfc4648.txt>.

## 12. Ideas fitting Mojo

Mojo facts are **not** asserted here; per project rule they are looked up in the `mojov1` buch (page `stdlib/base64`) before use. The buch records the current Mojo state as four functions — `b64encode`, `b64decode`, `b16encode`, `b16decode` — with one-line descriptions and no alphabet parameter ("The package exposes the standard functions; there is no exposed alphabet parameter on these four"), and marks the package **unstable by default** because it carries no `@stable(since=...)` marker. Source: buch `mojov1`, page `stdlib/base64` (mirrored from <https://mojolang.org/docs/std/base64/>). The points below name *properties of the C designs* and how they could map onto Mojo features; each Mojo-side mapping is marked `GUESS:` because no source states it.

1. **C proves that "no allocation by the codec" is a viable and testable contract — and Mojo can make it a type fact.** libbase64 states "Does not dynamically allocate memory", gnulib's core `base64_encode` takes a caller buffer, and libb64/libbase64 both pass a by-value state struct. In Mojo this is an `out` slice plus a value-semantics state; the C evidence is that the whole family of codecs fits without heap use. Sources: <https://github.com/aklomp/base64>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>. GUESS: the Mojo `out`-slice mapping is a design extrapolation, not a sourced fact.
2. **The gnulib asymmetry (stateless encode, stateful decode) is the right starting shape.** C's best-maintained implementation only adds stream state where it is unavoidable, and justifies it with a precondition (`ENC_BLOCKSIZE % 12 == 0`). MojoAkku can mirror this: an encode entry point that needs no state beyond the buffer, and a decode state that carries at most 3 leftover symbols. Sources: <https://raw.githubusercontent.com/projectgnu/coreutils/master/src/base64.c>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>. GUESS: the MojoAkku mirroring proposal is a design extrapolation, not a sourced fact.
3. **Model the leftover explicitly, as C does with fixed-size fields.** `struct base64_decode_context { int i; char buf[4]; }`, `struct base64_state { …; unsigned char carry; }` and libb64's `step`/`result`/`plainchar` all encode the leftover in a few bytes with a documented invariant. This is testable: a chunked round trip with chunk sizes 1..N must equal a single-shot round trip. Sources: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>. GUESS: the Mojo leftover-modelling proposal is a design extrapolation, not a sourced fact.
4. **Carry the error kind, which no library in this survey does.** The C column's weakest point is error reporting: glibc returns bare -1, OpenSSL's `EVP_DecodeUpdate` uses a tri-state whose 0 means "end of payload" while the context does not remember that end-of-input state (so the caller has to reject a 0 in mid-stream itself), and libb64 has no error at all. Mojo's `raises` can express distinct failures where C could not. Sources: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>. GUESS: the Mojo mapping is not source-backed (the C facts above are).
5. **Separate "bad input" from "bad buffer" explicitly — and do it better than libsodium.** C shows both extremes: libsodium aborts via `sodium_misuse()` on a size mistake while libbase64/gnulib silently truncate. A Mojo design should return a size error rather than abort or truncate. Sources: `src/libsodium/sodium/codecs.c`, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>. GUESS: the Mojo size-error proposal is a design extrapolation, not a sourced fact.
6. **Canonicality should be a first-class, checked property, because C shows the cost of omitting it.** Only gnulib and glibc check trailing bits in C; OpenSSL, libb64 and libbase64 do not, and the malleability paper documents the consequence. RFC 4648 §3.5 says pad bits MUST be zero. Sources: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>, `crypto/evp/encode.c`, <https://eprint.iacr.org/2022/361>, <https://www.rfc-editor.org/rfc/rfc4648.txt>. GUESS: the "first-class checked property" proposal is a design extrapolation, not a sourced fact.
7. **Padding belongs on two orthogonal axes, as libsodium's variant mask shows.** libsodium covers four codecs with two bits (`VARIANT_URLSAFE_MASK`, `VARIANT_NO_PADDING_MASK`) and a variant integer; C's other libraries hardcode one combination each. Source: `src/libsodium/sodium/codecs.c`, <https://doc.libsodium.org/helpers>. GUESS: the "two orthogonal axes" Mojo proposal is a design extrapolation, not a sourced fact.
8. **Alphabets should be compile-time-checkable values, and C shows why.** In C the alphabet is a string or a table selected at runtime (`data_ascii2bin` vs `srpdata_ascii2bin`, `BF_itoa64`, `Base64[]`, `b64c[64]`), and nothing prevents the pad symbol from being placed in the middle. Making an invalid alphabet a compile-time error removes a whole error class. Sources: `crypto/evp/encode.c`, <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c>, <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>. GUESS: the compile-time-alphabet proposal is a design extrapolation, and the Mojo half is to be verified against `mojov1`.
9. **Keep line wrapping out of the core codec, and make it an explicit opt-in layer.** C demonstrates three placements (OpenSSL hardcodes it in the encoder; libb64 makes it a state field with a `CHECK_BREAK()` macro; coreutils makes it a CLI column counter defaulting to 76) and RFC 4648 §3.1 forbids it by default. MojoAkku should default to no wrapping. Sources: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>, <https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html>, <https://www.rfc-editor.org/rfc/rfc4648.txt>. GUESS: the "keep wrapping out of the core codec" proposal is a design extrapolation, not a sourced fact.
10. **Leniency should be an explicit, named parameter, following libsodium's `ignore` rather than a global mode.** libsodium takes "an optional set of characters to ignore (typically: whitespaces and newlines)" as a per-call argument and otherwise honours RFC 4648 §3.3's MUST-reject default. That is the most inspectable leniency design in C. Sources: <https://doc.libsodium.org/helpers>, `src/libsodium/sodium/codecs.c`. GUESS: the "leniency as explicit named parameter" Mojo proposal is a design extrapolation, not a sourced fact.
11. **Do not treat constant-time as irrelevant, but keep it a separate mode.** libsodium's arithmetic `b64_byte_to_char`/`b64_char_to_byte` (built from `LT`/`GE`/`EQ` masks, no lookup table, no data-dependent branch) proves that base64 can leak through table lookups, which matters for PEM/key-adjacent data. Sources: `src/libsodium/sodium/codecs.c`, <https://doc.libsodium.org/helpers>. GUESS: the "keep constant-time a separate mode" proposal is a design extrapolation, not a sourced fact.
12. **The NUL-terminator-free, length-carrying API is the simpler one.** glibc, OpenSSL and libb64/libbase64 all differ on terminators and length conventions; the two APIs with a single clean "returns the number of bytes written" rule (gnulib's core `base64_encode`, libbase64's `outlen`) are the easiest to use correctly. 
Sources: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>, <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>, <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>, <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>. GUESS: the "NUL-terminator-free is simpler" judgement is a design extrapolation, not a sourced fact.

## Sources

Normative reference:
- RFC 4648, "The Base16, Base32, and Base64 Data Encodings" (Josefsson, 2006) — used for §3.1 line feeds, §3.2 padding, §3.3 non-alphabet characters, §3.4 choosing the alphabet, §3.5 canonical encoding, §4/§5 alphabets, §10 test vectors, §11 ISO C99 implementation pointer, §12 security considerations: <https://www.rfc-editor.org/rfc/rfc4648.txt>

Absence-of-stdlib evidence:
- C standard library header index (no base64 header exists): <https://en.cppreference.com/w/c/header>

OpenSSL (block/stream API):
- `EVP_EncodeInit`, `EVP_EncodeUpdate`, `EVP_EncodeFinal`, `EVP_EncodeBlock`, `EVP_DecodeInit`, `EVP_DecodeUpdate`, `EVP_DecodeFinal`, `EVP_DecodeBlock`, `EVP_ENCODE_CTX_*`: <https://docs.openssl.org/master/man3/EVP_EncodeInit/> and source pod <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/EVP_EncodeInit.pod>
- declarations and `EVP_ENCODE_LENGTH`/`EVP_DECODE_LENGTH` macros: <https://raw.githubusercontent.com/openssl/openssl/master/include/openssl/evp.h>
- implementation (sentinel tables, `EVP_ENCODE_B64_LENGTH 48`, legacy comments): <https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/encode.c>
- context struct `evp_Encode_Ctx_st`: <https://raw.githubusercontent.com/openssl/openssl/master/crypto/evp/evp_local.h>

OpenSSL (BIO filter):
- `BIO_f_base64` man page: <https://docs.openssl.org/master/man3/BIO_f_base64/> and pod <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/BIO_f_base64.pod>
- `bio` overview (filter BIOs, chains, blocking): <https://raw.githubusercontent.com/openssl/openssl/master/doc/man7/bio.pod>
- `BIO_should_retry` and the select()-based timeout pattern: <https://raw.githubusercontent.com/openssl/openssl/master/doc/man3/BIO_should_retry.pod>

Glibc / BIND resolver:
- `b64_ntop` / `b64_pton` declarations: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/resolv.h>
- implementation: <https://raw.githubusercontent.com/bminor/glibc/master/resolv/base64.c>

Gnulib / GNU coreutils:
- `base64.h`: <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.h>
- `base64.c` (encode/decode, canonicality checks, sizing contract): <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base64.c>
- coreutils `src/base64.c` (CLI, wrapping, `--ignore-garbage`): <https://raw.githubusercontent.com/projectgnu/coreutils/master/src/base64.c>
- coreutils manual `base64 invocation`: <https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html>
- Josefsson's project page (gnulib/coreutils provenance, RFC 4648bis): <https://josefsson.org/base-encoding/>

libsodium:
- Helpers documentation (base64 variants, `ignore`, `b64_end`, size helper): <https://doc.libsodium.org/helpers>
- header (variant `#define`s, `sodium_base64_ENCODED_LEN`, signatures): <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/utils.h>
- implementation (variant masks, constant-time conversions, `sodium_misuse`): <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/sodium/codecs.c>
- `sodium_misuse` declaration: <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/core.h>
- license (ISC): <https://raw.githubusercontent.com/jedisct1/libsodium/master/LICENSE>

libbase64 (aklomp/base64):
- README (features, SIMD/OpenMP, API reference, benchmark caveats): <https://github.com/aklomp/base64>
- header (`base64_state`, stream API, `BASE64_FORCE_*`): <https://raw.githubusercontent.com/aklomp/base64/master/include/libbase64.h>

libb64:
- README (fork history, licensing motivation, coroutine rationale): <https://raw.githubusercontent.com/libb64/libb64/master/README.md>
- `cencode.h` / `cdecode.h`: <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cencode.h>, <https://raw.githubusercontent.com/libb64/libb64/master/include/b64/cdecode.h>
- `cencode.c` / `cdecode.c`: <https://raw.githubusercontent.com/libb64/libb64/master/src/cencode.c>, <https://raw.githubusercontent.com/libb64/libb64/master/src/cdecode.c>

Alphabet evidence outside RFC 4648:
- crypt_blowfish `BF_itoa64`/`BF_atoi64` and the bcrypt alphabet: <https://raw.githubusercontent.com/openwall/crypt_blowfish/master/crypt_blowfish.c>

Security background:
- "Base64 Malleability in Practice", Chatzigiannis & Chalkias (AsiaCCS 2022), ePrint 2022/361 — non-canonical encodings, decoder incompatibility: <https://eprint.iacr.org/2022/361>

Error-representation convention:
- `errno(3)` (significance only on error, thread-locality): <https://man7.org/linux/man-pages/man3/errno.3.html>

Mojo side (read from the buch, not researched):
- buch `mojov1`, page `stdlib/base64` (the four functions, no alphabet parameter, unstable-by-default stability) — mirrored from <https://mojolang.org/docs/std/base64/>
