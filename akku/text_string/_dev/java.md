# string research: Java

Group: managed-JVM. Selected language: Java (JDK 21 / Java SE 21 as the reference
release). All Javadoc citations are to the Java SE 21 API documentation; JEP
numbers link to openjdk.org. Java is the canonical **UTF-16 code-unit** model with
an immutable owned `String`, a mature mutable builder (`StringBuilder` /
`StringBuffer`), and explicit opt-in code-point APIs — but **no dedicated
non-owning string view** and **no grapheme notion on the string type itself**.

## 1. Standard library support

`java.lang.String` is a `final` class implementing `Serializable`,
`CharSequence`, `Comparable<String>`, `Constable` and `ConstantDesc`
([String Javadoc](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/String.html)).
Everything string-adjacent is in `java.base`, so no dependency is needed:
`java.lang` (`String`, `StringBuilder`, `StringBuffer`, `Character`, `Math`),
`java.util` (`Formatter`, `MessageFormat`, `Scanner`, `StringJoiner`),
`java.util.regex` (`Pattern`, `Matcher`), `java.text` (`Collator`, `Normalizer`,
`BreakIterator`), `java.nio.charset` (`Charset`, `CharsetEncoder`,
`CharsetDecoder`, `StandardCharsets`), `java.nio` (`ByteBuffer`, `CharBuffer`).

Core surface on `String` (all cited to the String Javadoc):

- Construction/conversion: `String(char[])`, `String(char[],int,int)`,
  `String(int[] codePoints,int,int)`, `String(byte[], Charset)`,
  `String(StringBuffer)`, `String(StringBuilder)`; `toCharArray()`, `getBytes()`,
  `copyValueOf`, `valueOf`.
- Measurement: `length()`, `isEmpty()`.
- Reading: `charAt(int)`, `getChars(int,int,char[],int)`.
- Slicing: `substring(int)`, `substring(int,int)`, `subSequence(int,int)`.
- Search: `indexOf`, `lastIndexOf` (all return `-1` when absent),
  `contains(CharSequence)`, `startsWith`, `endsWith`, `matches`, `regionMatches`.
- Transform: `replace`, `replaceAll`/`replaceFirst` (regex), `split` (regex),
  `splitWithDelimiters`, `toLowerCase`/`toUpperCase` (with `Locale` overloads),
  `concat`, `repeat`, `strip`/`stripLeading`/`stripTrailing`, `trim`, `indent`,
  `stripIndent`, `translateEscapes`, `transform(Function)`, `formatted`.
- Compare: `equals`, `equalsIgnoreCase`, `compareTo`, `compareToIgnoreCase`,
  static `CASE_INSENSITIVE_ORDER`; `Collator` for locale-sensitive comparison.
- Unicode code-point APIs: `codePointAt`, `codePointBefore`, `codePointCount`,
  `offsetByCodePoints`, `codePoints()`, `chars()`.
- Lines: `lines()` (a `Stream<String>`).
- Composition: static `join(CharSequence, CharSequence...)`, `format`.

Version history that changed this surface (all source-backed):

| release | change | source |
| --- | --- | --- |
| 1.0/1.1 | `String`, `StringBuffer`, `trim`, `getBytes`, charset-name constructors | String Javadoc |
| 1.4/1.5 | `CharSequence`, `subSequence`, code-point methods, `StringBuilder` | Javadoc since-tags |
| 9 | internal representation `char[]` → `byte[]` + coder flag (Compact Strings) | [JEP 254](https://openjdk.org/jeps/254) |
| 9 | `+` concatenation no longer fixed to `StringBuilder` bytecode | [JEP 280](https://openjdk.org/jeps/280) |
| 9 | interned strings shared via CDS archives | [JEP 250](https://openjdk.org/jeps/250) |
| 11 | `strip`/`stripLeading`/`stripTrailing`, `isBlank`, `repeat`, `lines` | Javadoc since-tags |
| 12 | `indent`, `transform` | Javadoc since-tags |
| 15 | `stripIndent`, `translateEscapes`, `formatted`, **Text Blocks** | Javadoc; [JEP 378](https://openjdk.org/jeps/378) |
| 18 | UTF-8 becomes the default charset | [JEP 400](https://openjdk.org/jeps/400) |
| 20 | `BreakIterator` character breaks adopt UAX-29 Extended Grapheme Clusters | [JDK-8292992](https://bugs.openjdk.org/browse/JDK-8292992) |
| 21 | String Templates preview (`STR`, `FMT`, `RAW`, `\{…}`) | [JEP 430](https://openjdk.org/jeps/430) |

(Assessment: derived from the sources above — the stdlib has been *filling the
gaps* that community libraries covered between 2004 and 2021: `strip`/`isBlank`/
`repeat`/`lines`/`indent`/`formatted` replaced long-standing Apache/Guava
workarounds.)

## 2. Relevant community libraries

- **Apache Commons Lang — `StringUtils`**: a `null`-safe static utility bag.
  Its own Javadoc lists the categories: `IsEmpty/IsBlank`, `Trim/Strip`,
  `Equals/Compare`, `startsWith`, `endsWith`, `IndexOf/LastIndexOf/Contains`,
  `Substring/Left/Right/Mid`, `Split/Join`, `Remove/Delete`, `Replace/Overlay`,
  `Chomp/Chop`, `LeftPad/RightPad/Center/Repeat`, case changes,
  `CountMatches`, `LevenshteinDistance`, `Difference`, `Reverse`, `Abbreviate`.
  It defines `INDEX_NOT_FOUND = -1` as a named constant and documents that
  `null` input returns `null` and "a `NullPointerException` should be considered
  a bug in `StringUtils`"
  ([StringUtils Javadoc](https://commons.apache.org/proper/commons-lang/javadocs/api-release/org/apache/commons/lang3/StringUtils.html)).
  (Assessment: this library exists specifically because `String` is not
  `null`-safe and its methods throw `NullPointerException` by default.)
- **Apache Commons Text**: `StringEscapeUtils`, `WordUtils`, `TextStringBuilder`,
  and the similarity package (`LevenshteinDistance`, `JaroWinklerDistance`,
  `FuzzyScore`) — several of these are now *deprecated in Commons Lang* with the
  Javadoc pointing at Commons Text (StringUtils Javadoc deprecation notes).
- **Guava — `com.google.common.base`**: `Strings` (`nullToEmpty`, `emptyToNull`,
  `isNullOrEmpty`, `padStart`, `padEnd`, `repeat`, `commonPrefix`,
  `commonSuffix`, `lenientFormat`); `Splitter` and `Joiner`; `CharMatcher`.
  Notable precision detail: `commonPrefix`/`commonSuffix` are documented as
  "taking care not to split surrogate pairs"
  ([Guava Strings](https://guava.dev/releases/33.0.0-jre/api/docs/com/google/common/base/Strings.html)).
  `Splitter` is the counter-design to `String.split`: an **immutable configured
  object** (`on(char|String|Pattern|CharMatcher)`, `fixedLength`,
  `omitEmptyStrings`, `limit`, `trimResults`) whose configuration methods
  "return a new splitter instance"; it is documented as thread-safe and
  storable as `static final`
  ([Guava Splitter](https://guava.dev/releases/33.0.0-jre/api/docs/com/google/common/base/Splitter.html)).
- **ICU4J (ICU4J / `com.ibm.icu`)**: full Unicode services — rule-based boundary
  analysis (word/line/sentence/character) using rules "similar, but not
  identical, to the boundary rules from the Unicode specifications [UAX-14,
  UAX-29]", plus `Normalizer` and `Collator`
  ([ICU Break Rules](https://unicode-org.github.io/icu/userguide/boundaryanalysis/break-rules.html)).
  `BreakIterator` in `java.text` is the JDK's smaller, locale-pluggable version
  of the same idea (BreakIterator Javadoc).

## 3. Exposed APIs

`String` (Javadoc, method detail): `length`, `isEmpty`, `charAt`, `getChars`,
`substring`, `subSequence`, `indexOf`, `lastIndexOf`, `contains`, `startsWith`,
`endsWith`, `regionMatches`, `replace`, `replaceAll`, `replaceFirst`, `split`,
`splitWithDelimiters`, `toLowerCase`, `toUpperCase`, `concat`, `repeat`,
`strip`, `stripLeading`, `stripTrailing`, `trim`, `indent`, `stripIndent`,
`translateEscapes`, `transform`, `formatted`, `equals`, `equalsIgnoreCase`,
`compareTo`, `compareToIgnoreCase`, `contentEquals`, `matches`, `codePointAt`,
`codePointBefore`, `codePointCount`, `offsetByCodePoints`, `chars`,
`codePoints`, `lines`, static `join`, static `format`, `intern`, `toCharArray`,
`getBytes`, `valueOf`.

`StringBuilder` (StringBuilder Javadoc) is the mutable counterpart:
`append(...)` overloads for `boolean/char/char[]/double/float/int/long/Object/
String/StringBuffer/CharSequence`, `appendCodePoint(int)`, `insert(...)`
overloads, `delete(int,int)`, `deleteCharAt(int)`, `replace(int,int,String)`,
`reverse()`, `setCharAt(int,char)`, `setLength(int)`, `capacity()`,
`ensureCapacity(int)`, `trimToSize()`, `indexOf`/`lastIndexOf`,
`substring`/`subSequence`, `toString()`, plus the same code-point and
`chars`/`codePoints` methods as `String`, and `repeat(int,int)` /
`repeat(CharSequence,int)`.

`CharSequence` (CharSequence Javadoc) is the read-only interface:
`length()`, `charAt(int)`, `subSequence(int,int)`, `chars()`, `codePoints()`,
`isEmpty()` (default since 15, `length() == 0`), `toString()`, and static
`CharSequence.compare(cs1,cs2)` (since 11). Known implementors: `String`,
`StringBuffer`, `StringBuilder`, `CharBuffer`, `javax.swing.text.Segment`.

Supporting APIs: `Character` (per-code-point classification: `isLetter`,
`isWhitespace`, `toLowerCase(int)`, `toUpperCase(int)`, `charCount(int)`,
`toCodePoint(char,char)`), `Charset`/`CharsetDecoder`/`CharsetEncoder`,
`BreakIterator` factory methods (`getCharacterInstance`, `getWordInstance`,
`getLineInstance`, `getSentenceInstance`, each with a `Locale` overload),
`Normalizer`, `Collator`.

## 4. Error representation

Java uses **unchecked exceptions** for programming errors and a small number of
**checked exceptions** for environment failures. Exact throws clauses
(Javadocs):

- `IndexOutOfBoundsException` — `charAt` (negative or `>= length()`),
  `substring`, `subSequence`, `codePointAt`, `codePointBefore`, `codePointCount`,
  `offsetByCodePoints`.
- `StringIndexOutOfBoundsException` (a subclass of `IndexOutOfBoundsException`)
  — `StringBuilder.delete`, `deleteCharAt`, `replace(int,int,String)`,
  `insert(int, String)` and friends ("if the offset is invalid").
- `IllegalArgumentException` — `String(int[] codePoints, int, int)` "if any
  invalid Unicode code point is found"; `repeat(int)` "if the count is
  negative"; `translateEscapes()` "when an escape sequence is malformed".
- `PatternSyntaxException` — `split(String regex)`,
  `replaceAll`/`replaceFirst` when the regex is invalid.
- `NullPointerException` — the class-level default: "Unless otherwise noted,
  passing a `null` argument to a constructor or method in this class will cause
  a `NullPointerException` to be thrown" (String Javadoc). `String.join` also
  throws `NullPointerException` if delimiter or elements are null.
- `UnsupportedEncodingException` (**checked**) — the deprecated
  `String(byte[], String charsetName)` / `getBytes(String)` forms.
- `NegativeArraySizeException` — `StringBuilder(int capacity)` if capacity < 0.

Byte ↔ text decode errors have a richer, policy-based representation:
`CharsetDecoder` documents two error types — *malformed* input (not legal for
the charset) and *unmappable character* (legal but not mappable) — and three
actions from `CodingErrorAction`: `IGNORE`, `REPORT`, `REPLACE`. "The default
action for malformed-input and unmappable-character errors is to report them."
The replacement default is `"\uFFFD"`, changeable via `replaceWith`
(CharsetDecoder Javadoc). The convenience path is deliberately lenient:
`String(byte[], Charset)` "always replaces malformed-input and unmappable-
character sequences with this charset's default replacement string", whereas
the deprecated charset-name constructors say "behavior … is unspecified" for
invalid bytes (String Javadoc). `CharsetDecoder.decode(ByteBuffer)` throws
`MalformedInputException` / `UnmappableCharacterException` when the action is
`REPORT`.

(Assessment: derived from the above — Java has no `Result`/`Option` type for
these paths; every failure is an exception or a silent replacement policy, and
`null` is the pervasive out-of-band value, which is exactly why Commons Lang's
`StringUtils` markets itself as `null`-safe.)

## 5. Ownership semantics

`String` is **immutable**: "Strings are constant; their values cannot be changed
after they are created. String buffers support mutable strings. Because String
objects are immutable they can be shared" (String Javadoc). The class is
`final`, so no subclass can weaken that. There is no borrow checker and no
lifetime annotation: ownership is the JVM's garbage collector, and passing a
`String` passes a reference to an immutable object.

Consequences:

- Immutable values are shareable, which makes **interning** sound: `String`
  literals in a class file are `CONSTANT_String_info` entries and are interned;
  JEP 378 states "Two text blocks with the same processed content will refer to
  the same instance of `String` due to interning, just like for string
  literals." `String.intern()` exposes the same canonical table. JEP 250 stores
  interned strings in CDS archives so they can be shared across JVM processes.
- `String` implements `equals`/`hashCode` with **content** semantics, cached
  hash. In contrast `CharSequence` "does not refine the general contracts of the
  `equals` and `hashCode` methods. The result of testing two objects that
  implement `CharSequence` for equality is therefore, in general, undefined"
  (CharSequence Javadoc) — so the *view* interface is not a value type.
- `StringBuilder` is explicitly **not** safe for multiple threads; `StringBuffer`
  is the synchronized legacy sibling ("This class provides an API compatible
  with `StringBuffer`, but with no guarantee of synchronization"; StringBuilder
  Javadoc). Both are mutable owned builders; `toString()` copies the contents
  ("The contents of the string builder are copied", String Javadoc).
- There is **no non-owning string view type**. The closest is the read-only
  `CharSequence` interface, but for `String` even `subSequence` behaves "in
  exactly the same way as the invocation `str.substring(begin, end)`" — i.e. it
  produces an owned result, not a borrow (String Javadoc). `String` is immutable,
  so a borrow would be safe; Java simply never introduced one (Assessment:
  derived from the Javadoc, which offers `CharSequence` as abstraction and
  `substring`/`subSequence` as copies, and lacks any span type).
- GUESS: Since JDK 7 update 6, `substring` copies the backing array instead of
  sharing it (the pre-7u6 sharing leaked large arrays). Reason no source: not
  verified against a fetched primary source in this run; it is documented in
  OpenJDK bug JDK-6857194, not in the API Javadoc.

## 6. Blocking / non-blocking

A Java `String` is a pure in-memory value: no I/O, no blocking, no async state.
Blocking concerns live one layer out, in the byte ↔ text bridge and the I/O
classes:

- `java.io` `Reader`/`Writer`, `InputStreamReader`/`OutputStreamWriter`,
  `FileReader`/`FileWriter`, `PrintStream` are blocking by nature.
- `java.nio` `ByteBuffer`/`CharBuffer` and `Channels` support non-blocking I/O;
  `CharsetEncoder`/`CharsetDecoder` operate on those buffers and are incremental
  ("decode the input buffer … passing `false` for the `endOfInput` argument",
  CharsetDecoder Javadoc).
- The stream APIs on strings — `chars()`, `codePoints()`, `lines()` — are lazy
  but purely in-memory (`IntStream` / `Stream<String>`); "The stream binds to
  this sequence when the terminal stream operation commences … If the sequence
  is modified during that operation then the result is undefined" (CharSequence
  Javadoc).
- Thread-safety, not blocking, is the concurrency axis that touches the string
  types: `CharsetDecoder` "instances … are not safe for use by multiple
  concurrent threads" (CharsetDecoder Javadoc); `StringBuilder` is likewise not
  thread-safe, `StringBuffer` is (StringBuilder Javadoc). `String` is immutable
  and therefore freely shareable across threads.

## 7. Text model (encoding, length, indexing)

**What a "character" is.** Java's base unit is the **16-bit UTF-16 code unit**,
not a codepoint and not a grapheme. "A `String` represents a string in the
UTF-16 format in which supplementary characters are represented by surrogate
pairs … Index values refer to `char` code units, so a supplementary character
uses two positions in a `String`" (String Javadoc). `CharSequence` adds: "A
`char` value represents a character in the *Basic Multilingual Plane (BMP)* or
a surrogate" (CharSequence Javadoc). A Unicode **code point** is an `int`
exposed through the explicit `codePointAt` family; a **grapheme cluster** is not
a unit of `String` at all.

**Encoding.** Three distinct layers:

1. *Language-level string content* is a sequence of `char` code units
   (`String`/`CharSequence` model above).
2. *Internal storage* is an implementation detail. Since Java 9 a `String` is
   "a `byte` array plus an encoding-flag field", storing characters either as
   ISO-8859-1/Latin-1 (one byte per character) or as UTF-16 (two bytes per
   character) depending on contents; "This is purely an implementation change,
   with no changes to existing public interfaces," and "It is not a goal to use
   alternate encodings such as UTF-8 in the internal representation" (JEP 254).
3. *External bytes* use an explicit charset. Since Java 18 the default charset
   is UTF-8: APIs that omit a charset "will behave consistently across all
   implementations, operating systems, locales, and configurations" (JEP 400).
   Class-file string constants use **modified UTF-8**, which differs from
   standard UTF-8: the null character is encoded as two bytes, and only the
   1/2/3-byte forms are recognized — supplementary characters are each encoded
   as a separate three-byte surrogate, so an astral character takes six bytes
   (JVMS §4.4.7, [JVMS ch. 4](https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html#jvms-4.4.7)).

**How length is measured.** `length()` returns "the number of Unicode code units
in the string"; `CharSequence.length()` returns "the number of 16-bit `char`s"
(String/CharSequence Javadoc). `codePointCount(begin,end)` counts code points in
a code-unit range, and a supplementary character at the start of the range
"uses two positions"; "Unpaired surrogates within the text range count as one
code point each". A third measurement — graphemes — is **not** on the type; it
is obtained by iterating `BreakIterator.getCharacterInstance()`, which since
JDK 20 "conforms to Extended Grapheme Cluster breaks defined in Unicode
Standard Annex #29" (JDK-8292992, [UAX-29](https://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries)).

**How indexing/slicing defines a position.** Every index in the base API is a
**code-unit offset**. `charAt(i)` returns the code unit; "If the `char` value
specified by the index is a surrogate, the surrogate value is returned."
`substring(begin,end)` selects `[begin, end)` in code units: "the substring
begins at the specified `beginIndex` and extends to the character at index
`endIndex - 1`. Thus the length of the substring is `endIndex-beginIndex`."
Code-point navigation is opt-in: `offsetByCodePoints(index, codePointOffset)`
"returns the index within this `String` that is offset from the given `index` by
`codePointOffset` code points" (all String Javadoc). `chars()` streams code units
("Any char which maps to a surrogate code point is passed through
uninterpreted"), `codePoints()` streams codepoints ("surrogate pairs … are
combined as if by `Character.toCodePoint`").

**Comparison.** `compareTo` "is based on the Unicode value of each character in
the strings" (i.e. on code-unit numeric order), lexicographic; differing at
index `k` returns `charAt(k) - other.charAt(k)`, else `length() - other.length()`.
`compareToIgnoreCase` folds via `Character.toLowerCase(Character.toUpperCase(int))`
per code point. Locale-aware ordering is separate (`Collator`).

**Normalization.** Not automatic. `java.text.Normalizer` (NFC/NFD/NFKC/NFKD) is
a separate API; `String` never normalizes on construction or comparison
(Assessment: derived from the API layout — normalization lives in `java.text`
and is not referenced by any `String` equality/compare contract).

## 8. Bounds, invalid input and errors

Exact, source-backed rules:

- **Out-of-range index** → `IndexOutOfBoundsException`. `charAt`: "An index
  ranges from `0` to `length() - 1`"; throws "if the `index` argument is
  negative or not less than the length of this string." `substring(begin)`:
  throws if `beginIndex` is negative or larger than `length()`;
  `substring(begin,end)`: throws if `beginIndex` is negative, `endIndex` larger
  than `length()`, or `beginIndex > endIndex`. `codePointAt`: index `0 …
  length()-1`. `codePointBefore`: index `1 … length()`.
- **Slicing on a non-boundary is defined, not an error.** Because indices are
  code units, `substring` may cut a surrogate pair or split any multi-unit
  sequence; Java does not refuse it. `charAt` explicitly returns the lone
  surrogate. The result may be a string that is not well-formed Unicode. There
  is no boundary check outside `BreakIterator.isBoundary`.
- **Mutating at a supplementary character** is a documented trap:
  `StringBuilder.deleteCharAt` "does not remove the entire character. If correct
  handling of supplementary characters is required, determine the number of
  `char`s to remove by calling
  `Character.charCount(thisSequence.codePointAt(index))`" (StringBuilder
  Javadoc).
- **Invalid UTF-8/encoding on input**: `String(byte[], Charset)` replaces
  malformed and unmappable sequences with the charset's replacement string
  (default `U+FFFD`); the deprecated charset-name constructors have
  **unspecified** behavior for invalid bytes; `CharsetDecoder` with
  `CodingErrorAction.REPORT` throws `MalformedInputException` /
  `UnmappableCharacterException`. Invalid code points passed to
  `String(int[] codePoints, int, int)` throw `IllegalArgumentException`.
- **Empty / zero-length edges** are consistently defined: `isEmpty()` ⇔
  `length() == 0`; `repeat`: "If this string is empty or count is zero then the
  empty string is returned" (negative count throws `IllegalArgumentException`);
  `strip`/`isBlank` treat an all-whitespace string as empty-equivalent;
  `lines()`: "an empty string has zero lines and … there is no empty line
  following a line terminator at the end of a string"; `indexOf("")` is `0` and
  `lastIndexOf("")` is `length()` ("The last occurrence of the empty string ""
  is considered to occur at the index value `this.length()`").
- **`split` empties**: by default `split(String regex)` uses limit 0, so
  "Trailing empty strings are therefore not included in the resulting array";
  a negative limit keeps them, a positive limit caps the field count (String
  Javadoc).

## 9. Owned type, borrowed view and builder layer

Java splits the three roles **unevenly**:

| role | Java type(s) | notes |
| --- | --- | --- |
| owned value | `java.lang.String` | `final`, immutable, UTF-16 code-unit model; content `equals`/`hashCode` |
| borrowed view | **none dedicated** | only the read-only `CharSequence` interface; `subSequence` returns an owned result for `String` |
| builder | `StringBuilder` (1.5), `StringBuffer` (1.0, synchronized) | mutable, append/insert, explicit capacity |
| byte ↔ text bridge | `java.nio.charset.Charset`/`CharsetEncoder`/`CharsetDecoder` + `getBytes`/`new String(byte[], Charset)` | policy-based errors; `StandardCharsets` constants |

**The view role is the gap.** `CharSequence` is an *interface for read-only
access* across many implementations, not a borrowed slice of a `String`:
"provides uniform, read-only access to many different kinds of `char`
sequences" (CharSequence Javadoc), implementors include `String`,
`StringBuilder`, `StringBuffer`, `CharBuffer` and Swing's `Segment`. It carries
`length`, `charAt`, `subSequence`, `chars`, `codePoints`, `isEmpty` and
`toString` — but no zero-copy span type, and no `equals` contract.
`String.subSequence` is documented as behaving exactly like `substring`, so the
view-shaped method returns owned data. At the *byte* level the NIO
`ByteBuffer`/`CharBuffer` do provide a position/limit/slice view over a backing
buffer, and `CharBuffer.wrap` can present a `char[]`/`CharSequence` as a
`CharSequence`.

**The builder role is mature and is Java's strongest string asset.**
`StringBuilder`'s principal operations "are the `append` and `insert` methods,
which are overloaded so as to accept data of any type"; `append` adds at the
end, `insert` at a position, and `sb.append(x)` ≡ `sb.insert(sb.length(), x)`.
"Every string builder has a capacity. As long as the length of the character
sequence … does not exceed the capacity, it is not necessary to allocate a new
internal buffer. If the internal buffer overflows, it is automatically made
larger." Capacity is controllable via `capacity()`, `ensureCapacity(int)` and
`trimToSize()`, and `StringBuilder` gained the same code-point methods as
`String` (`appendCodePoint`, `codePointAt`, `offsetByCodePoints`, `repeat`).
Since Java 9 "String-related classes such as `AbstractStringBuilder`,
`StringBuilder`, and `StringBuffer` will be updated to use the same
representation" as compact strings (JEP 254).

**The byte ↔ text bridge** is explicit and charset-parameterised: the
constructors `String(byte[], Charset)` / `String(byte[], int, int, Charset)`,
`getBytes(Charset)`, and the engine classes `CharsetEncoder`/`CharsetDecoder`
with `CodingErrorAction` (IGNORE/REPORT/REPLACE) and a configurable replacement
string. `StandardCharsets` provides `UTF_8`, `US_ASCII`, `ISO_8859_1`,
`UTF_16`, etc. Charset is mandatory for correctness; omitting it uses the
default charset, which is UTF-8 since Java 18 (JEP 400).

## 10. Interesting design decisions

1. **A code-unit model frozen in 1995.** Java chose UTF-16 when Unicode was
   16-bit; when Unicode grew past the BMP, the surrogate-pair layer was added
   *under* the existing `char` index rather than changing `length()`/`charAt`.
   This kept source compatibility and created the same "length trap" as
   JavaScript (Assessment: derived from the String Javadoc's surrogate
   explanation plus the version history).
2. **Two index spaces on one type, with code points opt-in.** `length`/`charAt`/
   `substring` think in code units; `codePointCount`/`offsetByCodePoints`/
   `codePoints()` think in code points; `chars()` vs `codePoints()` exposes the
   distinction as two streams. The Javadoc makes the contract explicit rather
   than hiding it.
3. **Immutable value + mutable builder split**, plus interned literals and an
   explicit `intern()`. Immutability is what makes sharing and interning sound.
4. **`CharSequence` abstraction without a value contract.** Deliberately not a
   value type: "It is therefore inappropriate to use arbitrary `CharSequence`
   instances as elements in a set or as keys in a map." This is the honest
   admission that the view layer cannot carry equality.
5. **Compact Strings.** An implementation-only change (byte[] + coder flag,
   Latin-1 or UTF-16) that preserves every public contract and explicitly
   rejects UTF-8 internally (JEP 254) — the internal/text model is decoupled
   from the language model.
6. **Indify string concatenation.** `+` is no longer hard-wired to a
   `StringBuilder` chain; `javac` emits `invokedynamic` to
   `StringConstantFactory` (JEP 280), so concatenation can be optimised without
   recompiling user code.
7. **`split` is regex-based and drops trailing empties by default** — a
   documented but famously surprising default (String Javadoc). Guava's
   `Splitter` and Commons Lang's `StringUtils.split` are the corrective designs.
8. **`trim` vs `strip` as an API-migration case study.** `trim` removes "any
   character whose codepoint is less than or equal to `'U+0020'`"; `strip`
   removes `Character.isWhitespace(int)` whitespace. Java added the correct
   definition in 11 (`strip`) and kept the wrong one for compatibility — a
   deliberate non-breaking fix.
9. **Text Blocks as compile-time processing**, not a new type: content is
   LF-normalised, incidental indentation is stripped by a specified algorithm,
   escapes are interpreted last, and the same algorithm is exposed at runtime as
   `stripIndent()`/`translateEscapes()`; new escapes `\s` (a space) and
   `\<line-terminator>` (suppress newline) were added (JEP 378).
10. **String Templates (JEP 430) make interpolation *safe by construction*.**
    There is no implicit interpolation; a template processor must be named
    (`STR."…"`, `FMT."…"`, `RAW."…"`), embedded expressions use `\{…}`, and the
    design "deliberately makes it impossible to go directly from a string
    literal or text block with embedded expressions to a `String` with the
    expressions' values interpolated" — explicitly to avoid SQL-injection-style
    bugs. Only `String`, not the template object, is `java.lang.String`.
11. **`compareTo` returns a difference, `indexOf` returns `-1`.** Both are
    conventions with real ergonomic cost (callers must compare signs, not
    values); Commons Lang names `-1` as `INDEX_NOT_FOUND`.
12. **Case mapping and collation are locale concerns split off the type.**
    `toLowerCase()`/`toUpperCase()` without a `Locale` use the default locale;
    `compareToIgnoreCase` is explicitly locale-insensitive and "will result in
    an unsatisfactory ordering for certain locales"; `Collator` exists for real
    ordering.

## 11. Decisions NOT to copy

- **UTF-16 code-unit indexing.** Mojo is UTF-8 (`README.md`), so reproducing
  `length`/`charAt`/`substring` in Java's code-unit semantics would recreate the
  surrogate-pair machinery and the "length trap" for no benefit. Use Mojo's
  explicit `byte_length` / `count_codepoints` / `count_graphemes` instead
  (README.md). `(Assessment: derived from the UTF-16 code-unit model in the
  String Javadoc and the UTF-8 positioning fact in README.md.)`
- **No borrowed view.** Java's lack of a `&str`-style span forces either copies
  or the contract-free `CharSequence` abstraction. Mojo already has
  `StringSpan`/`StaticString`/`StringLiteral`; keep a real view layer (README.md).
- **Split equality contract.** `String` has content `equals`, `CharSequence`
  says equality is "undefined", and `StringBuilder` is `Comparable` but does not
  override `equals` ("the natural ordering of `StringBuilder` is inconsistent
  with equals", StringBuilder Javadoc). Do not let equality be defined on some
  text types and undefined on others.
- **`split(String regex)` default with trailing-empty removal.** Regex coupling
  plus an implicit empty-string policy is a long-standing surprise. Prefer an
  explicit, non-regex split with a limit and an explicit empty policy (Guava
  `Splitter` model).
- **`trim()`'s `<= U+0020` definition.** Copy the *correct* `strip` semantics
  (Unicode `isWhitespace`) from the start; do not ship a legacy-broken version
  and fix it a decade later.
- **`null` as a valid string value.** Pervasive null means every method needs a
  `null` policy and spawned `StringUtils`/`Strings`. Mojo has no null; a text
  library should not reintroduce an out-of-band empty/absent encoding.
- **Defined production of lone surrogates.** `substring`/`charAt` are allowed to
  yield malformed UTF-16 halves. A UTF-8 library should instead make boundary
  behaviour explicit — refuse, or return a well-defined lossy result.
- **Checked `UnsupportedEncodingException` and "unspecified" malformed-input
  behaviour** in some convenience constructors. Prefer the decoder model:
  charset is a required parameter, and the error policy
  (`from_utf8_lossy` vs strict) is explicit (README.md already frames Mojo this
  way).
- **`String.format`/`printf` with default-locale coupling and arity unsafety.**
  Mojo's `TString` (`t"…"`) is lazy and preferred (README.md); copy that intent,
  not Java's formatter.
- **Process-wide mutable interning.** `intern()` mutates a global canonical
  table; convenient for a JVM, wrong for a library's ownership story (JEP 250,
  `intern()` Javadoc).
- **`StringBuilder` as a thread-unsafe default with a separate synchronized
  `StringBuffer`.** Do not carry two near-identical builders forward; state one
  contract.

## 12. Ideas fitting Mojo

- **Mirror the owned/view/builder triad explicitly, and add the piece Java
  lacks.** Java's `String` ↔ Mojo `String`, Java's missing span ↔ Mojo
  `StringSpan`, Java's `StringBuilder` ↔ a Mojo builder (README.md notes `std`
  may lack one — Java's append/insert/capacity contract is the reference).
- **Keep measurement explicit by naming, not by a single `len`.** Java forces
  the caller to remember `length()` (code units) vs `codePointCount` (code
  points) vs `BreakIterator` (graphemes). Mojo already names them
  `byte_length`/`count_codepoints`/`count_graphemes` (README.md); that is
  strictly clearer and should stay.
- **Offer lower-level views as separate iterators, not overloaded indexing.**
  Java's `chars()` vs `codePoints()` is the right idea; Mojo's
  `codepoints()`, `codepoint_slices()` and `bytes()` are the analogue
  (README.md). Keep the base index model unambiguous (bytes/codepoints) and
  expose each projection explicitly.
- **A policy enum for the byte ↔ text bridge.** `CharsetDecoder`'s
  `CodingErrorAction` {IGNORE, REPORT, REPLACE} plus a configurable replacement
  string is a clean, testable contract that maps directly onto Mojo's
  `from_utf8_lossy` (replace) vs strict construction (report) (README.md).
- **A builder with an explicit capacity/flush contract.** Adopt `StringBuilder`'s
  `capacity`/`ensureCapacity`/`trimToSize` and the `append`/`insert` split; make
  the ownership boundary (`toString`/`finish` copies and consumes) explicit.
- **An immutable splitter/finder configuration object instead of regex
  `split`.** Guava `Splitter` (immutable, `on`, `omitEmptyStrings`, `limit`,
  `trimResults`) is the ergonomic target; Guava `Strings.commonPrefix/
  commonSuffix` (surrogate-safe) and `padStart`/`padEnd` are good candidates.
- **A boundary-iterator type for word/line/sentence/grapheme boundaries.**
  `BreakIterator` shows the correct separation: grapheme logic belongs in a
  dedicated boundary API, not inside the string type, and should follow UAX-29
  (JDK-8292992, UAX-29). Mojo's grapheme iteration could grow such an iterator
  cleanly.
- **Whitespace and case by Unicode property, with the Unicode version pinned.**
  `strip`/`isBlank` (Unicode `isWhitespace`) and `Character`'s Unicode-version
  based case mapping (String Javadoc notes "Case mapping is based on the Unicode
  Standard version specified by the `Character` class") are the right model;
  pin and document the Unicode data version.
- **Text munging as a small, well-scoped set.** `lines()`, `indent(n)`,
  `stripIndent()`, `translateEscapes()` are high-value, narrowly specified
  operations worth mirroring — and Java's text-block algorithm is a precise
  specification to reuse.
- **Lazy formatting instead of eager `format`.** Java's `formatted`/`format`
  are eager and locale-coupled; Mojo's lazy `TString` is the better target
  (README.md). Templates (JEP 430) show the safety value of requiring an
  explicit processor rather than implicit interpolation — a principle worth
  keeping even if the syntax differs.
- **Normalization as a separate concern.** `Normalizer` (NFC/NFD/NFKC/NFKD)
  living outside `String` is the right layering; keep normalization opt-in and
  out of constructors and equality.

## Sources

- Oracle, `java.lang.String` (Java SE 21 API):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/String.html
- Oracle, `java.lang.StringBuilder` (Java SE 21 API):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/StringBuilder.html
- Oracle, `java.lang.CharSequence` (Java SE 21 API):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/CharSequence.html
- Oracle, `java.nio.charset.CharsetDecoder` (Java SE 21 API):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/charset/CharsetDecoder.html
- Oracle, `java.text.BreakIterator` (Java SE 21 API):
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/text/BreakIterator.html
- Oracle, JVMS chapter 4, §4.4.7 `CONSTANT_Utf8_info` (modified UTF-8):
  https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html#jvms-4.4.7
- JEP 254, Compact Strings: https://openjdk.org/jeps/254
- JEP 250, Store Interned Strings in CDS Archives: https://openjdk.org/jeps/250
- JEP 280, Indify String Concatenation: https://openjdk.org/jeps/280
- JEP 378, Text Blocks: https://openjdk.org/jeps/378
- JEP 400, UTF-8 by Default: https://openjdk.org/jeps/400
- JEP 430, String Templates (Preview): https://openjdk.org/jeps/430
- OpenJDK JDK-8292992, Release Note: Grapheme Support in BreakIterator:
  https://bugs.openjdk.org/browse/JDK-8292992
- Unicode Consortium, UAX-29, Grapheme Cluster Boundaries:
  https://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries
- Apache Commons Lang `StringUtils` Javadoc:
  https://commons.apache.org/proper/commons-lang/javadocs/api-release/org/apache/commons/lang3/StringUtils.html
- Guava `com.google.common.base.Strings` Javadoc:
  https://guava.dev/releases/33.0.0-jre/api/docs/com/google/common/base/Strings.html
- Guava `com.google.common.base.Splitter` Javadoc:
  https://guava.dev/releases/33.0.0-jre/api/docs/com/google/common/base/Splitter.html
- ICU User Guide, Break Rules (UAX-14/UAX-29 rule model):
  https://unicode-org.github.io/icu/userguide/boundaryanalysis/break-rules.html
- MojoAkku frozen run configuration: `akku/text_string/_dev/README.md`
