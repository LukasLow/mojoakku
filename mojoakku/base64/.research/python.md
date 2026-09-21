# base64 research: Python

Scope: the `base64`/`binascii` standard-library pair, the `base64_codec`, and the
two main community libraries (`base64io`, `pybase64`). Every factual claim carries
a source; unsourced statements are marked `GUESS:`.

## 1. Standard library support

- `base64` is in the stdlib as `Lib/base64.py`, with the low-level routines in the
  C module `Modules/binascii.c`. Source:
  <https://docs.python.org/3/library/base64.html> ("Source code: Lib/base64.py").
- Module purpose: "functions for encoding binary data to printable ASCII
  characters and decoding such encodings back to binary data", covering the RFC 4648
  encodings (Base64, Base32, Base16) plus Base85/Ascii85. Source: same page.
- Two interfaces are provided: the modern interface (bytes-like to bytes) and the
  legacy interface (file objects, RFC 2045/MIME, newline every 76 characters).
  Source: same page.
- Both RFC 4648 base-64 alphabets are supported: "normal, and URL- and
  filesystem-safe". Source: same page.
- `binascii` is the "Support module containing ASCII-to-binary and binary-to-ASCII
  conversions"; the `base64` docstring says the high-level module is a wrapper.
  Source: <https://docs.python.org/3/library/binascii.html>.
- The codec registry also exposes `'base64_codec'` (aliases `base64`, `base_64`):
  "Convert the operand to multiline MIME base64 (the result always includes a
  trailing `'\n'`)." It is implemented on top of `base64.encodebytes()` and
  `base64.decodebytes()`. Source: <https://docs.python.org/3/library/codecs.html>
  (Binary Transforms) and
  <https://raw.githubusercontent.com/python/cpython/main/Lib/encodings/base64_codec.py>.
- `base64_codec` is a bytes-to-bytes codec, so `codecs.iterencode()`/`iterdecode()`
  explicitly do not support it ("Therefore it does not support bytes-to-bytes
  encoders such as `base64_codec`."). Source:
  <https://docs.python.org/3/library/codecs.html>.
- Version drift to be aware of: the dev documentation (3.15) lists `padded`,
  `wrapcol`, `canonical` and `ignorechars`; the stable 3.14 page does not. Sources:
  <https://docs.python.org/3.15/library/base64.html> vs
  <https://docs.python.org/3/library/base64.html>.

## 2. Relevant community libraries

- `base64io` (AWS, Apache 2.0). Purpose: "This project is designed to develop a
  class, `base64io.Base64IO`, that implements a streaming interface for Base64
  encoding." Stated motivation: "Python has supported native Base64 encoding since
  version 2.4. However, there is no streaming interface for Base64 encoding, and
  none is available from the community." Source:
  <https://github.com/aws/base64io-python/blob/master/README.rst>.
- `base64io` version 1.0.3 (2018-12-10), no dependencies beyond the stdlib, tested
  on CPython 3.8-3.12. Source:
  <https://base64io-python.readthedocs.io/en/latest/>.
- `pybase64` (maintainer mayeut, BSD-2-Clause, 182 stars at time of reading).
  "This project is a wrapper on libbase64" and "uses the same API as Python base64
  'modern interface' (introduced in Python 2.4) for an easy integration". Source:
  <https://github.com/mayeut/pybase64>.
- `pybase64` extra surface: `b64encode_as_string`, `b64decode_as_bytearray`, and
  the parameters `padded`, `wrapcol`, `ignorechars`, `canonical`. Source: same
  README (changelog 1.1.0 and 1.5.0).
- Reported throughput gap (pybase64 README benchmark; Python 3.15.0rc1 on Apple M1
  Max): `pybase64.b64encode` 17492 MB/s versus stdlib `base64.b64encode`
  2653 MB/s; `pybase64.b64decode` 9037 MB/s versus stdlib 2656 MB/s. Source: same
  README.
- `base64io` explicitly disclaims `seek()`, `tell()`, `fileno()` and `truncate()`,
  "Because the position of the `base64io.Base64IO` stream and the wrapped stream
  will almost always be different". Source: base64io README.

## 3. Exposed APIs

Modern interface (signatures as documented for 3.15; 3.14 lacks the starred
parameters):

- `base64.b64encode(s, altchars=None, *, padded=True, wrapcol=0) -> bytes`
- `base64.b64decode(s, altchars=None, validate=False, *, padded=True, canonical=False)`
- `base64.b64decode(s, altchars=None, validate=True, *, ignorechars, padded=True, canonical=False)`
- `base64.standard_b64encode(s) -> bytes` / `base64.standard_b64decode(s) -> bytes`
- `base64.urlsafe_b64encode(s, *, padded=True) -> bytes` / `base64.urlsafe_b64decode(s, *, padded=False) -> bytes`
- `base64.b32encode`, `b32decode`, `b32hexencode`, `b32hexdecode`
- `base64.b16encode`, `b16decode`
- `base64.b85encode`/`b85decode`, `a85encode`/`a85decode`, `z85encode`/`z85decode`
- Source: <https://docs.python.org/3.15/library/base64.html>.

Legacy interface:

- `base64.encode(input, output)` / `base64.decode(input, output)`: "input and output
  must be file objects. input will be read until `input.read()` returns an empty
  bytes object." `encode()` "inserts a newline character (`b'\n'`) after every 76
  bytes of the output, as well as ensuring that the output always ends with a
  newline, as per RFC 2045 (MIME)". Source:
  <https://docs.python.org/3/library/base64.html#base64-legacy>.
- `base64.encodebytes(s)` / `base64.decodebytes(s)`: the same MIME encoding to and
  from bytes. Source: same page.
- `base64.decodebytes` was added in 3.1. Source: same page.

Module surface from the current source (`__all__`): `encode, decode, encodebytes,
decodebytes, b64encode, b64decode, b32encode, b32decode, b32hexencode, b32hexdecode,
b16encode, b16decode, b85encode, b85decode, a85encode, a85decode, z85encode,
z85decode, standard_b64encode, standard_b64decode, urlsafe_b64encode,
urlsafe_b64decode`. Source:
<https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py>.

- CLI entry point: `python -m base64 [-h|-d|-e|-u] [file|-]`, encode by default,
  `-d`/`-u` decode; reads stdin when no file or `-`. Source: `Lib/base64.py` `main()`.

## 4. Error representation

- Exceptions only: no error codes, no `Result`/`Either`, no sentinels.
- `binascii.Error` is the decode-failure exception: "A `binascii.Error` exception is
  raised if s is incorrectly padded." Source:
  <https://docs.python.org/3/library/base64.html>.
- `binascii.Error` is a subclass of `ValueError`:
  `state->Error = PyErr_NewException("binascii.Error", PyExc_ValueError, NULL);` in
  `Modules/binascii.c`, verified by the test suite
  (`self.assertIsSubclass(binascii.Error, ValueError)`). Sources:
  <https://raw.githubusercontent.com/python/cpython/main/Modules/binascii.c>,
  <https://raw.githubusercontent.com/python/cpython/main/Lib/test/test_base64.py>.
- A second exception, `binascii.Incomplete`, exists for incomplete data:
  `state->Incomplete = PyErr_NewException("binascii.Incomplete", NULL, NULL);`.
  Source: `Modules/binascii.c`.
- `TypeError` for non-bytes-like input; `ValueError` for a non-length-2 `altchars`
  (`raise ValueError(f'invalid altchars: {altchars!r}')`) and for non-ASCII `str`
  input (`'string argument should contain only ASCII characters'`). Source:
  `Lib/base64.py` `_bytes_from_decode_data()` and `b64encode()`.
- Lenient by default: with `validate=False` "characters that are neither in the
  normal base-64 alphabet nor the alternative alphabet are discarded prior to the
  padding check"; with `validate=True` "these non-alphabet characters in the input
  result in a `binascii.Error`". Source:
  <https://docs.python.org/3/library/base64.html>.
- 3.15 adds `canonical=True`, which "rejects non-zero padding bits" per RFC 4648
  section 3.5. Source: <https://docs.python.org/3.15/library/base64.html> and
  `Modules/binascii.c` (`"Non-zero padding bits"`).
- The C decoder's error vocabulary doubles as a de facto taxonomy: `"Incorrect
  padding"`, `"Leading padding not allowed"`, `"Excess padding not allowed"`,
  `"Padding not allowed"`, `"Only base64 data is allowed"`, `"Excess data after
  padding"`, `"Discontinuous padding not allowed"`, `"Invalid base64-encoded string:
  number of data characters ... cannot be 1 more than a multiple of 4"`. Source:
  `Modules/binascii.c`.
- 3.15 migrates to stricter behaviour via warnings rather than exceptions:
  `FutureWarning` ("will be discarded in future Python versions") when `+`/`/` are
  passed alongside an alternative alphabet with `validate=False`, and
  `DeprecationWarning` with `validate=True`. Source: `Lib/base64.py` `b64decode()`.

## 5. Ownership semantics of encode input and output

- Encoding input is borrowed, never mutated. The test helper asserts this
  explicitly on a `bytearray` argument: "The bytearray wasn't mutated"
  (`BaseXYTestCase.check_other_types`). Source: `Lib/test/test_base64.py`.
- Accepted input is any bytes-like object, plus (decode only) an ASCII-only `str`:
  `bytes_types = (bytes, bytearray)`; `_bytes_from_decode_data()` accepts `str`
  (ASCII only), `bytes`/`bytearray`, or anything supporting the buffer protocol via
  `memoryview(s).tobytes()`. Source: `Lib/base64.py`.
- Output ownership: the modern interface always returns a freshly allocated `bytes`
  object ("return the encoded `bytes`"). The C side allocates with `PyBytesWriter`
  and finishes with `PyBytesWriter_FinishWithPointer`. Sources:
  <https://docs.python.org/3/library/base64.html>, `Modules/binascii.c`.
- `pybase64` is the only studied implementation that offers alternative output
  ownership: `b64encode_as_string` ("same as `b64encode` but returns a `str` object
  instead of a `bytes` object") and `b64decode_as_bytearray`. Source: pybase64
  README changelog 1.1.0.
- Legacy `encode(input, output)`/`decode(input, output)` own neither stream: they
  only read/write caller-provided file objects and never close them. Source:
  `Lib/base64.py` (`while s := input.read(MAXBINSIZE)` and `output.write(line)`).
- `base64io.Base64IO` wraps a caller-owned stream: "wraps the input stream and
  transparently encodes or decodes data written to or read from the input stream";
  `write()` encodes data before writing it to the wrapped stream, `read()` decodes
  data after reading it from the wrapped stream. Source: base64io README.
- `Base64IO` buffering contract: on write it "might hold up to two bytes of
  unencoded data in an internal buffer before writing it to the wrapped stream";
  the caller "must close the stream after your final write" unless the context
  manager is used, because "Calling `close()` flushes this buffer and writes the
  padded result to the wrapped stream". On decode, "it might read up to three
  additional bytes from the underlying stream". Source: base64io README.
- Python has no explicit free or ownership transfer; object lifetime is
  reference-count/GC driven, so "who frees what" has no API-level answer. Source:
  the API never exposes allocation or free (full listing in section 3).

## 6. Blocking / non-blocking

- The modern encode/decode functions perform no I/O at all; they are pure CPU-bound
  transformations of an in-memory buffer. Source: `Lib/base64.py` — the functions
  call `binascii.b2a_base64`/`a2b_base64` and return directly.
- There is no non-blocking, async, cancellation or coroutine API anywhere in
  `base64` or `binascii`. Source: the complete API listing at
  <https://docs.python.org/3/library/base64.html> and
  <https://docs.python.org/3/library/binascii.html>.
- Legacy `encode()`/`decode()` and `base64io` perform blocking reads/writes on the
  file objects/stream handed to them; concurrency behaviour is inherited from the
  stream, not from the codec. Sources: `Lib/base64.py`; base64io README.
- GIL: `pybase64` deliberately added GIL release in 1.2.0 ("Release the GIL"), a
  concurrency-relevant decision for a C extension. Source: pybase64 README
  changelog 1.2.0.
- `GUESS:` CPython's `binascii.a2b_base64`/`b2a_base64` do not release the GIL.
  Reason no source exists: neither the doc pages nor `Modules/binascii.c` mention a
  GIL release around these calls, and I found no source asserting either behaviour.

## 7. Alphabet variants and padding handling

- Standard alphabet per RFC 4648 section 4: `A-Z`, `a-z`, `0-9`, `+`, `/`, with `=`
  as pad. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt> section 4.
- URL-/filename-safe alphabet replaces value 62 `+` with `-` and value 63 `/` with
  `_`, pad `=` unchanged: "substitutes `-` instead of `+` and `_` instead of `/`".
  Sources: <https://docs.python.org/3/library/base64.html>; RFC 4648 section 5.
- Generic alternative alphabet: `altchars` is a two-byte override for exactly `+`
  and `/` — "a bytes-like object of length 2 which specifies an alternative alphabet
  for the `+` and `/` characters". It is not a full 64-character alphabet; the
  Python layer builds `binascii.BASE64_ALPHABET[:-2] + altchars`. Sources:
  <https://docs.python.org/3/library/base64.html>; `Lib/base64.py`.
- Padding default on encode: `padded=True`, i.e. "If padded is true (default), pad
  the encoded data with the '=' character to a size multiple of 4. If padded is
  false, do not add the pad characters." Source:
  <https://docs.python.org/3.15/library/base64.html>.
- `padded=False` on decode means padding is "neither required nor recognized: the
  '=' character is not treated as padding but as a non-alphabet character, which
  means it is silently discarded when validate is false, or causes an Error when
  validate is true unless b'=' is included in ignorechars". Source: 3.15 docs.
- Asymmetry to note: `urlsafe_b64decode` switched to `padded=False` by default in
  3.15 ("Padding of input is no longer required by default"), while `b64decode`
  still defaults to `padded=True`. Sources: 3.15 docs; `Lib/base64.py` signature.
- Missing padding is an error by default: the test suite asserts
  `binascii.Error` for `b'abc'` and "Incorrect padding" for unpadded
  `urlsafe_b64decode(b'YQ')` with `padded=True`. Source: `Lib/test/test_base64.py`
  (`test_b64decode_padding_error`, `test_b64decode_padded`).
- Decode is lenient about non-alphabet characters by default (whitespace, newlines,
  stray bytes are discarded). RFC 4648 section 3.3 says "Implementations MUST reject
  the encoded data if it contains characters outside the base alphabet when
  interpreting base-encoded data, unless the specification referring to this
  document explicitly states otherwise" — Python's default does not follow that
  recommendation. Source: RFC 4648 section 3.3.
- `urlsafe_b64decode` still tolerates `+`/`/` on input but warns; deprecation was
  announced in 3.15. Sources: `Lib/base64.py` (`FutureWarning` in
  `urlsafe_b64decode()`); 3.15 docs ("Deprecated since version 3.15").
- Canonical encoding: RFC 4648 section 3.5 says "These pad bits MUST be set to zero
  by conforming encoders" and "decoders MAY chose to reject an encoding if the pad
  bits have not been set to zero" — exactly what `canonical=True` implements.
  Sources: RFC 4648 section 3.5; 3.15 docs.

## 8. Timeouts

- No timeout, deadline, retry or cancellation concept exists in `base64` or
  `binascii`. Source: the complete API listings in sections 1 and 6.
- Time can only matter when the caller drives a stream: legacy
  `base64.encode()/decode()` and `base64io` block on the underlying file object, so
  timeouts are the stream's responsibility, not the codec's. Sources:
  `Lib/base64.py`; base64io README.
- Conclusion for this research: there is nothing to copy here. A base64 codec has no
  natural timeout surface; if MojoAkku needs timeouts they belong to the eventual
  TCP/HTTP layers, not to `base64`.

## 9. Streaming (incremental / chunked encode and decode, leftover bytes)

- The modern stdlib interface is strictly whole-buffer: every function takes a
  complete bytes-like object and returns a complete result. There is no
  `update()`/`final()` pair and no leftover-byte state exposed to the caller.
  Source: `Lib/base64.py`.
- The `base64_codec`'s `IncrementalEncoder`/`IncrementalDecoder` are not actually
  incremental: each call runs `base64.encodebytes(input)` /
  `base64.decodebytes(input)` on the whole argument and ignores the `final`
  parameter entirely. Source: `Lib/encodings/base64_codec.py`.
- `codecs.iterencode()`/`iterdecode()` cannot be used with it, because it is a
  bytes-to-bytes codec. Source: <https://docs.python.org/3/library/codecs.html>.
- The only real chunking in the stdlib is the legacy file interface:
  `encode()` reads `MAXLINESIZE = 76`, `MAXBINSIZE = (MAXLINESIZE//4)*3 = 57` bytes,
  tops the read up to a full 57-byte unit
  (`while len(s) < MAXBINSIZE and (ns := input.read(MAXBINSIZE-len(s))): s += ns`),
  then encodes one 76-character line at a time; `decode()` reads line by line via
  `input.readline()`. Source: `Lib/base64.py`.
- 57 is the chunk size because it is the largest whole number of input bytes that
  produces exactly one 76-character MIME line: 76 == 57*4/3. Source: the constant
  computation in `Lib/base64.py`; the same arithmetic is stated verbatim in the Perl
  POD (see perl.md).
- `base64io` is the community answer to the missing streaming API: a real streaming
  wrapper with internal buffers — up to 2 unencoded bytes held on write and flushed
  by `close()`, up to 3 extra bytes read on decode. Source: base64io README.
- `base64io`'s buffer sizes are exactly the quantum arithmetic: 3 input bytes map to
  4 output characters, so a streaming encoder must retain `len % 3` bytes (0, 1 or
  2) after every write; a streaming decoder must be able to look ahead within a
  4-character group. Source: RFC 4648 section 4 (24-bit input groups; final quantum
  of 8 or 16 bits).
- `pybase64` adds no streaming API; it mirrors the modern whole-buffer interface.
  Source: pybase64 README.
- Streaming default relevant to any chunked implementation: RFC 4648 section 3.1
  says "Implementations MUST NOT add line feeds to base-encoded data unless the
  specification referring to this document explicitly directs base encoders to add
  line feeds after a specific number of characters." Source: RFC 4648 section 3.1.

## 10. Interesting design decisions

- Two-tier interface with self-describing names: modern `b64encode`/`b64decode`
  beside `standard_*`/`urlsafe_*` convenience names and the legacy
  `encodebytes`/`decodebytes`. The alphabet choice is visible in the function name.
  Source: `Lib/base64.py` `__all__` and docstrings.
- Lenient by default, strict on request, canonical on request: correctness is added
  as *additional switches* (`validate`, then 3.15 `canonical`) instead of changing
  the default. Sources: <https://docs.python.org/3/library/base64.html>; 3.15 docs;
  `binascii_a2b_base64_impl`.
- A sentinel default makes one parameter depend on another:
  `_NOT_SPECIFIED = ['NOT SPECIFIED']` with
  `if validate is _NOT_SPECIFIED: validate = ignorechars is not _NOT_SPECIFIED` —
  passing `ignorechars` silently enables strict mode. Source: `Lib/base64.py`.
- `altchars` as a two-character override is cheap to reason about and cheap to
  implement (rebuild the 64-byte alphabet once per call). Source: `Lib/base64.py`.
- `b16encode` deliberately uppercases `hexlify`, and the source records why:
  "RFC 4648, Base 16 Alphabet specifies uppercase, but hexlify() returns lowercase.
  The RFC also recommends against accepting input case insensitively." Source:
  `Lib/base64.py`.
- The C decoder separates a fast path for complete quads from a slow path for
  padding/invalid/partial groups, with 64-byte-aligned lookup tables; the fast path
  "works for both strict and non-strict mode for valid input". Source:
  `Modules/binascii.c` (`base64_decode_fast`, `fastpath`, `_Py_ALIGNED_DEF(64, ...)`).
- Wrapping is done by inserting and shifting in place: `wraplines()` moves the
  already-encoded data right with `memmove` to make room for `\n` characters, so no
  second buffer is needed. Source: `Modules/binascii.c`.
- The error-message vocabulary is reused as the de facto error taxonomy (padding vs
  alphabet vs excess-after-padding vs discontinuous padding), giving callers
  machine-checkable messages without adding exception classes. Sources:
  `Modules/binascii.c`; `Lib/test/test_base64.py` `assertRaisesRegex` uses.
- `base64io` documents its limitations and its flush contract up front instead of
  hiding them — an honesty-about-buffering documentation decision worth copying.
  Source: base64io README.
- `pybase64` chose API convergence with CPython 3.15 (adopting `padded`,
  `wrapcol`, `ignorechars`, `canonical`) rather than inventing its own surface.
  Source: pybase64 README changelog 1.5.0.

## 11. Decisions NOT to copy into MojoAkku

- Lenient decode as the default. It silently discards arbitrary bytes; RFC 4648
  section 3.3 warns that "If non-alphabet characters are ignored, instead of causing
  rejection of the entire encoding (as recommended), a covert channel that can be
  used to 'leak' information is made possible." Python only begins tightening this
  in 3.15.
- Three overlapping ways to express the alphabet (`altchars`, `urlsafe_*`,
  `standard_*`). One concept plus an alphabet parameter is clearer.
- The bytes-versus-ASCII-`str` duality on decode (`_bytes_from_decode_data`
  accepting `str`). It hides an extra encode step and creates an error path
  ("string argument should contain only ASCII characters") unrelated to base64.
- The `base64_codec` pseudo-incremental encoder/decoder that ignores `final` and
  re-encodes the whole argument per call. An API that claims streaming but is not is
  worse than no streaming API. Source: `Lib/encodings/base64_codec.py`.
- MIME line wrapping (76 columns, trailing newline) baked into functions named
  `encodebytes`/`decodebytes`. RFC 4648 section 3.1 forbids adding line feeds unless
  an explicitly referenced spec says so; wrapping should be a clearly separate,
  opt-in function.
- A padding default that differs between the standard and the URL-safe decoder
  (`padded=True` versus `padded=False`) — a surprising asymmetry the docs have to
  call out explicitly.
- Warnings as a migration mechanism for a stricter default (`FutureWarning` /
  `DeprecationWarning`). It works in Python's ecosystem but complicates the error
  contract; a young library is better served by a clear break.
- `base64io`'s `close()`-to-flush requirement: forgetting it yields truncated output
  with no error. A streaming encoder should flush on finalise by construction.

## 12. Ideas fitting Mojo

- Context: the Mojo stdlib already ships `base64` with exactly four functions
  (`b64encode`, `b64decode`, `b16encode`, `b16decode`) and no `@stable(since=...)`
  marker, so it is unstable by default. MojoAkku `base64` must therefore add value
  beyond re-wrapping and must coexist with those names. Sources: buch
  `mojov1/stdlib/base64`; <https://mojolang.org/docs/std/base64/base64/>;
  <https://mojolang.org/docs/api-docs/stability/>.
- Adopt the stdlib's own ownership shape, which is the answer to the buffer question:
  `def b64encode(input_bytes: Span[UInt8]) -> String`, the sibling
  `def b64encode(input_string: StringSpan) -> String`, and the in-place form
  `def b64encode(input_bytes: Span[UInt8], mut result: String)` ("This method
  reserves the necessary capacity. `result` can be a 0 capacity string."), while
  `def b64decode(str: StringSpan) -> List[UInt8]`. Sources: buch
  `mojov1/stdlib/base64` (signatures confirmed there); also
  <https://mojolang.org/docs/std/base64/base64/b64encode/>,
  <https://mojolang.org/docs/std/base64/base64/b64decode/>. Caller-owned output plus
  borrowed `Span`/`StringSpan` input is the Mojo-native model.
- Typed errors instead of Python's exception zoo: `raises Base64Error` on decode
  only. Mojo allows at most one error type per function and bare `raises` erases it,
  so the type must be named. Sources: buch `mojov1/keyword-conventions/raises`
  ("A function can specify at most one error type after `raises`"; "Bare `raises`
  erases the type"); buch `mojov1/errors/error-model`.
- Non-raising by default matches the domain's asymmetry: encoding cannot fail (given
  a valid alphabet and padding policy) and should not be `raises`; only decoding
  raises. Source: buch `mojov1/errors/error-model` — "Mojo functions are
  non-raising by default".
- Make the alphabet and padding policy compile-time parameters, replacing Python's
  `altchars` and Perl's duplicated `*_base64url` functions. Mojo `comptime` values
  and `comptime for` unrolling plus `where` clauses make the alphabet a type-level
  choice with no runtime branching. Sources: buch `mojov1/appendix/cheat-sheet`
  (`comptime NAME = value`, `comptime for i in range(n)`);
  buch `mojov1/keyword-conventions/index` (`where` in declarations).
- Precompute the reverse decode table at compile time instead of per call; Python
  builds a 256-entry reverse table in `get_reverse_table()` (cached per process, but
  still loop-built). Source: `Modules/binascii.c`.
- Borrow the *idea* (not the spelling) of Perl's length-prediction functions as
  pure, non-raising arithmetic: `encoded_length(n)` and `decoded_length(n)` let
  callers reserve capacity for the `mut result` form without allocating. Source:
  MIME::Base64 POD (`encoded_base64_length`, `decoded_base64_length`) — see perl.md.
- Reject by default, with an explicit "ignore whitespace" option, following RFC 4648
  sections 3.3 and 3.5 rather than Python's lenient default. The Mojo stdlib already
  takes a stricter stance (it ignores whitespace only and rejects other invalid
  bytes), so this is prior art inside the language. Sources: RFC 4648 section 3.3;
  <https://mojolang.org/docs/std/base64/base64/b64decode/>.
- Keep streaming out of the core for now: neither the Mojo stdlib nor Python's
  modern interface streams, and Mojo has no file-object abstraction like Python's.
  If streaming is added later, model it on `base64io`'s explicit buffer contract
  (3-byte input quantum, finalise flushes the remainder, state how many bytes are
  held) rather than on Perl's `PerlIO::via` layer. Source: base64io README.
- Keep value semantics for decode output (owning `List[UInt8]`, as the Mojo stdlib
  does) and avoid Perl's "the string is the bytes" model, which is the root cause of
  the UTF8 pitfalls recorded in MIME::Base64's change log.

## Sources

- Python `base64` docs (stable): <https://docs.python.org/3/library/base64.html>
- Python `base64` docs (3.15): <https://docs.python.org/3.15/library/base64.html>
- Python `binascii` docs: <https://docs.python.org/3/library/binascii.html>
- Python `codecs` docs (Binary Transforms): <https://docs.python.org/3/library/codecs.html>
- CPython source `Lib/base64.py`:
  <https://raw.githubusercontent.com/python/cpython/main/Lib/base64.py>
- CPython source `Modules/binascii.c`:
  <https://raw.githubusercontent.com/python/cpython/main/Modules/binascii.c>
- CPython source `Lib/encodings/base64_codec.py`:
  <https://raw.githubusercontent.com/python/cpython/main/Lib/encodings/base64_codec.py>
- CPython tests `Lib/test/test_base64.py`:
  <https://raw.githubusercontent.com/python/cpython/main/Lib/test/test_base64.py>
- RFC 4648 (Base16, Base32, Base64): <https://www.rfc-editor.org/rfc/rfc4648.txt>
- `base64io` README:
  <https://github.com/aws/base64io-python/blob/master/README.rst>
- `base64io` docs: <https://base64io-python.readthedocs.io/en/latest/>
- `pybase64` README: <https://github.com/mayeut/pybase64>
- Mojo stdlib `base64` package: <https://mojolang.org/docs/std/base64/>
- Mojo stdlib `b64encode`: <https://mojolang.org/docs/std/base64/base64/b64encode/>
- Mojo stdlib `b64decode`: <https://mojolang.org/docs/std/base64/base64/b64decode/>
- Mojo stability guarantees: <https://mojolang.org/docs/api-docs/stability/>
- buch `mojov1/stdlib/base64`, `mojov1/errors/error-model`,
  `mojov1/keyword-conventions/raises`, `mojov1/appendix/cheat-sheet`
