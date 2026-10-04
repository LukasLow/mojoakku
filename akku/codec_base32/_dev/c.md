# base32 research: C

## 1. Standard library support

C has **no standard-library base32 (or base64/base16) codec**. The ISO C
standard library interface is defined by a fixed header list — `<assert.h>`,
`<ctype.h>`, `<stdint.h>`, `<stdio.h>`, `<stdlib.h>`, `<string.h>`, ... — and
none of them covers base-N encoding. (Source:
https://en.cppreference.com/w/c/header)

C users therefore get base32 from non-standard sources, and the field is much
thinner than for base64:

| Provider | Function family | Header / origin | base32? |
| --- | --- | --- | --- |
| gnulib / coreutils | `base32_encode*` / `base32_decode*` | `"base32.h"` | yes (the clean library entry point) |
| coreutils CLI | `base32` command | `<https://www.man7.org/linux/man-pages/man1/base32.1.html>` | yes (CLI only) |
| OpenSSL / BoringSSL | `EVP_Encode*` / `EVP_Decode*` | `<openssl/evp.h>` | **no base32** |
| libsodium | `sodium_bin2base64*` | `<sodium/utils.h>` | **no base32** |
| glibc/BSD libresolv | `b64_ntop` / `b64_pton` | `<resolv.h>` | **no base32** |
| mbedTLS | `mbedtls_base64_*` | `<mbedtls/base64.h>` | **no base32** |

The reason is that base32 was only standardized in RFC 4648 (2006), after the
crypto libraries' codec surfaces were fixed around base64. gnulib is the
exception: it ships a first-class `base32` module adapted from Simon Josefsson's
base64 code by Gijs van Tulder. (Source:
https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base32.c)

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page reads "The package has exactly four functions" — `b64encode`, `b64decode`,
`b16encode`, `b16decode` — and a `buch_search` for "base32" returns no hits.
(Source: `mojov1` buch `stdlib/base64`.)

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | base32 |
| --- | --- | --- | --- | --- |
| gnulib | GNU/FSF | coreutils dependency | LGPL-2.1-or-later | standard only, padded |
| coreutils `base32` | GNU | ubiquitous CLI | GPL | standard only |
| aklomp/base64 | Alfred Klomp | active, SIMD | BSD-2-Clause | base64 only (C++ file `cpp.md` §2) |
| OpenSSL / BoringSSL | OpenSSL Foundation / Google | ubiquitous | Apache-2.0 | base64 only |
| libsodium | Frank Denis | stable | ISC | base64 + hex; no base32 |
| mbedTLS | TrustedFirmware | LTS | Apache-2.0 | base64 only |

Sources:
- gnulib base32 license header "GNU Lesser General Public License … version 2.1
  or later": <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base32.h>.
- coreutils `base32` CLI: <https://www.man7.org/linux/man-pages/man1/base32.1.html>.
- libsodium has no base32: <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/utils.h>.
- mbedTLS base64 only: <https://raw.githubusercontent.com/Mbed-TLS/mbedtls/master/include/mbedtls/base64.h>.

(Assessment: derived from the sources above: C's base32 story is essentially
"gnulib if you already depend on GNU"; the crypto ecosystem never adopted it.
This is a sharper version of the C base64 split in `c.md` §2.)

## 3. Exposed APIs

**gnulib** (`"base32.h"`, the canonical C base32 API; source
<https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base32.h>):

- `#define BASE32_LENGTH(inlen) ((((inlen) + 4) / 5) * 8)` — the base32 quantum
  formula exposed as a macro (contrast base64's `((((inlen) + 2) / 3) * 4)`).
- `extern signed char const base32_to_int[256];` and inline predicates
  `isubase32(unsigned char ch)` / `isbase32(char ch)`.
- `void base32_encode(const char *restrict in, idx_t inlen, char *restrict out,
  idx_t outlen);` — "If OUTLEN is less than BASE32_LENGTH(INLEN), write as many
  bytes as possible. If OUTLEN is larger than BASE32_LENGTH(INLEN), also zero
  terminate the output buffer."
- `idx_t base32_encode_alloc(const char *in, idx_t inlen, char **out);` —
  allocating variant; "On return, the OUT variable will hold a pointer to newly
  allocated memory that must be deallocated by the caller". Returns the length
  excluding the NUL, `0` on overflow, or the needed size on OOM.
- `struct base32_decode_context { int i; char buf[8]; };` with
  `base32_decode_ctx_init`, `bool base32_decode_ctx(struct base32_decode_context
  *ctx, const char *restrict in, idx_t inlen, char *restrict out, idx_t
  *outlen);`, `bool base32_decode_alloc_ctx(...)`, and the macros
  `base32_decode(...)` / `base32_decode_alloc(...)` that pass `ctx = NULL`.

**coreutils CLI** (`base32`): a one-shot stdin→stdout filter; "base32 … encode
data and print to standard output", with `-d/--decode`, `-w/--wrap` (default 76)
and `-i/--ignore-garbage`. (Source:
<https://www.man7.org/linux/man-pages/man1/base32.1.html>)

The **absence** matters as much as the presence: there is no `EVP_Base32Block`,
no `sodium_bin2base32`, no `b64_ntop` for base32. (Assessment: derived from the
OpenSSL/libsodium/glibc headers cited in `c.md` §1.)

## 4. Error representation

C's base32 error surface is the same blunt family as base64, but with fewer
providers:

1. **`bool` plus an out-parameter length** (gnulib, the main library):
   `base32_decode_ctx` returns `true`/`false`; `*outlen` holds the produced
   length. The file comment gives the canonical caller pattern:
   `bool ok = base32_decode_alloc (in, inlen, &out, &outlen); if (!ok) FAIL:
   input was not valid base32; if (out == NULL) FAIL: memory allocation error`.
   The allocating variant also distinguishes overflow (`out == NULL && outlen ==
   0 && inlen != 0`) from OOM (`out == NULL && outlen != 0`). (Source:
   <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base32.c>)
2. **Exit status + stderr** (coreutils `base32 -d`): non-zero exit on invalid
   input; the CLI is the error channel. (Source:
   <https://www.man7.org/linux/man-pages/man1/base32.1.html>)

**Partial output on error is explicit**: "If *OUTLEN is too small, as many bytes
as possible are written to OUT", and "as soon as any non-alphabet, non-newline
character is encountered, decoding is stopped and false is returned" — so the
caller can inspect how far decoding got. (Source: gnulib `base32.c`)

**Canonicality is enforced silently.** gnulib's `decode_8` has three explicit
"Reject non-canonical encodings" checks on the trailing bits of the final symbol:
`base32_to_int[in[1]] & 0x03`, `base32_to_int[in[3]] & 0x0f`, and
`base32_to_int[in[4]] & 0x01` / `base32_to_int[in[6]] & 0x07`. RFC 4648 §3.5
explains why (otherwise "multiple base-encoded strings can be decoded to the
same binary data"). (Sources: gnulib `base32.c`;
<https://www.rfc-editor.org/rfc/rfc4648.txt>)

RFC 4648 §12 makes the security point that drives strictness: a decoder should
not break on invalid input "including, e.g. embedded NUL characters", and
ignoring non-alphabet characters opens a covert channel. (Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>)

## 5. Ownership semantics

The C rule is uniform and blunt: **the caller owns every buffer, on both sides.**

- **Caller-allocated output is the default.** `base32_encode(in, inlen, out,
  outlen)` writes at most `outlen` bytes and zero-terminates only if there is
  room; the caller sizes `out` with `BASE32_LENGTH(inlen)`. (Source: gnulib
  `base32.h`)
- **The encode input is borrowed `const`/`restrict` and never freed by the
  codec**: `const char *restrict in`; in/out may not overlap (`restrict`).
- **Allocation is an explicit, separate API**: `base32_encode_alloc(in, inlen,
  &out)` returns newly allocated memory "that must be deallocated by the
  caller"; on OOM it returns the requested length and sets `*out = NULL`.
  (Source: gnulib `base32.c`)
- **Output is NUL-terminated only if the buffer has room**; the length is
  always the authoritative result. (Source: gnulib `base32.h`)

(Assessment: derived from the sources above: the two recurring C contracts are
"caller provides output buffer, codec never allocates" and, additionally, the
gnulib explicit `_alloc` form. This is identical in shape to `c.md` §5 for
base64, just with `BASE32_LENGTH` instead of `BASE64_LENGTH`.)

## 6. Blocking / non-blocking

Not applicable: gnulib's base32 is a pure, in-process memory transform with no
I/O and no waiting. The only I/O is the coreutils CLI, which blocks on
stdin/stdout by construction. No C base32 API in this survey offers a
non-blocking or async variant. (Assessment: derived from the function
signatures above; every function is input-buffer → output-buffer with no fd,
callback or poll argument.)

## 7. Alphabet variants, case and padding

C support for base32 is **alphabet-poor and padding-rigid**:

- **gnulib: standard alphabet only.** `b32str[32] =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"`, padding `=` emitted unconditionally in
  the tail; there is **no base32hex and no Crockford**. (Source: gnulib
  `base32.c`)
- **Decode is uppercase-only by default, with `\n` (only) tolerated.** The
  `base32_to_int` table is built by the `B32` macro which maps only `A`–`Z` and
  `2`–`7`; lowercase letters map to `-1`. When `ctx != NULL`, newlines are
  ignored ("The input data may be interspersed with newlines"); with `ctx ==
  NULL` "newlines are treated as garbage and the input buffer is processed as a
  unit". (Source: gnulib `base32.c`)
- **Only `\n` is skipped, not `\r` or space**: the `get_8` helper checks `c !=
  '\n'` specifically. (Source: gnulib `base32.c`)
- **Valid padding lengths** are enforced structurally by the nested branches of
  `decode_8`: after 2, 4, 5 or 7 data symbols the only accepted continuations are
  the correct `=` runs; the impossible lengths (1, 3, 6 symbols) have no branch
  and fail. (Source: gnulib `base32.c`)
- **Canonicality is checked** (see §4).
- **RFC 4648 reference**: §6 Table 3 (base32 `A-Z2-7`), §7 Table 4 (base32hex
  `0-9A-V`), §3.2 padding, §3.4 the deliberate non-decoding of `0`/`O` and
  `1`/`I`/`L` by default, §3.5 canonical encoding.
  (https://www.rfc-editor.org/rfc/rfc4648.txt)

## 8. Timeouts

Not applicable. No C base32 function in this survey takes a timeout, a deadline
or a cancellation token; none performs I/O that could time out. The coreutils
CLI inherits whatever the shell provides, but the codec itself has no such
parameter. (Assessment: derived from the signatures above; no timeout parameter
appears in any cited prototype.)

## 9. Streaming / incremental encode and decode

This is the strongest C design axis, and the answer is clean: **gnulib streams
decode but not encode.**

- **Decode is incremental.** `struct base32_decode_context { int i; char buf[8];
  }` is the leftover buffer; `get_8()` "copy[s] up to 8 - CTX->i non-newline
  bytes" into `ctx->buf`, and the doc explains "It is necessary for when a
  octuple of base32 input bytes spans two input buffers." Passing `inlen == 0`
  flushes the context. (Source: gnulib `base32.c`)
- **Encode is one-shot.** `base32_encode` takes a complete `in`/`inlen`; there is
  no encode context and no `update`/`final` pair. So chunked encode is the
  caller's job: align chunks to a multiple of 5 bytes and carry the remainder.
  (Assessment: derived from the absence of any encode context in `base32.h`.)
- **Leftover granularity is 8 symbols on decode** (a full octuple), matching the
  40-bit quantum; the encode remainder is 0–4 bytes. This is exactly the base32
  analogue of gnulib's 4-byte decode carry for base64 (`c.md` §9).

## 10. Interesting design decisions

- **`BASE32_LENGTH` as a public macro.** Because callers must size buffers, the
  sizing formula is promoted to the API: `((((inlen) + 4) / 5) * 8)`. It is
  exact, unlike OpenSSL's deliberately over-estimated base64 macro.
  (Source: gnulib `base32.h`)
- **Decode-only streaming context with a public 8-byte buffer.** The context is a
  plain struct (`int i; char buf[8]`), so callers can stack-allocate it and see
  exactly what is carried — no opaque heap handle. (Source: gnulib `base32.c`)
- **Newline tolerance is scoped to the context.** With `ctx != NULL` newlines are
  skipped; with `ctx == NULL` they are garbage. So strictness is a property of
  *how you call*, not a separate flag. (Source: gnulib `base32.c`)
- **Canonicality checked by masking the final symbol's low bits**
  (`& 0x03`, `& 0x0f`, `& 0x01`, `& 0x07`) — a terse, table-free rejection of
  non-canonical base32. (Source: gnulib `base32.c`)
- **`base32_encode_alloc` splits three outcomes** — invalid input, overflow,
  OOM — across the return value and the out-pointer, with the doc spelling out
  the exact caller-side tests. (Source: gnulib `base32.c`)
- **The gnulib base32 module exists at all** is the design lesson: when the
  language has no codec, a portability project fills the gap and must choose
  exactly one alphabet and one padding policy rather than expose options.

## 11. Decisions NOT to copy

- **Encode has no incremental path.** gnulib streams decode but not encode;
  copying that asymmetry forces callers to re-implement the 5-byte carry.
  (Assessment: derived from `base32.h`.)
- **Uppercase-only decode with no case option.** Lowercase base32 is a valid RFC
  4648 spelling, but gnulib cannot accept it; a Mojo API should make case policy
  explicit rather than impossible. (Source: gnulib `base32.c`)
- **Skipping only `\n`, not `\r`/space.** Half-hearted whitespace tolerance is
  harder to reason about than either full tolerance or none. (Source: gnulib
  `base32.c`)
- **One hard-coded alphabet.** No base32hex means every base32hex user writes
  their own codec; an alphabet parameter/value is strictly better. (Source:
  gnulib `base32.c`)
- **`restrict`-based non-overlap requirements** and raw `char*`/`idx_t` APIs in
  general: they cannot express "output must have capacity `BASE32_LENGTH(n)`",
  so every mistake is a buffer overflow rather than a compile error.
- **Caller-allocated-output as the *only* API.** Having just the
  `base32_encode(out, outlen)` form forces every caller to duplicate the sizing
  formula; a safe language should also offer the allocating form.
- **Silent leniency / ambiguity of `ctx == NULL` vs `ctx != NULL`**: the same
  function changes whitespace semantics based on a pointer being NULL, which is
  a subtle, easy-to-miss contract. (Source: gnulib `base32.c`)

## 12. Ideas fitting Mojo

- **The size formula as a documented pure function, not a macro.**
  `BASE32_LENGTH(inlen)` is exactly `8*ceil(n/5)`; Mojo can expose
  `encoded_length(n)` as a total `def`, which is strictly better than a
  preprocessor macro because it is typed and cannot fail. (Source: gnulib
  `base32.h`; `mojov1/stdlib/base64`.)
- **Typed errors where C uses `bool` + out-params.** Mojo's `raises YourError`
  model can carry `{offset, symbol}` / invalid-length distinctions, matching the
  Go/Rust findings. (Source: `mojov1/errors/error-model`.)
- **`Span[UInt8]` is the C `(ptr, len)` pair with a compiler-checked lifetime.**
  `Span` "is a non-owning view of contiguous data" and "works with both Mojo and
  C memory"; the C lesson "input is borrowed, output is owned by the caller"
  becomes `Span[UInt8]` in, `String`/`List[UInt8]` out. (Sources:
  `mojov1/types/collections`, `mojov1/interop/calling-c`.)
- **A `with`-scoped streaming context is a natural Mojo shape.** C's
  init/update/final + public buffer can become a Mojo struct with `deinit` plus a
  `with` block, so release is guaranteed even on error paths.
  (`mojov1/keywords/with`.)
- **Canonicality as a named, first-class check.** gnulib's trailing-bit masking
  deserves a documented option (`canonical=True`) rather than being always-on or
  absent. (Sources: gnulib `base32.c`;
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **Explicit whitespace policy.** gnulib's "newlines only when a context is
  passed" is a warning: make tolerance a visible parameter, not a side effect of
  which overload you call.
- **Borrowing a C buffer directly is expressible.** `Span(unsafe_ptr=ptr.
  unsafe_bitcast[Byte](), length=Int(length))` wraps a `malloc`ed C buffer, so a
  Mojo base32 can consume a C buffer without a copy. (Source:
  `mojov1/interop/calling-c`.)

## Sources

- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- ISO C standard library header list (no base-N codec):
  <https://en.cppreference.com/w/c/header>
- gnulib `lib/base32.h`:
  <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base32.h>
- gnulib `lib/base32.c`:
  <https://raw.githubusercontent.com/coreutils/gnulib/master/lib/base32.c>
- coreutils `base32` manual:
  <https://www.man7.org/linux/man-pages/man1/base32.1.html>
- libsodium `sodium/utils.h` (no base32):
  <https://raw.githubusercontent.com/jedisct1/libsodium/master/src/libsodium/include/sodium/utils.h>
- mbedTLS `include/mbedtls/base64.h` (base64 only):
  <https://raw.githubusercontent.com/Mbed-TLS/mbedtls/master/include/mbedtls/base64.h>
- Mojo `mojov1` buch, `stdlib/base64` (Mojo-side reference for section 12)
- Mojo `mojov1` buch, `types/collections` (`Span`, ownership)
- Mojo `mojov1` buch, `errors/error-model` (`raises`, typed errors)
- Mojo `mojov1` buch, `interop/calling-c` (`unsafe_bitcast`, `unsafe_ptr`)
- Mojo `mojov1` buch, `keywords/with` (scoped release)
