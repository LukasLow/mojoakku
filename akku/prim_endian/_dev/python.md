# prim_endian research: python

Scope: byte-order/endianness handling in CPython's standard library and the
relevant Python ecosystem. Questions follow the workflow order; Q5, Q7 and Q9
are the endian-adapted ones from `_dev/README.md`.

## 1. Standard library support

Python exposes byte-order handling in four stdlib places:

- **`int.to_bytes()` / `int.from_bytes()`** — the primary integer ⇄ bytes
  conversion, with a `byteorder` string argument. `int.to_bytes(length=1,
  byteorder='big', *, signed=False)` returns a `bytes` object; `int.from_bytes(
  bytes, byteorder='big', *, signed=False)` is a classmethod returning an `int`.
  `byteorder` defaults to `'big'`. The docs give the equivalence:
  `byteorder == 'little'` orders bytes from least- to most-significant, `'big'`
  from most- to least-significant. Added in 3.2; defaults for `length` and
  `byteorder` added in 3.11. Source:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- **`sys.byteorder`** — "An indicator of the native byte order. This will have
  the value `'big'` on big-endian (most-significant byte first) platforms, and
  `'little'` on little-endian (least-significant byte first) platforms." Source:
  <https://docs.python.org/3/library/sys.html#sys.byteorder>.
- **`struct`** — packing/unpacking of C structs with an explicit byte-order
  prefix. Prefix characters: `@` native byte order/size/alignment, `=` native
  byte order + standard size/alignment, `<` little-endian, `>` big-endian, `!`
  network (= big-endian, per IETF RFC 1700). If the first character is none of
  these, `'@'` is assumed. Source:
  <https://docs.python.org/3/library/struct.html#byte-order-size-and-alignment>.
- **`array.array`** — a typed, mutable buffer that implements the buffer
  protocol and offers an in-place `byteswap()`. Source:
  <https://docs.python.org/3/library/array.html>.

The `struct` docs state the design intent directly: "When no prefix character is
given, native mode is the default. It packs or unpacks data based on the platform
and compiler", and for external data the programmer "is responsible for defining
byte ordering". Source:
<https://docs.python.org/3/library/struct.html#struct-format-strings>.

## 2. Relevant community libraries

- **NumPy** — `numpy.ndarray.byteswap(inplace=False)` swaps the bytes of every
  element, and `dtype` byte-order codes (`'<'`, `'>'`, `'='`) model endianness in
  the data type itself. Project: <https://numpy.org/>; `byteswap` reference:
  <https://numpy.org/doc/stable/reference/generated/numpy.ndarray.byteswap.html>.
- **`bitstring`** — a pure-Python bit-level container with endianness-aware
  pack/unpack. Project: <https://github.com/scott-griffiths/bitstring>.
- **`construct`** — a declarative binary parser/builder with byte-order fields.
  Project: <https://github.com/construct/construct>.

`struct` and `array` have no third-party dependency and are the de-facto default
for single values. (Assessment: derived from the fact that `struct.pack` is
documented as the standard interchange mechanism —
<https://docs.python.org/3/library/struct.html#struct-standard-formats>.)

## 3. Exposed APIs

Function/attribute surface relevant to byte order:

| API | Signature (as documented) | Byte-order parameter |
| --- | --- | --- |
| `int.to_bytes` | `to_bytes(length=1, byteorder='big', *, signed=False) -> bytes` | `byteorder: str` (`'big'`/`'little'`) |
| `int.from_bytes` | `from_bytes(bytes, byteorder='big', *, signed=False) -> int` (classmethod) | `byteorder: str` |
| `sys.byteorder` | read-only `str` attribute | `'big'` / `'little'` |
| `struct.pack` | `pack(format, v1, v2, ...) -> bytes` | prefix in `format` |
| `struct.pack_into` | `pack_into(format, buffer, offset, v1, v2, ...)` | prefix in `format` |
| `struct.unpack` | `unpack(format, buffer) -> tuple` | prefix in `format` |
| `struct.unpack_from` | `unpack_from(format, /, buffer, offset=0) -> tuple` | prefix in `format` |
| `struct.Struct` | `Struct(format)` with `.pack`, `.pack_into`, `.unpack`, `.unpack_from`, `.iter_unpack`, `.format`, `.size` | prefix in `format` |
| `array.array.byteswap` | `byteswap()` — in-place, no return | none (host order) |

Sources: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>,
<https://docs.python.org/3/library/struct.html#functions-and-exceptions>,
<https://docs.python.org/3/library/array.html#array.array.byteswap>.

Notably, `int.to_bytes`/`from_bytes` accept **only** `'big'` and `'little'` — the
documented equivalent raises `ValueError("byteorder must be either 'little' or
'big'")` for anything else. To use native order you must pass `sys.byteorder`
explicitly. Source:
<https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.

## 4. Error representation

Python represents endian failures as exceptions:

- `int.to_bytes` — `OverflowError` "if the integer is not representable with the
  given number of bytes"; with `signed=False` and a negative integer it also
  raises `OverflowError`. An invalid `byteorder` string raises `ValueError`.
  Source: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- `struct` — module-level exception `struct.error` covers range violations:
  `pack(">h", 99999)` raises `struct.error: 'h' format requires -32768 <= number
  <= 32767`. Sources:
  <https://docs.python.org/3/library/struct.html#struct.error>,
  <https://docs.python.org/3/library/struct.html#examples>.
- `array.byteswap` — `RuntimeError` for item sizes other than 1, 2, 4 or 8
  bytes. Source: <https://docs.python.org/3/library/array.html#array.array.byteswap>.
- Buffer size mismatches in `struct.unpack` are also `struct.error` (buffer size
  must match `calcsize`). Source:
  <https://docs.python.org/3/library/struct.html#functions-and-exceptions>.

There are no error codes or sentinel values; everything is an exception.
(Assessment: derived from the cited API docs, which list exceptions only.)

## 5. Ownership semantics (adapted: value-returning vs. in-place)

Two distinct ownership models exist side by side:

- **Value-returning:** `int.to_bytes` returns a fresh, immutable `bytes` object;
  the source `int` is untouched (ints are immutable). `struct.pack` likewise
  returns a new `bytes`. Sources:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>,
  <https://docs.python.org/3/library/struct.html#functions-and-exceptions>.
- **In-place (caller-owned buffer):** `struct.pack_into(format, buffer, offset,
  ...)` writes into a caller-supplied writable buffer; the docs describe `buffer`
  as an object implementing the buffer protocol "that provide[s] either a
  readable or read-writable buffer", most commonly `bytes`/`bytearray`. Offset is
  required; a negative offset counts from the end. Source:
  <https://docs.python.org/3/library/struct.html#functions-and-exceptions>.
  `array.array.byteswap()` is likewise in-place and returns nothing. Source:
  <https://docs.python.org/3/library/array.html#array.array.byteswap>.
- **Input flexibility:** `int.from_bytes` accepts "a bytes-like object or an
  iterable producing bytes", so ownership of the input is not required — it may
  even be a plain list such as `[255, 0, 0]`. Source:
  <https://docs.python.org/3/library/stdtypes.html#int.from_bytes>.

Memory ownership of the returned `bytes`/`bytearray` is handled by Python's own
reference counting/GC; there is no explicit free. (Assessment: derived from the
buffer-protocol description at
<https://docs.python.org/3/library/struct.html#struct-format-strings>.)

## 6. Blocking / non-blocking

Not applicable: `int.to_bytes`/`from_bytes`, `struct.*`, `array.byteswap` are
pure, synchronous, CPU-only operations with no I/O, handles or awaits. The Python
docs describe them purely as value transformations. Sources:
<https://docs.python.org/3/library/stdtypes.html#int.to_bytes>,
<https://docs.python.org/3/library/struct.html>. (Assessment: derived from the
absence of any async/I/O semantics in the cited API descriptions.)

## 7. IPv4 / IPv6 (adapted: which byte orders are represented)

Python's `struct` covers the full set of named byte orders in one format
language:

| Prefix | Byte order | Size | Alignment |
| --- | --- | --- | --- |
| `@` | native | native | native |
| `=` | native | standard | none |
| `<` | little-endian | standard | none |
| `>` | big-endian | standard | none |
| `!` | network (= big-endian) | standard | none |

Source: <https://docs.python.org/3/library/struct.html#byte-order-size-and-alignment>.

- **Native is a compile-time-ish property of the interpreter**, reported at
  runtime by `sys.byteorder`; the docs list "Intel x86, AMD64 (x86-64), and Apple
  M1 are little-endian; IBM z and many legacy architectures are big-endian".
  Source:
  <https://docs.python.org/3/library/struct.html#byte-order-size-and-alignment>.
- **Network order is an explicit alias for big-endian** (`!`), justified by
  "IETF RFC 1700". Source: same section.
- **No single-string abstraction:** `int.to_bytes` knows only `'big'`/`'little'`
  — there is no `'native'` or `'network'` token, so callers must translate
  `sys.byteorder` or hard-code `'big'` for network order. Source:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- The `struct` docs contain a statement worth flagging: "There is no way to
  indicate non-native byte order (force byte-swapping); use the appropriate
  choice of `'<'` or `'>'`." Read literally this is self-contradictory (`<`/`>`
  *are* the way); (Assessment: derived from
  <https://docs.python.org/3/library/struct.html#byte-order-size-and-alignment>,
  the sentence appears to intend "no separate 'swap' opcode", not "no way to
  select non-native order").

## 8. Timeouts

Not applicable. Byte-order conversion is a bounded, allocation-only, synchronous
computation; there is no I/O or wait state to time out. (Assessment: derived from
the cited API descriptions at
<https://docs.python.org/3/library/stdtypes.html#int.to_bytes> and
<https://docs.python.org/3/library/struct.html>.)

## 9. TLS (adapted: host-native endianness detection)

Host endianness is detected at **runtime** via `sys.byteorder`, which returns
`'big'` or `'little'`. Source:
<https://docs.python.org/3/library/sys.html#sys.byteorder>. There is no
documented compile-time constant on the Python side; the interpreter exposes
only this runtime string. `int.from_bytes` explicitly documents this as the
intended bridge: "To request the native byte order of the host system, use
`sys.byteorder` as the byte order value." Source:
<https://docs.python.org/3/library/stdtypes.html#int.from_bytes>. This is a
stringly-typed runtime query, not a boolean or enum.

## 10. Interesting design decisions

- **A string `byteorder` argument, not a bool.** `'big'`/`'little'` are
  self-documenting at call sites (`int.from_bytes(b, byteorder='little')`),
  whereas a boolean (JS `littleEndian`) requires a comment to be readable.
  Source: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- **Big-endian as the default everywhere.** `int.to_bytes`/`from_bytes` default
  to `'big'`, and `struct` without a prefix uses native — but the "standard" and
  network forms are big-endian. The docs frame this as the safe interchange
  default. Sources:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>,
  <https://docs.python.org/3/library/struct.html#standard-formats>.
- **The int ⇄ bytes API is length-explicit.** `to_bytes` requires `length`,
  which forces the caller to state the width and turns overflow into a checked
  error instead of silent truncation. Source:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- **Signedness is a separate orthogonal flag** (`signed=False` default),
  decoupled from byte order. Source:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- **Two ownership modes for the same operation** (`pack` vs. `pack_into`),
  letting callers avoid an allocation when they own the destination buffer.
  Source: <https://docs.python.org/3/library/struct.html#functions-and-exceptions>.
- **A pure in-place buffer swapper** (`array.byteswap`), useful when data was
  read from "a file written on a machine with a different byte order". Source:
  <https://docs.python.org/3/library/array.html#array.array.byteswap>.

## 11. Decisions NOT to copy

- **Stringly-typed byte order.** `'big'`/`'little'` as free strings admit
  `ValueError` at runtime. A Mojo library should use a typed enum/value so
  invalid orders are unrepresentable. (Assessment: derived from
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>, which documents
  the runtime `ValueError`.)
- **Two spellings of the same thing** (`'big'`/`'little'` vs. `>`/`<`/`!`).
  MojoAkku should pick one vocabulary instead of mirroring both `byteorder`
  strings and `struct` prefixes.
- **No native token in the integer API.** Forcing users to weave
  `sys.byteorder` through every call is error-prone; a first-class
  `Native`/`Network` order (like Rust/Go) is preferable. (Assessment: derived
  from the two API docs above.)
- **Implicit native default in `struct` when no prefix is given** — a
  surprising, platform-dependent default. Source:
  <https://docs.python.org/3/library/struct.html#struct-format-strings>.
- **Module-level format strings parsed at call time** — `struct.pack('>h', ...)`
  reparses on each call; the docs themselves recommend a cached `Struct` "since
  the format string is only compiled once". Mojo should prefer compile-time
  format types. Source:
  <https://docs.python.org/3/library/struct.html#classes>.

## 12. Ideas fitting Mojo

- **One typed order vocabulary for all four cases** (`Big`, `Little`, `Native`,
  `Network`), matching the concept the README froze for `prim_endian`. (This is
  the design space of the library; the Python evidence is the `@/=/</>/!` table at
  <https://docs.python.org/3/library/struct.html#byte-order-size-and-alignment>.)
- **`comptime` order parameter.** Because Python resolves `byteorder` at runtime
  (string comparison in the documented equivalence), Mojo can instead specialize
  at compile time via a parameterized function — no branch, no `ValueError`.
  Source for the runtime nature:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>. Mojo
  `comptime` parameters are documented in the buch:
  `buch mojov1/keywords/comptime`.
- **Value-returning core with an explicit in-place variant**, mirroring
  `pack`/`pack_into`, but typed on a `MutSpan[Byte]` rather than a generic buffer
  protocol. Python source:
  <https://docs.python.org/3/library/struct.html#functions-and-exceptions>.
  Mojo's `Span`/pointer model is documented in the buch:
  `buch mojov1/stdlib/memory`.
- **Checked width.** Keep Python's length-explicit `to_bytes` and turn overflow
  into `raises`, matching Mojo's error-by-return model (`buch
  mojov1/errors/error-model`). Python precedent:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
- **A `byteswap` primitive is genuinely useful**; Python only offers it on
  `array.array`, not on `bytes`. A Mojo function over `MutSpan[Byte]` with a
  1/2/4/8-byte element width would generalize it. Python precedent:
  <https://docs.python.org/3/library/array.html#array.array.byteswap>.
- **Mojo-side primitives already exist; the library adds the ordering layer.**
  The `mojov1` buch documents `std.bit.byte_swap` ("Byte-swaps an integer with an
  even number of bytes") at `mojov1/stdlib/bit`, and the host-order predicates
  `std.sys.is_little_endian()` / `is_big_endian()` at `mojov1/stdlib/sys`. Python's
  gap is therefore not the swap but the *named-order* API on top. Source (buch):
  `mojov1/stdlib/bit`, `mojov1/stdlib/sys`.

## Sources

- CPython `int.to_bytes` / `int.from_bytes`:
  <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>
- CPython `sys.byteorder`:
  <https://docs.python.org/3/library/sys.html#sys.byteorder>
- CPython `struct` (format strings, byte order, errors, classes):
  <https://docs.python.org/3/library/struct.html>
- CPython `array.byteswap` / `frombytes`:
  <https://docs.python.org/3/library/array.html>
- NumPy `ndarray.byteswap`:
  <https://numpy.org/doc/stable/reference/generated/numpy.ndarray.byteswap.html>
- NumPy project: <https://numpy.org/>
- `bitstring`: <https://github.com/scott-griffiths/bitstring>
- `construct`: <https://github.com/construct/construct>
- RFC 1700 (network order = big-endian; the `struct` docs describe `!` as
  "network (= big-endian) order"):
  <https://datatracker.ietf.org/doc/html/rfc1700>
- Mojo buch (local, read-only lookups in this session):
  `mojov1/stdlib/memory`, `mojov1/keywords/comptime`, `mojov1/errors/error-model`
