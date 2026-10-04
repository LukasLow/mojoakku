# base32 research: JS/TS

## 1. Standard library support

**There is no base32 anywhere in the JS/TS standard platform** — not in the
WHATWG/HTML `Window.btoa`/`atob` pair, not in the ES 2027 `Uint8Array`
base64/base16 methods, and not in Node.js `Buffer`. The platform family is
base64 (`btoa`/`atob`, `Uint8Array.fromBase64`/`toBase64`/`setFromBase64`,
`Buffer` `'base64'`/`'base64url'`) and base16 (`toHex`/`fromHex`/`setFromHex`,
`Buffer` `'hex'`). There is **no `fromBase32`, no `'base32'` Buffer encoding, and
no `atob`-style base32** anywhere in the platform. (Sources:
https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa,
https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64,
https://nodejs.org/api/buffer.html) (Assessment: derived from those three
surfaces, none of which name base32.)

Base32 is therefore entirely **community-library territory** in JS/TS, and the
libraries are simple and unopinionated.

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page records only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

- **hi-base32** (`base32.js`) — author Chen, Yi-Cyuan (emn178), MIT, version
  0.5.1, last published 6 years ago; ~853,602 weekly downloads, 176 dependents.
  "A simple Base32(RFC 4648) encode / decode function for JavaScript supports
  UTF-8 encoding." (Source: https://www.npmjs.com/package/hi-base32)
- **base32-encode** — author Linus Unnebäck (LinusU), MIT, version 2.0.0,
  ~402,590 weekly downloads, 139 dependents; "Base32 encoder with support for
  multiple variants" (`RFC3548`/`RFC4648`, `RFC4648-HEX`, `Crockford`). The
  matching **base32-decode** package is the decoder. (Source:
  https://www.npmjs.com/package/base32-encode)
- **base32.js** (`base32.js` npm) — a third small encoder/decoder; `GUESS:` its
  exact API, because only its existence is referenced here and it was not
  fetched.
- **ulid** (`ulid/javascript`) — uses Crockford base32 to render 128-bit ULIDs
  as 26-character, case-insensitive, lexicographically sortable strings; it is
  the main real-world driver of Crockford base32 in JS. (Source:
  https://github.com/ulid/spec)

(Assessment: derived from the npm listings above: the JS/TS base32 signal is
two or three tiny libraries, none of which is a platform primitive, and the only
widely deployed non-RFC alphabet use is Crockford via ULID.)

## 3. Exposed APIs

hi-base32 (Source: https://www.npmjs.com/package/hi-base32 and
`emn178/hi-base32/src/base32.js`):

- `base32.encode(input, asciiOnly)` — `input` is `String | Array | Uint8Array |
  ArrayBuffer`; returns a string.
- `base32.decode(base32Str, asciiOnly)` — returns a UTF-8-decoded string.
- `base32.decode.asBytes(base32Str)` — returns a byte `Array` (e.g.
  `base32.decode.asBytes('JBSWY3DP') // [72, 101, 108, 108, 111]`).
- Example: `base32.encode('中文') // 4S4K3ZUWQ4======` — so it emits `=`
  padding.

base32-encode (Source: https://www.npmjs.com/package/base32-encode):

- `base32Encode(data, variant[, options])` where `data` is `ArrayBuffer |
  Int8Array | Uint8Array | Uint8ClampedArray`, `variant` is `'RFC3548' |
  'RFC4648' | 'RFC4648-HEX' | 'Crockford'`, and `options.padding` "forcefully
  enable[s] or disable[s] padding. The default behavior is to follow the default
  of the selected variant." Returns a string.
- Examples: `base32Encode(data, 'RFC4648')` → `"ORSXG5A="`;
  `base32Encode(data, 'RFC4648', { padding: false })` → `"ORSXG5A"`;
  `base32Encode(data, 'RFC4648-HEX')` → `"EHIN6T0="`;
  `base32Encode(data, 'Crockford')` → `"EHJQ6X0"`.

There is **no decode-side option object** documented for base32-encode (it is an
encoder); base32-decode is a separate package. (Assessment: derived from the
base32-encode README.)

## 4. Error representation

- **hi-base32** throws on malformed input. `GUESS:` the exact exception type and
  message, because the README does not document the error contract and the
  source was not fetched line-by-line in this pass.
- **base32-encode** is an encoder, which for base32 cannot fail on any byte
  input; it throws only on bad arguments (unknown variant / wrong `data` type).
  `GUESS:` the exact `TypeError`/`Error` used, for the same reason.
- The JS/TS platform's nearest analogue is the base64 story: `atob` throws
  `InvalidCharacterError` (`DOMException`), ES 2027 throws `SyntaxError`, and
  Node `Buffer.from(str,'hex')` silently truncates — three incompatible models
  (see the sibling run's `js-ts.md` §4). Base32 libraries add a fourth, ad-hoc
  model. (Sources:
  https://developer.mozilla.org/en-US/docs/Web/API/Window/atob,
  https://nodejs.org/api/buffer.html)

(Assessment: derived from the library READMEs and the platform docs above: there
is no standard error shape for JS base32.)

## 5. Ownership semantics

JavaScript is garbage-collected; no manual free. The relevant distinctions:

- **hi-base32 accepts `String`, `Array`, `Uint8Array` or `ArrayBuffer`** and
  returns a new JS string. Passing a `String` triggers a UTF-8 conversion unless
  `asciiOnly` is set; `decode.asBytes` returns a **new** `Array` (not a typed
  array), so there is an extra copy when the caller wants bytes. (Source:
  https://www.npmjs.com/package/hi-base32)
- **base32-encode accepts only binary views** (`ArrayBuffer | Int8Array |
  Uint8Array | Uint8ClampedArray`) — no string input — and returns a new string.
  (Source: https://www.npmjs.com/package/base32-encode)
- Neither library exposes a caller-provided output buffer or an in-place
  variant; the result is always a fresh string (or, for hi-base32, a fresh
  `Array`). There is no `setFromBase32`-style "populate an existing array" form
  as ES 2027 provides for base64. (Assessment: derived from the two READMEs,
  contrasted with
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64.)

## 6. Blocking / non-blocking

The codecs are synchronous, CPU-bound and non-blocking by nature; no awaiting is
involved, and neither base32 library offers an async API or a stream adapter.
For large payloads the only way to avoid blocking the event loop is a Web
Worker / Node `worker_threads` around the whole call. (Assessment: derived from
the two READMEs and the platform's `btoa` model in the sibling run's
`js-ts.md` §6.)

## 7. Alphabet variants, case and padding

- **Standard base32 (RFC 4648 §6)**: hi-base32's only alphabet; base32-encode's
  `'RFC4648'` (alias `'RFC3548'`). Both emit `=` padding by default;
  base32-encode can disable it with `{ padding: false }`. (Sources:
  https://www.npmjs.com/package/hi-base32,
  https://www.npmjs.com/package/base32-encode)
- **base32hex (RFC 4648 §7)**: only base32-encode exposes it, as
  `'RFC4648-HEX'` (`0-9 A-V`); hi-base32 has no hex variant. (Source:
  https://www.npmjs.com/package/base32-encode)
- **Crockford base32**: only base32-encode exposes it, as `'Crockford'`; ULID's
  rendering is the dominant real use. Crockford's alphabet
  `0123456789ABCDEFGHJKMNPQRSTVWXYZ` excludes `I`, `L`, `O`, `U`, is
  case-insensitive and has no padding. (Sources:
  https://www.npmjs.com/package/base32-encode, https://github.com/ulid/spec)
- **Case handling**: hi-base32's README does not document a case option and its
  examples call `decode` with uppercase input; `GUESS:` whether lowercase is
  accepted, because the source was not read line-by-line. base32-encode's
  `'RFC4648'` decoder (`base32-decode`) is a separate package and its case policy
  is not documented in the encoder README. Crockford is case-insensitive by
  design. (Sources: the two READMEs, the ULID spec.)
- **Padding policy**: RFC variants default to padded, disable via
  `{ padding: false }`; Crockford is unpadded. (Source:
  https://www.npmjs.com/package/base32-encode)
- **RFC 4648 reference**: §6 Table 3 (`A-Z2-7`), §7 Table 4 (`0-9A-V`), §3.2
  padding, §3.4 confusables, §3.5 canonical encoding.
  (https://www.rfc-editor.org/rfc/rfc4648.txt)

(Assessment: derived from the READMEs above: unlike the platform's base64, which
now has a structured `lastChunkHandling`/`omitPadding` option set, JS base32
options are a bare `variant` string plus one `padding` boolean, and the
canonicality question is not addressed at all.)

## 8. Timeouts

Not applicable: no I/O and no blocking wait inside the codec. There is no
timeout or cancellation parameter on any base32 library function; cancellation
only applies to the surrounding I/O (e.g. `fetch`/`FileReader` `AbortSignal`),
not to encode/decode. (Assessment: derived from the two READMEs; contrast
https://developer.mozilla.org/en-US/docs/Web/API/Window/atob.)

## 9. Streaming / incremental encode and decode

**No JS base32 library offers a streaming or incremental API**, and there is no
documented leftover-carry recipe — unlike base64, where MDN publishes
`Base64Encoder`/`Base64Decoder` examples that hold back 0–2 bytes / up to 3
characters using `stop-before-partial` and `{read, written}`. (Sources:
https://www.npmjs.com/package/hi-base32,
https://www.npmjs.com/package/base32-encode,
https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64)

Consequently, chunked base32 in JS/TS is entirely caller-implemented: an encoder
must buffer to a multiple of 5 input bytes (carrying `len % 5`), and a decoder
must buffer to a multiple of 8 symbols (carrying `len % 8`) until the final
padding group. The base64 `{read, written}` result shape is the natural model to
copy if an incremental base32 is ever built. (Assessment: derived from the
absence of any base32 streaming API and the base64 MDN precedent.)

## 10. Interesting design decisions

- **Variant as a string literal plus a single `padding` option** (base32-encode):
  `base32Encode(data, 'RFC4648', { padding: false })` — a minimal, data-driven
  config that avoids one function per alphabet. (Source:
  https://www.npmjs.com/package/base32-encode)
- **`decode.asBytes(...) -> Array`** (hi-base32): a byte-oriented decode path
  alongside the default UTF-8 string decode, acknowledging that base32 is often
  used for binary data. (Source: https://www.npmjs.com/package/hi-base32)
- **String-or-bytes input with an `asciiOnly` fast path** (hi-base32): a pragmatic
  API that serves both text and binary callers, at the cost of an ambiguous input
  type. (Source: https://www.npmjs.com/package/hi-base32)
- **Crockford shipped side-by-side with RFC 4648** (base32-encode), reflecting
  ULID's real-world adoption — the JS ecosystem is more willing to treat
  Crockford as a first-class variant than Go's stdlib is.
- **Separate encode and decode packages** (`base32-encode` + `base32-decode`):
  the npm ecosystem's granularity, opposite to the single-module design of the
  other languages.
- **No canonicality/error rigor**: neither README discusses non-zero trailing
  bits, so the RFC 4648 §3.5 malleability question is simply absent. (Assessment:
  derived from the READMEs.)

## 11. Decisions NOT to copy

- **String-or-bytes overloaded input without a type distinction** (hi-base32):
  the UTF-8-vs-bytes ambiguity is the same trap the ES 2027 `Uint8Array` API was
  designed to remove; Mojo's `StringSpan` vs `Span[UInt8]` overloads keep them
  honest.
- **A bare `variant` string with runtime validation**: a compile-time enum/alias
  is better than stringly-typed configuration.
- **Separate packages for encode and decode**: a single library with both
  directions is the MojoAkku model.
- **No canonicality checking and no documented error contract**: make invalid
  input a typed `raises`, not an undocumented throw.
- **`decode.asBytes` returning a plain `Array`** rather than a byte view:
  copying into a generic array defeats the byte-first design.
- **No streaming API**: a codec library can cheaply expose an incremental state
  type; JS's absence is a gap, not a model.
- **UTF-8 auto-detection with an `asciiOnly` flag**: implicit encoding decisions
  hidden behind a performance flag are hard to reason about.
  (Assessment: derived from the two READMEs.)

## 12. Ideas fitting Mojo

- **A single `variant` value rather than a function per alphabet**: model
  `RFC4648`, `RFC4648-HEX`, `Crockford` as a Mojo enum/alias, mirroring
  base32-encode's data-driven design, and let `padding` be an orthogonal option.
- **A byte-first API returning an owned `List[UInt8]`**, with an optional `String`
  convenience overload — the lesson from hi-base32's `decode.asBytes` and from ES
  2027 preferring `Uint8Array` over binary strings.
- **`{read, written}` result shape** for any future buffer-filling decode (from
  `setFromBase64`): Mojo can return a small struct recording consumed symbols and
  produced bytes, enabling allocation-free, caller-provided output buffers.
- **A typed streaming codec** that carries the documented leftovers (0–4 bytes
  encode, 0–? symbols decode; for base32 the encode remainder is 0–4 bytes and the
  decode remainder is 0–7 symbols) internally, replacing the userland buffering
  JS libraries omit.
- **Explicit `padding` and `variant` orthogonal options**, matching
  `base32Encode(data, variant, {padding})`.
- **Compile-time alphabet tables** (like hi-base32's lookup) as immutable
  constants, with `comptime` selection of the standard vs hex vs Crockford table.
- **Treat Crockford as a real variant, not an exotic one**: ULID's adoption makes
  it worth at least a backlog entry, with its confusable normalization and
  unpadded-by-default behavior made explicit. (Sources:
  https://www.npmjs.com/package/base32-encode, https://github.com/ulid/spec.)

(Assessment: derived from the JS/TS findings above and `mojov1` buch
`stdlib/base64`.)

## Sources

- https://www.npmjs.com/package/hi-base32
- https://www.npmjs.com/package/base32-encode
- https://github.com/ulid/spec
- https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa
- https://developer.mozilla.org/en-US/docs/Web/API/Window/atob
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64
- https://nodejs.org/api/buffer.html
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  https://www.rfc-editor.org/rfc/rfc4648.txt
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
