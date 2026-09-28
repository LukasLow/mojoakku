# string research: Rust

## 1. Standard library support

Rust splits text across three std primitives — an owned `String`, a borrowed
`&str`, and a scalar `char` — with no string *methods* on the language itself.

- `str` is "the most primitive string type … usually seen in its borrowed form
  `&str` … also the type of string literals, `&'static str`" —
  <https://doc.rust-lang.org/std/primitive.str.html>
- `String` is "A UTF-8–encoded, growable string … ownership over the contents
  of the string, stored in a heap-allocated buffer" —
  <https://doc.rust-lang.org/std/string/struct.String.html>
- `char` is "a single character. More specifically, since 'character' isn't a
  well-defined concept in Unicode, `char` is a 'Unicode scalar value'." It is
  always four bytes — <https://doc.rust-lang.org/std/primitive.char.html>
- Every method of `str` is reachable on `String` through
  `Deref<Target = str>`; `String` adds only the mutation/ownership methods —
  <https://doc.rust-lang.org/std/string/struct.String.html#deref>
- The everyday surface lives on `str` and is vast: `find`, `rfind`, `split`,
  `splitn`, `rsplit`, `split_once`, `split_at`, `split_at_checked`,
  `split_inclusive`, `split_whitespace`, `lines`, `replace`, `replacen`,
  `trim*`, `strip_prefix`, `strip_suffix`, `starts_with`, `ends_with`,
  `contains`, `matches`, `match_indices`, `repeat`, `to_lowercase`,
  `to_uppercase`, `to_ascii_lowercase`, `eq_ignore_ascii_case`,
  `eq_ignore_case_unnormalized`, `to_casefold_unnormalized`, `substr_range`,
  `chars`, `char_indices`, `bytes`, `encode_utf16`, `get`, `is_char_boundary`,
  `floor_char_boundary`, `ceil_char_boundary`, `escape_debug` — the full
  method index is in <https://doc.rust-lang.org/std/primitive.str.html>.
  Stability is not uniform on `str`: `word_to_titlecase` is unstable (feature
  `titlecase`, #153892) —
  <https://doc.rust-lang.org/unstable-book/library-features/titlecase.html>;
  `substr_range` was feature-gated (`substr_range`, #126769) and stabilized in
  1.98.0 — <https://github.com/rust-lang/rust/issues/126769>
- `String` adds `new`, `with_capacity`, `from_utf8`, `from_utf8_lossy`,
  `from_utf16*`, `push`, `push_str`, `insert`, `remove`, `truncate`,
  `clear`, `reserve`, `shrink_to_fit`, `as_str`, `as_mut_str`,
  `as_mut_vec`, `into_bytes`, `into_boxed_str`, `leak`, `retain`, `pop`,
  `split_off`, `drain`, `replace_range`, plus the **nightly-only in-place**
  mutators `replace_first`/`replace_last` (feature `string_replace_in_place`,
  #147949) and `remove_matches` (feature `string_remove_matches`, #72826),
  which take `&mut self` and are **not** available on `str` —
  <https://doc.rust-lang.org/std/string/struct.String.html>,
  <https://github.com/rust-lang/rust/issues/147949>,
  <https://github.com/rust-lang/rust/issues/72826>
- `core::char` / `std::char` add the scalar predicates and conversions
  (`is_alphabetic`, `is_numeric`, `to_digit`, `from_u32`,
  `REPLACEMENT_CHARACTER`) —
  <https://doc.rust-lang.org/std/primitive.char.html>

## 2. Relevant community libraries

The stdlib deliberately stops at **Unicode scalar values**; everything above
that is crates:

- **`unicode-segmentation`** — "Iterators which split strings on Grapheme
  Cluster, Word, or Sentence boundaries, according to the Unicode Standard
  Annex #29 rules", exposing `graphemes`, `unicode_words`,
  `split_word_bounds`, `GraphemeCursor`, and a `UNICODE_VERSION` constant.
  It is `no_std`-capable — <https://docs.rs/unicode-segmentation/latest/unicode_segmentation/>
- **`bstr`** — byte strings that are "*conventionally* UTF-8" while std
  strings are "*guaranteed* to be valid UTF-8": `BStr` (analogous to `str`)
  and `BString` (analogous to `String`), plus `find_iter`, grapheme/word/
  sentence iterators and case conversion that tolerate invalid UTF-8.
  Operations defined only on codepoints substitute `U+FFFD` using the
  Unicode "substitution of maximal subparts" strategy —
  <https://docs.rs/bstr/latest/bstr/>
- **`unicode-normalization`** (Unicode normalization: NFC/NFD/NFKC/NFKD) —
  the crate's public repository is `github.com/unicode-rs/unicode-normalization`.
  `GUESS:` no page was fetched for this run; the claim rests on the crate's
  public repository, not on a cited doc page.
- **`regex`** operates on `&str` and `&[u8]`; the stdlib has no pattern
  engine beyond `str`/`char` patterns and `char_indices` —
  <https://docs.rs/bstr/latest/bstr/> (discusses exactly the `&str`/`&[u8]`
  split that motivated `bstr`)

## 3. Exposed APIs

Rust's surface is **methods on `&str` plus a small set of `String` methods**:

- Search: `find`/`rfind` return `Option<usize>` (a **byte** offset),
  `starts_with`/`ends_with`/`contains` return `bool`,
  `matches`/`match_indices` are lazy iterators —
  <https://doc.rust-lang.org/std/primitive.str.html#method.find>
- Split: `split`, `splitn`, `rsplit`, `rsplitn`, `split_once`,
  `split_inclusive`, `split_terminator`, `split_whitespace`,
  `split_ascii_whitespace`, `lines`, `lines_any` —
  <https://doc.rust-lang.org/std/primitive.str.html>
- Replace/trim (on `str`): `replace`, `replacen`,
  `trim`, `trim_start`, `trim_end`, `trim_matches`,
  `trim_start_matches`, `trim_end_matches`, `trim_prefix`, `trim_suffix`,
  `strip_prefix`, `strip_suffix` — <https://doc.rust-lang.org/std/primitive.str.html>.
  `replace_first`, `replace_last` and `remove_matches` are **not** `str`
  methods: they are `String` methods taking `&mut self`, and are
  **nightly-only** — `replace_first`/`replace_last` under feature
  `string_replace_in_place` and `remove_matches` under feature
  `string_remove_matches` —
  <https://doc.rust-lang.org/std/string/struct.String.html>,
  <https://github.com/rust-lang/rust/issues/147949>,
  <https://github.com/rust-lang/rust/issues/72826>
- Case: `to_uppercase`, `to_lowercase` (full Unicode), `to_ascii_uppercase`,
  `to_ascii_lowercase`, `eq_ignore_ascii_case`, `to_casefold_unnormalized`,
  `eq_ignore_case_unnormalized`, and `word_to_titlecase`
  (**unstable**, feature `titlecase`, #153892) —
  <https://doc.rust-lang.org/std/primitive.str.html>,
  <https://doc.rust-lang.org/unstable-book/library-features/titlecase.html>
- Byte-level: `as_bytes`, `bytes()`, `is_char_boundary`,
  `floor_char_boundary`, `ceil_char_boundary`, `encode_utf16` —
  <https://doc.rust-lang.org/std/primitive.str.html>
- Scalar-level: `chars()`, `char_indices()` (scalar + byte offset),
  `unicode_scalars` via `chars` — <https://doc.rust-lang.org/std/primitive.str.html>
- Slicing: `get(range) -> Option<&str>`, `split_at(mid)` (panicking),
  `split_at_checked(mid) -> Option<(&str, &str)>` —
  <https://doc.rust-lang.org/std/primitive.str.html#method.split_at_checked>
- Construction: `String::from_utf8`, `String::from_utf8_lossy`,
  `String::from_utf16`, `String::with_capacity`, `push`, `push_str` —
  <https://doc.rust-lang.org/std/string/struct.String.html>
- Conversion to bytes/owned bytes: `as_bytes`, `into_bytes`,
  `into_boxed_bytes`, `into_string`, `Box<str>`, `Cow<'_, str>` —
  <https://doc.rust-lang.org/std/primitive.str.html>,
  <https://doc.rust-lang.org/std/string/struct.String.html>
- `String` is a writer: it implements `Write` and `Extend<&str>/<char>` —
  <https://doc.rust-lang.org/std/string/struct.String.html>

## 4. Error representation

Rust distinguishes *invalid encoding* (a checked error), *out of bounds /
non-boundary* (a panic or `Option`), and *not found* (`Option`):

- `str::from_utf8(&[u8]) -> Result<&str, Utf8Error>` — "Returns `Err` if the
  slice is not UTF-8 with a description as to why the provided slice is not
  UTF-8." — <https://doc.rust-lang.org/std/primitive.str.html#method.from_utf8>
- `Utf8Error` reports the valid prefix and the error length
  (`valid_up_to()`, `error_len()`) —
  <https://doc.rust-lang.org/std/str/struct.Utf8Error.html>
- `String::from_utf8(Vec<u8>) -> Result<String, FromUtf8Error>`; on error
  "The vector you moved in is also included" so no data is lost —
  <https://doc.rust-lang.org/std/string/struct.String.html#method.from_utf8>
- Lossy repair: `from_utf8_lossy` substitutes `U+FFFD` and returns
  `Cow<'_, str>` (borrowed when already valid, owned when repaired) —
  <https://doc.rust-lang.org/std/string/struct.String.html#method.from_utf8_lossy>
- Non-panicking slicing: `get(range) -> Option<&str>` — "Returns `None`
  whenever equivalent indexing operation would panic", including indices not
  on UTF-8 sequence boundaries and out-of-bounds ranges —
  <https://doc.rust-lang.org/std/primitive.str.html#method.get>
- Panicking slicing: "Note this will panic if the byte indices provided are
  not character boundaries" — <https://doc.rust-lang.org/std/string/struct.String.html>
  (the "UTF-8" section, on `&s[i..j]`)
- Not found is `None`, never a sentinel: `find`/`rfind`/`parse` return
  `Option`; `matches`/`split` yield empty iterators —
  <https://doc.rust-lang.org/std/primitive.str.html>
- Invalid `char` is unrepresentable at the type level: constructing one from
  `u32` needs `char::from_u32` (`Option`) or `char::from_u32_unchecked`
  (`unsafe`, "Violating this rule causes undefined behavior") —
  <https://doc.rust-lang.org/std/primitive.char.html>

## 5. Ownership semantics

This is Rust's defining layer for text and the closest ancestor of the Mojo
model:

- `String` **owns** a heap buffer described as (pointer, length, capacity);
  "This buffer is always stored on the heap." — moving the `String` moves the
  ownership — <https://doc.rust-lang.org/std/string/struct.String.html#representation>
- `&str` is **borrowed**: "A `&str` is made up of two components: a pointer to
  some bytes, and a length." — <https://doc.rust-lang.org/std/primitive.str.html#representation>
- `String: Deref<Target = str>`, so `&String` coerces to `&str` and borrows
  all `str` methods — <https://doc.rust-lang.org/std/string/struct.String.html#deref>
- `&'static str` for literals; `Cow<'a, str>` for "borrowed or owned"
  (used by `from_utf8_lossy`) —
  <https://doc.rust-lang.org/std/primitive.str.html>,
  <https://doc.rust-lang.org/std/string/struct.String.html#method.from_utf8_lossy>
- The borrow checker statically prevents aliasing mutation; to mutate bytes
  you must own a `String` (`push`, `insert`) or use
  `unsafe { as_mut_vec() }` / `unsafe { as_bytes_mut() }` with an explicit
  safety contract — <https://doc.rust-lang.org/std/string/struct.String.html>
- Non-UTF-8 OS strings have their own owned/borrowed pair, `OsString`/`OsStr`
  — <https://doc.rust-lang.org/std/string/struct.String.html>
- `Vec<u8>` vs `String`: both own a heap byte buffer, but only `String` is
  constrained to valid UTF-8; `as_bytes`/`into_bytes`/`from_utf8` are the
  bridge — <https://doc.rust-lang.org/std/string/struct.String.html>

## 6. Blocking / non-blocking

`str`, `String` and `char` methods are pure in-memory transformations; there
is no I/O and no blocking in the text primitives.
`(Assessment: derived from the method signatures in
<https://doc.rust-lang.org/std/primitive.str.html> and
<https://doc.rust-lang.org/std/string/struct.String.html>, all of which take
and return in-memory values.)`

Streaming is delegated to `io` traits (`Read`/`Write`); `String`
implementing `Write` is the only I/O-adjacent surface —
<https://doc.rust-lang.org/std/string/struct.String.html>

## 7. Text model (encoding, length, indexing)

**Rust's model is: UTF-8 always, `char` = Unicode scalar, indexing in bytes,
and *no* grapheme concept in std.**

- Encoding is UTF-8 and it is a **type invariant**: "Rust libraries may assume
  that string slices are always valid UTF-8. Constructing a non-UTF-8 string
  slice is not immediate undefined behavior, but any function called on a
  string slice may assume that it is valid UTF-8" —
  <https://doc.rust-lang.org/std/primitive.str.html#invariant>
- `String` is "A UTF-8–encoded, growable string" and "`String`s are always
  valid UTF-8. If you need a non-UTF-8 string, consider `OsString`." —
  <https://doc.rust-lang.org/std/string/struct.String.html>
- What a "character" is: `char` is a **Unicode scalar value** (any code point
  except a surrogate). It is *not* a grapheme cluster: "the 'é' character is
  one Unicode code point while 'e'+U+0301 is two Unicode code points" —
  <https://doc.rust-lang.org/std/primitive.char.html>
- Length: `str::len()` "is in bytes, not `char`s or graphemes. In other
  words, it might not be what a human considers the length of the string."
  `"ƒoo".len() == 4` but `"ƒoo".chars().count() == 3` —
  <https://doc.rust-lang.org/std/primitive.str.html#method.len>
- There is no stdlib grapheme count or grapheme iterator; the Unicode scalar
  is the top-level unit in std — <https://doc.rust-lang.org/std/primitive.str.html>
- Normalization is *not* applied: std offers `to_casefold_unnormalized` and
  `eq_ignore_case_unnormalized`, and the `_unnormalized` names encode the
  absence of normalization — <https://doc.rust-lang.org/std/primitive.str.html>
- Indexing rules:
  - `s[i]` with a plain `usize` is **forbidden at compile time**: "Due to
    these ambiguities/restrictions, indexing with a `usize` is simply
    forbidden" — <https://doc.rust-lang.org/std/string/struct.String.html>
  - Byte access goes through `s.as_bytes()[i] -> u8` —
    <https://doc.rust-lang.org/std/primitive.str.html#method.as_bytes>
  - `&s[i..j]` accepts **byte indices** and must land on char boundaries:
    "only byte indices would provide constant time indexing … Note this will
    panic if the byte indices provided are not character boundaries" —
    <https://doc.rust-lang.org/std/string/struct.String.html>
  - The i'th scalar is a traversal, not an index: `s.chars().nth(2)` —
    <https://doc.rust-lang.org/std/string/struct.String.html>
  - A position is validated by `is_char_boundary(index)`: "Checks that
    `index`-th byte is the first byte in a UTF-8 code point sequence or the
    end of the string. The start and end of the string (when
    `index == self.len()`) are considered to be boundaries. Returns `false` if
    `index` is greater than `self.len()`." —
    <https://doc.rust-lang.org/std/primitive.str.html#method.is_char_boundary>
  - Boundary *repair* helpers exist: `floor_char_boundary` ("the closest `x`
    not exceeding `index`") and `ceil_char_boundary` (added 1.91). Even
    `floor_char_boundary` documents that it may split graphemes: the scientist
    emoji can be truncated to the person emoji —
    <https://doc.rust-lang.org/std/primitive.str.html#method.floor_char_boundary>

## 8. Bounds, invalid input and errors

| Case | Behaviour | Source |
| --- | --- | --- |
| `s[i]` (usize index) | compile error | <https://doc.rust-lang.org/std/string/struct.String.html> |
| `&s[a..b]` out of bounds | panic | <https://doc.rust-lang.org/std/primitive.str.html#method.get> ("out of bounds", `get(..42).is_none()`) |
| `&s[a..b]` not on a char boundary | panic | <https://doc.rust-lang.org/std/string/struct.String.html> |
| `s.get(a..b)` for either case | `None`, never panics | <https://doc.rust-lang.org/std/primitive.str.html#method.get> |
| `s.is_char_boundary(i)` with `i > len` | `false` (defined, not panic) | <https://doc.rust-lang.org/std/primitive.str.html#method.is_char_boundary> |
| `split_at(mid)` off-boundary / past end | panic; `split_at_checked` returns `None` | <https://doc.rust-lang.org/std/primitive.str.html#method.split_at_checked> |
| bytes that are not valid UTF-8 | `str::from_utf8` → `Err(Utf8Error)`; `from_utf8_lossy` → `U+FFFD` (`Cow`) | <https://doc.rust-lang.org/std/primitive.str.html#method.from_utf8> |
| invalid `char` from `u32` | `char::from_u32` → `None`; `_unchecked` → UB | <https://doc.rust-lang.org/std/primitive.char.html> |
| empty string | `""` is valid, `is_empty()` true, `find` → `None`, `split('x')` yields one empty piece | <https://doc.rust-lang.org/std/primitive.str.html> |
| substring not found | `None` (`find`) / empty iterator (`matches`) | <https://doc.rust-lang.org/std/primitive.str.html#method.find> |
| `char::from_digit` radix > 36 | panic | <https://doc.rust-lang.org/std/primitive.char.html#method.from_digit> |

The `str` invariant makes "invalid UTF-8 in a `str`" **undefined behavior**
downstream, so the safe constructors either check (`from_utf8`) or repair
(`from_utf8_lossy`), and the unchecked ones are `unsafe` and explicitly
documented — <https://doc.rust-lang.org/std/primitive.str.html#invariant>

## 9. Owned type, borrowed view and builder layer

- **Owned type:** `String` (heap, ptr/len/cap, growable). The owned layer also
  includes `Box<str>` and `OsString` for size-fixed and non-UTF-8 cases —
  <https://doc.rust-lang.org/std/string/struct.String.html#representation>
- **Borrowed view:** `&str` / `&mut str` — a fat pointer (ptr + len) with the
  UTF-8 invariant. `String: Deref<Target = str>` is the bridge between the
  two layers — <https://doc.rust-lang.org/std/primitive.str.html>,
  <https://doc.rust-lang.org/std/string/struct.String.html#deref>
- **Builder layer:** Rust has **no dedicated builder type**. `String` itself
  *is* the builder (`new`, `with_capacity`, `push`, `push_str`, `insert`,
  `reserve`, `truncate`, `clear`), and it implements `Write` and
  `Extend<&str>/<char>` — <https://doc.rust-lang.org/std/string/struct.String.html>.
  `(Assessment: derived from the absence of any Builder type in the
  `std::string` module index and from the presence of the mutation methods on
  `String`.)`
- **Byte ↔ text bridge:** `as_bytes`, `as_bytes_mut` (`unsafe`), `into_bytes`
  (owned, no copy), `Vec<u8> -> String` via `String::from_utf8`/`TryFrom`,
  `str::from_utf8`/`from_utf8_unchecked`, and `OsString`/`OsStr`/`PathBuf`
  for platform strings that may not be UTF-8 —
  <https://doc.rust-lang.org/std/string/struct.String.html>,
  <https://doc.rust-lang.org/std/primitive.str.html>
- The stdlib provides all three layers, but fuses "owned" and "builder" into
  `String`, exactly as the README's gap item 2 anticipated.

## 10. Interesting design decisions

1. **UTF-8 is a type invariant, enforced at construction.** Once inside a
   `str`, no further validation is needed; invalid UTF-8 is UB, not a value.
   — <https://doc.rust-lang.org/std/primitive.str.html#invariant>
2. **Indexing by `usize` is a compile error, not a runtime panic.** The type
   system removes the ambiguity instead of documenting a convention —
   <https://doc.rust-lang.org/std/string/struct.String.html>
3. **Range slicing is byte-indexed for O(1), boundary-checked for correctness,
   and has a non-panicking twin (`get`).** The panicking and safe variants are
   both first-class — <https://doc.rust-lang.org/std/primitive.str.html#method.get>
4. **`char` is a scalar, and `len()` is bytes.** The API names never pretend
   a scalar index is O(1) — <https://doc.rust-lang.org/std/primitive.char.html>,
   <https://doc.rust-lang.org/std/primitive.str.html#method.len>
5. **`Cow<'_, str>` for lossy repair** avoids allocation when the input was
   already valid — <https://doc.rust-lang.org/std/string/struct.String.html#method.from_utf8_lossy>
6. **`String` doubles as the builder**, so there is no second type and no
   `flush`/`finish` ceremony — <https://doc.rust-lang.org/std/string/struct.String.html>
7. **`Deref` coercion keeps the borrowed view ergonomic**: `fn f(s: &str)`
   accepts `&String` with no explicit conversion —
   <https://doc.rust-lang.org/std/string/struct.String.html#deref>
8. **Boundary repair (`floor_char_boundary`/`ceil_char_boundary`) is a
   stdlib concern**, and the docs are explicit that it may still split a
   grapheme — <https://doc.rust-lang.org/std/primitive.str.html#method.floor_char_boundary>
9. **The `_unnormalized` suffixes** document that std does not normalize,
   rather than leaving it as folk knowledge —
   <https://doc.rust-lang.org/std/primitive.str.html>
10. **Non-UTF-8 text has separate, honest types** (`OsString`, `bstr`'s
    `BStr`/`BString`) instead of weakening the main type —
    <https://doc.rust-lang.org/std/string/struct.String.html>,
    <https://docs.rs/bstr/latest/bstr/>

## 11. Decisions NOT to copy

1. **Undefined behaviour on non-UTF-8 `str`.** Mojo's contract offers
   `String(from_utf8_lossy=…)`, which replaces invalid bytes, and
   `String(unsafe_from_utf8=…)`, which explicitly does **not** enforce and
   requires a caller guarantee; Mojo should not let an invalid value become
   UB, and its checked/lossy path is the safer default for a low-vision user.
   `(Assessment: derived from <https://doc.rust-lang.org/std/primitive.str.html#invariant>
   vs. `mojov1/types/bool-and-strings`.)`
2. **Two panicking paths for slicing.** `&s[..]` panicking while `get` returns
   `None` is idiomatic Rust but adds a choice a text-primitive library does
   not need; prefer one checked path plus a clearly named clamping helper.
   `(Assessment: reasoning from the two documented behaviours at
   <https://doc.rust-lang.org/std/primitive.str.html#method.get> and
   <https://doc.rust-lang.org/std/string/struct.String.html>.)`
3. **`char` = scalar only.** Rust's `char` is a codepoint, so `count()` over
   `chars` over-counts user-perceived characters; Mojo already defaults
   iteration to grapheme clusters and should not regress to scalar-only
   thinking. `(Assessment: derived from <https://doc.rust-lang.org/std/primitive.char.html>
   and `mojov1/types/bool-and-strings`.)`
4. **No builder type.** Fusing owned+builder into one type works in Rust
   because `Deref` supplies the view, but it gives no explicit `flush`
   contract; the README asks for an explicit append/flush contract.
   `(Assessment: derived from the mutation methods listed at
   <https://doc.rust-lang.org/std/string/struct.String.html> and the
   README.md gap premise, item 2.)`
5. **`Deref`-coercion magic.** It is ergonomic but implicit; a Mojo library
   should make `String`↔`StringSpan` conversion explicit rather than
   operator-driven. `(Assessment: reasoning from the `Deref`/coercion
   behaviour at
   <https://doc.rust-lang.org/std/string/struct.String.html#deref>.)`
6. **std's silence on graphemes and normalization.** Leaving both to crates
   means every consumer must discover `unicode-segmentation` and
   `unicode-normalization`; the primitive library should own the grapheme
   boundary it already counts. `(Assessment: derived from the absence of a
   grapheme/normalization API at
   <https://doc.rust-lang.org/std/primitive.str.html> plus the crate list in
   §2.)`

## 12. Ideas fitting Mojo

1. **The `String`/`&str` owned-vs-borrowed split is the model to mirror**
   with Mojo's `String`/`StringSpan` — including `Deref`-like ergonomics made
   explicit — `(Assessment: derived from Mojo's already-existing pair in
   `mojov1/types/bool-and-strings`.)`
2. **A named boundary predicate + repair pair**: `is_char_boundary`,
   `floor_char_boundary`, `ceil_char_boundary`. Mojo's
   `byte_length`/`count_codepoints`/`count_graphemes` need exactly this to
   turn a byte offset into a safe slice — <https://doc.rust-lang.org/std/primitive.str.html#method.is_char_boundary>
3. **Checked slicing as the default**: a `get(range) -> Optional[StringSpan]`
   analogue that returns `None` on out-of-bounds *and* on non-boundary, with
   `split_at_checked` returning the two halves —
   <https://doc.rust-lang.org/std/primitive.str.html#method.get>. README gap
   item 3.
4. **`find`/`rfind` returning `Optional[Int]` byte offsets**, plus
   `contains`/`starts_with`/`ends_with` returning `Bool` —
   <https://doc.rust-lang.org/std/primitive.str.html>. README gap item 1.
5. **Iterator families instead of allocating collections**: `split`,
   `splitn`, `rsplit`, `lines`, `matches`, `match_indices`,
   `char_indices` — a lazy API keeps large-text processing cheap.
   <https://doc.rust-lang.org/std/primitive.str.html>
6. **`from_utf8_lossy`-style repair returning a borrow-when-possible type**
   (`Cow` analogue) so validating valid input costs nothing —
   <https://doc.rust-lang.org/std/string/struct.String.html#method.from_utf8_lossy>
7. **`split_once`/`split_at_checked` returning tuples** for the
   split-once case, complementary to Go's `Cut` —
   <https://doc.rust-lang.org/std/primitive.str.html#method.split_at_checked>
8. **An explicit `_unnormalized` naming convention** for case-fold/compare
   variants, so the absence of normalization is visible in the API —
   <https://doc.rust-lang.org/std/primitive.str.html>
9. **`char`-style scalar predicates** (`is_alphabetic`, `is_numeric`,
   `to_digit`, `from_u32`) as the codepoint-level toolkit beneath the
   grapheme-level API — <https://doc.rust-lang.org/std/primitive.char.html>
10. **A `bstr`-inspired "conventionally UTF-8" path** for parsing arbitrary
    bytes (network/HTTP bodies) without forcing validation or `U+FFFD` repair
    upfront — <https://docs.rs/bstr/latest/bstr/>. The README's byte↔text
    bridge item 3 is precisely this problem.

## Sources

- `str` primitive type (representation, invariant, methods, boundaries):
  <https://doc.rust-lang.org/std/primitive.str.html>
- `String` type (UTF-8, Deref, representation, constructors):
  <https://doc.rust-lang.org/std/string/struct.String.html>
- `char` primitive type (scalar semantics, 4-byte layout, UB rules):
  <https://doc.rust-lang.org/std/primitive.char.html>
- `std::str::Utf8Error`:
  <https://doc.rust-lang.org/std/str/struct.Utf8Error.html>
- `unicode-segmentation` crate (UAX #29 graphemes/words/sentences):
  <https://docs.rs/unicode-segmentation/latest/unicode_segmentation/>
- `bstr` crate (conventionally-UTF-8 byte strings):
  <https://docs.rs/bstr/latest/bstr/>
- `unicode-normalization` crate: `github.com/unicode-rs/unicode-normalization`
  (not fetched this run)
- Unstable Book, feature `titlecase` (`str::word_to_titlecase`):
  <https://doc.rust-lang.org/unstable-book/library-features/titlecase.html>
- Tracking issue #147949 (`string_replace_in_place`):
  <https://github.com/rust-lang/rust/issues/147949>
- Tracking issue #72826 (`string_remove_matches`):
  <https://github.com/rust-lang/rust/issues/72826>
- Tracking issue #126769 (`substr_range`, stabilized 1.98.0):
  <https://github.com/rust-lang/rust/issues/126769>
- Mojo facts: `mojov1/types/bool-and-strings`
