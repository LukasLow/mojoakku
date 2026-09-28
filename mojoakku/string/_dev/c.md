# string research: C

## 1. Standard library support

C has **no string type**. A "string" is a convention, not a type: a
*null-terminated byte string* (NTBS) is

> a sequence of nonzero bytes followed by a byte with value zero (the
> terminating null character). Each byte in a byte string encodes one
> character of some character set.
> — <https://en.cppreference.com/w/c/string/byte>

The type is therefore `char *` (a pointer) plus the terminating `'\0'`; the
length is not stored and must be recomputed. `<string.h>` supplies functions,
not an object. Source: <https://en.cppreference.com/w/c/string/byte>.

The `char` type is a byte-sized integer type; a character literal like `'a'`
has type `int` in C and its value is the execution-character-set
representation of the char. Source:
<https://en.cppreference.com/w/c/language/character_constant>.

Three parallel families exist:

- **byte strings** (`<string.h>`, `<ctype.h>`) — the default, one byte per
  "character". Source: <https://en.cppreference.com/w/c/string/byte>.
- **multibyte strings** (NTMBS) — same layout as a byte string, but a
  character may occupy several bytes; the encoding is **locale-specific**
  (UTF-8, GB18030, EUC-JP, Shift-JIS, …). Source:
  <https://en.cppreference.com/w/c/string/multibyte>.
- **wide strings** (`<wchar.h>`, `wchar_t`) — the C95 attempt at a real
  character type. Source:
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.

C11/C23 added fixed-width character types `char16_t` (C11), `char32_t` (C11)
and `char8_t` (C23, an alias of `unsigned char`) in `<uchar.h>` for UTF-16 /
UTF-32 / UTF-8. Source:
<https://en.cppreference.com/w/c/string/multibyte/char8_t>.

There is **no owned type** and **no builder** in the standard library (see
§9).

## 2. Relevant community libraries

- **ICU** (International Components for Unicode) — mature C/C++ libraries for
  Unicode and globalization; its C++ `UnicodeString` stores Unicode
  characters directly, like Java's `String`. Source:
  <https://unicode-org.github.io/icu/userguide/strings/>.
- **utf8proc** — "a clean C library for processing UTF-8 Unicode data:
  normalization, case-folding, graphemes, and more" (used by Julia). Source:
  <https://github.com/JuliaStrings/utf8proc>.
- **GNU libunistring** — Unicode string functions for C, built on a
  locale-encoding abstraction (`locale_charset`). Source:
  <https://www.gnu.org/software/libunistring/manual/libunistring.html>.
- **BSD `strlcpy`/`strlcat`** — widely deployed bounded copies; not standard C.
  Referenced from <https://en.cppreference.com/w/c/string/byte/strcat>.
- **`strtok_r`** — the reentrant POSIX tokenizer that C11 `strtok_s` is
  contrasted with. Source:
  <https://en.cppreference.com/w/c/string/byte/strtok>.
- **stb_ds / Redis `sds`** (GUESS: ecosystem-level dynamic-string builders.
  Source for the model: the Redis `sds` project <https://github.com/redis/redis>
  ships `sds.c`; no single authoritative doc page was fetched, hence GUESS on
  the exact API surface.)

(Assessment: derived from the two facts "no string type in stdlib" and the
existence of these third-party libraries — the community layer exists precisely
because the stdlib does not provide owned strings or Unicode.)

## 3. Exposed APIs

All from <https://en.cppreference.com/w/c/string/byte> unless noted.

**Length / inspection**

- `size_t strlen(const char *str)` — number of bytes up to (not including) the
  first null. Source: <https://en.cppreference.com/w/c/string/byte/strlen>.
- `size_t strnlen_s(const char *str, size_t strsz)` — bounded variant (C11,
  Annex K). Source: same page.
- `int strcmp(const char *lhs, const char *rhs)` — lexicographic comparison,
  sign of the first differing byte pair interpreted as `unsigned char`.
  Source: <https://en.cppreference.com/w/c/string/byte/strcmp>.
- `int strncmp(...)` — bounded comparison. Source:
  <https://en.cppreference.com/w/c/string/byte>.
- `int strcoll(...)` — locale-aware comparison. Source: same page.

**Search**

- `char *strchr(const char *str, int ch)` — first occurrence of a byte; the
  terminator is considered part of the string and can be found. Source:
  <https://en.cppreference.com/w/c/string/byte/strchr>.
- `char *strrchr(...)` — last occurrence. Source:
  <https://en.cppreference.com/w/c/string/byte>.
- `char *strstr(const char *str, const char *substr)` — first occurrence of a
  substring; an empty needle returns `str`. Source:
  <https://en.cppreference.com/w/c/string/byte/strstr>.
- `size_t strspn(...)`, `size_t strcspn(...)`, `char *strpbrk(...)` —
  prefix-length / set membership primitives (the raw material for tokenizers).
  Source: <https://en.cppreference.com/w/c/string/byte>.
- `char *strtok(char *str, const char *delim)` — destructive tokenizer, see §6.
  Source: <https://en.cppreference.com/w/c/string/byte/strtok>.

**Copy / concatenate**

- `char *strcpy(char *dest, const char *src)`, `strncpy`, `strcat`, `strncat`,
  `strxfrm`, `strdup`/`strndup` (C23). Source:
  <https://en.cppreference.com/w/c/string/byte>; details:
  <https://en.cppreference.com/w/c/string/byte/strcpy>,
  <https://en.cppreference.com/w/c/string/byte/strncpy>,
  <https://en.cppreference.com/w/c/string/byte/strcat>.

**Byte-buffer (length-explicit) primitives** — the closest thing to a "view":

- `void *memchr(const void *ptr, int ch, size_t count)`, `memcmp`, `memset`,
  `memcpy`, `memmove`, `memccpy` (C23). Source:
  <https://en.cppreference.com/w/c/string/byte/memchr> and
  <https://en.cppreference.com/w/c/string/byte>.

**Character classification / case** — `<ctype.h>`: `isalnum`, `isalpha`,
`islower`, `isupper`, `isdigit`, `isxdigit`, `iscntrl`, `isgraph`, `isspace`,
`isblank` (C99), `isprint`, `ispunct`, `tolower`, `toupper`. Source:
<https://en.cppreference.com/w/c/string/byte>.

**Numeric conversion** — `<stdlib.h>`: `atoi`, `atol`, `atoll` (C99), `atof`,
`strtol`/`strtoll` (C99), `strtoul`/`strtoull` (C99), `strtoimax`/`strtoumax`
(C99), `strtof`/`strtod`/`strtold` (C99), `strfromf`/`strfromd`/`strfroml`
(C23). Source: <https://en.cppreference.com/w/c/string/byte>.

**Unicode / multibyte** — `<wchar.h>`, `<stdlib.h>`, `<uchar.h>`: `mbrtowc`,
`mbrlen`, `mbtowc`, `mbsinit`, `btowc`, `wctob`, `wcrtomb`, `mbsrtowcs`,
`wcsrtombs`, `mbrtoc8`/`c8rtomb` (C23), `mbrtoc16`/`c16rtomb` (C11),
`mbrtoc32`/`c32rtomb` (C11), plus `mbstate_t`, `char8_t`/`char16_t`/`char32_t`.
Sources: <https://en.cppreference.com/w/c/string/multibyte>,
<https://en.cppreference.com/w/c/string/multibyte/mbrtowc>,
<https://en.cppreference.com/w/c/string/multibyte/char8_t>.

## 4. Error representation

C has no exceptions. Three mechanisms coexist, and most of the library does
**not check at all**:

- **Return-value sentinel.** `strchr`, `strrchr`, `strstr`, `strpbrk`,
  `strtok` return a **null pointer** on "not found" / "no more tokens".
  Sources: <https://en.cppreference.com/w/c/string/byte/strchr>,
  <https://en.cppreference.com/w/c/string/byte/strstr>,
  <https://en.cppreference.com/w/c/string/byte/strtok>.
- **`errno` + `ERANGE`.** `strtol` sets `errno` to `ERANGE` and returns
  `LONG_MAX`/`LONG_MIN` (or the `long long`/unsigned equivalents) when the
  converted value is out of range; it returns `0` when no conversion could be
  performed. Source: <https://en.cppreference.com/w/c/string/byte/strtol>.
- **`errno_t` + constraint handler (Annex K).** `strcpy_s`, `strncpy_s`,
  `strcat_s`, `strtok_s`, `strnlen_s` return `errno_t` (0 success, non-zero
  error) and, on violation, call the currently installed **constraint handler**
  (or write 0 to `dest[0]`). These are only guaranteed if
  `__STDC_LIB_EXT1__` is defined and the user defines `__STDC_WANT_LIB_EXT1__`
  to 1 before including `<string.h>`. Sources:
  <https://en.cppreference.com/w/c/string/byte/strcpy>,
  <https://en.cppreference.com/w/c/string/byte/strncpy>,
  <https://en.cppreference.com/w/c/string/byte/strcat>,
  <https://en.cppreference.com/w/c/string/byte/strtok>,
  <https://en.cppreference.com/w/c/string/byte/strlen>.
- **`mbrtowc` return protocol.** For Unicode decoding the error signal is
  encoded in the return value: `0` = converted null character, `1..n` = bytes
  consumed, `(size_t)-2` = incomplete but so-far-valid sequence, `(size_t)-1` =
  **encoding error**, with `EILSEQ` stored in `errno` and the state
  unspecified. Source:
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.
- **Undefined behavior.** For everything else there is no error channel: the
  contract is "the behavior is undefined" (see §8).

(Assessment: derived from the above pages — C's error model is a mixture of
sentinels, global `errno`, a non-portable Annex K layer, and UB, with no single
uniform representation.)

## 5. Ownership semantics

- **Caller owns everything.** `char *` carries no ownership information; memory
  comes from the caller (`malloc`, arrays, stack, string literals) and must be
  freed by the caller (`free`). `strdup`/`strndup` are the only stdlib
  functions that allocate, and the result must be `free`d. Source:
  <https://en.cppreference.com/w/c/string/byte>.
- **No borrow checker, no lifetime tracking.** A pointer to a string in a
  stack buffer is indistinguishable from a pointer into a heap allocation or
  read-only static storage. `strcpy` is UB if the arrays overlap. Source:
  <https://en.cppreference.com/w/c/string/byte/strcpy>.
- **Aliasing is an explicit precondition.** `strcpy`, `strncpy`, `strcat`,
  `strncmp` family: behavior is undefined if source and destination overlap;
  `memmove` exists as the overlapping-safe byte copy. Sources:
  <https://en.cppreference.com/w/c/string/byte/strcpy>,
  <https://en.cppreference.com/w/c/string/byte/strcat>,
  <https://en.cppreference.com/w/c/string/byte>.
- **`restrict`.** Since C99 the copy/compare functions take `restrict`
  qualifiers on `dest`/`src`, promising no aliasing and enabling optimization.
  Source: <https://en.cppreference.com/w/c/string/byte/strcpy>.

(Assessment: derived from the C model — ownership is a discipline, not a type
property; the standard library assumes the caller has allocated enough for the
*whole* operation, including the terminator.)

## 6. Blocking / non-blocking

All `<string.h>` / `<ctype.h>` operations are **in-memory, synchronous and
non-blocking**; none performs I/O or waits. There is no async/futures model.
(Assessment: derived from the absence of any I/O object in the function
signatures, <https://en.cppreference.com/w/c/string/byte>.)

The relevant axis in C is not blocking but **reentrancy / thread-safety**:

- `strtok` "modifies a static variable: is not thread safe"; it writes `'\0'`
  into the input (destructive), so a string literal cannot be passed. Source:
  <https://en.cppreference.com/w/c/string/byte/strtok>.
- `strtok_s` (C11 Annex K) and POSIX `strtok_r` remove the static state by
  taking an explicit state pointer. Source: same page.
- Locale-dependent functions (`strcoll`, `mbrtowc`, `mbstowcs`, …) read the
  **global locale** and are therefore not usable with different encodings
  concurrently without locale discipline. Source:
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.

(Assessment: derived from the above — "non-blocking" is trivially true; the
interesting C property is the absence of hidden global state, which `strtok`
violates.)

## 7. Text model (encoding, length, indexing)

**What a "character" is: a byte.** In `<string.h>`, "Each byte in a byte string
encodes one character of some character set" — the model is byte-per-character
and encoding-agnostic. Source: <https://en.cppreference.com/w/c/string/byte>.

**Encoding: not specified; locale-specific for multibyte.** "The encoding used
to represent characters in a multibyte character string is locale-specific: it
may be UTF-8, GB18030, EUC-JP, Shift-JIS, etc." Source:
<https://en.cppreference.com/w/c/string/multibyte>. UTF-8 itself is defined by
RFC 3629: characters from U+0000..U+10FFFF encoded as 1–4 octets, one-octet
encoding unit, ASCII-compatible, U+D800..U+DFFF forbidden, and C0/C1/F5–FF
never appear. Source: <https://www.rfc-editor.org/rfc/rfc3629.txt> (§3–§4).

**Length.** `strlen` returns the **number of bytes** up to the null, i.e. byte
length, not codepoint or grapheme length. Source:
<https://en.cppreference.com/w/c/string/byte/strlen>. For an NTMBS, the number
of characters must be computed by walking the string with `mbrlen`/`mbrtowc`
(or the wide-string equivalents); there is no "codepoint count" function.
Source: <https://en.cppreference.com/w/c/string/multibyte>.

**Position / indexing.** A position is a **byte offset** (pointer difference or
`size_t` index). `strchr` returns a pointer to the found byte; `strstr` returns
a pointer to the first byte of the match; the idiom is `pos = p - str`.
Sources: <https://en.cppreference.com/w/c/string/byte/strchr>,
<https://en.cppreference.com/w/c/string/byte/strstr>. Slicing is manual pointer
arithmetic plus a length; there is no slice type. The length-explicit
(`ptr, count`) form is the byte-buffer API (`memchr`, `memcmp`, `memcpy`).
Source: <https://en.cppreference.com/w/c/string/byte/memchr>.

**No grapheme concept at all.** Grapheme clusters are a Unicode-text concept
(UAX #29); nothing in `<string.h>`, `<ctype.h>` or the multibyte family
addresses them. (Assessment: derived from the complete function list at
<https://en.cppreference.com/w/c/string/> — there is no grapheme/cluster API.)

**Wide characters.** `wchar_t` is the closest thing to a character type; if
`__STDC_ISO_10646__` is defined its values are Unicode scalar values
(typically UTF-32), otherwise implementation-defined. Source:
<https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.

## 8. Bounds, invalid input and errors

C's default answer is **undefined behavior**, not a panic and not a return
code:

- **Out-of-range index.** There is no index operation to bound — you dereference
  a pointer. Reading past the array end is UB: `memchr` "The behavior is
  undefined if access occurs beyond the end of the array searched." Source:
  <https://en.cppreference.com/w/c/string/byte/memchr>.
- **Missing terminator.** `strlen` "The behavior is undefined if `str` is not a
  pointer to a null-terminated byte string." Source:
  <https://en.cppreference.com/w/c/string/byte/strlen>. Same precondition for
  `strcmp`, `strchr`, `strstr`. Sources:
  <https://en.cppreference.com/w/c/string/byte/strcmp>,
  <https://en.cppreference.com/w/c/string/byte/strchr>,
  <https://en.cppreference.com/w/c/string/byte/strstr>.
- **Buffer overflow.** `strcpy` "The behavior is undefined if the `dest` array
  is not large enough"; `strcat` UB if the destination array is not large
  enough for both strings plus the terminator. Sources:
  <https://en.cppreference.com/w/c/string/byte/strcpy>,
  <https://en.cppreference.com/w/c/string/byte/strcat>.
- **`strncpy`'s trap.** If `count` is reached before the source ends, the
  destination is **not null-terminated**; conversely if the source is shorter,
  `strncpy` pads with nulls to `count`. Source:
  <https://en.cppreference.com/w/c/string/byte/strncpy>.
- **Null pointer.** `memchr` UB if `ptr` is a null pointer; `strcpy_s`/Annex K
  functions detect a null pointer and call the constraint handler. Sources:
  <https://en.cppreference.com/w/c/string/byte/memchr>,
  <https://en.cppreference.com/w/c/string/byte/strcpy>.
- **Invalid encoding.** `mbrtowc` reports it: returns `(size_t)-1`, sets
  `errno = EILSEQ`, writes nothing. Source:
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>. RFC 3629 makes
  rejecting invalid sequences a MUST: "Implementations of the decoding
  algorithm above MUST protect against decoding invalid sequences." Source:
  <https://www.rfc-editor.org/rfc/rfc3629.txt> (§3).
- **Empty / zero-length edges.** Defined: `strstr(str, "")` returns `str`;
  `strchr` can find the terminating `'\0'`; `strtok` returns null when no
  tokens remain; `strlen("") == 0`; `strnlen_s(NULL, n) == 0`. Sources:
  <https://en.cppreference.com/w/c/string/byte/strstr>,
  <https://en.cppreference.com/w/c/string/byte/strchr>,
  <https://en.cppreference.com/w/c/string/byte/strtok>,
  <https://en.cppreference.com/w/c/string/byte/strlen>.
- **Bounded escape hatch.** Annex K's `_s` functions turn truncation/overflow
  into a detected runtime-constraint violation instead of UB (but only where
  Annex K is provided). Source:
  <https://en.cppreference.com/w/c/string/byte/strcat>.

(Assessment: derived from the above — C partitions the space into "defined on
the empty edge", "detected only by Annex K / mbrtowc", and "UB", with UB as the
default for the common mistakes.)

## 9. Owned type, borrowed view and builder layer

- **Owned type: none.** There is no standard owning string object. Ownership is
  `char *` + a memory-management convention (`malloc`/`free`, arrays, or an
  allocator of the caller's choosing). Source:
  <https://en.cppreference.com/w/c/string/byte>.
- **Borrowed view: implicit and ad hoc.** A `char *` or `(const char *, size_t)`
  pair *is* the view; it is not a distinct type, carries no lifetime, and the
  length-explicit form lives in the byte-buffer API (`memchr`, `memcpy`,
  `memcmp`). Source: <https://en.cppreference.com/w/c/string/byte/memchr>.
  C23's `char8_t *` is the first typed pointer for UTF-8 data, but still not a
  view type. Source:
  <https://en.cppreference.com/w/c/string/multibyte/char8_t>.
- **Builder: none in stdlib.** Efficient incremental construction is manual:
  track a length and capacity, `realloc`, and append bytes; or use
  `open_memstream` (POSIX) / GNU `asprintf` / third-party builders (`sds`,
  `stb_ds`). (Assessment: derived from the absence of any builder type in
  <https://en.cppreference.com/w/c/string/>; the POSIX/GNU names are ecosystem
  facts, GUESS on their exact signatures.)
- **Byte ↔ text bridge.** This is where the stdlib is actually rich: `mbrtowc`,
  `mbrtoc8`/`c8rtomb`, `mbrtoc16`/`c16rtomb`, `mbrtoc32`/`c32rtomb` convert
  between the locale's multibyte encoding and a wide/Unicode encoding, with an
  explicit `mbstate_t` for state-dependent encodings. Sources:
  <https://en.cppreference.com/w/c/string/multibyte>,
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.
  The bridge is **stateful and locale-dependent**: the encoding is chosen by the
  current locale, not by the string. Source:
  <https://en.cppreference.com/w/c/string/multibyte>.

Summary: C provides the **view primitive** (pointer + length) and the
**byte↔text bridge**, but neither the owned type nor the builder.

## 10. Interesting design decisions

- **The terminator instead of a stored length.** One convention gives
  C-interop for free and keeps the type a single pointer; the cost is that
  `strlen` is O(n) and the length is recomputed on every call, and that a
  string cannot contain a NUL byte. Sources:
  <https://en.cppreference.com/w/c/string/byte>,
  <https://en.cppreference.com/w/c/string/byte/strlen>.
- **NUL cannot appear in an NTBS.** This is why `c_str()` in C++ and the whole
  C-interop story carry an embedded-NUL caveat. Source:
  <https://en.cppreference.com/w/c/string/byte>.
- **Layout-compatibility of NTMBS and NTBS.** A multibyte string can be stored,
  copied and examined with the byte-string functions — only *counting
  characters* differs. Source:
  <https://en.cppreference.com/w/c/string/multibyte>. That is a deliberate
  "bytes are always a valid fallback view" design.
- **`n`-suffixed functions are not the safe version.** `strncpy`'s `count` is a
  *maximum copy*, not a destination size, and it can leave the result
  unterminated; `strncat`'s `n` is a maximum append, still requiring room for
  the terminator. Source:
  <https://en.cppreference.com/w/c/string/byte/strncpy>,
  <https://en.cppreference.com/w/c/string/byte/strcat> (the `strcat` page's
  discussion of Annex K).
- **`strtok`'s static state and destructiveness.** It tokenizes in place by
  writing `'\0'` over delimiters, and the "different delimiter per call"
  feature falls out of that design. Source:
  <https://en.cppreference.com/w/c/string/byte/strtok>.
- **The return protocol of `mbrtowc`.** Encoding a three-state result
  (`incomplete`, `error`, `n bytes consumed`) into `size_t` sentinels
  `(size_t)-2` / `(size_t)-1` is a compact but error-prone design; callers must
  know it. Source:
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.
- **Locale as ambient global state.** `strcoll`, `mbtowc`, `mbrtowc` read the
  process-global locale, so the *meaning* of a byte string depends on
  `setlocale`. Source: <https://en.cppreference.com/w/c/string/multibyte>.
- **UTF-8's self-synchronizing property.** "Character boundaries are easily
  found from anywhere in an octet stream", and byte-lexicographic order equals
  codepoint order. Source: <https://www.rfc-editor.org/rfc/rfc3629.txt> (§1).
- **Security as a first-class concern.** RFC 3629 §10 documents the overlong
  sequence (`C0 80` as NUL) and `/../` smuggling attacks, and the risk of
  5/6-byte sequences if the U+10FFFF cap is not enforced. Source:
  <https://www.rfc-editor.org/rfc/rfc3629.txt> (§10).

## 11. Decisions NOT to copy

- **Undefined behavior as the failure mode.** `strcpy` overflow, `strlen` on a
  non-terminated buffer, out-of-array `memchr` — UB is not an acceptable
  contract for a low-vision-user, predictable API. Mojo should surface a
  defined error or a checked operation. Sources:
  <https://en.cppreference.com/w/c/string/byte/strcpy>,
  <https://en.cppreference.com/w/c/string/byte/strlen>,
  <https://en.cppreference.com/w/c/string/byte/memchr>.
- **NUL-termination with no stored length.** Recomputing length and forbidding
  embedded NUL is a step backwards from `String.byte_length()`. Sources:
  <https://en.cppreference.com/w/c/string/byte/strlen>,
  <https://en.cppreference.com/w/c/string/byte>.
- **`n`-truncation that is not length-aware and can drop the terminator.**
  `strncpy`'s semantics are a classic correctness trap. Source:
  <https://en.cppreference.com/w/c/string/byte/strncpy>.
- **Hidden global state (`strtok`) and ambient locale (`strcoll`/`mbrtowc`).**
  A modern API should make encoding and tokenizer state explicit parameters.
  Sources: <https://en.cppreference.com/w/c/string/byte/strtok>,
  <https://en.cppreference.com/w/c/string/multibyte>.
- **`size_t` sentinel encodings** like `(size_t)-2`/`(size_t)-1`. Source:
  <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>.
- **Annex-K-only safety.** Safety that is conditional on
  `__STDC_LIB_EXT1__` is not safety you can rely on. Sources:
  <https://en.cppreference.com/w/c/string/byte/strcpy>,
  <https://en.cppreference.com/w/c/string/byte/strcat>.
- **Byte = character.** The default byte-string model cannot express
  codepoints or graphemes; Mojo already commits to UTF-8 with three distinct
  counts (source: `mojov1/types/bool-and-strings`).

## 12. Ideas fitting Mojo

- **Explicit byte↔text bridge with named conversions.** C's `mbrtoc8` /
  `c8rtomb` pair is the right shape: named functions in both directions.
  Mojo's gap is the *rules* — when a raw byte buffer becomes text and what
  validity check runs. Source:
  <https://en.cppreference.com/w/c/string/multibyte>; gap premise in
  `mojoakku/string/_dev/mojo.md`.
- **Length-explicit view as the universal interchange primitive.** The
  `(ptr, len)` byte-buffer API (`memchr`, `memcpy`, `memcmp`) is the one part
  of C's model that maps cleanly onto `StringSpan` + a byte layer. Source:
  <https://en.cppreference.com/w/c/string/byte/memchr>.
- **Defined empty-edge semantics.** C defines the empty cases well (`strstr` ""
  → `str`, `strchr` finds `'\0'`, `strtok` → null); Mojo's search/trim API
  should be equally explicit. Sources:
  <https://en.cppreference.com/w/c/string/byte/strstr>,
  <https://en.cppreference.com/w/c/string/byte/strchr>,
  <https://en.cppreference.com/w/c/string/byte/strtok>.
- **A named byte-search primitive separate from text search.** `memchr` /
  `strchr` being distinct is a good separation: byte search does not pretend to
  be text search. Source: <https://en.cppreference.com/w/c/string/byte/memchr>.
- **Locale-free by default.** {fmt}'s and C++'s `from_chars`/`to_chars` lesson
  (see `cpp.md` §10) is that the default should not read ambient locale. C is
  the cautionary example. Source:
  <https://en.cppreference.com/w/c/string/multibyte>.
- **Document the security cases.** RFC 3629 §10's overlong-sequence and
  normalization-confusion warnings belong in the `string` library's boundary
  documentation, because MojoAkku's `string` sits under `url`, `json`, `regex`,
  `html` — all parser surfaces. Source:
  <https://www.rfc-editor.org/rfc/rfc3629.txt>.

## Sources

- Null-terminated byte strings: <https://en.cppreference.com/w/c/string/byte>
- `strlen`, `strnlen_s`:
  <https://en.cppreference.com/w/c/string/byte/strlen>
- `strcmp`: <https://en.cppreference.com/w/c/string/byte/strcmp>
- `strchr`: <https://en.cppreference.com/w/c/string/byte/strchr>
- `strstr`: <https://en.cppreference.com/w/c/string/byte/strstr>
- `strtok`, `strtok_s`: <https://en.cppreference.com/w/c/string/byte/strtok>
- `memchr`: <https://en.cppreference.com/w/c/string/byte/memchr>
- `strcpy`, `strcpy_s`: <https://en.cppreference.com/w/c/string/byte/strcpy>
- `strncpy`, `strncpy_s`:
  <https://en.cppreference.com/w/c/string/byte/strncpy>
- `strcat`, `strcat_s`: <https://en.cppreference.com/w/c/string/byte/strcat>
- `strtol`, `strtoll`: <https://en.cppreference.com/w/c/string/byte/strtol>
- Null-terminated multibyte strings:
  <https://en.cppreference.com/w/c/string/multibyte>
- `mbrtowc`: <https://en.cppreference.com/w/c/string/multibyte/mbrtowc>
- `char8_t`: <https://en.cppreference.com/w/c/string/multibyte/char8_t>
- Character constant:
  <https://en.cppreference.com/w/c/language/character_constant>
- RFC 3629 (UTF-8): <https://www.rfc-editor.org/rfc/rfc3629.txt>
- ICU strings: <https://unicode-org.github.io/icu/userguide/strings/>
- utf8proc: <https://github.com/JuliaStrings/utf8proc>
- GNU libunistring:
  <https://www.gnu.org/software/libunistring/manual/libunistring.html>
- Mojo facts, via buch: `mojov1/types/bool-and-strings`
- Frozen run configuration: `mojoakku/string/_dev/README.md`
- Mojo gap premise: `mojoakku/string/_dev/mojo.md`
