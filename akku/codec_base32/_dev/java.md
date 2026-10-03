# base32 research: Java

## 1. Standard library support

The JDK has **no Base32**. Its codec surface is:

- `java.util.Base64` (since Java 8) with `Base64.Encoder`/`Base64.Decoder` and
  three base64 flavours (Basic, URL/filename-safe, MIME).
- `java.util.HexFormat` (since Java 17), a *formatter* for base16.
- The old XML `javax.xml.bind.DatatypeConverter` was removed in Java 11 by
  JEP 320, which recommends `java.util.Base64`.

The Java 21 `java.util` package class list contains `Base64`, `Base64.Decoder`,
`Base64.Encoder` and `HexFormat`, but **no `Base32`**; the package description
mentions only "base64 encoding and decoding". (Sources:
https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html,
https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html,
https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HexFormat.html,
https://openjdk.org/jeps/320)

So base32 in Java is entirely a community-library concern — which is the
opposite of base64, where the JDK is the reference.

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page records only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

| Library | Coordinates / package | Maintainer | Maturity | License | base32 |
| --- | --- | --- | --- | --- | --- |
| Apache Commons Codec | `org.apache.commons.codec.binary.Base32` | ASF | 1.22.1 (Jul 2026), Java 8+ | Apache-2.0 | standard + base32hex |
| Guava | `com.google.common.io.BaseEncoding.base32()` / `.base32Hex()` | Google | since 14.0 | Apache-2.0 | standard + base32hex |
| Bouncy Castle | `org.bouncycastle.util.encoders.Base32` | Legion of the Bouncy Castle Inc. | bcprov-jdk18on 1.85 | MIT | standard only |
| Netty | `io.netty.handler.codec.base64.*` | Netty Project | 4.1.138.Final | Apache-2.0 | **base64 only** |

Sources:
- Commons Codec `Base32`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>.
- Guava `BaseEncoding` (`base32()`, `base32Hex()`):
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
- Bouncy Castle `Base32`:
  <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base32.html>,
  license <https://www.bouncycastle.org/about/license/>.
- Netty `Base64` only: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>.

(Assessment: derived from the four sources above: base32 in Java is supplied by
exactly the three general codec libraries, with Commons Codec the oldest and
most configurable, Guava the cleanest, and Bouncy Castle the minimal one. The
sibling run's `java.md` §12 already flagged "Base32 belongs in the library, since
neither the JDK nor Mojo's stdlib has it".)

## 3. Exposed APIs

### Apache Commons Codec `Base32`

`public class Base32 extends BaseNCodec` — "Provides Base32 encoding and
decoding as defined by RFC 4648." Configuration is via a builder (constructors
are `@Deprecated`):

```java
Base32 base32 = Base32.builder()
  .setDecodingPolicy(DecodingPolicy.LENIENT) // default is lenient
  .setLineLength(0)                          // default is none
  .setLineSeparator('\\r', '\\n')              // default is CR LF
  .setPadding('=')                           // default is '='
  .setEncodeTable(customEncodeTable)         // default is RFC 4648 §6, Table 3
  .get();
```

It "can be parameterized … [by] whether to use the 'base32hex' variant instead
of the default 'base32'", line length (the class javadoc says "Default 76", but
the actual `Base32()` and builder default is 0/no chunking; "Line length that
aren't multiples of 8 will still essentially end up being multiples of 8 in the
encoded data" — the base32 quantum made visible), line separator, padding and a
custom encode table. Inherited `BaseNCodec` methods include `encode(byte[])`,
`encode(byte[],int,int)`, `encodeAsString`, `encodeToString`, `decode(byte[])`,
`decode(String)`, `decode(Object)`, `isInAlphabet(...)`, `getEncodedLength(...)`,
`isStrictDecoding()`. Streaming variants: `Base32InputStream` /
`Base32OutputStream`. (Sources:
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.)

### Guava `BaseEncoding`

Static factories `base16()`, `base32()`, `base32Hex()`, `base64()`,
`base64Url()` — all RFC 4648 (§8/§6/§7/§4/§5). Instance methods:
`encode(byte[]) -> String`, `encode(byte[],int,int)`, `decode(CharSequence) ->
byte[]`, `canDecode(CharSequence)`, `encodingStream(Writer)`,
`decodingStream(Reader)`, `encodingSink(CharSink)`, `decodingSource(CharSource)`,
and configuration `omitPadding()`, `withPadChar(char)`, `withSeparator(String,int)`,
`upperCase()`, `lowerCase()`, `ignoreCase()`. Instances are immutable and
config-by-copy. (Source:
<https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.)

### Bouncy Castle `Base32`

`org.bouncycastle.util.encoders.Base32` is a static utility: `toBase32String(byte[])`,
`toBase32String(byte[],int,int)`, `encode(byte[])`, `encode(byte[],int,int)`,
`encode(byte[],OutputStream)` / `encode(byte[],int,int,OutputStream) -> int`,
`decode(byte[])`, `decode(String)`, `decode(String,OutputStream)`,
`decode(byte[],int,int,OutputStream)`. The `String` decode "whitespace will be
ignored". There is no alphabet parameter. (Source:
<https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base32.html>.)

### Netty

Base64-only (see the sibling run's `java.md` §3); there is no
`io.netty.handler.codec.base32` package. (Assessment: derived from the Netty API
index.)

## 4. Error representation

Java uses **unchecked and checked exceptions**, split by layer:

- **Commons Codec**: lenient by default (`DecodingPolicy.LENIENT`); with
  `CodecPolicy.STRICT` decoding raises `IllegalArgumentException` "if trailing
  bits are not part of a valid encoding. Any unused bits from the final character
  must be zero." The `Decoder`/`Encoder` object interfaces throw checked
  `DecoderException`/`EncoderException`, while the static helpers throw
  `IllegalArgumentException`. (Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>.)
- **Guava**: `decode` throws `IllegalArgumentException` "if the input is not a
  valid encoded string according to this encoding"; the decoding *stream* throws
  the dedicated `BaseEncoding.DecodingException`. (Source:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.)
- **Bouncy Castle**: encoding to/from an `OutputStream` throws checked
  `IOException`; the in-memory `decode` assumes valid input ("It is assumed the
  input data is valid") and otherwise throws the codec's `DecoderException`.
  (Source: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base32.html>.)
- There is **no typed, offset-carrying decode error** in any Java base32 library;
  the caller gets a message string at best.

(Assessment: derived from the sources above: Java's base32 error surface is
fragmented by library and layer, and the canonicality/trailing-bit question is a
*policy* that only Commons Codec exposes — exactly as with base64 in the sibling
run.)

## 5. Ownership semantics

Java has no user-visible ownership model; every byte container is a managed
reference on the heap, and the GC owns it. What matters is **which side allocates
the output buffer and who sizes it**:

- **Input is borrowed.** All three libraries read the `byte[]`/`String` argument
  and never claim it; the caller keeps the array. Bouncy Castle's `decode(String)`
  materialises an internal copy for whitespace removal. (Source: the Bouncy
  Castle `Base32` doc.)
- **Returning forms allocate a fresh array/String owned by the caller**:
  Guava `encode(byte[]) -> String`; Bouncy Castle `encode(byte[]) -> byte[]`;
  Commons Codec `encode(byte[])` and `encodeToString(byte[])`. (Sources: the
  three APIs above.)
- **Caller-supplied offsets/streams shift sizing to the caller**: Commons Codec's
  `encode(byte[],int,int)` + `getEncodedLength(byte[])`; Bouncy Castle's
  `encode(byte[],int,int,OutputStream)` and `decode(String,OutputStream)`, which
  return the number of bytes produced. (Sources: the two APIs above.)
- **Guava is String-centric on encode** (`encode -> String`) but byte-centric on
  decode (`decode -> byte[]`), so the charset decision is on the encode side
  only. (Source: the Guava `BaseEncoding` doc.)

(Assessment: derived from the sources above: the Java base32 ownership question
reduces to "who allocates and sizes the output", and all three libraries offer a
fresh-allocation form plus a stream/offset form.)

## 6. Blocking / non-blocking

Not applicable at the codec level: all three libraries are synchronous in-memory
(or stream) transforms. Their `java.io` stream wrappers are **blocking** by
contract; Commons Codec's `Base32InputStream`/`Base32OutputStream` inherit that.
There is no async/reactive base32 API. Thread-safety is the only concurrency
concern addressed: Commons Codec's `Base32` is documented "The class is
thread-safe"; Guava's `BaseEncoding` instances "are immutable, so they may be
stored safely as static constants". (Sources:
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>,
<https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.)

(Assessment: derived from the sources above: for a pure codec, "blocking vs
non-blocking" reduces entirely to "in-memory vs streaming"; Java answers it by
offering both shapes and making neither asynchronous — the same conclusion as
base64 in the sibling run, but now without any JDK fallback.)

## 7. Alphabet variants, case and padding

### Commons Codec

- **Standard base32 (RFC 4648 §6 Table 3)** is the default encode table;
  **base32hex (RFC 4648 §7 Table 4)** is selected by `useHex=true` (or the
  builder's hex mode). (Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>.)
- **Line length: the class javadoc says "Default 76", but the actual
  `Base32()` no-arg constructor and the builder default are line length 0 (no
  chunking).** The javadoc's "Line length: Default 76" describes the historical
  constructor family, while `Base32()` is documented as "When encoding the line
  length is 0 (no chunking)" and the builder example shows `.setLineLength(0) //
  default is none`. Line lengths "that aren't multiples of 8 will still
  essentially end up being multiples of 8 in the encoded data." (Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>.)
- **Padding** is `'='` by default and adjustable via `setPadding(char)`.
- **Custom encode table** via `setEncodeTable`.
- Case: not exposed as an option; the default encode table is uppercase, and the
  decoder is lenient by default.

### Guava

- `base32()` (`A-Z 2-7`) and `base32Hex()` (`0-9 A-V`), both RFC 4648, default
  padding `=`. (Source:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.)
- **Case is explicit**: `upperCase()`, `lowerCase()`, `ignoreCase()`; the class
  docs warn that by default "Decoding rejects characters in the wrong case,
  though padding is optional", and `ignoreCase()` is "since 32.0.0". This is the
  cleanest case model of the three. (Source: the same page.)
- `omitPadding()` / `withPadChar(char)` for padding; `withSeparator(String,int)`
  for line breaks.
- The docs guarantee `encoding.decode(encoding.encode(x)) == x` but note "the
  reverse does not necessarily hold" — i.e. non-canonical inputs may still decode.
  (Source: the same page.)

### Bouncy Castle

- `Base32` is standard-alphabet only, no config; `decode(String)` ignores
  whitespace. (Source:
  <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base32.html>.)
- **No base32hex and no Crockford** in any of the three libraries; Commons Codec
  has `Base58` too but not Crockford. (Assessment: derived from the three API
  pages.)

### RFC 4648 reference

§6 Table 3 (base32 `A-Z2-7`), §7 Table 4 (base32hex `0-9A-V`), §3.2 padding,
§3.4 the default non-decoding of `0/O` and `1/I/L`, §3.5 canonical encoding.
(https://www.rfc-editor.org/rfc/rfc4648.txt)

(Assessment: derived from the sources above: the Java base32 variant split is
between Commons Codec's builder/hex-flag model and Guava's immutable
config-by-copy model; neither ships Crockford, and only Commons Codec exposes the
strict-vs-lenient trailing-bit policy.)

## 8. Timeouts

Not applicable. Nothing in the Commons Codec, Guava or Bouncy Castle base32
surfaces accepts or documents a timeout or cancellation token; the methods are
synchronous in-memory transformations. For stream wrappers, the underlying
`java.io` stream's own blocking semantics and `IOException` are the only failure
paths. (Sources: the three API pages above.)

(Assessment: derived from the sources above: a pure codec has no cancellation
surface, and Java deliberately does not invent one — it exposes stream wrappers
so that the *transport* owns blocking, timeouts and interruption.)

## 9. Streaming / incremental encode and decode

Base32 encodes 5 input bytes to 8 output characters. Every streaming
implementation therefore buffers 0–4 trailing *input* bytes on the encoding side
and up to 7 trailing *characters* on the decoding side until a full quantum (or
padded final quantum) exists.

- **Commons Codec**: `Base32InputStream` / `Base32OutputStream`, plus the generic
  `BaseNCodec` context mechanism (`Context`, `ensureBufferSize`,
  `getEncodedLength`) that holds partial-block state between calls. The builder's
  line length must be a "multiple of 8" for clean chunk boundaries — the base32
  quantum surfacing in the chunking rule. (Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.)
- **Guava**: `encodingStream(Writer)` returns an `OutputStream` that flushes on
  close; `decodingStream(Reader)` returns an `InputStream` that "throws a
  BaseEncoding.DecodingException upon decoding-specific errors"; plus
  `encodingSink`/`decodingSource`. (Source:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.)
- **Bouncy Castle**: no stream *class*, but `encode(byte[],OutputStream)` and
  `decode(String,OutputStream)` write incrementally and return the byte count;
  buffering is left to the caller. Its sibling `org.bouncycastle.util.encoders`
  package also ships `BufferedDecoder`/`BufferedEncoder`, "A buffering class to
  allow translation from one format to another to be done in discrete chunks."
  (Source:
  <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>.)
- None of the in-memory methods (`encode(byte[])`, `decode(String)`) is
  incremental; they take a complete input and return a complete output.

(Assessment: derived from the sources above: Java base32 streaming is
library-specific, and the carry quantum is 5 bytes/8 symbols — a detail a Mojo
API must state explicitly.)

## 10. Interesting design decisions

1. **Builder-based configuration** (Commons Codec) versus **immutable
   config-by-copy** (Guava). Commons Codec's builder consolidates a large
   deprecated-constructor history; Guava's `omitPadding()`/`ignoreCase()` return
   new instances, and the doc even shows the anti-pattern (`hex.lowerCase();`
   does nothing). (Sources: the two API pages.)
2. **`getEncodedLength(byte[])` and Guava's `encode(byte[],int,int)`**: both
   expose a size/range computation so callers can pre-size buffers without doing
   the work twice. (Sources: `BaseNCodec`, `BaseEncoding`.)
3. **Explicit case configuration only in Guava.** `upperCase()`/`lowerCase()`/
   `ignoreCase()` is the cleanest of the three; Commons Codec and Bouncy Castle
   silently fix upper case. (Source: Guava `BaseEncoding`.)
4. **A strict-vs-lenient *decoding policy*** (Commons Codec `CodecPolicy.STRICT`
   vs `LENIENT`): makes canonical-vs-non-canonical input an explicit, typed
   choice, matching RFC 4648 §3.5. (Source: `BaseNCodec`.)
5. **Line-length config in a binary codec** (Commons Codec: the javadoc's "Default
   76" vs. the actual constructor/builder default of 0, either way rounded to a
   multiple of 8). Carried over from the MIME era; Guava's default is no line
   breaks, matching RFC 4648 §3.1. (Sources: both pages.)
6. **Whitespace leniency by default in Bouncy Castle** (`decode(String)` "-
   whitespace will be ignored") with no strict switch, versus Guava's strict
   case handling. (Source: Bouncy Castle `Base32`.)
7. **A custom `setEncodeTable`** (Commons Codec), the only Java escape hatch for
   non-RFC alphabet tables — but still no Crockford preset. (Source:
   `Base32.Builder`.)

## 11. Decisions NOT to copy

1. **Checked exceptions in a pure codec** (`IOException` from Bouncy Castle's
   stream encode/decode; `DecoderException`/`EncoderException` from Commons Codec
   object interfaces). A malformed base32 string is a data error, not an I/O
   condition. (Sources: the two API pages.)
2. **The `Object`-based `Encoder`/`Decoder` bridge** (`encode(Object)`,
   `decode(Object)`), type-erasure legacy a statically typed language should not
   reproduce. (Source: `BaseNCodec`.)
3. **Silent leniency by default** (Commons Codec `LENIENT` discards non-zero
   trailing bits; Bouncy Castle ignores whitespace with no strict mode). Silent
   acceptance of malformed input hides corruption. (Sources: `BaseNCodec`,
   Bouncy Castle `Base32`.)
4. **Deprecated-constructor sprawl** (Commons Codec's `Base32` has nine mostly
   `@Deprecated` constructors). Do not design a public API with a deprecated
   parallel universe from day one. (Source: `Base32`.)
5. **Line-wrapping support carried in from the MIME era** (Commons Codec's
   javadoc "Default 76", rounded to a multiple of 8). RFC 4648 §3.1
   says "Implementations MUST NOT add line feeds … unless the specification
   referring to this document explicitly directs base encoders to add line
   feeds"; wrapping belongs to an explicit option. (Sources: `Base32`;
   https://www.rfc-editor.org/rfc/rfc4648.txt.)
6. **"Caller must size the destination buffer" without a size query** — the
   Bouncy Castle stream forms avoid it, but if only offsets were offered the
   sizing formula would be implicit. Expose the size computation.
7. **String-only encode results** (Guava `encode -> String`) force a charset
   decision into a binary codec; keep bytes as the primary result type and make
   the string form explicit.
8. **No Crockford anywhere.** Since ULID and Crockford IDs are real, a new
   library should at least record Crockford as a backlog candidate rather than
   inherit Java's silence. (Sources: the three APIs;
   https://github.com/ulid/spec.)
9. **The `Object`/`boolean useHex` boolean-flag API** — Commons Codec's
   `useHex` flag is unreadable at the call site; a named `Alphabet` value is
   better.

## 12. Ideas fitting Mojo

Anchored on the Mojo stdlib `base64` package as documented in the `mojov1` buch
(page `mojov1/stdlib/base64`): four functions `b64encode` (three overloads,
including an in-place `mut result: String` overload), `b64decode`, `b16encode`,
`b16decode`; borrowed spans in, fresh `List[UInt8]` out; decoders raise on
malformed input. Source: `mojov1` buch page `stdlib/base64` (whose underlying
sources are <https://mojolang.org/docs/std/base64/base64/> and
<https://mojolang.org/docs/std/base64/base64/b64encode/>).

1. **Borrowed-span input plus fresh output is the right default.** Mojo already
   takes `StringSpan`/`Span[UInt8]` by immutable reference and returns a new
   `List[UInt8]` (buch) — the same stance as Guava's `encode`/`decode` pair.
   Java's extra caller-buffer overload suggests adding a Mojo variant that writes
   into an `out`/`mut` buffer. Source: `mojov1` buch page `stdlib/base64`.
2. **Errors as values via `raises`, not exceptions.** Java's checked/unchecked
   split and Commons Codec's `DecoderException` show the cost of exception
   taxonomies. Mojo's model — `raises` declares the effect, typed errors carry
   structured detail — fits a codec far better; the buch shows the compiler
   enforcing `raises` on every caller. Sources: `mojov1/errors/error-model`,
   `mojov1/keyword-conventions/raises` (the buch's underlying source is
   <https://mojolang.org/docs/manual/errors/>).
3. **A typed decode error.** Commons Codec's `STRICT` policy distinguishes
   "trailing bits not zero" from "impossible final character count". A Mojo
   `struct` error with fields such as `kind` and `symbol_index` implements
   `Writable` and gives callers structured diagnostics. Source:
   `mojov1/errors/error-model`.
4. **Alphabet/padding as compile-time parameters, not runtime flags.** Java needs
   a builder (`setEncodeTable`, `useHex`) or factory method per variant; Mojo's
   value parameters (`[alphabet: Alphabet, padded: Bool]`) specialize at compile
   time, removing branches. Sources: `mojov1/functions/parameters-and-generics`
   (underlying source <https://mojolang.org/docs/manual/generics/>).
5. **Explicit case policy, adopting Guava's `ignoreCase()` as an enum.** Guava is
   the only Java library that exposes case; model it as `Case { Upper, Lower,
   Mixed }` (Elixir's `:case` is the direct precedent, §Elixir `elixir.md` §7).
   Source: Guava `BaseEncoding`.
6. **Streaming via a typed state struct with a documented carry.** Commons
   Codec's `BaseNCodec` context and Bouncy Castle's `Buffered*` keep the partial
   block in an object; a Mojo struct can hold the 0–4 leftover input bytes /
   up-to-7 leftover symbols and document the flush contract; its
   `deinit`/`__del__` should flush. Sources: `BaseNCodec`,
   `org.bouncycastle.util.encoders` package summary, `mojov1/lifecycle/death`.
7. **No `Object`/type-erased bridge.** Mojo is statically typed; skip Commons
   Codec's `encode(Object)`/`Decoder` interfaces entirely. Source:
   `mojov1/interop/migration-from-python`.
8. **Base32 belongs in the library, since neither the JDK nor Mojo's stdlib has
   it.** The JDK has no `Base32` class; Guava (`base32`, `base32Hex`), Commons
   Codec (`Base32`) and Bouncy Castle (`Base32`) all have one. (Sources:
   `java.util` package summary; the three library APIs; `mojov1/stdlib/base64`.)
9. **Return a size/`getEncodedLength` function.** Commons Codec's
   `getEncodedLength(byte[])` and the buch's advice to "reserve capacity with the
   in-place encoder" both point at exposing `encoded_length(n) -> Int` (for
   base32: `8*ceil(n/5)`) as a pure function. Sources: `BaseNCodec`;
   `mojov1/stdlib/base64`.
10. **Round-trip as the invariant, and immutability of encoders.** Guava
    documents `decode(encode(x)) == x` while warning the reverse need not hold;
    a Mojo config-by-value encoder with a documented round-trip guarantee and an
    explicit canonicality option matches both Guava's guarantee and RFC 4648
    §3.5. Sources: Guava `BaseEncoding`;
    https://www.rfc-editor.org/rfc/rfc4648.txt.

## Sources

JDK:
- `java.util.Base64` (Java 21): <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>
- `java.util.HexFormat`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HexFormat.html>
- `java.util` package summary (shows no Base32): <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html>
- JEP 320: <https://openjdk.org/jeps/320>

Apache Commons Codec:
- `Base32`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>
- `BaseNCodec`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>
- Project home: <https://commons.apache.org/proper/commons-codec/>

Guava:
- `BaseEncoding`: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>
- License (Apache-2.0): <https://github.com/google/guava/blob/master/LICENSE>

Bouncy Castle:
- `Base32`: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base32.html>
- Package summary: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>
- License (MIT): <https://www.bouncycastle.org/about/license/>

Netty (base64 only):
- `Base64`: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>

Other:
- RFC 4648, The Base16, Base32, and Base64 Data Encodings: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- ULID spec (Crockford base32 use case): <https://github.com/ulid/spec>

Mojo (`mojov1` buch):
- Page `mojov1/stdlib/base64` (stdlib package, four functions, signatures)
- Page `mojov1/errors/error-model`
- Page `mojov1/keyword-conventions/raises`
- Page `mojov1/functions/parameters-and-generics`
- Page `mojov1/interop/migration-from-python`
- Page `mojov1/lifecycle/death`
