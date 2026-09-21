# base64 research: Python

## 1. Standard library support

Python ships a dedicated `base64` module for Base16, Base32, Base64, Base85 and
Ascii85 (RFC 4648 plus non-standard Base85 variants), with two interfaces: a
modern one (bytes-like in, `bytes` out) and a legacy file-oriented one. Base64
decode support in the modern interface also accepts ASCII-only strings.
(Source: https://docs.python.org/3/library/base64.html)

The low-level C engine is `binascii`, which "contains low-level functions written
in C for greater speed that are used by the higher-level modules", including
`a2b_base64`, `b2a_base64`, `b2a_base32`/`a2b_base32`, `b2a_hex`/`a2b_hex`.
(Source: https://docs.python.org/3/library/binascii.html)

Base16 also exists directly on `bytes`: `bytes.hex()` returns a text string, while
`binascii.hexlify` / `binascii.b2a_hex` return `bytes`; `hexlify` produces
lowercase, whereas `base64.b16encode` upper-cases the result. (Sources:
https://docs.python.org/3/library/binascii.html,
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

There is also a codec-registry path (`codecs.encode(obj, "base64_codec")`), but
`iterencode`/`iterdecode` explicitly do not support bytes-to-bytes codecs such as
`base64_codec`; the `base64` module is the recommended route. (Source:
https://docs.python.org/3/library/codecs.html)

## 2. Relevant community libraries

- **pybase64** — a wrapper around the C library `libbase64` (aklomp/base64),
  author Matthieu Darbois, license BSD-2-Clause, production/stable, "uses the same
  API as Python base64 'modern interface' … for easy integration". It is the
  performance-oriented drop-in (benchmarks in its README show ~17 GB/s encode vs
  ~2.6 GB/s for CPython's `base64`). (Source: https://pypi.org/project/pybase64/)
- **base64io** — a PyPI package that wraps streams for transparent base64
  encode/decode; noted as the common streaming alternative to the stdlib. No
  primary source fetched for this run. `GUESS:` base64io's API details, because
  only its PyPI landing page was referenced and the fetch failed (JS challenge).
- The wider ecosystem also has `base64url`, `pybase64`, and codec-based packages;
  the reference signal is dominated by pybase64 and stdlib. (Assessment: derived
  from https://pypi.org/project/pybase64/ and the stdlib docs.)

## 3. Exposed APIs

Modern RFC 4648 interface (Source: https://docs.python.org/3/library/base64.html):

- `b64encode(s, altchars=None)` → `bytes`; optional `altchars` is a 2-byte
  alternative alphabet for `+` and `/`.
- `b64decode(s, altchars=None, validate=False)` → `bytes`.
- `standard_b64encode(s)` / `standard_b64decode(s)`.
- `urlsafe_b64encode(s)` / `urlsafe_b64decode(s)` — `-` for `+` and `_` for `/`;
  "the result can still contain `=`".
- `b32encode(s)` / `b32decode(s, casefold=False, map01=None)`.
- `b32hexencode(s)` / `b32hexdecode(s, casefold=False)` (added 3.10).
- `b16encode(s)` / `b16decode(s, casefold=False)`.
- `a85encode`/`a85decode`, `b85encode`/`b85decode`, `z85encode`/`z85decode`
  (Base85 family, options `foldspaces`, `wrapcol`, `pad`, `adobe`).

Legacy interface (file objects / RFC 2045): `encode(input, output)`,
`decode(input, output)`, `encodebytes(s)`, `decodebytes(s)` — 76-char lines plus
trailing newline. (Source: https://docs.python.org/3/library/base64.html)

The current `main` branch source adds `padded` and `wrapcol` keyword arguments to
`b64encode`, `b64decode`, `b32*`, `b16*` and `urlsafe_b64encode`, plus new
`ignorechars`, `canonical` decode options. (Source:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py) The 3.14.7
docs page still documents the older signatures without `padded`/`wrapcol`.
(Assessment: derived from comparing the docs page with the main-branch source.)

## 4. Error representation

Errors are **exceptions**, not return codes. `binascii.Error` is raised for
incorrect padding or non-alphabet characters; `TypeError` when `altchars` is not
bytes-like; `ValueError` when `altchars` is not length 2; `UnicodeEncodeError`
(under `binascii`/`base64`) when a decode input string contains non-ASCII.
(Sources: https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/binascii.html)

Important semantic split: `b64decode(..., validate=False)` (default) **discards**
non-alphabet characters before the padding check, while `validate=True` raises. In
`binascii.a2b_base64(strict_mode=True)` valid input must contain no excess data
after padding, must not start with padding, and must contain only alphabet chars.
(Sources: https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/binascii.html)

`binascii.Incomplete` exists specifically for "incomplete data … may be handled by
reading a little more data and trying again" — the stdlib's own hint that stream
decoding needs a retry path. (Source: https://docs.python.org/3/library/binascii.html)

## 5. Ownership semantics (buffer/ownership of input and output)

Python is memory-managed: every encode/decode call returns a **new immutable
`bytes` object** owned by the caller; there is no manual free. The input is a
"bytes-like object" (accepts `bytes`, `bytearray`, other buffer-protocol objects),
but the module never mutates it. (Source:
https://docs.python.org/3/library/base64.html)

`_bytes_from_decode_data(s)` normalizes input: `str` is ASCII-encoded, `bytes`/
`bytearray` pass through, anything else goes through `memoryview(s).tobytes()`
(i.e. copied). Decode outputs may be large temporary allocations; the module
relies on GC. (Source: https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

`b64encode` builds an alphabet by slicing `binascii.BASE64_ALPHABET[:-2]` and
appending `altchars`, i.e. it constructs a new 64-byte alphabet table rather than
mutating a shared one. (Source:
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

`bytes.hex()` returns an owned `str`; `binascii.hexlify` an owned `bytes`. The
`sep`/`bytes_per_sep` options of `b2a_hex` produce a formatted copy, never an
in-place edit. (Source: https://docs.python.org/3/library/binascii.html)

The legacy file interface is the only mutation-ish path: `encode(input, output)`
writes into a caller-supplied file object; ownership of the file stays with the
caller. (Source: https://docs.python.org/3/library/base64.html)

## 6. Blocking / non-blocking

Not applicable in the concurrency sense: base64 is a pure, CPU-bound transform
with no I/O and no await points. The modern API is synchronous and blocking only
for the duration of the CPU work. `binascii` releases the GIL inside the C
functions when possible; pybase64 documents "Release the GIL" in its 1.2.0 change
log. (Sources: https://docs.python.org/3/library/base64.html,
https://pypi.org/project/pybase64/)

GUESS: whether every `binascii` entry point releases the GIL is not documented
per-function; the pybase64 changelog is the only explicit GIL statement found.

## 7. Alphabet variants and padding

- **Standard Base64**: `A–Z a–z 0–9 + /` with `=` padding.
- **URL- and filesystem-safe Base64**: `-` instead of `+`, `_` instead of `/`;
  "the result can still contain `=`" in the classic API.
- **Alternative alphabet (`altchars`)**: caller passes a 2-byte object replacing
  `+` and `/` — this is how arbitrary custom alphabets are expressed without a new
  function. `altchars` must be length 2.
- **Base32** has the standard alphabet plus `casefold` for lowercase input, and
  `map01` to optionally map `0`→`O` and `1`→`I`/`L`; for security the default is
  `None` (0 and 1 not allowed).
- **Base32hex** (Extended Hex Alphabet, RFC 4648) deliberately does **not** allow
  the `0`/`O` and `1`/`I`/`L` mappings because those characters are all in the
  alphabet.
- **Base16** uppercase output from `b16encode`, lowercase from `hexlify`;
  `casefold` controls lowercase input acceptance.
- **Base85 family**: `a85` (btoa/PDF, `adobe`, `foldspaces`), `b85` (RFC 1924/git),
  `z85` (ZeroMQ).

(Sources: https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/binascii.html,
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

Padding is **on by default and expected** for Base64/Base32/Base16; wrong padding
raises `binascii.Error`. URL-safe decode historically tolerates missing padding
only via `validate=False`/`padded=False`; `urlsafe_b64decode` in the current main
branch defaults to `padded=False`. (Sources:
https://docs.python.org/3/library/base64.html,
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

## 8. Timeouts

Not applicable: no I/O, no blocking resource, no cancellation. There is no timeout
parameter anywhere in `base64`/`binascii`. (Source:
https://docs.python.org/3/library/base64.html) Cancellation would only be a
thread/process-level concern, not part of the codec API.

## 9. Streaming / incremental encode+decode

The stdlib `base64` module has **no incremental encoder/decoder class**. The
`codecs` module defines generic `IncrementalEncoder`/`IncrementalDecoder` base
classes, but `iterencode`/`iterdecode` explicitly reject bytes-to-bytes codecs like
`base64_codec`. (Sources: https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/codecs.html)

Leftover-byte handling is therefore done by the **caller** choosing chunk sizes.
The legacy `encode()` reads chunks of `MAXBINSIZE = (76//4)*3 = 57` bytes so each
block produces a clean 76-char line with no interior padding; `decode()` reads
line by line. (Source: https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

Practical streaming with padding handled correctly must carry the remainder: a
common pattern is to buffer `len(data) % 3` input bytes on encode (or align chunks
to 3/57 bytes), and on decode to defer the final 0–3 characters until the last
call. (Assessment: derived from the module's `encode()` chunk logic and the
`binascii.Incomplete` retry contract.)

## 10. Interesting design decisions

- **Two APIs, one module**: modern bytes API vs legacy RFC-2045 file API, with the
  legacy one kept for MIME compatibility (`encodebytes`, 76-char wrap).
- **Alphabet as a parameter, not a function family**: `altchars` gives custom
  alphabets generically, while `urlsafe_*` are convenience wrappers.
- **Lax-by-default decode**: `validate=False` discards junk silently;
  `validate=True` opts into strictness. This is the opposite of the usual
  "secure default" and is explicitly called out in the security note.
- **Security defaults for Base32**: `casefold=False`, `map01=None` — deliberately
  strict because the alternative permits confusable inputs.
- **Error taxonomy**: `binascii.Error` (bad data) vs `binascii.Incomplete` (need
  more data) vs `TypeError`/`ValueError` (bad arguments) — a useful separation of
  "data is wrong" from "caller is wrong".
- **`bytes.hex()` and `binascii.hexlify` both exist**, with different case and
  return types (str vs bytes) — a real-world redundancy to learn from.

(Sources: https://docs.python.org/3/library/base64.html,
https://docs.python.org/3/library/binascii.html,
https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py)

## 11. Decisions NOT to copy

- **Silent discard by default** (`validate=False`). A predictable, low-vision-
  friendly API should make strictness the explicit, easy default rather than
  requiring `validate=True`. (Assessment: derived from
  https://docs.python.org/3/library/base64.html)
- **Two overlapping Base16 spellings** (`hexlify` vs `b16encode`, str vs bytes,
  lower vs upper). Pick one canonical name and one return type.
- **Legacy file-object API baked into the same module** (`encode`/`decode`
  shadowing the modern meaning). Keep streaming as its own typed abstraction.
- **A `map01` confusable-mapping option**: it exists for interop with sloppy
  producers, but accepting `0/O` and `1/I/L` by default is a security footgun.
- **Codec-registry entry (`base64_codec`)** as a parallel path that cannot do
  incremental iteration — inconsistent and not worth mirroring.

## 12. Ideas fitting Mojo

- A **pure, `raises`-based codec**: encode/decode declare `raises` for
  malformed/incorrectly-padded input, matching Mojo's error model instead of
  exceptions; separate "invalid data" from "incomplete data" the way `binascii.Error`
  vs `binascii.Incomplete` does.
- **Explicit, typed alphabet parameter** (e.g. an enum plus an optional custom
  alphabet) mirroring `altchars`, with standard/URL-safe as first-class constants.
- **Value-semantics output**: return an owned `String`/`List[UInt8]`, and take the
  input as `borrowed` bytes so encode never copies the caller's buffer.
- **Padding as an explicit `padded: Bool` parameter**, not an implicit lax mode —
  strict by default, matching Python's newer `padded` direction.
- **A dedicated streaming/incremental type** exposing `feed(chunk)` and `finish()`
  with an internally carried 0–2 byte encode remainder or 0–3 char decode
  remainder — filling the gap Python leaves to the caller.
- **Compile-time alphabet selection** via parameter/comptime if Mojo allows, so the
  common standard/URL-safe cases have no runtime branch.

(Assessment: derived from the Python findings above plus the `mojov1` buch page
`stdlib/base64`, which records that Mojo's stdlib already offers `b64encode`,
`b64decode`, `b16encode`, `b16decode` and that `b64decode` ignores whitespace but
rejects other non-alphabet characters.)

## Sources

- https://docs.python.org/3/library/base64.html
- https://docs.python.org/3/library/binascii.html
- https://docs.python.org/3/library/codecs.html
- https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py
- https://pypi.org/project/pybase64/
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
