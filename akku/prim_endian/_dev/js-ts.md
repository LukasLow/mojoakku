# prim_endian research: js-ts

Scope: byte-order/endianness handling in JavaScript/ECMAScript (browser +
Node.js) and TypeScript, including `DataView`, `ArrayBuffer`, `TypedArray`, and
Node's `Buffer`. Questions follow the workflow order; Q5, Q7 and Q9 are the
endian-adapted ones from `_dev/README.md`.

## 1. Standard library support

- **`DataView`** — the standard low-level interface "for reading and writing
  multiple number types in a binary `ArrayBuffer`, without having to care about
  the platform's endianness". Every multi-byte accessor takes an optional
  `littleEndian` boolean. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
- **`ArrayBuffer`** — fixed-length raw binary buffer, no byte-order semantics of
  its own; endianness enters only through the view used to read it. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer>.
- **Typed arrays** (`Uint16Array`, `Int32Array`, …) — read/write the buffer "using
  the platform's endianness"; there is no per-access flag. The MDN `DataView`
  page demonstrates detecting this with `new Int16Array(buffer)[0]`. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
- **Node.js `Buffer`** (`node:buffer`) — a `Uint8Array` subclass with explicit
  per-method byte-order selection in the method name: `readUInt16LE`/`BE`,
  `writeUInt32LE`/`BE`, `readBigInt64BE`, `readDoubleLE`, plus variable-length
  `readUIntLE(offset, byteLength)` / `readUIntBE(offset, byteLength)`. It also
  provides in-place `swap16()`, `swap32()`, `swap64()`. Sources:
  <https://nodejs.org/api/buffer.html#bufreaduint16leoffset>,
  <https://nodejs.org/api/buffer.html#bufswap16>.
- **Node.js `os.endianness()`** — returns `'BE'` or `'LE'` for the CPU the Node
  binary was compiled for. Source: <https://nodejs.org/api/os.html#osendianness>.
- **TypeScript** — adds no runtime byte-order API beyond the DOM/Node typings;
  it types `DataView` and `Buffer` signatures. (Assessment: TypeScript is defined
  as JavaScript plus static types, so it inherits these APIs;
  <https://www.typescriptlang.org/docs/handbook/typescript-in-5-minutes.html>.)

The ECMAScript normative home of `DataView` is the language spec, section
"DataView Objects". Source:
<https://tc39.es/ecma262/multipage/structured-data.html#sec-dataview-objects>.

## 2. Relevant community libraries

- **`buffer` (feross/buffer)** — the Node `Buffer` implementation ported to the
  browser; gives browser code the LE/BE method surface. License: MIT. Project:
  <https://github.com/feross/buffer>.
- **`bytebuffer`** — "A fast and complete ByteBuffer implementation using either
  ArrayBuffers in the browser or node Buffers"; index-carrying with a default
  endianness. License: Apache-2.0 (`bytebuffer` on npm shows 785 dependents).
  Project: <https://www.npmjs.com/package/bytebuffer>.
- **`byte-data`** — binary pack/unpack in pure JS; the npm page notes it "works in
  little-endian hosts" and warns about big-endian hosts. License: MIT. Project:
  <https://www.npmjs.com/package/byte-data>.
- **`binary-parser`** — declarative binary parser with `.endianness('big'|'little')`
  and typed fields; license MIT. Project: <https://github.com/keichi/binary-parser>.
- **`endianness`** — small "swap endianness in byte arrays" utility. Project:
  <https://www.npmjs.com/package/endianness>.

Maturity caveat: `endianness` was last published ~2018 and `bytebuffer` ~2016
(per their npm pages), so both are effectively unmaintained. (Assessment: derived
from the "last published" dates shown on the cited npm pages.)

## 3. Exposed APIs

`DataView` (per instance, over one `ArrayBuffer`):

| Method | Bytes | Signed | Endian param |
| --- | --- | --- | --- |
| `getInt8` / `setInt8` | 1 | yes | none (single byte) |
| `getUint8` / `setUint8` | 1 | no | none |
| `getInt16` / `setInt16` | 2 | yes | `littleEndian?` |
| `getUint16` / `setUint16` | 2 | no | `littleEndian?` |
| `getInt32` / `setInt32` | 4 | yes | `littleEndian?` |
| `getUint32` / `setUint32` | 4 | no | `littleEndian?` |
| `getBigInt64` / `setBigInt64` | 8 | yes | `littleEndian?` |
| `getBigUint64` / `setBigUint64` | 8 | no | `littleEndian?` |
| `getFloat16`/`32`/`64`, `setFloat16`/`32`/`64` | 2/4/8 | — | `littleEndian?` |

Sources:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#instance_methods>,
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/getUint16>.

The `getUint16` syntax is `getUint16(byteOffset)` / `getUint16(byteOffset,
littleEndian)`; "If `false` or `undefined`, a big-endian value is read." There is
"no alignment constraint; multi-byte values may be fetched from any offset within
bounds." Source:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/getUint16>.

Node `Buffer` relevant methods (name encodes order):

- Fixed-width: `readUInt16LE/BE`, `readInt16LE/BE`, `readUInt32LE/BE`,
  `readInt32LE/BE`, `readBigUInt64LE/BE`, `readBigInt64LE/BE`, `readFloatLE/BE`,
  `readDoubleLE/BE`, and the matching `write*` methods.
- Variable-width: `readUIntLE(offset, byteLength)`, `readUIntBE(offset,
  byteLength)`, `readIntLE`/`readIntBE`, with `writeUIntLE`/`writeUIntBE`.
- In-place: `buf.swap16()`, `buf.swap32()`, `buf.swap64()`.
- Host query: `os.endianness() -> 'BE' | 'LE'`.

Sources: <https://nodejs.org/api/buffer.html>, <https://nodejs.org/api/os.html#osendianness>.

## 4. Error representation

JavaScript/Node use exceptions, not codes:

- `DataView` getters/setters throw **`RangeError`** "if the `byteOffset` is set
  such that it would read beyond the end of the view." Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/getUint16>
  (Exceptions section).
- Node `Buffer.swap16()` "Throws `ERR_INVALID_BUFFER_SIZE` if `buf.length` is not
  a multiple of 2"; `swap32()` for a multiple of 4, `swap64()` for 8. Sources:
  <https://nodejs.org/api/buffer.html#bufswap16>,
  <https://nodejs.org/api/buffer.html#bufswap32>.
- Historical note: older Node versions threw `RangeError: Buffer size must be a
  multiple of 16-bits` before the `ERR_INVALID_BUFFER_SIZE` code was introduced.
  Source: <https://nodejs.org/download/release/v10.2.0/docs/api/buffer.html>.
- There is no error type for "wrong endianness" — endianness is a parameter, so
  the only failures are bounds/size errors. (Assessment: derived from the two
  cited API references.)

## 5. Ownership semantics (adapted: value-returning vs. in-place)

- **`DataView` is a view, not an owner.** `new DataView(buffer, byteOffset,
  byteLength)` creates a window over an existing `ArrayBuffer`; `set*` mutates the
  underlying buffer in place, `get*` reads it. The view exposes `.buffer`,
  `.byteOffset`, `.byteLength`. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#instance_properties>.
- **`buf.swap16/32/64` are in-place** and return "a reference to `buf`". Source:
  <https://nodejs.org/api/buffer.html#bufswap16>.
- **`Buffer.prototype.slice` returns a view, not a copy** (unlike
  `TypedArray.prototype.slice`), "only exists for legacy compatibility", and
  `subarray()` is the preferred spelling. Source:
  <https://nodejs.org/api/buffer.html#buffers-and-typedarrays>.
- **Copy vs. share on construction is explicit:** passing a `Buffer` to a typed
  array constructor copies; passing `buf.buffer` shares memory. Source:
  <https://nodejs.org/api/buffer.html#buffers-and-typedarrays>.
- Ownership is GC-managed; there is no explicit free. `Buffer.allocUnsafe`
  explicitly warns it "might contain old data that needs to be overwritten".
  Source: <https://nodejs.org/api/buffer.html#buffer>.

## 6. Blocking / non-blocking

Not applicable. `DataView` and `Buffer` byte-order accessors are pure,
synchronous, in-memory operations with no I/O, handles, promises or awaits.
(Assessment: derived from the absence of async semantics in the cited
references; the only async members on the `buffer` page are `Blob.arrayBuffer()`
and `Blob.text()`, which are unrelated to byte order —
<https://nodejs.org/api/buffer.html#class-blob>.)

## 7. IPv4 / IPv6 (adapted: which byte orders are represented)

- **`DataView` represents exactly two orders**: big-endian and little-endian,
  chosen per call by the boolean. Default is big-endian: "`DataView` defaults to
  big-endian read and write, but most platforms use little-endian." Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.
- **Node `Buffer` represents two orders via name suffixes** `LE`/`BE`; there is no
  single `readUInt16(order)` taking a value. `readUIntLE`/`BE` with an explicit
  `byteLength` generalize to 1–6 byte integers. Source:
  <https://nodejs.org/api/buffer.html>.
- **Host native order is a separate query**, not a token in the read/write API:
  `os.endianness() -> 'BE' | 'LE'`. Source:
  <https://nodejs.org/api/os.html#osendianness>.
- **Network order (big-endian) has no dedicated name** in JS or Node; callers use
  `BE`/`littleEndian=false`. (Assessment: derived from the two references above —
  neither defines a "network" keyword.)
- **Typed arrays are native-endian only** and thus not usable for portable
  parsing: "WebAssembly memory is always little-endian, so you should use
  `DataView` instead of typed arrays to read and write multi-byte values." Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.

So no single abstraction covers big/little/native/network: `DataView` covers
big+little, Node `Buffer` covers big+little plus a separate native query, and
typed arrays cover only native. (Assessment: synthesized from the cited sources.)

## 8. Timeouts

Not applicable. All endian accessors are bounded in-memory reads/writes; there is
no wait, socket or cancellation token. The only asynchronous members of the
`node:buffer` module are `Blob` promise methods, unrelated to byte order. Source:
<https://nodejs.org/api/buffer.html#class-blob>. (Assessment: derived from the
cited reference.)

## 9. TLS (adapted: host-native endianness detection)

- **Node.js: runtime query** — `os.endianness()` "Returns a string identifying the
  endianness of the CPU for which the Node.js binary was compiled. Possible values
  are `'BE'` for big endian and `'LE'` for little endian." Added in v0.9.4.
  Source: <https://nodejs.org/api/os.html#osendianness>.
- **Browsers/ECMAScript: no built-in query.** MDN documents a userland detection
  idiom: create an `ArrayBuffer(2)`, `setInt16(0, 256, true)`, then check
  `new Int16Array(buffer)[0] === 256` to learn whether the platform is
  little-endian. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.
- **Typed arrays implicitly encode host order** and are the detection mechanism;
  there is no `navigator.endianness`. (Assessment: derived from the MDN idiom
  above, which is the only documented detection method.)

## 10. Interesting design decisions

- **A per-call boolean `littleEndian`, defaulting to big-endian.** Extremely loose
  and terse, but it inverts the "usual" ergonomics on the dominant little-endian
  platforms and makes call sites unreadable without a comment. MDN spells out the
  trap. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.
- **Order in the method name (Node `LE`/`BE`) vs. order as an argument (`DataView`).**
  Two competing idioms inside a single ecosystem. Sources:
  <https://nodejs.org/api/buffer.html>, <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
- **A view type (`DataView`) cleanly separate from the storage type
  (`ArrayBuffer`)** — one buffer can be read through many overlapping views with
  no alignment constraint. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/getUint16>.
- **In-place buffer swapping** (`swap16/32/64`) with size-multiple validation
  turned into a named error code. Source:
  <https://nodejs.org/api/buffer.html#bufswap16>.
- **Variable-width integer read/write** (`readUIntLE(offset, byteLength)`), a
  capability Python's int API lacks. Source:
  <https://nodejs.org/api/buffer.html#bufreaduintleoffset-bytelength>.
- **Explicit host-order query** (`os.endianness()`) rather than inferring it.
  Source: <https://nodejs.org/api/os.html#osendianness>.

## 11. Decisions NOT to copy

- **Boolean `littleEndian` flag.** `getUint16(0, true)` is unreadable and easy to
  invert silently; Mojo should use a named typed order. (Assessment: derived from
  the readability critique implicit in MDN's warning at
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.)
- **Order encoded in the identifier name** (`readUInt16BE`/`LE`) — combinatorial
  explosion across width × signedness × order. Source:
  <https://nodejs.org/api/buffer.html>.
- **Platform-native typed arrays as a data-interchange primitive** — a portability
  foot-gun the `DataView` docs explicitly warn against. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.
- **`Buffer.prototype.slice` returning a view while `TypedArray.prototype.slice`
  returns a copy** — a legacy inconsistency the docs themselves flag as
  "surprising". Source:
  <https://nodejs.org/api/buffer.html#buffers-and-typedarrays>.
- **`ERR_INVALID_BUFFER_SIZE`-style validation only at swap time** rather than
  encoding the element width in the type. Source:
  <https://nodejs.org/api/buffer.html#bufswap16>.
- **No dedicated network-order spelling** — rely on big-endian `BE`. (Assessment:
  derived from the absence of a network token in the cited APIs.)

## 12. Ideas fitting Mojo

- **A typed order value (`Big`/`Little`/`Native`/`Network`) replaces both the
  `littleEndian` bool and the `LE`/`BE` name suffixes**; call sites stay readable
  and the order becomes a `comptime` parameter so the branch disappears. Source
  for the two JS idioms to unify:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>,
  <https://nodejs.org/api/buffer.html>. Mojo `comptime` parameters:
  `buch mojov1/keywords/comptime`.
- **View-not-owner semantics map well to Mojo**: `DataView` over `ArrayBuffer`
  is essentially `Span[Byte]`/`MutSpan[Byte]` plus typed load/store; Mojo should
  keep the storage/lens split. Mojo memory model: `buch mojov1/stdlib/memory`.
- **Value-returning `get` + in-place `set` pair** mirrors `DataView.get*/set*`;
  in Mojo the `set*` side naturally takes a `MutSpan[Byte]` and may `raises` on
  bounds (vs. JS `RangeError`). Sources:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/getUint16>,
  `buch mojov1/errors/error-model`.
- **In-place `swap16/32/64` is a good primitive**; in Mojo the element width is a
  compile-time parameter and a non-multiple length is a typed `raises` error, not
  a string error code. Source:
  <https://nodejs.org/api/buffer.html#bufswap16>.
- **Host-order detection should be an explicit, typed query** (a `native_order()`
  function returning the order value) rather than something inferred; both JS
  runtime queries (`os.endianness()`, the `Int16Array` trick) support this.
  Sources: <https://nodejs.org/api/os.html#osendianness>,
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView#endianness>.
- **Mojo-side primitives already exist; the library adds the ordering layer.**
  The `mojov1` buch documents `std.bit.byte_swap` ("Byte-swaps an integer with an
  even number of bytes") at `mojov1/stdlib/bit`, and the host-order predicates
  `std.sys.is_little_endian()` / `is_big_endian()` at `mojov1/stdlib/sys`. JS/TS'
  gap is not the swap but the explicit per-access order flag, which maps to a
  named-order API on top. Source (buch): `mojov1/stdlib/bit`, `mojov1/stdlib/sys`.

## Sources

- MDN `DataView` (overview, endianness, methods, properties, exceptions):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>
- MDN `DataView.prototype.getUint16()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/getUint16>
- MDN `ArrayBuffer`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer>
- ECMAScript spec, DataView Objects:
  <https://tc39.es/ecma262/multipage/structured-data.html#sec-dataview-objects>
- Node.js `Buffer`:
  <https://nodejs.org/api/buffer.html>
- Node.js `Buffer.swap16`:
  <https://nodejs.org/api/buffer.html#bufswap16>
- Node.js `Buffer.readUIntLE`:
  <https://nodejs.org/api/buffer.html#bufreaduintleoffset-bytelength>
- Node.js `os.endianness()`:
  <https://nodejs.org/api/os.html#osendianness>
- Node.js `Buffer` (historical, `RangeError` era):
  <https://nodejs.org/download/release/v10.2.0/docs/api/buffer.html>
- TypeScript (JS + types):
  <https://www.typescriptlang.org/docs/handbook/typescript-in-5-minutes.html>
- `feross/buffer`: <https://github.com/feross/buffer>
- `bytebuffer`: <https://www.npmjs.com/package/bytebuffer>
- `byte-data`: <https://www.npmjs.com/package/byte-data>
- `binary-parser`: <https://github.com/keichi/binary-parser>
- `endianness`: <https://www.npmjs.com/package/endianness>
- Mojo buch (local, read-only lookups in this session):
  `mojov1/stdlib/memory`, `mojov1/keywords/comptime`, `mojov1/errors/error-model`
