# string research: Swift

## 1. Standard library support

Swift has a single first-class text type, `String`, whose `Element` is
`Character` (an extended grapheme cluster), plus the view types
`Substring`, `String.UTF8View`, `String.UTF16View` and
`UnicodeScalarView`.

- "A *string* is a series of characters … Swift strings are represented by
  the `String` type. The contents of a `String` can be accessed in various
  ways, including as a collection of `Character` values." —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- `String` is a value type: "Swift's `String` type is a *value type*. If you
  create a new `String` value, that `String` value is *copied* when it's
  passed to a function or method" — copy-on-write behind the scenes —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Mutability is `var` vs `let`, not a type pair: "You indicate whether a
  particular `String` can be modified (or *mutated*) by assigning it to a
  variable … or to a constant" —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Concat/append: `+`, `+=`, `String.append(_:)`, and string interpolation
  `"\(expr)"` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Insert/remove: `insert(_:at:)`, `insert(contentsOf:at:)`, `remove(at:)`,
  `removeSubrange(_:)` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Comparison: `==`/`!=` (canonical equivalence), `hasPrefix(_:)`,
  `hasSuffix(_:)`, `Comparable` — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Unicode views: `.utf8` (`String.UTF8View`, `UInt8` units), `.utf16`
  (`String.UTF16View`, `UInt16` units), `.unicodeScalars`
  (`UnicodeScalarView`, 21-bit scalars) —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Foundation extends `String` with the `NSString` methods when imported
  (bridged) — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- `String` itself is the builder: there is **no** `StringBuilder` type; you
  mutate a `var String` with `append`/`insert`/`+=` —
  `(Assessment: derived from the absence of a builder type anywhere in the
  Swift book's Strings chapter; <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>.)`
- Since Swift 5 the native storage encoding is UTF-8; prior to Swift 5 it was
  UTF-16 with a separate ASCII storage class —
  <https://www.swift.org/blog/utf8-string/>

## 2. Relevant community libraries

- **Foundation / `NSString` bridging** is part of the platform rather than a
  third-party choice: "Swift's `String` type is bridged with Foundation's
  `NSString` class", and NSStrings are lazily bridged (zero-copy) —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
  <https://www.swift.org/blog/utf8-string/>
- **swift-collections** (Apple) and **swift-algorithms** (Apple) provide
  generic collection algorithms and data structures that compose with
  `String`/`Substring` because both conform to `Collection`/`StringProtocol`
  — `GUESS:` no page was fetched this run; the claim rests on the packages'
  public repositories, not on a cited doc page.
- **Grapheme/word/sentence segmentation is in the stdlib** (`Character` is
  already a grapheme cluster), so unlike Rust and Go there is no need for a
  `unicode-segmentation` analogue for the default unit —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- **ICU / Foundation `StringTransform`** for case mapping, normalization and
  locale-aware comparison beyond `==` — `GUESS:` not fetched; rests on the
  Foundation API surface, not on a cited page.
- **SwiftNIO** is a downstream consumer that gained ~20% throughput from the
  Swift 5 UTF-8 switch (transcoding removal) —
  <https://www.swift.org/blog/utf8-string/>

## 3. Exposed APIs

`String`'s surface is **properties and methods on the type plus generic
`Collection` algorithms**, which is markedly different from Go's free
functions and Rust's `&str` methods.

- Count: `String.count` returns the number of `Character` values, and it is
  an **O(n) traversal** — "the number of characters in a string can't be
  calculated without iterating through the string" —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Empty: `isEmpty` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Indices: `startIndex`, `endIndex`, `index(before:)`, `index(after:)`,
  `index(_:offsetBy:)`, `indices`, and subscripting `s[i]` with a
  `String.Index` (never an `Int`) —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Substrings: prefix/suffix/subscript produce a `Substring`; `String(_:)`
  copies it into independent storage —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
  <https://developer.apple.com/documentation/swift/substring.md>
- Case: `uppercased()`, `lowercased()` (shown on `Substring`) —
  <https://developer.apple.com/documentation/swift/substring.md>
- Comparison: `==`, `!=`, `<`, `hasPrefix(_:)`, `hasSuffix(_:)`,
  `firstIndex(of:)` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Bytes: `utf8` view; `String.UTF8View` is the "most performant view for
  native strings", and `utf8.withContiguousStorageIfAvailable { … }` gives a
  contiguous UTF-8 buffer (SE-0237/SE-0247) —
  <https://www.swift.org/blog/utf8-string/>
- UTF-16: `utf16` view; `unicodeScalars` view with `.value: UInt32` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Decoding from code units in a named encoding: `String(decoding:as:)` —
  "Creates a string from the given Unicode code units in the specified
  encoding" —
  <https://developer.apple.com/documentation/swift/string/init(decoding:as:).md>
- C interop: `withCString { … }` operates on zero-terminated UTF-8 without
  allocating or transcoding for native strings —
  <https://www.swift.org/blog/utf8-string/>

## 4. Error representation

Swift's text APIs mostly eliminate the *representable* error instead of
returning it; invalid Unicode is either unconstructible or repaired.

- Invalid input in the safe scalar/character API is **not representable**:
  `Character` is a grapheme cluster built from scalars, and scalar escapes
  reject invalid values at compile time (`"\u{110000}"` → "invalid unicode
  scalar") —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Decoding from raw code units is a **non-throwing initializer** that takes
  the source encoding explicitly: `String(decoding:as:)` —
  <https://developer.apple.com/documentation/swift/string/init(decoding:as:).md>.
  `(Assessment: because it does not return `Result`/`throws`, invalid input
  must be handled by the decoding/replacement policy rather than surfaced as
  an error; the page does not state the invalid-input policy for every
  encoding.)`
- Out-of-range index is a **runtime error**, not an error value: "Attempting
  to access an index outside of a string's range or a `Character` at an index
  outside of a string's range will trigger a runtime error." —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Bridged `NSString`s may contain invalid content (isolated surrogates) and
  "are lazily validated when read from" — i.e. validation is deferred, not an
  upfront error — <https://www.swift.org/blog/utf8-string/>
- The stdlib validates native string creation once, "like Rust": "Swift 5,
  like Rust, performs encoding validation once on creation" —
  <https://www.swift.org/blog/utf8-string/>
- There is no "not found" sentinel: `firstIndex(of:)` returns
  `Optional`, and the Swift book's own example uses
  `?? greeting.endIndex` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>

## 5. Ownership semantics

- `String` and `Substring` are **value types** with copy-on-write: "a `String`
  value is *copied* when it's passed to a function or method … Behind the
  scenes, Swift's compiler optimizes string usage so that actual copying
  takes place only when absolutely necessary." —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- `Substring` is the borrowed view, but a **retaining** one: "a substring
  shares its storage with the original string … a substring holds a reference
  to the entire storage of the string it comes from, not just to the portion
  it presents" and storing one "may, therefore, prolong the lifetime of
  string data that is no longer otherwise accessible, which can appear to be
  memory leakage" —
  <https://developer.apple.com/documentation/swift/substring.md>
- Conversion between layers is explicit and copying: `String(substring)`
  copies into fresh storage; `Substring.base` returns the backing `String` —
  <https://developer.apple.com/documentation/swift/substring.md>
- Generic functions should take `some StringProtocol` so they accept both
  `String` and `Substring` without copying —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
  <https://developer.apple.com/documentation/swift/substring.md>
- There are no lifetimes and no borrow checker; sharing is hidden inside the
  copy-on-write buffer and reference counting —
  `(Assessment: derived from the value-type/COW description in
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>.)`

## 6. Blocking / non-blocking

Text primitives are pure in-memory operations. `count`, subscripting and the
`*View` iterations are synchronous traversals with no I/O and no blocking.
`(Assessment: derived from the API descriptions in
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
none of which involve I/O.)`

The only performance caveat is CPU, not blocking: `count` is O(n), and
`utf8.withContiguousStorageIfAvailable` / `withUTF8` may materialise
contiguous storage on first use —
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
<https://developer.apple.com/documentation/swift/substring.md>

## 7. Text model (encoding, length, indexing)

**Swift's model is the sharpest contrast to Go/Rust: the default unit is the
extended grapheme cluster, storage is UTF-8, and integer indexing is
forbidden.**

- What a "character" is: "Every instance of Swift's `Character` type
  represents a single *extended grapheme cluster*. An extended grapheme
  cluster is a sequence of one or more Unicode scalars that (when combined)
  produce a single human-readable character." —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Encodings available simultaneously: UTF-8 (`.utf8`), UTF-16 (`.utf16`) and
  21-bit scalars (`.unicodeScalars`); these are "encoding forms" whose chunks
  are "code units" — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Storage: the native representation is UTF-8 since Swift 5 — "Swift 5
  switches the preferred encoding of strings from UTF-16 to UTF-8"; small
  strings pack up to 15 UTF-8 code units inline on 64-bit (10 on 32-bit) and
  large/indirect/opaque strings cover the rest —
  <https://www.swift.org/blog/utf8-string/>
- `String` is "built from *Unicode scalar values*" — a scalar is a "unique
  21-bit number for a character or modifier" —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Length: `count` counts **grapheme clusters**, is O(n) and can *decrease in
  meaning*: appending U+0301 to "cafe" leaves `count == 4`, with the fourth
  character `é` — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Characters have no fixed byte width, so positions are not integers: "you
  must iterate over each Unicode scalar from the start or end of that
  `String`. For this reason, Swift strings can't be indexed by integer
  values." — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Position type: `String.Index` "corresponds to the position of each
  `Character` in the string"; `startIndex` is the first character, `endIndex`
  is "the position after the last character" and is **not** a valid subscript
  argument — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Traversal primitives: `index(before:)`, `index(after:)`,
  `index(_:offsetBy:)` (offsetBy is O(n)) —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Byte positions are a *view*, not the string's index space: `utf8`,
  `utf16`, `unicodeScalars`; UTF-16 offsets differ from UTF-16 *code units* in
  `NSString.length` only by the grapheme-vs-code-unit distinction —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
- Normalization is **not** applied to storage, but equality is canonical:
  "\u{E9}" and "\u{65}\u{301}" are two different scalar sequences that are
  `==` — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>

## 8. Bounds, invalid input and errors

| Case | Behaviour | Source |
| --- | --- | --- |
| integer subscript `s[0]` | does not compile (strings can't be indexed by `Int`) | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| `s[endIndex]` | runtime error (`endIndex` is not a valid subscript argument) | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| `index(after: endIndex)` | runtime error | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| index outside the string's range | runtime error | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| empty string | `startIndex == endIndex`; `isEmpty` true; subscripting either is an error | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| substring not found | `Optional` (`nil`), e.g. `firstIndex(of:)` | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| invalid scalar literal (`\u{110000}`, surrogates) | compile-time error: "invalid unicode scalar" | <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/> |
| decoding code units in an encoding | `String(decoding:as:)`, non-throwing | <https://developer.apple.com/documentation/swift/string/init(decoding:as:).md> |
| NSString with isolated surrogates | lazily validated on read | <https://www.swift.org/blog/utf8-string/> |
| grapheme "boundary" slicing | subscripts by `String.Index` are grapheme-aligned by construction | `(Assessment: derived from `Character` = grapheme cluster + `String.Index` indexing `Character`.)` |

Note the model consequence: because the index space *is* graphemes, a slice
can never split a grapheme — the boundary-safety problem Go and Rust solve
with byte predicates is removed by the type system at the cost of O(n)
indexing. `(Assessment: derived from
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>.)`

## 9. Owned type, borrowed view and builder layer

- **Owned type:** `String` — a value type with copy-on-write storage,
  UTF-8-backed since Swift 5, mutable via `var` —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
  <https://www.swift.org/blog/utf8-string/>
- **Borrowed view:** `Substring` — "A slice of a string … shares its storage
  with the original string"; it presents the same interface via the
  `StringProtocol` protocol but retains the whole original buffer, so it is
  explicitly "not suitable for long-term storage" —
  <https://developer.apple.com/documentation/swift/substring.md>
- **Builder layer:** there is **no dedicated builder**; `String` is mutated in
  place via `append`, `insert`, `+=`, `replaceSubrange` — and `Substring` is
  itself `RangeReplaceableCollection`, so the same methods work on a view.
  `(Assessment: derived from the absence of a builder type in the Swift book
  and from `RangeReplaceableCollection` conformance listed in
  <https://developer.apple.com/documentation/swift/substring.md>.)`
- **Encoding views (the byte ↔ text bridge):** `String.UTF8View`,
  `String.UTF16View`, `UnicodeScalarView`, plus `String(decoding:as:)` to
  build from code units and `withCString` / `utf8.withContiguousStorageIfAvailable`
  for contiguous C/byte access —
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>,
  <https://www.swift.org/blog/utf8-string/>
- The stdlib provides owner + borrowed view + encoding views, but **no
  builder type**; the "three layers" are really owner, view, and a *family of
  encoding views*.

## 10. Interesting design decisions

1. **`Character` = extended grapheme cluster**, making the default iteration
   and the default length match human perception — the closest match to
   Mojo 1.0's grapheme iteration — Swift book, StringsAndCharacters.
2. **`String.Index` instead of integer positions**, which makes splitting a
   grapheme unrepresentable rather than an error to check —
   Swift book, String Indices.
3. **`count` is honestly O(n) and documented as such**, including the
   `NSString.length` caveat (UTF-16 code units ≠ graphemes) —
   Swift book, Counting Characters.
4. **Canonical equivalence in `==` and `hasPrefix`/`hasSuffix`**: "\u{E9}" is
   equal to "\u{65}\u{301}" — Swift book, Comparing Strings.
5. **Three named encoding views on one type** (`.utf8`, `.utf16`,
   `.unicodeScalars`) instead of two parallel types like `str`/`[u8]` —
   Swift book, Unicode Representations.
6. **Value semantics with copy-on-write and a retaining `Substring`**, traded
   against explicit no-lifetimes/leak warnings —
   <https://developer.apple.com/documentation/swift/substring.md>
7. **Small-string optimisation on UTF-8 content** (≤15 code units on 64-bit)
   as a first-class representation —
   <https://www.swift.org/blog/utf8-string/>
8. **Lazy zero-copy `NSString` bridging with UTF-16↔UTF-8 "breadcrumbs"** to
   keep Objective-C interop amortised O(1) —
   <https://www.swift.org/blog/utf8-string/>
9. **Explicit source encoding on decode** via `String(decoding:as:)`, so the
   encoding is a parameter rather than an implicit assumption —
   <https://developer.apple.com/documentation/swift/string/init(decoding:as:).md>
10. **`StringProtocol` as the abstraction** shared by `String` and
    `Substring`, so generic algorithms accept views without copying —
    <https://developer.apple.com/documentation/swift/substring.md>

## 11. Decisions NOT to copy

1. **Grapheme-cluster default unit for *all* operations.** It matches human
   perception but makes `count`, `offsetBy` and integer-indexed access O(n);
   Mojo should keep grapheme *iteration* but must retain O(1)
   `byte_length()`/`StringSpan` slicing for protocol layers (HTTP, JSON,
   parsers). `(Assessment: derived from Swift book Counting Characters +
   `mojov1/types/bool-and-strings`.)`
2. **Canonical-equivalence `==`.** Two byte-different strings comparing equal
   is user-friendly for UI but dangerous for protocol/security code (hash
   keys, cache lookup, signature comparison) and forces normalization work
   inside equality. Provide it as an explicitly named operation, not as `==`.
   Swift book, Comparing Strings. `(Assessment.)`
3. **A retaining `Substring` that can appear to leak memory.** Mojo's
   `StringSpan` should keep the ownership story explicit rather than hiding a
   full-buffer retain behind a value type —
   <https://developer.apple.com/documentation/swift/substring.md>. `(Assessment.)`
4. **No builder type.** Mutating a `var String` is convenient but gives no
   explicit reserve/flush contract; the README asks for one.
   `(Assessment.)`
5. **Opaque index tokens whose distance computation is O(n).** Good for
   correctness, but a Mojo text library needs explicit numeric byte and
   codepoint offsets too (`byte_length`, `count_codepoints`,
   `count_graphemes` already exist). `(Assessment.)`
6. **Platform-specific NSString bridging complexity.** The lazy-bridging and
   breadcrumb machinery exists to serve Objective-C; Mojo has no such
   constraint and should not reproduce it —
   <https://www.swift.org/blog/utf8-string/>. `(Assessment.)`
7. **A `.utf16` view as a first-class API.** It is a legacy-interop need;
   for new UTF-8-native libraries it adds surface without value.
   `(Assessment.)`

## 12. Ideas fitting Mojo

1. **A view type that shares storage and presents the same API as the owned
   type** (`Substring` : `StringProtocol`) — Mojo's `StringSpan` already
   plays this role; the idea to import is "one set of operations works on
   both owner and view". — <https://developer.apple.com/documentation/swift/substring.md>
2. **Named encoding views**: `s.utf8`-style byte access and a scalar view,
   mirroring Mojo's existing `bytes()`/`codepoints()`/`codepoint_slices()`
   — <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>.
3. **A safe opaque position type** that makes "index into the middle of a
   codepoint/grapheme" unrepresentable, in addition to (not instead of) plain
   integer byte offsets — Swift book, String Indices.
4. **Documenting cost in the API**: Swift states `count` is O(n); Mojo's
   three length functions should each state their cost explicitly so a
   low-vision user can choose without benchmarking —
   Swift book, Counting Characters, plus `mojov1/types/bool-and-strings`.
5. **An explicitly named `is_canonically_equal` / normalization-aware
   compare**, separate from byte equality — Swift book, Comparing Strings.
   This is the one "don't copy as `==`, do copy as a named API" idea.
6. **Contiguous-buffer escape hatch**: a `with_utf8_contiguous`-style scoped
   accessor (Swift's `withUTF8` / `withContiguousStorageIfAvailable`) for
   interop and fast byte scanning without exposing the raw pointer beyond the
   closure — <https://www.swift.org/blog/utf8-string/>. Fits README gap
   item 3 (byte↔text bridge).
7. **`hasPrefix`/`hasSuffix` as first-class methods**, matching both Swift and
   Go, as the prefix/suffix family for README gap item 1 —
   <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>.
8. **Explicit source-encoding parameter on decode**
   (`String(decoding:as:)`): a `from_bytes(bytes, encoding=…)`-style entry
   point makes the assumption visible — <https://developer.apple.com/documentation/swift/string/init(decoding:as:).md>.
9. **Grapheme-safe substring extraction by *character offset*, implemented as
   a traversal**, for the UI/display use case, separate from the O(1)
   byte-slice API — Swift book, String Indices. `(Assessment.)`

## Sources

- The Swift Programming Language — Strings and Characters:
  <https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/>
  (raw source:
  <https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/StringsAndCharacters.md>)
- Michael Ilseman, "UTF-8 String", Swift.org blog (2019):
  <https://www.swift.org/blog/utf8-string/>
- `Substring` — Apple Developer Documentation:
  <https://developer.apple.com/documentation/swift/substring.md>
- `String.init(decoding:as:)` — Apple Developer Documentation:
  <https://developer.apple.com/documentation/swift/string/init(decoding:as:).md>
- swift-collections / swift-algorithms: `github.com/apple/swift-collections`,
  `github.com/apple/swift-algorithms` (not fetched this run)
- Mojo facts: `mojov1/types/bool-and-strings`
