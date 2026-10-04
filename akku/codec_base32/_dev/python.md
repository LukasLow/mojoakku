# base32 research: Python

## 1. Standard library support

Python ships a dedicated `base64` module covering Base16, Base32, Base64 and
Base85/Ascii85, described as including "the encodings specified in RFC 4648
(Base64, Base32 and Base16)". For base32 it exposes two independent schemes:
the standard alphabet (`b32encode`/`b32decode`) and, since **3.10**, the
extended hex alphabet (`b32hexencode`/`b32hexdecode`). The modern interface is
bytes-in/bytes-out; older decode paths also accept ASCII-only strings. (Source:
https://docs.python.org/3/library/base64.html)

Unlike Base64, whose hot path is C in `binascii`, Base32 is implemented **in
pure Python** inside `Lib/base64.py` and delegates to new `binascii` helpers
`b2a_base32`/`a2b_base32`; the module comment states "Base32
encoding/decoding must be done in Python". (Sources:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py,
https://docs.python.org/3/library/base64.html)

**Mojo anchor:** the Mojo stdlib has no base32 at all. The `mojov1` buch page
`stdlib/base64` records the package's four functions — `b64encode`,
`b64decode`, `b16encode`, `b16decode` — and no base32 entry; a `buch_search`
for "base32" returns no hits. (Source: `mojov1` buch `stdlib/base64`.)

## 2. Relevant community libraries

- **pybase64** — a wrapper around the C library `libbase64` (aklomp/base64),
  author Matthieu Darbois, BSD-2-Clause, advertised as a drop-in for the
  "modern interface". Its README documents **Base64 only**; no Base32 path is
  claimed. (Source: https://pypi.org/project/pybase64/)
- **base64io** — stream wrapper for transparent base64 encode/decode. Only its
  PyPI landing page was referenced; no base32 claim. `GUESS:` base64io's API
  details and whether it handles base32, because the project page was not
  fetched in this pass.
- The reference signal for base32 is therefore the **stdlib**; there is no
  widely-used third-party base32 package that adds a distinct API over
  `base64.b32encode`/`b32hexencode`. (Assessment: derived from
  https://pypi.org/project/pybase64/ and the stdlib docs.)

## 3. Exposed APIs

Modern RFC 4648 interface (Source: https://docs.python.org/3/library/base64.html):

- `b32encode(s, *, padded=True, wrapcol=0)` → `bytes` (the `padded`/`wrapcol`
  parameters are new in 3.15; the 3.14 docs show `b32encode(s)` only).
- `b32decode(s, casefold=False, map01=None, *, padded=True, ignorechars=b'',
  canonical=False)` → `bytes`.
- `b32hexencode(s, *, padded=True, wrapcol=0)` / `b32hexdecode(s,
  casefold=False, *, padded=True, ignorechars=b'', canonical=False)` (added
  3.10).
- `b16encode(s)` / `b16decode(s, casefold=False)` for Base16.

Semantics documented for base32 (Source:
https://docs.python.org/3/library/base64.html):

- `casefold` — "a flag specifying whether a lowercase alphabet is acceptable as
  input. For security purposes, the default is `False`."
- `map01` — when not `None`, maps digit `0`→letter `O`, and digit `1`→ either
  `I` or `L` depending on the supplied value; "For security purposes the
  default is `None`, so that 0 and 1 are not allowed in the input."
- `b32hexdecode` "does not allow the digit 0 (zero) to the letter O (oh) and
  digit 1 (one) to either the letter I (eye) or letter L (el) mappings, all
  these characters are included in the Extended Hex Alphabet and are not
  interchangeable."
- On error: "A `binascii.Error` is raised if `s` is incorrectly padded or if
  there are non-alphabet characters present in the input."

Pure-Python wrapper bodies (Source:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py):
`b32decode` applies `map01` via `s.translate(bytes.maketrans(b'01', b'O' +
map01))`, then optionally `s = s.upper()` for `casefold`, then calls
`binascii.a2b_base32(s, padded=..., ignorechars=..., canonical=...)`.

## 4. Error representation

Errors are **exceptions**, not return codes. `binascii.Error` is raised for
incorrect padding or non-alphabet characters in base32/base16 decode;
`TypeError`/`ValueError` for bad arguments (e.g. `altchars` wrong length, or a
non-bytes-like decode input). (Sources:
https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/binascii.html)

The module docstrings name the exact failure contract — "A binascii.Error is
raised if the input is incorrectly padded or if there are non-alphabet
characters present in the input" — so there is **no partial-output-plus-error
path** in the modern interface as there is in Go. `binascii.Incomplete` exists
for "incomplete data … may be handled by reading a little more data and trying
again", the stdlib's own hint that stream decoding needs a retry path, but it
is not raised by the modern `b32*` wrappers. (Sources:
https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/binascii.html)

## 5. Ownership semantics

Python is memory-managed: each call returns a **new immutable `bytes` object**
owned by the caller, with no manual free. `_bytes_from_decode_data` normalizes
input — `str` is ASCII-encoded, `bytes`/`bytearray` pass through, anything else
goes through `memoryview(s).tobytes()` (i.e. copied). (Source:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

The base32 decode path may allocate a temporary `bytes` for the `map01`
translation and another for `casefold` (`s.upper()`), then hands the result to
`binascii.a2b_base32`; the caller sees only the final `bytes`. No caller-provided
buffer form exists in the modern interface — `wrapcol` (3.15) inserts newlines
into the returned `bytes`, it does not write into a caller buffer. (Sources:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py,
https://docs.python.org/3.15/library/base64.html)

The legacy file interface (`encode`/`decode`) writes into a caller-supplied file
object, but it is **Base64-only** and adds 76-char lines; it has no base32
equivalent. (Source: https://docs.python.org/3/library/base64.html)

## 6. Blocking / non-blocking

Not applicable in the concurrency sense: base32 is a pure, CPU-bound transform
with no I/O and no await points. The modern API is synchronous and blocking only
for the duration of the CPU work. There is no async or non-blocking variant in
`base64`. (Source: https://docs.python.org/3/library/base64.html)

Notably, the base32 implementation is pure Python, so it does **not** release
the GIL even in principle (there is no C conversion entry point being executed
for the Python-level loop); the 3.15 `binascii.b2a_base32`/`a2b_base32` helpers
may release it, but the docs do not state this. (Assessment: derived from
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py and
https://docs.python.org/3/library/binascii.html)

## 7. Alphabet variants, case and padding

- **Standard base32 (RFC 4648 §6)**: `A-Z 2-7`, `=` padding, default uppercase.
  `b32encode(b"foobar") == b"MZXW6YTBOI======"`.
- **base32hex (RFC 4648 §7)**: `0-9 A-V`, `=` padding, via `b32hexencode`/
  `b32hexdecode`. Its decoder explicitly disables the `0`/`1` confusable
  mappings because those characters are in the alphabet. (Source:
  https://docs.python.org/3/library/base64.html)
- **Case handling**: encode always emits uppercase; decode is uppercase-only by
  default. `casefold=True` upper-cases the whole input first, i.e. it is a
  *lenient opt-in* and "for security purposes, the default is False". RFC 4648
  §12 warns that case-insensitive handling of the base16/base32 alphabets can
  "leak information or make string equality comparisons fail". (Sources:
  https://docs.python.org/3/library/base64.html,
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **Confusable mapping (`map01`)**: optional `0→O` and `1→I`/`L` mapping,
  default `None` ("0 and 1 are not allowed in the input"). This mirrors RFC
  4648 §3.4's note that "a decoder may interpret 0 as O, and 1 as I or L …
  (However, by default it should not)". (Sources:
  https://docs.python.org/3/library/base64.html,
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **Crockford base32**: **not** provided; there is no `b32crockford*` function.
  (Assessment: derived from the `base64` module's documented function list.)
- **Padding policy**: default `padded=True` on encode and decode; `padded=False`
  (new in 3.15) omits padding on encode and accepts unpadded input on decode.
  `canonical=True` (3.15) rejects non-canonical encodings, i.e. checks the
  trailing pad bits per RFC 4648 §3.5; the default is off. Wrong padding still
  raises `binascii.Error`. (Sources:
  https://docs.python.org/3.15/library/base64.html,
  https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py,
  https://www.rfc-editor.org/rfc/rfc4648.txt)

## 8. Timeouts

Not applicable: no I/O, no blocking resource, no cancellation. There is no
timeout parameter anywhere in `base64`/`binascii`. (Source:
https://docs.python.org/3/library/base64.html) Cancellation would only be a
thread/process-level concern, not part of the codec API.

## 9. Streaming / incremental encode and decode

The stdlib `base64` module has **no incremental encoder/decoder class** for
base32. The `codecs` module defines generic `IncrementalEncoder`/
`IncrementalDecoder` base classes, but `iterencode`/`iterdecode` explicitly
reject bytes-to-bytes codecs such as `base64_codec`, and there is no
`base32_codec` at all. (Sources: https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/codecs.html)

Leftover-byte handling is therefore the **caller's** responsibility. The
base32-internal chunk logic only exists inside one call; across calls the caller
must align encode chunks to a multiple of 5 bytes and carry `len(data) % 5`
bytes, and on decode must defer the final 0–7 symbols (a partial 8-symbol
quantum) until the last call. `binascii.Incomplete` is the stdlib's own
acknowledgement that "incomplete data … may be handled by reading a little more
data and trying again", but the modern `b32*` wrappers do not raise it. (Sources:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py,
https://docs.python.org/3/library/binascii.html) (Assessment: derived from the
absence of an incremental API and the `binascii.Incomplete` retry contract.)

## 10. Interesting design decisions

- **Two independent alphabets with security-hardened defaults.** `casefold=False`
  and `map01=None` are deliberately restrictive because accepting lower case or
  `0/1` is a confusability and equality-comparison risk; the docs say so
  explicitly, matching RFC 4648 §12. (Sources:
  https://docs.python.org/3/library/base64.html,
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **Alphabet as a separate function pair, not a parameter.** `b32encode` vs
  `b32hexencode`: two functions rather than one `alphabet=` argument — simple,
  but it multiplies the surface across the base16/32/64 family.
- **3.15 converges on cross-codec options.** `padded`, `wrapcol`,
  `ignorechars` and `canonical` are added consistently across the `b64*`,
  `b32*`, `b32hex*` and `b16*` pairs, so padding, wrapping and canonicality
  become uniform concepts. (Source:
  https://docs.python.org/3.15/library/base64.html)
- **`canonical` as an explicit opt-in.** Rather than always rejecting
  non-zero trailing bits (as gnulib/C and glibc do), Python exposes
  `canonical=False` by default — a permissive default with a strict switch.
  (Source: https://docs.python.org/3.15/library/base64.html)
- **Pure-Python base32 vs C base64.** The performance asymmetry is explicit:
  base64 delegates to `binascii`, base32 loops in Python. A reminder that a
  base32 core deserves a native implementation if speed matters. (Source:
  https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)
- **Error taxonomy**: `binascii.Error` ("data is wrong") vs
  `binascii.Incomplete` ("need more data") — a useful separation to reuse.
  (Source: https://docs.python.org/3/library/binascii.html)

## 11. Decisions NOT to copy

- **Permissive-by-default decode for base32.** `casefold=False`/`map01=None` are
  strict, but `canonical=False` and (pre-3.15) no `padded` control mean
  non-canonical encodings are silently accepted. A predictable API should make
  canonicality the explicit, easy default. (Assessment: derived from
  https://docs.python.org/3.15/library/base64.html)
- **A separate function pair per alphabet.** `b32encode`/`b32hexencode` scales
  poorly; a typed alphabet parameter/enum is more composable.
- **`map01` confusable mapping as an opt-in.** Accepting `0/O` and `1/I/L` is a
  security footgun even opt-in; keep it out or document it as interop-only.
- **Pure-Python hot loop.** Do not reproduce a slow base32 core when Mojo can
  have one native path for all radices.
- **`ignorechars` coupled to `validate` semantics — base64-derived only.**
  In `b64decode` the default of `validate` changes to `True` iff `ignorechars` is
  supplied, an implicit coupling of two arguments a Mojo signature should keep
  orthogonal. This is a **base64** observation: `b32decode`/`b32hexdecode` accept
  `ignorechars` but have **no `validate` parameter**, so the coupling does not
  exist on the base32 path. (Sources:
  https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py,
  https://docs.python.org/3.15/library/base64.html)

## 12. Ideas fitting Mojo

- **A pure, `raises`-based base32 codec** declaring malformed/incorrectly-padded
  input as a typed error, separating "invalid data" from "incomplete data" the
  way `binascii.Error` vs `binascii.Incomplete` does. (Sources:
  https://docs.python.org/3/library/binascii.html, `mojov1/errors/error-model`.)
- **Explicit, typed alphabet parameter** — standard base32 and base32hex as
  first-class values (mirroring `b32*` vs `b32hex*`), plus a future Crockford
  variant, instead of one function per alphabet.
- **Case policy as an explicit enum** (`Upper` default, `Lower`, `Mixed`) rather
  than a boolean `casefold`, so strictness/leniency is visible at the call site;
  Elixir's `:case` option is the direct precedent (§Elixir `elixir.md` §7).
- **Padding and canonicality as explicit, orthogonal `comptime` parameters**
  (`padded: Bool`, `canonical: Bool`), matching Python 3.15's naming and RFC
  4648 §3.2/§3.5. (Sources:
  https://docs.python.org/3.15/library/base64.html,
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **A dedicated streaming type** exposing `feed(chunk)` and `finish()` with an
  internally carried 0–4 byte encode remainder or 0–7 symbol decode remainder —
  filling the gap Python leaves to the caller.
- **Value-semantics output**: return an owned `String`/`List[UInt8]` and take the
  input as `borrowed` bytes, so encode never copies the caller's buffer.
- **`encoded_length(n) = 8*ceil(n/5)` as a pure function** for caller-side buffer
  sizing, the base32 analogue of Python's implicit sizing.
  (Assessment: derived from RFC 4648 §6 and the Python findings above.)

## Sources

- https://docs.python.org/3/library/base64.html
- https://docs.python.org/3.15/library/base64.html
- https://docs.python.org/3/library/binascii.html
- https://docs.python.org/3/library/codecs.html
- https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py
- https://pypi.org/project/pybase64/
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  https://www.rfc-editor.org/rfc/rfc4648.txt
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
