# string research: JS/TS

Reference: ECMAScript 2026/2027 language specification (TC39) plus MDN and the
Node.js API docs. TypeScript adds no runtime string model — it only adds static
types over JavaScript's `string` primitive (`string` vs `String`, see Q3/Q11).

## 1. Standard library support

Strings are a **language primitive with a built-in prototype of methods** — the
runtime provides everything; there is no separate "text library".

- `string` is one of the language's primitive types; "The `String` object is
  used to represent and manipulate a sequence of characters."
  (Sources: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String>;
  the primitive type entry: MDN "String" under Standard built-in objects)
- Strings are **immutable primitives**: bracket-notation character properties
  "are neither writable nor configurable", and assigning to `.length` "has no
  observable effect, and will throw in strict mode".
  (Sources:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String>
  and .../String/length)
- The method family lives on `String.prototype`: `at`, `charAt`, `charCodeAt`,
  `codePointAt`, `concat`, `endsWith`, `includes`, `indexOf`, `isWellFormed`,
  `lastIndexOf`, `localeCompare`, `match`, `matchAll`, `normalize`, `padEnd`,
  `padStart`, `repeat`, `replace`, `replaceAll`, `search`, `slice`, `split`,
  `startsWith`, `substr`, `substring`, `toLowerCase`, `toUpperCase`,
  `toLocaleLowerCase`, `toLocaleUpperCase`, `toString`, `toWellFormed`, `trim`,
  `trimEnd`, `trimStart`, `valueOf`, `[Symbol.iterator]`, plus the deprecated
  HTML-wrapper methods (`bold`, `link`, …).
  (Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String#instance_methods>)
- Static helpers: `String.fromCharCode`, `String.fromCodePoint`, `String.raw`.
  (Source: same page, #static_methods)
- Unicode-aware helpers outside `String.prototype`: `Intl.Segmenter`
  (graphemes/words/sentences — "locale-sensitive text segmentation"),
  `Intl.Collator` (locale-aware comparison), `String.prototype.normalize`.
  (Sources:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter>,
  .../String/normalize)
- Node.js adds `Buffer` ("a fixed-length sequence of bytes", a
  `Uint8Array` subclass) plus `node:string_decoder` for incremental UTF-8
  decoding; there is **no builder class** for strings.
  (Sources: <https://nodejs.org/api/buffer.html>,
  <https://nodejs.org/api/string_decoder.html>)
- In the browser, `TextEncoder`/`TextDecoder` are the byte↔text bridge
  ("A decoder takes an array of bytes as input and returns a JavaScript
  string"). (Source:
  <https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder>)

## 2. Relevant community libraries

The community layer exists because the built-in unit is the UTF-16 **code
unit**, and `Intl.Segmenter` arrived late (Baseline 2024) and is not everywhere.

- `grapheme-splitter` (npm) — "breaks JavaScript strings into what a human user
  would call separate letters (or 'extended grapheme clusters' in Unicode
  terminology), no matter what their internal representation is".
  (Source: <https://www.npmjs.com/package/grapheme-splitter>,
  <https://github.com/orling/grapheme-splitter>)
- `graphemer` (npm) — the maintained successor, same UAX #29 purpose.
  (Source: <https://www.npmjs.com/package/graphemer>)
- `unicode-segmenter` (npm) — "a lightweight implementation of …" grapheme/
  word/sentence segmentation, with a `splitGraphemes()` generator that "yields
  substrings directly, so it allocates less than graphemeSegments()".
  (Source: <https://github.com/cometkim/unicode-segmenter>)
- `string-width` / `east-asian-width` (npm, transitive ecosystem) — display
  width, the terminal-layout counterpart of grapheme counting.
  (Source: <https://www.npmjs.com/package/string-width>) (Assessment: derived —
  width is a different question than length; the package family exists for it.)
- `iconv-lite` (npm) — pure-JS legacy-encoding transcoding, since the built-in
  `TextDecoder` supports a limited encoding set. (Source:
  <https://www.npmjs.com/package/iconv-lite>) (Assessment: derived from Node's
  documented encoding list in <https://nodejs.org/api/buffer.html>.)

## 3. Exposed APIs

`String.prototype` (source:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String#instance_methods>):

- **Index:** `at(i)` (one UTF-16 code unit, accepts negatives, `undefined` out
  of range), `charAt(i)` (one code unit, `""` out of range), `charCodeAt(i)`
  (code unit value), `codePointAt(i)` (code point starting at a code-unit
  index, `undefined` out of range).
- **Search:** `indexOf`/`lastIndexOf` → index or `-1`; `includes`;
  `startsWith`/`endsWith`; `match`/`matchAll`/`search` (regex).
- **Extract:** `slice(start,end)` (negative indices allowed, no swapping),
  `substring(start,end)` (swaps if start > end, clamps negatives to 0),
  the deprecated `substr(start,length)`.
- **Split:** `split(separator, limit)` — accepts a string, regex, or an object
  with `[Symbol.split]`; regex capturing groups are spliced into the result.
- **Build/reshape:** `concat`, `repeat`, `padStart`, `padEnd`, `replace`,
  `replaceAll`, `trim`/`trimStart`/`trimEnd`, `toLowerCase`/`toUpperCase`/
  `toLocaleLowerCase`/`toLocaleUpperCase`, `normalize(form)`.
- **Compare:** `<`/`>` (code-unit lexicographic), `===`, `localeCompare`
  (locale-aware, `Intl.Collator` interface).
- **Unicode validity:** `isWellFormed()` ("whether this string contains any lone
  surrogates"), `toWellFormed()` (replace lone surrogates with U+FFFD).
- **Iterate:** `[Symbol.iterator]` "iterates over the **code points** of a
  String value".

Bytes side (Node.js, source: <https://nodejs.org/api/buffer.html>):
`Buffer.from(string, encoding)`, `buf.toString(encoding[, start[, end]])`,
`Buffer.byteLength`, `Buffer.concat`, `buf.slice`/`buf.subarray`,
`buf.indexOf`, and the read/write integer helpers. Encodings: `utf8`, `utf16le`,
`latin1`, `ascii`, `base64`, `base64url`, `hex`, `binary`, `ucs2`.

TypeScript layer: `string` is the type for primitive strings; "The type names
`String`, `Number`, and `Boolean` (starting with capital letters) are legal, but
refer to some special built-in types that will very rarely appear in your code.
*Always* use `string`, `number`, or `boolean` for types."
(Source: <https://www.typescriptlang.org/docs/handbook/2/everyday-types.html>)

## 4. Error representation

JS errors are **exceptions** (`TypeError`, `RangeError`, `URIError`) or
**sentinel values** depending on the API — there is no `Result` type.

| Situation | Behavior | Source |
| --- | --- | --- |
| `codePointAt` out of range | returns `undefined` | MDN codePointAt |
| `charAt` out of range | returns `""` | MDN charAt |
| bracket access `s[i]` out of range | `undefined` | MDN charAt (comparison table) |
| `at(i)` out of range | `undefined` | MDN at |
| `slice` out of range | clamped / empty string, never throws | MDN slice |
| `indexOf` not found | `-1` | MDN String |
| `normalize("bogus")` | `RangeError` | MDN normalize #exceptions |
| regex-invalid pattern used by `match`/`split` | `SyntaxError` | (Assessment: derived from ECMA-262 RegExp construction) |
| lone surrogate passed to `encodeURI` | `URIError` ("URI encoding uses UTF-8 encoding, which does not have any encoding for lone surrogates") | MDN String #utf-16… |
| `JSON.stringify` of BigInt etc. | `TypeError` (unrelated to strings) | (not string-specific; omitted) |

The important structural fact: **out-of-range reads return sentinels, they do
not throw**, because strings are array-like and `undefined` is the natural
"no element" value. (Assessment: derived from MDN charAt/codePointAt/at.)

## 5. Ownership semantics

No ownership/borrow system; the relevant semantics are **primitive immutability
and value semantics at the language level, plus engine-side sharing**:

- Strings are primitives: bracket-notation properties "are neither writable nor
  configurable"; `myString.length = 4` has no effect.
  (Sources: MDN String, MDN String/length)
- `String` objects (`new String(x)`) exist as wrappers, but
  "**Warning:** You should rarely find yourself using `String` as a
  constructor." They are `typeof "object"` and misbehave with `eval`; use
  `valueOf()` to unwrap. (Source: MDN String
  #string_primitives_and_string_objects)
- There is **no borrowed view type**. `slice`/`substring` return new strings
  (engines may copy-on-write, but that is not exposed). The only zero-copy views
  are binary: `Uint8Array`/`Buffer.subarray`/`buf.slice`, and Node explicitly
  warns that `Buffer.prototype.slice()` "creates a view over the existing
  `Buffer` without copying … only exists for legacy compatibility" and that
  `subarray()` should be preferred. (Source:
  <https://nodejs.org/api/buffer.html#buffers-and-typedarrays>)
- Equality is value equality (`===` compares string contents) and identity is
  not observable for primitives.
  (Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String#comparing_strings>)

(Assessment: derived from the sources above — JS has *one* text layer, no
view, and pushes the view concept to binary types.)

## 6. Blocking / non-blocking

Pure string operations are **synchronous and CPU-bound** — no I/O, no blocking
concept. The event-loop split appears only around the string APIs:

- `TextDecoder.decode()` and `TextEncoder.encode()` are synchronous.
  (Source: <https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder>)
- `Blob.text()` is **asynchronous** ("Returns a promise that fulfills with the
  contents of the `Blob` decoded as a UTF-8 string"); `Blob.stream()` returns a
  `ReadableStream`; `blob.textStream()` is a stream of UTF-8 strings.
  (Source: <https://nodejs.org/api/buffer.html#class-blob>)
- `node:string_decoder` is stateful/synchronous but exists precisely to handle
  **chunked** input: "an internal buffer is used to ensure that the decoded
  string does not contain any incomplete multibyte characters".
  (Source: <https://nodejs.org/api/string_decoder.html>)
- On the web, `TextDecoderStream` is the streaming, backpressure-aware variant.
  (Source: <https://developer.mozilla.org/en-US/docs/Web/API/Encoding_API>)

## 7. Text model (encoding, length, indexing)

**JS strings are sequences of UTF-16 code units. `.length` and indexing count
code units; iteration counts code points; graphemes need a library or
`Intl.Segmenter`.**

- "Strings are represented fundamentally as sequences of **UTF-16 code units**.
  In UTF-16 encoding, every code unit is exact 16 bits long."
  (Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String#utf-16_characters_unicode_code_points_and_grapheme_clusters>)
- `.length` "contains the length of the string in UTF-16 code units"; "it's
  possible for the value returned by `length` to not match the actual number of
  Unicode characters".
  (Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/length>)
- **The classic trap:** `"😄".length === 2` (a surrogate pair) while
  `[...emoji].length === 1`. (Source: MDN String/length #examples)
- Indexing is by code unit: `"cat"[1]` is `"a"`; `charAt` "always indexes the
  string as a sequence of UTF-16 code units, so it may return lone surrogates";
  `codePointAt` "note that the index is still based on UTF-16 code units, not
  Unicode code points". (Sources: MDN String #character_access, MDN charAt,
  MDN codePointAt)
- Iteration differs from indexing: `[Symbol.iterator]` "iterates by Unicode
  code points"; `split("")` "will split by UTF-16 code units and will separate
  surrogate pairs". (Sources: MDN String #utf-16…, MDN split)
- Graphemes: "Iterating through grapheme clusters will require some custom
  code." The standard answer is `Intl.Segmenter(granularity:"grapheme")`.
  (Sources: MDN String #utf-16…, MDN Segmenter)
- Encoding: there is **no encoding field** on a string; the internal
  representation is UTF-16 (engines may store Latin-1 internally: "all major
  engines use a more compact internal representation, such as one-byte storage,
  for strings containing only Latin-1 characters"). Conversion is at the edges:
  `TextEncoder`/`TextDecoder`, `Buffer`, `encodeURI`.
  (Sources: MDN String/length, MDN TextDecoder, Node Buffer)
- Bounds beyond Unicode: strings are **not guaranteed well-formed**. Lone
  surrogates are allowed values; `isWellFormed()`/`toWellFormed()` were added to
  detect/repair them. (Source: MDN String #utf-16…)
- Max length: the spec caps strings at 2^53−1 code units, but engines lower it
  (V8 ≈ 2^29−24 ≈ 1 GiB; Firefox ≈ 2^30−2; Safari 2^31−1). Exceeding it throws
  `RangeError: Invalid string length`. (Source: MDN String/length)

Position definition: a position is a **UTF-16 code-unit index**; `slice`/`substring`
are half-open `[start, end)` in that unit (Q8 for bounds).

## 8. Bounds, invalid input and errors

- **Out-of-range reads never throw:**
  - `s[i]` → `undefined` (bracket access "directly uses `index` as a property
    name"). (Source: MDN charAt)
  - `charAt(i)` → `""` out of range. (Source: MDN charAt)
  - `at(i)` → `undefined` out of range; negative indices count from the end.
    (Source: MDN at)
  - `codePointAt(i)` → `undefined` if `index` outside `0..length-1`.
    (Source: MDN codePointAt)
- **Slicing clamps rather than throws:** for `slice`, "If `indexStart >=
  str.length`, an empty string is returned"; negative indices become
  `max(indexStart + str.length, 0)`; `indexEnd <= indexStart` → `""`.
  (Source: MDN slice)
- **Slicing on a non-boundary is possible.** Because the unit is a code unit,
  `slice(0,1)` of `"😄"` yields a **lone surrogate** — a string that is not a
  valid Unicode scalar sequence. This is the sharpest divergence from Python
  (which indexes code points) and from Mojo (UTF-8 + validity).
  (Assessment: derived from MDN String #utf-16…: `"😄".split("")` → two lone
  surrogates; and MDN String/length: `"😄".length` is 2.)
- **Empty edges:** `"".length === 0`; `"".charAt(0) === ""`;
  `"abc".split("")` → `["a","b","c"]`; `"".split("")` → `[]` (the only way to
  get an empty array with an empty separator and no limit); `"".split("a")` →
  `[""]`; `"".split()` → `[""]`. (Sources: MDN String/length, MDN split)
- **Invalid encoding on input:** in Node,
  `Buffer.from(...).toString('utf8')` replaces bad bytes with U+FFFD (since
  v8.0.0 "Each invalid character is now replaced by a single replacement
  character"). The WHATWG `TextDecoder` has a `fatal` flag: with `fatal: true`
  it throws `TypeError` on invalid sequences, otherwise U+FFFD.
  (Sources: <https://nodejs.org/api/string_decoder.html>,
  <https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder>)
- **`normalize(form)` throws `RangeError`** for a form outside
  `"NFC"|"NFD"|"NFKC"|"NFKD"`. (Source: MDN normalize)
- **Comparison is code-unit-lexicographic and **case-sensitive**; robust
  caseless comparison needs `localeCompare`/`Intl.Collator` with `sensitivity`
  ("`ß` and `ss` are both transformed to `SS` by `toUpperCase()`" — the
  toUpperCase trick is not robust beyond Latin). (Source: MDN String
  #comparing_strings)
- **Normalization is explicit:** `"\u00F1" !== "\u006E\u0303"`; after
  `normalize("NFC")` they are `===` and equal length.
  (Source: MDN normalize #description)

(Assessment: derived from the sources above — JS's rule is the *opposite* of
Python's on the two key points: reads are non-raising sentinels, and slicing can
split a code point, leaving ill-formed strings behind.)

## 9. Owned type, borrowed view and builder layer

JS provides **one** layer of the three as a text type, and replaces the other
two with conventions and binary types:

- **Owned type:** the `string` primitive (immutable, value semantics). The
  `new String(...)` wrapper object exists but is discouraged.
  (Source: MDN String #string_primitives_and_string_objects)
- **Borrowed view:** **none for text.** There is no `&str`/`StringSpan`
  equivalent; `slice`/`substring` allocate new primitive strings. The view
  concept exists only for bytes: `Uint8Array`, `ArrayBuffer`, `DataView`, and
  Node's `Buffer.subarray()` (zero-copy). (Sources: Node Buffer
  #buffers-and-typedarrays; MDN slice)
- **Builder layer:** **no builder concept at all.** Concatenation is `+`/`+=`
  or `Array.prototype.join`, and engines optimize the rope/cons-string case
  internally without exposing an API. Node has no `StringBuilder`; the closest
  analogue is accumulating in an array and `join("")`, or writing to a
  `ReadableStream`/`Buffer` for bytes. (Assessment: derived from the absence of
  any builder in the MDN `String` API list and the Node `buffer`/`string_decoder`
  docs; `Array.prototype.join` is the documented idiom in MDN String #description:
  "to build and concatenate them using the `+` and `+=` string operators".)
- **Byte ↔ text bridge:** `TextEncoder.encode(str) -> Uint8Array` and
  `TextDecoder.decode(bytes) -> string` in the browser/WHATWG; `Buffer.from(str,
  encoding)` and `buf.toString(encoding)` in Node; `StringDecoder` for chunked
  decoding; `encodeURI`/`decodeURI` for URL percent-encoding.
  (Sources: MDN TextDecoder, Node Buffer, Node string_decoder)
  There is **no implicit conversion** between text and bytes: text APIs take
  strings, byte APIs take `Uint8Array`/`Buffer`; mixing means an explicit
  encoder/decoder call.

(Assessment: derived from the sources above — the three-layer picture maps to
JS as *one primitive + nothing + nothing*; both the borrowed view and the
builder are absent, and binary types carry the view idea.)

## 10. Interesting design decisions

1. **UTF-16 code units as the indexing unit**, inherited from the 1995 Java
   design, kept for compatibility. It buys O(1) indexing for BMP text and
   cheap interop with the DOM/COM, at the cost of the surrogate-pair trap.
   (Source: MDN String #utf-16…)
2. **Two different units on the same object:** indexing/`.length` use code
   units, iterating (`for…of`, spread) uses code points, and graphemes need a
   third tool. The inconsistency is deliberate and documented.
   (Sources: MDN String/length, MDN String #utf-16…)
3. **Non-raising, array-like reads** (`undefined`/`""`/`-1`) instead of
   exceptions — consistent with the language's property-access semantics.
   (Sources: MDN charAt, codePointAt, at, slice)
4. **Strings may be ill-formed** (lone surrogates are legal values), and
   `isWellFormed`/`toWellFormed` are the explicit repair API — the opposite of
   Mojo's "valid UTF-8 at construction".
   (Sources: MDN String #utf-16…, MDN String/isWellFormed)
5. **`Intl.Segmenter` as the sanctioned grapheme API**, locale-aware and
   spec'd in ECMA-402 rather than baked into `String`.
   (Source: MDN Segmenter; spec
   <https://tc39.es/ecma402/#segmenter-objects>)
6. **`normalize()` is on the string itself** (unlike Python's `unicodedata`),
   but comparison is still code-unit-exact unless you call it.
   (Source: MDN normalize)
7. **`replace` vs `replaceAll`** are separate methods because `replace` with a
   string only replaces the first occurrence while `replaceAll` replaces all —
   a compatibility-driven split. (Source: MDN String #instance_methods)
8. **String immutability is a primitive-level property**, not a class contract:
   even the wrapper object's index properties are non-writable/non-configurable.
   (Source: MDN String #character_access)
9. **A max length** tied to engine representation (V8 2^29−24) surfaces as a
   `RangeError` only on allocation, not a declared type bound.
   (Source: MDN String/length)

## 11. Decisions NOT to copy

- **UTF-16 code-unit indexing and `.length`.** The single most-copied mistake:
  `"😄".length === 2` and `slice` producing lone surrogates. Mojo stores UTF-8
  and already offers `byte_length()`/`count_codepoints()`/`count_graphemes()`;
  do not add a unit that is neither bytes nor code points.
  (Source: MDN String/length; Mojo facts from
  `mojov1/types/bool-and-strings`.)
- **Slicing that can split a character.** `slice(0,1)` of an emoji yields an
  invalid lone surrogate. Mojo's UTF-8-validated model should refuse or snap to
  a boundary instead. (Source: MDN String #utf-16…; Mojo facts from
  `mojov1/types/bool-and-strings`.)
- **Silent sentinel returns for out-of-range reads.** `undefined`/`""` hides
  bugs; a typed `Optional` result is better, and Mojo has `Optional`. (Sources:
  MDN charAt/at/codePointAt; `mojov1/idioms/patterns`.)
- **Strings that may be ill-formed.** A text type whose bytes are not valid
  Unicode forces `isWellFormed()` checks everywhere downstream; Mojo enforces
  validity at construction for good reason. (Source: MDN String #utf-16…;
  Mojo facts from `mojov1/types/bool-and-strings`.)
- **No builder and no borrowed view.** Both gaps push users into `+=`-in-a-loop
  or array-join idioms and into allocations per slice; Mojo should keep
  `StringSpan` and provide an explicit builder. (Sources: MDN String
  #description, MDN slice; Mojo facts from `mojov1/types/bool-and-strings`.)
- **`substr`/`substring`/`slice` with three different edge rules.** Having
  `substring` swap indices and clamp negatives while `slice` does not is a
  readability hazard; pick one rule. (Source: MDN slice, MDN String
  #instance_methods.)
- **Case-insensitive comparison by `toUpperCase()`** is documented as wrong for
  `ß`/`ss` and Turkish `ı`/`I`; a `casefold`-style primitive (like Python's) is
  the correct shape. (Source: MDN String #comparing_strings.)
- **The `new String()` wrapper.** "You should rarely find yourself using
  `String` as a constructor"; a separate boxed text type is a bug source.
  (Source: MDN String #string_primitives_and_string_objects.)

## 12. Ideas fitting Mojo

- **Keep UTF-8 and the three explicit lengths** rather than importing the
  code-unit unit — JS is the cautionary tale that justifies Mojo's model.
  (Sources: MDN String/length; Mojo facts from
  `mojov1/types/bool-and-strings`.)
- **Provide `is_well_formed`/repair only if a raw-bytes constructor is offered.**
  JS needed `isWellFormed`/`toWellFormed` because it never validates; Mojo's
  `String(from_utf8_lossy=…)`/`unsafe_from_utf8` already cover the two policies.
  (Sources: MDN String/isWellFormed; Mojo facts from
  `mojov1/types/bool-and-strings`.)
- **A grapheme iterator as a first-class API** — JS only reaches graphemes via
  `Intl.Segmenter` or third-party libs; Mojo's 1.0 iteration already yields
  graphemes, so the library should expose the explicit
  grapheme/codepoint/byte views and their boundary queries.
  (Sources: MDN Segmenter, MDN String #utf-16…; Mojo facts from
  `mojov1/types/bool-and-strings`.)
- **`normalize(form)` as a method-like primitive**, mirroring JS's ergonomics
  but with an explicit set of forms and a defined error on a bad form.
  (Source: MDN normalize.)
- **A builder with an append/flush contract** — the layer JS lacks entirely;
  it also removes the `+=`-in-a-loop quadratic risk that JS leaves to the
  engine. (Sources: MDN String #description; Python's documented
  quadratic-concatenation warning, see `python.md` Q9.)
- **`Optional`-returning search plus a `raises` variant** to replace the
  `-1`/`undefined` sentinels with typed outcomes.
  (Sources: MDN String #instance_methods; `mojov1/idioms/patterns`.)
- **Locale-aware comparison as an opt-in** (`collate`/`casefold`) instead of
  putting `localeCompare` and `Intl` semantics into `==`; keep `==` as exact
  codepoint/code-unit equality and make locale sorting explicit.
  (Source: MDN String #comparing_strings.)

## Sources

- MDN — `String` (constructor, statics, instance properties/methods, UTF-16
  characters/code points/grapheme clusters, primitives vs objects, comparison):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String>
- MDN — `String: length` (UTF-16 code units, engine limits, examples):
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/length>
- MDN — `String.prototype.slice()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/slice>
- MDN — `String.prototype.charAt()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/charAt>
- MDN — `String.prototype.codePointAt()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/codePointAt>
- MDN — `String.prototype.at()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/at>
- MDN — `String.prototype.split()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/split>
- MDN — `String.prototype.normalize()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/normalize>
- MDN — `String.prototype.isWellFormed()`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/isWellFormed>
- MDN — `Intl.Segmenter`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter>
- MDN — `TextDecoder`:
  <https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder>
- MDN — Encoding API (TextEncoder/TextDecoder/Streams):
  <https://developer.mozilla.org/en-US/docs/Web/API/Encoding_API>
- ECMAScript Language Specification, *The String Type*:
  <https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-ecmascript-language-types-string-type>
- ECMA-402 `Segmenter` objects:
  <https://tc39.es/ecma402/#segmenter-objects>
- Node.js — `Buffer`:
  <https://nodejs.org/api/buffer.html>
- Node.js — String decoder:
  <https://nodejs.org/api/string_decoder.html>
- TypeScript Handbook — Everyday Types (`string` vs `String`):
  <https://www.typescriptlang.org/docs/handbook/2/everyday-types.html>
- npm — `grapheme-splitter`:
  <https://www.npmjs.com/package/grapheme-splitter>
- npm — `graphemer`: <https://www.npmjs.com/package/graphemer>
- GitHub — `unicode-segmenter`:
  <https://github.com/cometkim/unicode-segmenter>
- npm — `string-width`: <https://www.npmjs.com/package/string-width>
- npm — `iconv-lite`: <https://www.npmjs.com/package/iconv-lite>
- UAX #29 Unicode Text Segmentation (referenced by the grapheme libraries and
  by `Intl.Segmenter`'s grapheme granularity):
  <https://www.unicode.org/reports/tr29/>
- Mojo side (buch, not internet): `mojov1/types/bool-and-strings`,
  `mojov1/idioms/patterns`.
