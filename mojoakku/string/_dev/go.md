# string research: Go

## 1. Standard library support

Go's string support is split across the language core and a small set of
standard packages; there is no single `String` type with methods.

- The `string` type is built into the language: "A string type represents the
  set of string values. A string value is a (possibly empty) sequence of
  bytes. The number of bytes is called the length of the string and is never
  negative. Strings are immutable: once created, it is impossible to change
  the contents of a string." — <https://go.dev/ref/spec#String_types>
- `byte` is an alias for `uint8` and `rune` is an alias for `int32`; `rune`
  is used for a Unicode code point — <https://go.dev/ref/spec#Numeric_types>
- `len(s)` is a built-in returning the byte length; `s[i]` with `0 <= i <
  len(s)` reads the i'th byte; taking the address of a byte in a string
  (`&s[i]`) is illegal — <https://go.dev/ref/spec#String_types>
- The `strings` package "implements simple functions to manipulate UTF-8
  encoded strings", including `Index`, `Split`, `Join`, `Replace`, `Trim`,
  `ToLower`/`ToUpper`, `HasPrefix`/`HasSuffix`, `Compare`, `Cut*`, `Clone`,
  and the `Builder` type — <https://pkg.go.dev/strings>
- `unicode/utf8` provides the byte↔rune primitives: `DecodeRune`,
  `DecodeRuneInString`, `EncodeRune`, `RuneCountInString`, `Valid`,
  `ValidString`, `RuneStart`, `FullRune`, `AppendRune` —
  <https://pkg.go.dev/unicode/utf8>
- `unicode` provides the category predicates (`IsSpace`, `IsLetter`,
  `IsNumber`, `IsDigit`, `Is(unicode.Han, r)`) used by the `*Func` variants
  — see examples in <https://pkg.go.dev/strings>

`strings.Builder` (since Go 1.10) is the incremental construction type. Its
methods are `Write`, `WriteByte`, `WriteRune`, `WriteString`, `String`,
`Grow`, `Reset`, `Len`, `Cap`. — <https://pkg.go.dev/strings#Builder>

## 2. Relevant community libraries

The Go team's own supplementary text module is `golang.org/x/text`. It is a
module of packages "related to internationalization (i18n) and localization
(l10n), such as character encodings, text transformations, and locale-specific
text handling" and contains:

- `encoding` — converters to/from UTF-8 (Shift JIS, Windows-1252, GBK, Big5,
  EUC-JP, UTF-16, UTF-32, …)
- `unicode/norm` — Unicode normalization
- `cases` — general and language-specific case mappers (beyond ASCII/simple
  Unicode case folding)
- `collate` — language-aware sorting/comparison
- `search` — language-specific string matching
- `width` — East Asian character widths
- `secure/precis` — PRECIS internationalized-string preparation (RFC 8264)
- `runes` — transforms for UTF-8 text
- `transform` — reader/writer wrappers

Source: <https://pkg.go.dev/golang.org/x/text>

`rivo/uniseg` (grapheme-cluster / word / sentence segmentation per UAX #29)
is a widely used third-party option, because the standard library has no
grapheme iterator. `GUESS:` no fetchable authoritative page was retrieved for
this run; the claim rests on the package's public repository
(`github.com/rivo/uniseg`), not on a cited doc page.

There is no widely adopted third-party owned-string replacement: the built-in
`string` plus `strings` covers the mainstream need. `GUESS:` this is an
assessment from the shape of the ecosystem, not a sourced survey.

## 3. Exposed APIs

The idiomatic Go surface is **free functions over `string`**, not methods:

- Search: `strings.Index`, `LastIndex`, `IndexByte`, `IndexRune`, `IndexAny`,
  `IndexFunc`, `Contains`, `ContainsAny`, `ContainsRune`, `ContainsFunc`,
  `Count`, `Find`-equivalents. `Index` returns a **byte index** or `-1` —
  <https://pkg.go.dev/strings#Index>
- Split/join: `Split`, `SplitN`, `SplitAfter`, `SplitAfterN`, `SplitSeq`,
  `Fields`, `FieldsFunc`, `FieldsSeq`, `Cut`, `CutLast`, `CutPrefix`,
  `CutSuffix`, `Join` — <https://pkg.go.dev/strings>
- Replace: `Replace(s, old, new, n)` and `ReplaceAll`; if `old` is empty it
  matches at the start and after each UTF-8 sequence; `n < 0` means no limit —
  <https://pkg.go.dev/strings#Replace>
- Trim: `Trim`, `TrimLeft`, `TrimRight`, `TrimPrefix`, `TrimSuffix`,
  `TrimSpace`, `TrimFunc`, `TrimLeftFunc`, `TrimRightFunc` —
  <https://pkg.go.dev/strings>
- Case: `ToLower`, `ToUpper`, `ToTitle`, `Title` (deprecated), plus
  `*Special` locale variants and `EqualFold` (simple Unicode case-folding;
  `EqualFold("ß","ss")` is `false`) — <https://pkg.go.dev/strings#EqualFold>
- Comparison: operators `==`, `<`, `>`; `strings.Compare(a,b)` returns
  `-1/0/+1` for three-way compare — <https://pkg.go.dev/strings#Compare>
- Encoding repair: `strings.ToValidUTF8(s, replacement)` —
  <https://pkg.go.dev/strings#ToValidUTF8>
- Byte/rune primitives: `s[i]` yields a `byte`; a `for range` loop over a
  string decodes one UTF-8 rune per iteration and yields the **byte offset**
  of each rune as the index — <https://go.dev/blog/strings>
- Conversion views: `[]byte(s)`, `[]rune(s)`, `string(b)`, `string(r)` —
  <https://go.dev/ref/spec#Conversions>

`strings.Builder` exposes `Write`/`WriteByte`/`WriteRune`/`WriteString`/
`String`/`Grow`/`Reset`/`Len`/`Cap`.
— <https://pkg.go.dev/strings#Builder>

## 4. Error representation

Go has **no error type for text**. Invalid UTF-8 is a normal, representable
state, not an exception:

- A string may contain arbitrary bytes and is not required to be UTF-8:
  "only string literals are UTF-8. … string *values* can contain arbitrary
  bytes." — <https://go.dev/blog/strings>
- UTF-8 validation is a query, not an error: `utf8.Valid(b) bool` /
  `utf8.ValidString(s) bool` — <https://pkg.go.dev/unicode/utf8#Valid>
- Decoding never fails: `utf8.DecodeRuneInString` returns
  `(RuneError, 1)` on invalid input; on an empty string it returns
  `(RuneError, 0)`. `RuneError` is `'\uFFFD'` —
  <https://pkg.go.dev/unicode/utf8#DecodeRuneInString>
- Encoding out-of-range runes never fails: `utf8.EncodeRune` writes the
  encoding of `RuneError` when the rune is out of range —
  <https://pkg.go.dev/unicode/utf8#EncodeRune>
- "Not found" is signalled by a sentinel value, not an error: `Index` and
  friends return `-1` — <https://pkg.go.dev/strings#Index>
- Out-of-range **indexing/slicing is a run-time panic**, not an error value:
  "If the index is out of range at run time, a run-time panic occurs." —
  <https://go.dev/ref/spec#Index_expressions>
- `strings.Repeat` documents a panic "if count is negative or if the result
  of (len(s) * count) overflows" — <https://pkg.go.dev/strings#Repeat>

## 5. Ownership semantics

- A string value is an immutable **header** — pointer + length — copied by
  assignment, with the backing bytes shared and not tracked by lifetimes.
  It is exactly a read-only `[]byte` analogue — <https://go.dev/blog/strings>
- Mutability is expressed by *converting*: `[]byte(s)` and `[]rune(s)` are
  copies (conversions allocate new backing slices), and `string(b)` copies
  back — <https://go.dev/ref/spec#Conversions>. `(Assessment: derived from
  the spec's conversion rules and from the immutability of string.)`
- Because a string is a view, a small substring keeps the whole backing
  allocation alive. `strings.Clone` exists to force a copy "when retaining
  only a small substring of a much larger string" —
  <https://pkg.go.dev/strings#Clone>
- Reclamation is by the garbage collector; there is no borrow checker, no
  lifetime annotations and no ownership transfer of the backing bytes.
  `(Assessment: derived from Go's documented GC + value-copy model.)`

## 6. Blocking / non-blocking

Text primitives in `strings` / `unicode/utf8` are pure, in-memory,
allocation-oriented functions with no I/O and no blocking semantics.
`(Assessment: derived from the function signatures in
<https://pkg.go.dev/strings> and <https://pkg.go.dev/unicode/utf8>, all of
which take and return in-memory values.)`

The only streaming type in the package is `strings.Reader` (a read-only,
seekable in-memory reader satisfying `io.Reader`/`io.Seeker`/`io.RuneReader`);
blocking is determined by the caller's I/O layer, not by the string type —
<https://pkg.go.dev/strings#Reader>

## 7. Text model (encoding, length, indexing)

**Go's string is a byte container, conventionally UTF-8, not a character
type.**

- A string "holds *arbitrary* bytes. It is not required to hold Unicode text,
  UTF-8 text, or any other predefined format. As far as the content of a
  string is concerned, it is exactly equivalent to a slice of bytes." —
  <https://go.dev/blog/strings>
- Source code is defined to be UTF-8, so literals (absent byte-level escapes)
  hold valid UTF-8, but that is a property of literals only —
  <https://go.dev/blog/strings>
- Length: `len(s)` counts **bytes** — <https://go.dev/ref/spec#String_types>;
  `utf8.RuneCountInString(s)` counts **code points** —
  <https://pkg.go.dev/unicode/utf8#RuneCountInString>. There is no stdlib
  grapheme count.
- What a "character" is: Go defines `rune` = Unicode code point, but does
  **not** promise normalization: "No guarantee is made in Go that characters
  in strings are normalized." — <https://go.dev/blog/strings>
- Grapheme clusters are *not* a stdlib unit; segmentation lives in
  `rivo/uniseg` (community) or `golang.org/x/text` (words/sentences).
- Indexing: `s[i]` is the i'th **byte**; a `for range` over a string decodes
  runes and reports each rune's starting **byte position** —
  <https://go.dev/blog/strings>
- Slice expressions `s[i:j]` operate on byte offsets and are legal at any
  byte boundary (they can split a rune) — `(Assessment: derived from the
  byte-slice nature of string and the general slice rules in
  <https://go.dev/ref/spec#Slice_expressions>.)`
- The dual views are explicit conversions: `[]byte(s)` (bytes) and
  `[]rune(s)` (code points) — <https://go.dev/ref/spec#Conversions>

## 8. Bounds, invalid input and errors

| Case | Behaviour | Source |
| --- | --- | --- |
| `s[i]` with `i < 0` or `i >= len(s)` | run-time panic | <https://go.dev/ref/spec#Index_expressions> |
| `s[i:j]` out of range | run-time panic | <https://go.dev/ref/spec#Index_expressions> |
| `s[i:j]` on a non-rune byte boundary | **defined**, no panic; may yield invalid UTF-8 | `(Assessment: derived from byte indexing + no boundary check in string slicing.)` |
| invalid UTF-8 in a string | allowed by design; not an error | <https://go.dev/blog/strings> |
| `DecodeRuneInString` on invalid bytes | returns `(RuneError, 1)` | <https://pkg.go.dev/unicode/utf8#DecodeRuneInString> |
| `DecodeRuneInString` on `""` | returns `(RuneError, 0)` | <https://pkg.go.dev/unicode/utf8#DecodeRuneInString> |
| `for range` over invalid UTF-8 | yields one `U+FFFD` (width 1) and advances one byte | `(Assessment: range is defined to match `DecodeRuneInString`; <https://go.dev/blog/strings>.)` |
| `RuneCount` on erroneous/short encodings | each counts as a single width-1 rune | <https://pkg.go.dev/unicode/utf8#RuneCount> |
| `EncodeRune` out-of-range rune | writes `U+FFFD` encoding | <https://pkg.go.dev/unicode/utf8#EncodeRune> |
| substring not found | `-1` sentinel | <https://pkg.go.dev/strings#Index> |
| `strings.Repeat` negative/overflow | panic | <https://pkg.go.dev/strings#Repeat> |
| empty string edges | `len("")==0`; `Split("", sep)=[""]` for non-empty sep; `Contains("","")` is `true`; `HasPrefix(s,"")` is `true` | <https://pkg.go.dev/strings> |

`utf8.MaxRune = '\U0010FFFF'`, `utf8.UTFMax = 4`, `utf8.RuneSelf = 0x80`,
`utf8.RuneError = '\uFFFD'` are the encoding bounds —
<https://pkg.go.dev/unicode/utf8#pkg-constants>

## 9. Owned type, borrowed view and builder layer

- **Owned type:** `string`. Despite being immutable, it is the owned value
  (copied header, shared bytes; GC-managed). `strings.Clone` forces private
  storage — <https://pkg.go.dev/strings#Clone>
- **Borrowed view:** `string` itself *is* the view; there is no separate
  span/view type. The alternative views are conversions to `[]byte` / `[]rune`
  (copies). `(Assessment: derived from <https://go.dev/ref/spec#Conversions>
  and the absence of any span type in <https://pkg.go.dev/strings>.)`
- **Builder layer:** `strings.Builder` — explicit incremental construction
  with `Write*`, `Grow`, `Reset`, `String`, plus `Len`/`Cap`. `String()`
  returns the accumulated bytes without copying in the common case.
  — <https://pkg.go.dev/strings#Builder>
- **Byte ↔ text bridge:** `unicode/utf8` (`DecodeRune*`, `EncodeRune`,
  `Valid`, `RuneStart`, `FullRune`, `AppendRune`) plus the
  `string ↔ []byte ↔ []rune` conversions —
  <https://pkg.go.dev/unicode/utf8>, <https://go.dev/ref/spec#Conversions>

All three layers exist in the stdlib, but the "borrowed view" is implicit
(the `string` value) and the builder is a distinct type.

## 10. Interesting design decisions

1. **A string is a read-only `[]byte`, not a character sequence.** "In Go, a
   string is in effect a read-only slice of bytes." —
   <https://go.dev/blog/strings>
2. **Arbitrary bytes are legal.** String values, unlike literals, need not be
   valid UTF-8 — <https://go.dev/blog/strings>. This keeps strings usable as
   a universal byte buffer and shifts validation to the caller.
3. **Decoding never errors** — invalid input maps to `U+FFFD` with width 1.
   — <https://pkg.go.dev/unicode/utf8#DecodeRuneInString>
4. **Dual explicit views** `[]byte` / `[]rune` plus `byte`/`rune` aliases
   make the encoding level a *type choice* rather than a method name.
   — <https://go.dev/ref/spec#Numeric_types>
5. **`for range` is the UTF-8 special case.** The only place the language
   treats strings as UTF-8 is range iteration, which reports byte offsets.
   — <https://go.dev/blog/strings>
6. **Free functions over methods** keep the type minimal and let the same
   operations be expressed over `string`, `[]byte` and readers.
7. **`-1` as not-found and panic as out-of-range** — two different failure
   channels for two different mistakes. — <https://pkg.go.dev/strings#Index>
8. **`Cut` returns `(before, after, found)`** instead of `Split(...)[0]`,
   making the common "split once" case allocation-light and safe.
   — <https://pkg.go.dev/strings#Cut>
9. **Iterator variants (`SplitSeq`, `FieldsSeq`, `Lines`)** since Go 1.24
   yield substrings without allocating the result slice —
   <https://pkg.go.dev/strings>

## 11. Decisions NOT to copy

1. **No UTF-8 invariant on the type.** Values may be arbitrary bytes and the
   type silently permits invalid text; every consumer must re-validate.
   Mojo guarantees valid UTF-8 at construction
   (`mojov1/types/bool-and-strings`), which is a stronger contract worth
   keeping. `(Assessment.)`
2. **Panic on out-of-range indexing.** A library that must be predictable for
   a low-vision user should prefer a checked/`get`-style result or a defined
   clamp over a runtime panic. `(Assessment: derived from
   <https://go.dev/ref/spec#Index_expressions>.)`
3. **`-1` sentinels.** Overloading an index result to encode "not found"
   hides errors in arithmetic; Mojo already has `Optional`. `(Assessment.)`
4. **No grapheme unit.** Go forces users to third-party segmentation; Mojo
   1.0 already iterates grapheme clusters by default
   (`mojov1/types/bool-and-strings`). `(Assessment.)`
5. **No separate borrowed view type.** `string` conflates owner and view, so
   substring lifetime/retention is invisible; a distinct `StringSpan` is more
   explicit. `(Assessment.)`
6. **No normalization guarantee.** Go documents the ambiguity and leaves it
   to `x/text`; a text-primitive library should state the normalization
   contract explicitly. — <https://go.dev/blog/strings>

## 12. Ideas fitting Mojo

1. **`Cut`-style split-once**: return `(before, after, found)` for the first
   occurrence, mirroring `strings.Cut` — allocation-light and unambiguous.
   — <https://pkg.go.dev/strings#Cut>. Fits the README gap item "search /
   split".
2. **`IndexOf` returning `Optional[Int]`** instead of `-1`, with separate
   `byte` and `codepoint` index variants (`IndexByte` vs `IndexRune` are the
   Go precedent) — <https://pkg.go.dev/strings#IndexByte>.
3. **`CutPrefix`/`CutSuffix`/`TrimPrefix`/`TrimSuffix`** as a coherent
   prefix/suffix family — <https://pkg.go.dev/strings>. README gap item 1.
4. **A builder with the Go contract**: `Write`/`WriteString`/`WriteByte`/
   `WriteRune`/`Grow`/`Reset`/`String`/`Len`/`Cap`. The explicit
   `Grow(n)`/`Reset()` pair and `Len`/`Cap` introspection are the parts a
   Mojo `String` alone does not expose — <https://pkg.go.dev/strings#Builder>.
   README gap item 2.
5. **UTF-8 byte-level primitives**: `RuneStart`, `FullRune`, `RuneLen`,
   `DecodeRune`, `EncodeRune` with an explicit replacement-character
   convention for invalid input — <https://pkg.go.dev/unicode/utf8>. Directly
   supports README gap item 3 (byte↔text bridge + boundary safety).
6. **`Func` variants** (`IndexFunc`, `TrimFunc`, `FieldsFunc`, `Map`) taking
   a predicate over codepoints — a compact way to cover many operations
   without exploding the API surface — <https://pkg.go.dev/strings>.
7. **Non-allocating iterator variants** (`SplitSeq`, `FieldsSeq`, `Lines`)
   for large text, matching Go 1.24 — <https://pkg.go.dev/strings>.
8. **`ToValidUTF8(s, replacement)` / `Valid`** as the explicit repair and
   validation entry points — <https://pkg.go.dev/strings#ToValidUTF8>.
9. **`EqualFold` with a documented simple-vs-full case-folding boundary**
   (`ß` ≠ `ss`), rather than silently claiming full case-insensitivity —
   <https://pkg.go.dev/strings#EqualFold>.

## Sources

- Go language specification — string types:
  <https://go.dev/ref/spec#String_types>
- Go language specification — source code representation:
  <https://go.dev/ref/spec#Source_code_representation>
- Go language specification — numeric types (`byte`, `rune` aliases):
  <https://go.dev/ref/spec#Numeric_types>
- Go language specification — index expressions:
  <https://go.dev/ref/spec#Index_expressions>
- Go language specification — slice expressions:
  <https://go.dev/ref/spec#Slice_expressions>
- Go language specification — conversions:
  <https://go.dev/ref/spec#Conversions>
- Rob Pike, "Strings, bytes, runes and characters in Go" (2013):
  <https://go.dev/blog/strings>
- `strings` package: <https://pkg.go.dev/strings>
- `unicode/utf8` package: <https://pkg.go.dev/unicode/utf8>
- `golang.org/x/text` module: <https://pkg.go.dev/golang.org/x/text>
- `rivo/uniseg` (community, UAX #29): `github.com/rivo/uniseg` — no doc page
  fetched this run (`GUESS` marker)
- Mojo facts: `mojov1/types/bool-and-strings`
