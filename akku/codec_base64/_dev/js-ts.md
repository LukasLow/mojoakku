# base64 research: JS/TS

## 1. Standard library support

There is no single "base64 module"; support is split across the web platform and
Node.js:

- **Web/WHATWG**: `Window.btoa()` (encode a binary string) and `Window.atob()`
  (decode to a binary string) are Baseline widely available since July 2015, per
  the HTML spec (`dom-btoa-dev` / `dom-atob-dev`). They operate on *binary strings*
  (one byte per code unit) and throw `InvalidCharacterError` (`DOMException`).
  (Sources: https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa,
  https://developer.mozilla.org/en-US/docs/Web/API/Window/atob)
- **ECMAScript 2027 / Baseline 2025**: `Uint8Array.fromBase64()`,
  `Uint8Array.prototype.toBase64()` and `Uint8Array.prototype.setFromBase64()` were
  added to the language spec (ES 2027, "Baseline 2025", working since September
  2025). These are the modern byte-oriented replacements for `atob`/`btoa`.
  (Sources:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64)
- **Node.js `Buffer`**: binary-to-text encodings `'base64'`, `'base64url'` and
  `'hex'` are string encodings accepted by `Buffer.from(str, enc)` and
  `buf.toString(enc)`. `'base64url'` was introduced in v15.7.0/v14.18.0. (Source:
  https://nodejs.org/api/buffer.html)
- **`Uint8Array.fromHex()` / `setFromHex()` / `toHex()`** provide Base16 in the
  same ES 2027 / Baseline 2025 family. (Sources:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromHex,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromHex,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toHex)

## 2. Relevant community libraries

- **js-base64** (`base64.js`) — author Dan Kogai (dankogai), BSD-3-Clause, written
  in TypeScript since 3.3, ES5-compatible since 3.7; publishes `base64.js`/`.mjs`.
  Widely used, zero-dependency. (Source:
  https://raw.githubusercontent.com/dankogai/js-base64/main/README.md)
- **base64-js** — "basic base64 encoding/decoding in pure JS" for binary data in
  the browser, MIT license; exposes `byteLength`, `toByteArray`, `fromByteArray`.
  (Source: https://raw.githubusercontent.com/beatgammit/base64-js/master/README.md)
- **base64url** — Brian J. Brennan, MIT, 3.0.1, ~5M weekly downloads; Node/Buffer
  oriented URL-safe helpers with `fromBase64`/`toBase64` conversion. (Source:
  https://www.npmjs.com/package/base64url)
- **core-js** and **es-shims/es-arraybuffer-base64** provide polyfills for the new
  `Uint8Array` base64 methods. (Sources:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64)

## 3. Exposed APIs

Web platform (Sources: MDN btoa/atob, Uint8Array pages):

- `btoa(stringToEncode) -> string`; `atob(encodedData) -> string` (binary string).
- `Uint8Array.fromBase64(string[, options]) -> Uint8Array`, options:
  `alphabet: "base64" | "base64url"`, `lastChunkHandling: "loose" | "strict" |
  "stop-before-partial"`.
- `Uint8Array.prototype.toBase64([options]) -> string`, options:
  `alphabet: "base64" | "base64url"`, `omitPadding: boolean` (default `false`).
- `Uint8Array.prototype.setFromBase64(string[, options]) -> {read, written}`.

Node.js `Buffer` (Source: https://nodejs.org/api/buffer.html):

- `Buffer.from(string, 'base64' | 'base64url' | 'hex')`; `buf.toString(enc)`.
- `Buffer.byteLength(string, 'base64'|'base64url'|'hex')`; `Buffer.isEncoding(enc)`;
  `Buffer.alloc(size, fill, encoding)`.

js-base64 (Source: https://raw.githubusercontent.com/dankogai/js-base64/main/base64.ts):
`encode(src, urlsafe?)`, `encodeURI(src)`, `decode(src)`, `atob(a)`, `btoa(bin)`,
`isValid(src)`, `fromUint8Array(u8a, urlsafe?)`, `toUint8Array(a)`,
`extendString()`, `extendUint8Array()`, `extendBuiltins()`, plus `version`/`VERSION`
and the assembled `Base64` namespace object.

base64-js: `byteLength`, `toByteArray`, `fromByteArray`. (Source:
https://raw.githubusercontent.com/beatgammit/base64-js/master/README.md)

## 4. Error representation

- `atob` throws `InvalidCharacterError` (`DOMException`) "if `encodedData` is not
  valid base64"; `btoa` throws `InvalidCharacterError` if a character does not fit
  in a single byte. (Sources:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/atob,
  https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa)
- `Uint8Array.fromBase64` / `setFromBase64` throw `SyntaxError` for characters
  outside the alphabet or a last chunk violating `lastChunkHandling`, and
  `TypeError` for non-string input / bad options. (Sources:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64)
- `Buffer.from(str, 'base64')` **never throws on malformed base64** in the general
  case; `Buffer.from(str, 'hex')` **silently truncates** at the first non-hex
  character / odd length ("Data truncation may occur …"). (Source:
  https://nodejs.org/api/buffer.html)
- js-base64 throws `TypeError('malformed base64.')` in its `atobPolyfill` after a
  regex check, and throws for non-byte characters in `btoaPolyfill`
  (`TypeError('invalid character found')`). (Source:
  https://raw.githubusercontent.com/dankogai/js-base64/main/base64.ts)

Summary: three incompatible models — typed DOMException (web legacy), typed
SyntaxError/TypeError (ES 2027), silent truncation (Node `hex`). (Assessment:
derived from the MDN and Node sources above.)

## 5. Ownership semantics (buffer/ownership of input and output)

JavaScript is garbage-collected; no manual free. Key distinctions:

- `Buffer.from(arrayBuffer, byteOffset, length)` creates a **view sharing memory**
  ("This creates a view of the `ArrayBuffer` without copying"), while
  `Buffer.from(buffer)` **copies** the data. `buf.slice()` creates a view
  (legacy-compat), whereas `TypedArray.prototype.slice()` copies and `subarray()`
  is the view alternative. (Source: https://nodejs.org/api/buffer.html)
- `Uint8Array.fromBase64()` returns a **new** `Uint8Array`; `setFromBase64()`
  **populates an existing** `Uint8Array` in place and returns `{read, written}` —
  "the string is only read up to the point where the array is filled". (Sources:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64)
- `btoa`/`atob` traffic in **strings**; raw bytes must be marshalled through
  `TextEncoder`/`TextDecoder` or per-code-unit conversion, each producing new
  objects. (Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa)
- js-base64's `toUint8Array` routes through `_toUint8Array`, prefixed by
  `_unURI` which replaces `-`/`_`; the fallback path does
  `_U8Afrom(_atob(a).split('').map(c => c.charCodeAt(0)))` — an allocating copy.
  (Source: https://raw.githubusercontent.com/dankogai/js-base64/main/base64.ts)
- Node `Buffer.allocUnsafe` returns **uninitialized** memory that "may contain
  sensitive data"; `Buffer.alloc` zero-fills. A security-relevant ownership detail.
  (Source: https://nodejs.org/api/buffer.html)

## 6. Blocking / non-blocking

The codecs are synchronous, CPU-bound and non-blocking by nature; no awaiting is
involved. Two async-adjacent escape hatches exist, but they are not codec APIs:

- `FileReader.readAsDataURL` / `fetch(dataUrl)` for async base64 data-URL
  conversion, shown in MDN's `btoa` guidance. (Source:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa)
- Node `Blob.arrayBuffer()` / `blob.text()` / `blob.bytes()` return `Promise`s for
  bulk data, but the base64 encoding itself stays synchronous. (Source:
  https://nodejs.org/api/buffer.html)

Web Workers / Node `worker_threads` are the practical way to move large base64 work
off the main thread. (Assessment: derived from the MDN/Node docs above.)

## 7. Alphabet variants and padding

- **Standard (`base64`)**: `+` and `/`; accepts padding `=`. `Uint8Array.fromBase64`
  default `alphabet: "base64"`; `toBase64` default emits padding unless
  `omitPadding: true`. (Sources:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64)
- **URL-safe (`base64url`)**: `-` and `_`; Node "will omit padding" when encoding,
  and decoding `'base64url'` "will also correctly accept regular base64-encoded
  strings". (Source: https://nodejs.org/api/buffer.html)
- **Lax cross-alphabet decoding**: Node's `'base64'` "will also correctly accept
  'URL and Filename Safe Alphabet'", and whitespace (spaces, tabs, newlines) is
  ignored. (Source: https://nodejs.org/api/buffer.html)
- **Last-chunk / padding policy** is explicit in ES 2027 via `lastChunkHandling`:
  - `"loose"` (default): last chunk may be 2 or 3 chars, or 4 with padding;
    overflow bits ignored.
  - `"strict"`: last chunk must be exactly 4 chars with `=` padding and overflow
    bits must be 0.
  - `"stop-before-partial"`: decode a complete padded chunk, otherwise ignore the
    partial chunk entirely (for streaming).
  (Source:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64)
- **Base16**: Node `'hex'`; ES 2027 `toHex`/`fromHex`/`setFromHex`. Node truncates
  odd-length or non-hex input. (Sources: https://nodejs.org/api/buffer.html,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromHex,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toHex,
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromHex)
- js-base64 additionally exposes an `isValid()` that accepts either alphabet but
  rejects mixing (`'+-' // false: can't mix both`) and allows omitted padding.
  (Source: https://raw.githubusercontent.com/dankogai/js-base64/main/base64.ts)

No Base32 API exists in the JS/TS standard surface or in the three surveyed
libraries. (Assessment: derived from the MDN/Node/buffer/base64-js/js-base64
sources, none of which expose base32.)

## 8. Timeouts

Not applicable: no I/O and no blocking wait inside the codec. There is no timeout
or cancellation parameter on `atob`/`btoa`, the `Uint8Array` methods, or
`Buffer.toString`. Cancellation only applies to the surrounding I/O
(`fetch`/`FileReader` `AbortSignal`), not to encode/decode. (Sources:
https://developer.mozilla.org/en-US/docs/Web/API/Window/atob,
https://nodejs.org/api/buffer.html)

## 9. Streaming / incremental encode+decode

The platform gives **primitives, not a stream object**; streaming is documented as
userland code built on `stop-before-partial` / `{read, written}`:

- Decoder example (`Base64Decoder`, adapted from the TC39 proposal) keeps
  `#extra`, and when `opts.stream` is set uses
  `lastChunkHandling: "stop-before-partial"`; it allocates
  `new Uint8Array(Math.ceil((chunk.length * 3) / 4))`, calls `setFromBase64`, slices
  to `written`, and stores `chunk.slice(read)` as the leftover. So the **leftover is
  carried as unconsumed string characters** (`read` tells how many chars were
  consumed). (Source:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64)
- The docs note chunks "will never be split (because the remaining bits cannot be
  partially 'put back' into the base64 without completely re-encoding it)"; if the
  next chunk cannot fit, it is entirely unread, so up to 2 bytes of the output
  array may remain unwritten. (Source:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64)
- Encoder example (`Base64Encoder`) carries `#extra`/`#extraLength` (up to 3
  bytes), fills it to 3 bytes from the incoming chunk, emits
  `this.#extra.subarray(0, this.#extraLength).toBase64()`, and holds back
  `chunk.length % 3` bytes for the next call. (Source:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64)

So the leftover carry is explicit: 0–2 bytes held back on encode, up to 3 characters
on decode. (Assessment: derived from the two MDN stream examples.)

## 10. Interesting design decisions

- **`setFromBase64` return object `{read, written}`** — a clean, allocation-free way
  to report partial consumption, which is exactly what a streaming decoder needs.
- **`lastChunkHandling` enum** (`loose`/`strict`/`stop-before-partial`) — turns the
  padding/partial-chunk policy into one explicit option rather than a boolean tangle.
- **`omitPadding`** as a separate encode option — padding and alphabet are orthogonal.
- **Bytes-over-strings direction**: the new API deliberately returns `Uint8Array`
  and the MDN text says it "should be preferred over `Window.atob()` because it
  results in a byte array, which is easier to work with than a string containing raw
  bytes". (Source:
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64)
- **Per-library leniency**: js-base64's `isValid` allows padding omission and either
  alphabet but rejects mixing; its `decode` accepts both flavors while `atob`
  returns bytes. (Source:
  https://raw.githubusercontent.com/dankogai/js-base64/main/base64.ts)
- **Node's asymmetric leniency**: `'base64'` decode ignores whitespace and accepts
  both alphabets, while `'hex'` silently truncates — inconsistent strictness within
  one API. (Source: https://nodejs.org/api/buffer.html)

## 11. Decisions NOT to copy

- **Silent truncation** on malformed `hex` input in Node. A predictable Mojo codec
  must `raise` on odd-length/non-hex input instead. (Source:
  https://nodejs.org/api/buffer.html)
- **String-based `btoa`/`atob`** with per-code-unit byte semantics and
  `InvalidCharacterError` on >0xFF — an encoding trap that forced the ES 2027
  redesign. (Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa)
- **Three competing error types** for the same conceptual failure
  (`DOMException` vs `SyntaxError` vs silent). One typed error is better.
- **Prototype extension** (`Base64.extendString()` / `extendUint8Array()`): patching
  global prototypes is a known anti-pattern (the README itself warns about
  "tainting `window`"). (Source:
  https://raw.githubusercontent.com/dankogai/js-base64/main/README.md)
- **`Buffer.allocUnsafe`-style uninitialized output** in a codec: returning a
  buffer that may contain previous heap contents is a security hazard.
- **Lax cross-alphabet decode by default** (Node accepts URL-safe chars under
  `'base64'`): convenient, but blurs which encoding was actually validated.

## 12. Ideas fitting Mojo

- **`{read, written}` result shape** for any buffer-filling decode (from
  `setFromBase64`): Mojo can return a small struct recording consumed input and
  produced output, enabling allocation-free, caller-provided output buffers.
- **`lastChunkHandling`-style enum** for partial/padding policy: model as a Mojo
  enum (`Loose`, `Strict`, `StopBeforePartial`) instead of booleans.
- **Explicit `omitPadding` and alphabet enum** for encode, keeping alphabet and
  padding orthogonal, matching `toBase64({alphabet, omitPadding})`.
- **Byte-first API** returning an owned `List[UInt8]`, with an optional `String`
  convenience overload — the lesson from ES 2027 preferring `Uint8Array` over
  binary strings.
- **A typed streaming codec** that carries the documented leftovers (≤2 bytes
  encode, ≤3 chars decode) internally, replacing the userland `#extra` pattern with
  a Mojo struct holding a small `InlineArray`.
- **Compile-time alphabet/lookup tables** (like base64-js's `lookup`/`revLookup`
  and Perl's `index_64`) as immutable constants, and `comptime` selection of the
  standard vs URL-safe table.

(Assessment: derived from the JS/TS findings above and `mojov1` buch
`stdlib/base64`.)

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa
- https://developer.mozilla.org/en-US/docs/Web/API/Window/atob
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromHex
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromHex
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toHex
- https://nodejs.org/api/buffer.html
- https://raw.githubusercontent.com/dankogai/js-base64/main/README.md
- https://raw.githubusercontent.com/dankogai/js-base64/main/base64.ts
- https://raw.githubusercontent.com/beatgammit/base64-js/master/README.md
- https://raw.githubusercontent.com/beatgammit/base64-js/master/index.js
- https://www.npmjs.com/package/base64url
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
