# base64 research: JS/TS

> Scope: JavaScript/TypeScript base64 support as it exists in 2026 — browser platform (`atob`/`btoa`), ES2027 typed-array methods, Node.js `Buffer`. Every claim carries a source; unsourced items are marked `GUESS:` with a reason.

## 1. Standard library support

The JS/TS standard library has **four distinct base64 surfaces**, split across two specs (WHATWG HTML and ECMAScript) and one runtime (Node.js):

1. **`btoa()` / `atob()`** — the oldest surface, a *web platform* API (not ECMAScript), defined in the WHATWG HTML Standard §8.3 "Base64 utility methods". Available on `Window` and `WorkerGlobalScope`; support is Baseline "widely available" since July 2015. (Sources: HTML Standard https://html.spec.whatwg.org/multipage/webappapis.html#atob ; MDN https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa , https://developer.mozilla.org/en-US/docs/Web/API/Window/atob )
2. **`Uint8Array.fromBase64()` + `Uint8Array.prototype.toBase64()`** — the modern ECMAScript surface, reached stage 4 via the TC39 proposal `proposal-arraybuffer-base64` (repo header: "archived by the owner on Oct 28, 2025"); MDN's specification table names the spec **"ECMAScript® 2027 Language Specification"** (#sec-uint8array.frombase64) and its status banner reads "Baseline 2025 / Newly available / Since September 2025". VERIFIED 2026-09-21 against TC39 repo header + MDN spec table + MDN Baseline banner. (Sources: https://github.com/tc39/proposal-arraybuffer-base64 ; https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64 ; spec: https://tc39.es/ecma262/multipage/indexed-collections.html#sec-uint8array.frombase64 )
3. **`Uint8Array.prototype.setFromBase64()`** — the same proposal's write-into-existing-buffer variant, returning `{ read, written }`; ECMAScript 2027. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64 )
4. **Node.js `Buffer`** — `Buffer.from(str, 'base64')` and `buf.toString('base64')`; plus the separate encodings `'base64url'`, `'hex'`, `'latin1'` in the same encoding-string union. `Buffer` is a subclass of `Uint8Array` (since v3.0.0) and is global but recommended to be imported from `node:buffer`. (Source: https://nodejs.org/api/buffer.html )

There is **no built-in streaming base64 encoder/decoder** anywhere: the TC39 proposal states "There is no explicit support for streaming. However, it is relatively straightforward to do efficiently in userland on top of this API" and links `stream.mjs`. (Source: https://github.com/tc39/proposal-arraybuffer-base64 )

TypeScript adds no base64 API of its own; it inherits the DOM lib types (`btoa`/`atob`) and Node's `Buffer` types. `GUESS:` — the claim "TypeScript contributes no base64-specific type" is inferred from the absence of any base64 mention in the TS-facing docs surfaced by this search; no single canonical page states it explicitly.

## 2. Relevant community libraries

The TC39 proposal's own survey (`base64.md`) is the best single source of the JS library landscape; it filters to libraries with ≥1M downloads/week and ≥100 distinct dependents. Its table (Source: https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md ):

| library | downloads/wk (per that table) | notes |
| --- | --- | --- |
| `base64-js` | 38M | pure JS; illegal chars interpreted as `A` |
| `@smithy/util-base64` | 8M | AWS SDK helper |
| `crypto-js` | 6M | broad crypto lib; illegal chars as `A` |
| `js-base64` | 5M | supports arbitrary chars + whitespace in input |
| `base64-arraybuffer` | 4M | ArrayBuffer in/out; illegal chars as `A` |
| `base64url` | 2M | URL-safe focused; padding omitted by default |
| `base-64` | 2M | arbitrary chars + whitespace in input |

Concrete package facts (all from the npm registry pages fetched for this research):

- **`base64-js`** — v1.5.1, last published 6 years ago (package is effectively frozen), MIT, ~108M weekly downloads, ships built-in TypeScript declarations, 0 dependencies, 3344 dependents. API: `byteLength`, `toByteArray`, `fromByteArray`. (Source: https://www.npmjs.com/package/base64-js )
- **`js-base64`** — v3.9.4, published 2 days before this research, BSD-3-Clause, ~12.4M weekly downloads, written in TypeScript since v3.3, 4088 dependents. API is the richest of the set: `encode`, `encodeURI`, `decode`, `atob`, `btoa`, `fromUint8Array`, `toUint8Array`, `isValid`, optional prototype extensions. (Source: https://www.npmjs.com/package/js-base64 )
- **`base64url`** — v3.0.1, last published 8 years ago, MIT, ~5.0M weekly downloads. API: `base64url()`, `.encode`, `.decode`, `.fromBase64`, `.toBase64`, `.toBuffer`. (Source: https://www.npmjs.com/package/base64url )
- **`base64-arraybuffer`** — v1.0.2, last published 5 years ago, MIT, ~19.2M weekly downloads. API: exactly two functions, `encode(buffer)` and `decode(str)`. (Source: https://www.npmjs.com/package/base64-arraybuffer )

Structural observation (sourced, not inferred): three of the four headline packages have not been published for 5-8 years, i.e. the ecosystem stabilised *before* the native ECMAScript methods landed in 2025. (Dates above.)

## 3. Exposed APIs

### 3.1 WHATWG HTML — `btoa(data)` / `atob(data)`

- `btoa(data)` → `DOMString`; `atob(data)` → `DOMString`. Both take and return **strings**. The spec says: "In these APIs, for mnemonic purposes, the 'b' can be considered to stand for 'binary', and the 'a' for 'ASCII'. In practice, though, for primarily historical reasons, both the input and output of these functions are Unicode strings." (Source: https://html.spec.whatwg.org/multipage/webappapis.html#atob )
- `btoa` requires every code point < U+0100 (i.e. "Latin-1/binary string"); `atob` returns a string whose chars are U+0000..U+00FF, each = one byte. (Same source; MDN https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa )
- No options, no alphabet parameter, no padding control, no streaming. (Same sources.)
- Available as `window.btoa`/`window.atob` and `WorkerGlobalScope.btoa`/`.atob`. (MDN see-also sections.)

### 3.2 ECMAScript typed-array methods

- `Uint8Array.fromBase64(string[, options])` → new `Uint8Array`. Options: `alphabet: "base64" | "base64url"` (default `"base64"`), `lastChunkHandling: "loose" | "strict" | "stop-before-partial"` (default `"loose"`). ASCII whitespace inside input is ignored. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64 )
- `Uint8Array.prototype.toBase64([options])` → string. Options: `alphabet` (same values), `omitPadding: boolean` (default `false`). Encoder never emits whitespace/line breaks. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64 )
- `Uint8Array.prototype.setFromBase64(string[, options])` → `{ read, written }`; writes in place, starts at index 0 (use `subarray(offset)` for offsets), never splits a 4-char chunk. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64 )
- Sibling hex methods exist in the same proposal: `Uint8Array.fromHex`, `.toHex`, `.setFromHex`; hex output is always lowercase and mixed case is accepted on decode. (Sources: MDN Uint8Array sidebar; https://github.com/tc39/proposal-arraybuffer-base64 )

### 3.3 Node.js `Buffer`

- `Buffer.from(string[, encoding])`, `buf.toString([encoding[, start[, end]]])`, `Buffer.byteLength(string[, encoding])`. Supported binary-to-text encodings: `'base64'`, `'base64url'`, `'hex'`; plus text encodings `'utf8'`, `'utf16le'`, `'latin1'`, legacy `'ascii'`, `'binary'`, `'ucs2'`. Encoding names are case-insensitive (`'UTF8'`, `'uTf8'` work). (Source: https://nodejs.org/api/buffer.html )
- Node-specific semantics worth noting (all from the same `buffer.html`):
  - decoding `'base64'` **also accepts the URL-safe alphabet** in the same string; whitespace (spaces, tabs, newlines) is ignored;
  - decoding `'base64url'` also accepts regular base64; encoding to `'base64url'` **omits padding**;
  - `buffer.byteLength(str, 'base64')` "assumes valid input" and may over-report for strings containing non-base64 data such as whitespace.
- Legacy aliases: global `atob(data)` / `btoa(data)` (added v16.0.0) and `buffer.atob` / `buffer.btoa` (v15.13.0) are **Stability 3 - Legacy**, documented with "Use `Buffer.from(data, 'base64')` instead" / "Use `buf.toString('base64')` instead", and have a codemod. (Sources: https://nodejs.org/api/globals.html#atobdata , https://nodejs.org/api/buffer.html#bufferatobdata )
- `Buffer.prototype.slice()` returns a **view over the same memory** while `TypedArray.prototype.slice()` copies — documented as a legacy-compat surprise; `subarray()` is recommended instead. (Source: https://nodejs.org/api/buffer.html#buffers-and-typedarrays )

### 3.4 Community API shapes

- `base64-js`: `byteLength(str)`, `toByteArray(str)`, `fromByteArray(bytes)` — three free functions, no options object. (Source: https://www.npmjs.com/package/base64-js )
- `js-base64`: `Base64.encode(str[, urlsafe])`, `encodeURI`, `decode`, `atob`, `btoa`, `fromUint8Array(u8[, urlsafe])`, `toUint8Array`, `isValid`, `noConflict`, plus opt-in `extendString()`/`extendUint8Array()`/`extendBuiltins()`. Note the **boolean second argument** for URL-safe instead of an options object. (Source: https://www.npmjs.com/package/js-base64 )
- `base64url`: `base64url(input[, encoding='utf8'])`, `.encode`, `.decode(input[, encoding])`, `.fromBase64`, `.toBase64`, `.toBuffer`. (Source: https://www.npmjs.com/package/base64url )
- `base64-arraybuffer`: only `encode(ArrayBuffer)` / `decode(string)`. (Source: https://www.npmjs.com/package/base64-arraybuffer )

## 4. Error representation

JS/TS uses **exceptions** (no `Result`, no error codes, no sentinels):

- `btoa`: throws `InvalidCharacterError` `DOMException` if any code point > U+00FF. Spec text: "The btoa(data) method must throw an InvalidCharacterError DOMException if data contains any character whose code point is greater than U+00FF." (Source: https://html.spec.whatwg.org/multipage/webappapis.html#atob )
- `atob`: runs "forgiving-base64 decode"; if the result is *failure*, throws `InvalidCharacterError` `DOMException`. (Same source; MDN https://developer.mozilla.org/en-US/docs/Web/API/Window/atob )
- **The failure predicate is precisely specified** in Infra §7 "Forgiving base64": remove ASCII whitespace; if length % 4 == 0, strip one or two trailing `=`; if length % 4 == 1 → failure; if any code point is not `+`, `/` or ASCII alphanumeric → failure. Crucially, **non-zero pad bits are not an error**: "The discarded bits mean that, for instance, `YQ` and `YR` both return `a`." So `atob` cannot distinguish `YQ` from `YR`. (Source: https://infra.spec.whatwg.org/#forgiving-base64-decode )
- `Uint8Array.fromBase64` / `setFromBase64`: throw `SyntaxError` when the input contains characters outside the selected alphabet or when the last chunk violates `lastChunkHandling`; throw `TypeError` for non-string input, non-object `options`, or invalid option values. With `lastChunkHandling: "strict"` non-zero overflow bits become a `SyntaxError`; with `"stop-before-partial"` a lone base64 char followed by `=` is still a `SyntaxError` (it "cannot possibly be part of a valid base64 string"). (Sources: MDN fromBase64, setFromBase64.)
- `Uint8Array.prototype.toBase64`: throws `TypeError` only for a bad `options` object / bad `alphabet` value. The encoder has **no error case at all** (any byte sequence is encodable). (Source: MDN toBase64.)
- Node.js `Buffer.from(str, 'base64')` is **error-free for malformed input**: it never throws; docs only warn that `byteLength()` may over-report for invalid input. Node's own `atob`/`btoa` legacy wrappers do throw (they carry HTML semantics). (Sources: https://nodejs.org/api/buffer.html , https://nodejs.org/api/globals.html )

Two incompatible error philosophies coexist in the *same* language: "forgiving/never-fail" (`atob`, `Buffer`) vs "strict `SyntaxError`" (ECMAScript typed-array methods). (Synthesis of the sources above.)

## 5. Ownership semantics (buffer and ownership of encode input and produced output)

JS has **no ownership system**: memory is garbage-collected, there is no `free`, and "who owns the buffer" is not expressible. What *is* expressible and matters for API design is **copy vs view (aliasing)**:

- `Uint8Array.fromBase64(str)` / `toBase64()` **allocate a fresh result**; there is no aliasing question — input string is immutable, output array/string is new. `GUESS:` no source states "fresh allocation" verbatim, but the return-value descriptions ("A new Uint8Array object containing the decoded bytes" / "returns a base64-encoded string") imply it. (Sources: MDN fromBase64, toBase64.)
- `Uint8Array.prototype.setFromBase64(str)` is the **in-place** variant: it writes into `this` and reports `{ read, written }`; `written` "will never be greater than this Uint8Array's byteLength". Partial-write semantics are explicit: chunks are never split, so "the last one or two bytes of the array" may stay unwritten. This is the JS answer to *output ownership*: caller pre-allocates, callee reports what it used. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64 )
- Node's `Buffer` **shares memory with its backing `ArrayBuffer`** by design: `Buffer.from(arrayBuffer)` creates a view that shares memory, and `Buffer.prototype.slice()` returns a view (not a copy) — the docs call this "surprising, and only exists for legacy compatibility" and recommend `subarray()`. (Source: https://nodejs.org/api/buffer.html#buffers-and-typedarrays )
- Node pools small allocations: `Buffer.from(string)` "may also use the internal Buffer pool like Buffer.allocUnsafe() does", so a returned Buffer can be one window into a much larger pooled `ArrayBuffer` (visible via `buf.buffer` / `buf.byteOffset`). (Sources: https://nodejs.org/api/buffer.html#static-method-bufferfromstring-encoding , and `Buffer.poolSize` — the docs history table states "v26.3.0: Default raised from 8192 to 65536", current default `65536`. VERIFIED 2026-09-21 at https://nodejs.org/api/buffer.html#bufferpoolsize )
- Decoding **never mutates the input string** (strings are immutable primitives in JS). `GUESS:` stated as a language generalisation; no base64-specific page says it, because it is trivially true of JS strings (MDN String: strings are immutable — not separately fetched for this report).

## 6. Blocking / non-blocking

**Synchronous, always, everywhere.** There is no async/promise base64 API in any of the four surfaces, and this is an explicit, justified design decision:

- The TC39 proposal FAQ asks "Why are these synchronous?" and answers: "In practice most base64'd data I encounter is on the order of hundreds of bytes (e.g. SSH keys), which can be encoded and decoded extremely quickly. It would be a shame to require Promises to deal with such data… especially given that the alternatives people currently use all appear to be synchronous." (Source: https://github.com/tc39/proposal-arraybuffer-base64 )
- `btoa`/`atob` are synchronous by definition (pure functions in the HTML spec). (Source: https://html.spec.whatwg.org/multipage/webappapis.html#atob )
- Node `Buffer.from`/`toString` are synchronous. (Source: https://nodejs.org/api/buffer.html )

Consequences and escape hatches (sourced from the same sources unless noted):

- Encoding a very large buffer blocks the event loop / the UI thread. The web platform's *only* async-ish native route is `FileReader.readAsDataURL()` (a `Promise`-wrapped data-URL conversion) and decoding via `fetch(dataURL)`; MDN presents these as "For better performance, asynchronous conversion between base64 data URLs is possible natively within the web platform via the FileReader and fetch APIs". (Source: MDN btoa, section "Converting arbitrary binary data".)
- Web Workers / Node `worker_threads` are the general way to move large codec work off the main thread. `GUESS:` no base64-specific doc recommends workers; it is the generic JS concurrency mechanism.
- `setFromBase64()` is the closest thing to an incremental API but it is still synchronous; it bounds *output* size, not *time* per call. (Source: MDN setFromBase64.)

## 7. Alphabet variants (standard / URL-safe / others) and padding

This is the area with the most genuine design divergence, and the JS story is: **the alphabet and padding are the only two encoding knobs that exist; there is no base32/base16 in the browser platform, and hex only in the newest + Node APIs.**

**Supported alphabets per surface:**

| surface | standard `+/` | url-safe `-_` | other |
| --- | --- | --- | --- |
| `btoa`/`atob` | yes | **no** | none |
| `Uint8Array.toBase64/fromBase64` | yes (default) | yes via `alphabet: "base64url"` | hex via `toHex`/`fromHex` |
| Node `Buffer` | yes | yes (`'base64url'` **and** accepted when decoding `'base64'`) | `'hex'` |
| `base64-js` | yes | decoding only, per the TC39 table | none |
| `js-base64` | yes | yes | none |
| `base64url` | conversion helpers `fromBase64`/`toBase64` | yes (native) | none |

(Sources: MDN btoa/fromBase64/toBase64; https://nodejs.org/api/buffer.html ; https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md ; npm pages for the three packages.)

**Padding handling:**

- RFC 4648 requires padding by default and permits omitting it only when the referring spec says so: "Implementations MUST include appropriate pad characters at the end of encoded data unless the specification referring to this document explicitly states otherwise." (Source: https://www.rfc-editor.org/rfc/rfc4648.txt §3.2 )
- `btoa` always pads (it is plain RFC 4648 §4 encoding); `atob` accepts both padded and unpadded input via the forgiving-decode rules (strips trailing `=` only when length % 4 == 0). (Sources: HTML spec, Infra §7.)
- `toBase64` pads by default and exposes `omitPadding: true` to drop it. `fromBase64`'s `lastChunkHandling` is effectively the padding-strictness knob: `"loose"` (treat missing padding as implicit), `"strict"` (require exactly 4-char final chunk **and** zero overflow bits), `"stop-before-partial"` (ignore an incomplete final chunk). (Sources: MDN toBase64, fromBase64.)
- Node's `'base64url'` **omits padding when encoding** and **accepts regular base64 when decoding**; `'base64'` **accepts URL-safe input when decoding** but **emits standard alphabet with padding**. Node explicitly allows *mixing alphabets within one input string* (TC39 table footnote [^node]). Net effect: Node's two encodings are not symmetric and are mutually lenient. (Sources: https://nodejs.org/api/buffer.html , https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md )
- `base64url` (package) **omits padding by default** (`'bGFkaWVz…c3BhY2U'` — no `=`), and provides `fromBase64`/`toBase64` to convert padding/`+`/`/` ↔ `-`/`_`. (Source: https://www.npmjs.com/package/base64url )
- `js-base64` uses a **boolean** `true` as second arg for URL-safe (`Base64.encode(latin, true)` skips padding; `encodeURI` = URL-safe, unpadded). Its `isValid` accepts unpadded input, `++`, and `--`, but rejects `+-` ("can't mix both") — the strictest mixed-alphabet stance in the ecosystem, contrasting with Node which accepts mixing. (Source: https://www.npmjs.com/package/js-base64 )

**Non-zero pad bits (canonicality):** RFC 4648 §3.5 says pad bits MUST be zero for canonical output and "decoders MAY chose to reject an encoding if the pad bits have not been set to zero". The TC39 proposal deliberately chose leniency: "non-zero padding bits are silently ignored unless `lastChunkHandling: "strict"` is specified", while `atob`/`Buffer` also ignore them. (Sources: https://www.rfc-editor.org/rfc/rfc4648.txt , https://github.com/tc39/proposal-arraybuffer-base64 , https://infra.spec.whatwg.org/#forgiving-base64-decode )

**Security note (why leniency costs something):** RFC 4648 §12 warns that ignoring non-alphabet characters opens a covert channel and that non-significant pad bits "may be abused to leak information or used to bypass string equality comparisons". (Source: https://www.rfc-editor.org/rfc/rfc4648.txt §12 )

## 8. Timeouts / cancellation

**Not applicable — and the reason is structural, not an omission.** A timeout or cancellation token only makes sense for an operation that can (a) take unbounded time and (b) be abandoned midway. A synchronous, total, in-memory pure function is neither:

- Every JS base64 surface here is a **synchronous pure function** over an in-memory string/array (sources in §6). There is no I/O, no network, no file descriptor, hence nothing to time out against. JS's cancellation primitive (`AbortSignal`, `AbortController`) is explicitly scoped to "selected `Promise`-based APIs" / "cancelation in selected Promise-based APIs" — base64 is not one of them. (Source: https://nodejs.org/api/globals.html#class-abortcontroller — "A utility class used to signal cancelation in selected Promise-based APIs.")
- The only cancellation-adjacent capability in the ecosystem is the `stop-before-partial` option, and its documented purpose is *streaming*, not aborting: "This is useful if the string is coming from a stream and the last chunk is not yet complete." That is a *resume/continue* semantic (partial input is ignored, not thrown away), the opposite of cancellation. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64 )
- Node's `Buffer` API has no timeout/cancellation parameter at all. `GUESS:` the absence is documented only implicitly (the signature list on buffer.html contains no such argument); no page states "base64 cannot be cancelled" in those words.

Design takeaway: for a pure codec, "no timeouts" is the *correct* answer, and any MojoAkku design that exposes a timeout/cancel parameter on encode/decode would be modelling a problem that does not exist.

## 9. Streaming (incremental/chunked encode and decode, leftover bytes across calls)

JS is the reference case of a language where streaming is **deliberately absent from the API but trivially constructible on top of it**. This is the single most instructive part of the JS story for MojoAkku.

**The official position** (TC39 proposal, section "Streaming"): "There is no explicit support for streaming. However, it is relatively straightforward to do efficiently in userland on top of this API, with support for all the same options as the underlying functions." The proposal ships a reference implementation `stream.mjs`. (Source: https://github.com/tc39/proposal-arraybuffer-base64 )

**How leftovers are carried — encoder.** MDN's `toBase64` page reproduces (adapted from the proposal) a `Base64Encoder` class whose entire state is `#extra: Uint8Array(3)` + `#extraLength`. The rule: keep 0, 1 or 2 unconsumed bytes; because base64 consumes 3 input bytes per 4 output chars, only chunks that are multiples of 3 can be emitted immediately. On `stream: true` the residual `chunk.length % 3` bytes are copied into `#extra` and returned next time; on the final (non-stream) call the leftover is flushed *with padding*: `encoder.encode()` → `"bGQ="`. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64 , "Stream encoding" section.)

**How leftovers are carried — decoder.** MDN's `setFromBase64` page shows a `Base64Decoder` whose state is `#extra: string`. Stream mode sets `lastChunkHandling = "stop-before-partial"`; the decoder concatenates the carry string with the new chunk, allocates `new Uint8Array(Math.ceil((chunk.length * 3) / 4))` ("guaranteed to be enough, but may be too much if there is whitespace"), calls `setFromBase64`, then stores `chunk.slice(read)` back into `#extra`. The `{read, written}` pair is exactly what makes this possible: `read` tells the caller how much input was *consumed* (so the rest is leftover), `written` how much output was produced. (Source: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64 , "Stream decoding" section.)

**The two structural facts that make this work** (both sourced from `setFromBase64`):

1. **Chunks are never split.** "Chunks will never be split (because the remaining bits cannot be partially 'put back' into the base64 without completely re-encoding it); if the next chunk cannot fit into the remainder of the array, it will be entirely unread." So the leftover can be as large as one whole 4-char input chunk, not just 1-3 chars.
2. **`read` accounts for padding length.** "If the decoded data fits into the array, this is the length of the input string (including padding)."

**Also relevant:** MDN notes the `setFromBase64` page's decoder allocates new memory every call and remarks "if you're really concerned about memory, a TextDecoder style API is a bad choice" — i.e. the JS stream idiom is a convenience, not a zero-copy design. (Source: same page.)

**Not stream-aware at all:** `btoa`/`atob` have no incremental form; there is no `TextEncoderStream`/`TextDecoderStream` equivalent for base64, and TextEncoder/TextDecoder are explicitly *not* appropriate: the proposal FAQ says "base64 is not a text encoding format; there's no code points involved. So despite fitting with the type signature of TextEncoder/TextDecoder, base64 encoding and decoding is not a conceptually appropriate thing for those APIs to do." (Source: https://github.com/tc39/proposal-arraybuffer-base64 )

## 10. Interesting design decisions

1. **Two generations of API in one language, with opposite error philosophies.** Legacy `atob`/`btoa` are forgiving (never fail on non-zero pad bits; ignore whitespace) and string-typed; the 2025 ECMAScript methods are strict (default `loose` but with explicit `strict` that enforces zero overflow bits) and byte-typed. (Sources: Infra §7; MDN fromBase64; HTML spec.)
2. **Bytes, not strings, for the new API — and the reason is stated.** The proposal FAQ: "Those methods take and consume strings, rather than translating between a string and a Uint8Array." `Uint8Array.fromBase64` replaces `atob` precisely because a byte array is "easier to work with than a string containing raw bytes, unless your decoded binary data is actually intended to be ASCII text." (Sources: proposal README, MDN fromBase64.)
3. **An options bag with exactly two knobs, both orthogonal to the core algorithm.** Encoder: `alphabet`, `omitPadding`. Decoder: `alphabet`, `lastChunkHandling`. Nothing else — no line-wrapping, no line-length limit, no "ignore all non-alphabet chars" switch. (Sources: MDN toBase64, fromBase64.)
4. **Rejecting MIME line-wrapping outright.** The TC39 survey documents MIME's 76-char CRLF rule and PEM's 64-char rule as historical variants, and the new encoder simply never emits whitespace: "The encoders do not output whitespace." RFC 4648 §3.1 supports this: "Implementations MUST NOT add line feeds to base-encoded data unless the specification referring to this document explicitly directs base encoders to add line feeds after a specific number of characters." (Sources: https://github.com/tc39/proposal-arraybuffer-base64 , https://www.rfc-editor.org/rfc/rfc4648.txt )
5. **`{read, written}` as the incremental contract.** Borrowed explicitly from `TextEncoder.encodeInto` (the proposal README: "Like the TextEncoder encodeInto method, it returns a `{ read, written }` pair"), this is what lets streaming be userland without any hidden mutable state inside the codec. (Source: https://github.com/tc39/proposal-arraybuffer-base64 )
6. **`setFromBase64` writes from index 0 only; offsets via `subarray`.** Deliberate simplification: "the setFromBase64() method always starts writing at the beginning of the Uint8Array. If you want to write to the middle of the array, you can write to a subarray instead." Same idiom as `encodeInto`. (Sources: MDN setFromBase64; proposal README.)
7. **Whitespace is *only* ASCII whitespace, everywhere.** The proposal states this explicitly: "In all of the above, 'whitespace' means only ASCII whitespace. I don't think anyone has special handling for Unicode but non-ASCII whitespace." (Source: https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md )
8. **A published inter-library compatibility table.** The proposal authors wrote `base64.md` comparing 8 languages and 9 JS libraries across 7 behavioural axes (urlsafe, `=` in output, whitespace in output, omittable `=` in input, non-zero pad bits, arbitrary chars in input, whitespace in input). This is a rare and directly reusable artefact for MojoAkku's own docs: it is the format of a *compatibility matrix*, not prose. (Source: same `base64.md`.)
9. **Encoder is total, decoder is partial.** Every encode path in JS has zero or one (options-validation) error case, while every decode path has a real failure mode. This asymmetry is honest: any byte sequence is encodable, only some strings are decodable. (Synthesis of §4.)
10. **Naming as a deliberate non-goal.** `toBase64`/`fromBase64` were chosen over `encode`/`decode` because the latter are ambiguous about direction; the sibling hex methods share the `to*/from*` shape. (Synthesis of the API list; `GUESS:` the rationale is not spelled out in the pages fetched — only the naming pattern itself is sourced.)

## 11. Decisions NOT to copy

1. **Do NOT copy the "binary string" transport.** `btoa`/`atob` marshal bytes through a JS string where each code point < U+0100 is one byte. This is the source of the single most famous JS base64 bug class: `btoa("✓")` throws, and encoding real Unicode text requires the `TextEncoder` → `Uint8Array` → string round-trip shown in MDN. It also means the decoded output is a *string*, so it silently passes through string operations that corrupt bytes. (Sources: https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa , https://html.spec.whatwg.org/multipage/webappapis.html#atob ) MojoAkku should work on byte spans/`UInt8` only.
2. **Do NOT copy the forgiving decoders as a *default*.** `atob` and `Buffer.from(str,'base64')` silently ignore whitespace, ignore extra `=`, ignore non-zero pad bits, and (Node) accept a mixture of standard and URL-safe alphabets inside one string. RFC 4648 §3.3 says implementations MUST reject out-of-alphabet characters unless the referring spec says otherwise, and §3.5 permits rejecting non-canonical pad bits; §12 explains the covert-channel/bypass risk of ignoring them. `Buffer.from('a@b','base64')` decoding as if `@` were valid is exactly the "illegal characters are interpreted as A" behaviour the TC39 table flags in `base64-js`/`crypto-js`/`base64-arraybuffer` too. (Sources: https://www.rfc-editor.org/rfc/rfc4648.txt , https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md , https://nodejs.org/api/buffer.html )
3. **Do NOT copy permissive mixed-alphabet input.** Node's documented "decoding `'base64'` will also correctly accept the URL and Filename Safe Alphabet" removes the ability to state which alphabet a payload claims to use — a real problem for signature/JWT-style inputs where `-`/`_` vs `+`/`/` matters. `js-base64.isValid` even names the failure case ("can't mix both"). (Sources: https://nodejs.org/api/buffer.html , https://www.npmjs.com/package/js-base64 ) Prefer one explicit alphabet per call.
4. **Do NOT copy the boolean-flag / overloaded-parameter style.** `Base64.encode(str, true)` for URL-safe and `base64url(input, 'utf8')` where the second arg means an *encoding* rather than an *alphabet* are both ambiguity traps; the modern ECMAScript surface fixed this with a named options bag. (Sources: https://www.npmjs.com/package/js-base64 , https://www.npmjs.com/package/base64url , MDN fromBase64 ) A low-vision/readability-first library should require named options.
5. **Do NOT copy a silent-truncation `byteLength`-style helper.** Node documents `Buffer.byteLength(str,'base64')` as "assumes valid input", possibly *over-reporting* for strings with non-base64 data such as whitespace. A length/`decoded_length` function that can return a wrong-but-plausible number is worse than no function. (Source: https://nodejs.org/api/buffer.html )
6. **Do NOT copy prototypal extension as an API feature.** `js-base64.extendString()` / `extendUint8Array()` / `extendBuiltins()` monkey-patch built-in prototypes; the package itself warns "you should consider using ES6 Module to avoid tainting `window`". This is globally-scoped action-at-a-distance that no Mojo library should imitate. (Source: https://www.npmjs.com/package/js-base64 )
7. **Do NOT copy view-vs-copy surprises.** Node keeps `Buffer.prototype.slice()` as a *view* while `TypedArray.prototype.slice()` copies, documented as "surprising, and only exists for legacy compatibility". A new library must not have two same-named operations with different aliasing semantics. (Source: https://nodejs.org/api/buffer.html#buffers-and-typedarrays )
8. **Do NOT copy the split-brain error model.** Having `atob` (throws `DOMException`), `Buffer` (never throws) and `fromBase64` (throws `SyntaxError`/`TypeError`) coexist under one language name forces every library author to guess. MojoAkku should pick *one* error contract (`raises` in Mojo) and document it per function. (Sources: §4 above.)
9. **Do NOT copy MIME/line-wrapping as an option.** RFC 4648 §3.1 forbids adding line feeds unless the referring spec explicitly requires it; PEM's 64-char and MIME's 76-char rules are inherited mail constraints, not base64 semantics. The TC39 authors explicitly declined to expose them. (Sources: https://www.rfc-editor.org/rfc/rfc4648.txt , https://github.com/tc39/proposal-arraybuffer-base64 )
10. **Do NOT copy the runtime-dependent encoding-union dispatch.** `Buffer.from(str,'base64')` selects a codebase (base64 vs utf8 vs hex vs latin1) via a *runtime string* that is case-insensitive and can be any of ~10 values; a typo only surfaces as a runtime `TypeError`. (Source: https://nodejs.org/api/buffer.html ) Mojo should make the codec a distinct type/function, not an enum-valued last argument.

## 12. Ideas fitting Mojo

1. **Byte-first, never string-first.** The whole JS evolution from `atob` → `Uint8Array.fromBase64` is the argument for a Mojo API whose encode input and decode output are `Span[UInt8]`/`List[UInt8]` (or `String` only where the payload is provably ASCII text), with an explicit `text-encoder`-style conversion left to the caller. (Sources: MDN fromBase64; proposal FAQ "Those methods take and consume strings, rather than translating between a string and a Uint8Array.")
2. **Two named knobs, mirroring the ECMAScript shape.** An `Alphabet` type (standard / url-safe) and a padding/strictness policy (`required` / `optional` / `omitted` on encode, `loose`/`strict`/`stop-before-partial`-like on decode) map cleanly onto Mojo enums — and Mojo's compile-time enums can make them *zero-cost*, which JS's runtime string-valued options bag cannot. (Sources: MDN toBase64/fromBase64 for the semantics.)
3. **`read`/`written` incremental contract → Mojo borrowed/Span output.** `setFromBase64` proves the pattern works with plain data: a decode-into-buffer entry point that returns *how much input was consumed and how much output was written*, with the caller owning and pre-allocating the output. In Mojo this becomes a `borrowed` output `Span[UInt8]` plus a returned count struct — no allocation inside the codec, and no hidden state. (Source: MDN setFromBase64; proposal README.)
4. **Streaming as a separate, explicit stateful type — not baked into the codec functions.** The JS design keeps encode/decode pure and puts the 0-2 leftover bytes / partial 4-char chunk in a tiny caller-side object. Mojo should do the same: stateless one-shot functions plus an optional `Encoder`/`Decoder` struct holding at most 2 bytes (encode) or 3 characters (decode) of carry. (Sources: MDN toBase64 "Stream encoding", setFromBase64 "Stream decoding".)
5. **Chunks must never be split — encode this in the contract.** "Chunks will never be split … if the next chunk cannot fit into the remainder of the array, it will be entirely unread" is a rule whose violation cannot be repaired by the caller (re-encoding would be required). Stating it in Mojo docs/`raises`-invariants prevents a class of partial-output bugs. (Source: MDN setFromBase64.)
6. **Canonicality as a first-class decode policy.** RFC 4648 §3.5 allows rejecting non-zero pad bits; the ECMAScript `strict` mode implements exactly that and the JS legacy paths deliberately do not. Mojo can express this as a distinct mode (`strict` canonical check) with the security rationale (RFC §12) cited in the docs, rather than as hidden leniency. (Sources: https://www.rfc-editor.org/rfc/rfc4648.txt , MDN fromBase64.)
7. **Errors belong in `raises`, and the encoder should be total.** JS's own asymmetry (§10.9) is a good model: encode has no failure mode (only option validation, which Mojo can do at compile time), decode raises on invalid alphabet/padding. A Mojo `encode(...) -> String`-like pure function with no `raises`, next to `decode(...) raises`, makes that asymmetry visible in the type system — something JS cannot do. (Synthesis of §4; error model reference: Infra §7 / MDN.)
8. **Publish a compatibility matrix, in the TC39 `base64.md` format.** That table's seven behavioural axes (urlsafe; `=` in output; whitespace in output; omittable `=` in input; non-zero pad bits; arbitrary chars in input; whitespace in input) is a ready-made, citable template for `BASE64_DOCS.md`'s "what we do / what others do" section, and it directly serves the low-vision goal of predictable, comparable APIs. (Source: https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md )
9. **No timeouts, no cancellation, no async surface.** The JS answer ("structurally not applicable", §8) is correct for a pure codec, and Mojo should say so explicitly in the docs rather than leaving the absence unexplained. (Sources: §6 and §8 above.)
10. **Compile-time alphabet/padding selection via `comptime`/parameterization.** The two knobs are the only variability in the core algorithm; a `comptime` alphabet parameter would let Mojo generate a specialized, branch-free loop per (alphabet, padding) combination — the exact thing the JS options bag cannot do because the values arrive at runtime. (`GUESS:` no fetched source discusses Mojo comptime base64 specialization; this is a design extrapolation from the fact that JS's variability is confined to two enumerable knobs.)
11. **Reject, don't ignore, out-of-alphabet input by default.** Follow RFC 4648 §3.3's MUST-reject rather than RFC 2045/MIME's ignore-everything rule; if a lenient mode is wanted, make it an explicit, separately named flag (mirroring how the ECMAScript proposal documents leniency as a *choice*). (Sources: https://www.rfc-editor.org/rfc/rfc4648.txt , https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md )

## Sources

**Specifications / standards**
- WHATWG HTML Standard, §8.3 Base64 utility methods (`btoa`, `atob`) — https://html.spec.whatwg.org/multipage/webappapis.html#atob (accessed 2026-09-21; "Last Updated 21 September 2026")
- WHATWG Infra Standard, §7 "Forgiving base64" (`forgiving-base64 encode`/`decode`) — https://infra.spec.whatwg.org/#forgiving-base64-decode
- RFC 4648, "The Base16, Base32, and Base64 Data Encodings" (Josefsson, 2006) — https://www.rfc-editor.org/rfc/rfc4648.txt
- ECMAScript 2027 (draft), `Uint8Array.fromBase64` / `prototype.toBase64` / `prototype.setFromBase64` — https://tc39.es/ecma262/multipage/indexed-collections.html#sec-uint8array.frombase64 , #sec-uint8array.prototype.tobase64 , #sec-uint8array.prototype.setfrombase64

**Runtime documentation**
- Node.js v26.9.0 `Buffer` documentation (version VERIFIED 2026-09-21: page header reads "Node.js v26.9.0 documentation") (encodings, `Buffer.from`/`toString`/`byteLength`, `buffer.atob`/`btoa` legacy, view-vs-copy, `poolSize`) — https://nodejs.org/api/buffer.html
- Node.js v26.9.0 Global objects (version VERIFIED 2026-09-21: page header reads "Node.js v26.9.0 documentation") (`atob`, `btoa`, `AbortController` scope) — https://nodejs.org/api/globals.html

**Reference material / design rationale**
- TC39 proposal `proposal-arraybuffer-base64` (stage 4, archived 2025-10-28), README (options, `{read,written}`, streaming, FAQ) — https://github.com/tc39/proposal-arraybuffer-base64
- TC39 proposal `base64.md` — "Notes on Base64 as it exists": RFC survey, language table (Boost/Ruby/Python/Rust/Java/Go/C#/PHP/Swift), JS library table with download counts and per-library quirks, whitespace definition — https://github.com/tc39/proposal-arraybuffer-base64/blob/main/base64.md

**MDN (behavioural reference)**
- `Window.btoa()` — https://developer.mozilla.org/en-US/docs/Web/API/Window/btoa
- `Window.atob()` — https://developer.mozilla.org/en-US/docs/Web/API/Window/atob
- `Uint8Array.fromBase64()` — https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/fromBase64
- `Uint8Array.prototype.toBase64()` — https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/toBase64
- `Uint8Array.prototype.setFromBase64()` — https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Uint8Array/setFromBase64

**Community libraries (npm registry pages; last inspected 2026-09-21)**
- `base64-js` v1.5.1 — https://www.npmjs.com/package/base64-js
- `js-base64` v3.9.4 — https://www.npmjs.com/package/js-base64
- `base64url` v3.0.1 — https://www.npmjs.com/package/base64url
- `base64-arraybuffer` v1.0.2 — https://www.npmjs.com/package/base64-arraybuffer

**Unsourced / inferred statements (all marked in place above)**
- TypeScript adds no base64-specific API (§1) — `GUESS:`
- "fresh allocation" wording for `fromBase64`/`toBase64` (§5) — `GUESS:`, implied by doc wording
- Strings are immutable, so input is never mutated (§5) — `GUESS:`, language generalisation
- Workers/`worker_threads` as the large-payload escape hatch (§6) — `GUESS:`, generic concurrency mechanism
- "No timeout argument exists" stated in words (§8) — `GUESS:`, argued from the documented signatures
- Rationale for `to*/from*` naming over `encode`/`decode` (§10.10) — `GUESS:`
- Mojo `comptime` specialization of the two knobs (§12.10) — `GUESS:`, design extrapolation

**Not answered with a single authoritative source:**
- The exact **current** download numbers per package (the TC39 table's numbers differ from the npm registry's — e.g. `base64-js` 38M in the table vs ~108M on npm, `base64-arraybuffer` 4M vs ~19M). The table is undated and the registry numbers are point-in-time; no single source gives an authoritative, dated set. Reported both with their origins instead of picking one.
