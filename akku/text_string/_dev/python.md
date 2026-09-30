# string research: Python

Reference version: CPython 3.14.x (the docs fetched describe 3.14.7). The model
described here is the Python 3 model; Python 2's `str`/`unicode` split is out of
scope and is not a design target.

## 1. Standard library support

Python ships a **complete text stack** in the built-in types and `str` methods —
there is no need for a third-party library to do everyday text work.

- `str` — owned, immutable, heap-allocated sequence of Unicode code points.
  "Textual data in Python is handled with `str` objects, or *strings*." It is
  the only text type; there is no separate character type.
  (Source: <https://docs.python.org/3/library/stdtypes.html#textseq>)
- `bytes` — immutable "sequence of single bytes"; `bytearray` — its mutable
  counterpart; `memoryview` — a zero-copy buffer-protocol view.
  (Source: <https://docs.python.org/3/library/stdtypes.html#binaryseq>)
- `str` carries the whole everyday operation set as methods: `find`, `rfind`,
  `index`, `rindex`, `count`, `split`, `rsplit`, `splitlines`, `join`,
  `replace`, `strip`/`lstrip`/`rstrip`, `removeprefix`/`removesuffix`,
  `startswith`/`endswith`, `lower`/`upper`/`casefold`, `partition`/`rpartition`,
  `center`/`ljust`/`rjust`/`zfill`, `expandtabs`, `translate`/`maketrans`,
  `format`/`format_map`, `isalpha`/`isdigit`/… classification.
  (Source: <https://docs.python.org/3/library/stdtypes.html#string-methods>)
- `unicodedata` — normalization (`normalize` NFC/NFD/NFKC/NFKD), character
  categories, `casefold`-adjacent data.
  (Source: <https://docs.python.org/3/howto/unicode.html#unicode-properties>)
- `re` — Unicode-aware regex over `str` (`\d`, `\w`, `\s` are Unicode classes
  by default, restricted to ASCII with `re.ASCII`); the stdlib `re` does **not**
  support `\p{...}` properties or `\X` grapheme matching — the docs point to the
  third-party `regex` module for that.
  (Source: <https://docs.python.org/3/library/re.html>)
- `string` — module of constants (`ascii_lowercase`, `digits`, …) and the older
  `Template` class. (Source: `re` docs example uses `string.ascii_lowercase` +
  `string.digits`, <https://docs.python.org/3/library/re.html>; module page:
  <https://docs.python.org/3/library/string.html>)
- `io.StringIO` / `io.BytesIO` — in-memory text/binary streams, documented as
  the efficient way to build text incrementally.
  (Source: <https://docs.python.org/3/library/io.html#io.StringIO>)
- Since 3.14 there are also **template string literals** (`t"..."`, PEP 750),
  documented as `string.templatelib` next to `re` in the stdlib index.
  (Source: <https://peps.python.org/pep-0750/>; TOC entry in
  <https://docs.python.org/3/library/re.html>)

## 2. Relevant community libraries

Everything below is *optional*, motivated by the one gap the stdlib leaves:
**grapheme clusters** (`str` counts code points, not user-perceived characters).

- `regex` (PyPI, mrab-regex) — drop-in superset of `re`; adds `\p{property}`,
  set operations, full case-folding, and **`\X`, "matching a single grapheme"**,
  which "conforms to the Unicode specification at
  http://www.unicode.org/reports/tr29/". (Source:
  <https://pypi.org/project/regex/>)
- `grapheme` (PyPI) — "string manipulation and calculation functions for working
  with grapheme cluster groups (graphemes) as defined by Unicode Standard Annex
  #29". (Source: <https://pypi.org/project/grapheme/>,
  <https://grapheme.readthedocs.io/en/latest/>)
- `graphemeu` (PyPI) — same UAX #29 grapheme-cluster purpose, actively
  maintained successor flavor. (Source: <https://pypi.org/project/graphemeu/>)
- `ugrapheme` (PyPI) — Cython-accelerated grapheme handling ("so that the
  length of 👩🏽‍🔬🏴󠁧󠁢󠁳󠁣󠁴󠁿Hi is 4 instead of 13").
  (Source: <https://pypi.org/project/ugrapheme/>)
- `pyuegc` (PyPI) — pure-Python UAX #29 extended grapheme clusters.
  (Source: <https://pypi.org/project/pyuegc/>)
- `graphemex`, `grapheme-cluster-break` (PyPI) — Rust/C-accelerated grapheme
  segmentation. (Sources: <https://pypi.org/project/graphemex/>,
  <https://pypi.org/project/grapheme-cluster-break/>)

(Assessment: derived from the sources above — the community layer exists
*precisely because* `str`'s unit is the code point.)

## 3. Exposed APIs

`str` (methods, from
<https://docs.python.org/3/library/stdtypes.html#string-methods>):

- **Search:** `find(sub[,start[,end]])` → lowest index or `-1`;
  `rfind` → highest index or `-1`; `index`/`rindex` → same but raise `ValueError`
  when not found; `count`; `in` membership operator.
- **Split/join:** `split(sep=None, maxsplit=-1)`, `rsplit`, `splitlines`,
  `partition`/`rpartition` (3-tuples with the separator kept),
  `sep.join(iterable)` (note: the **separator is the receiver**).
- **Replace:** `replace(old, new[, count])`.
- **Trim:** `strip`, `lstrip`, `rstrip` — the `chars` argument is a **set of
  characters**, "not a prefix or suffix".
- **Affix:** `startswith`/`endswith` (accept tuples), `removeprefix`,
  `removesuffix`.
- **Case:** `lower`, `upper`, `casefold` ("more aggressive … intended to remove
  all case distinctions"), `capitalize`, `title`, `swapcase`.
- **Layout:** `center`, `ljust`, `rjust`, `zfill`, `expandtabs`.
- **Mapping:** `translate(table)`, `maketrans(...)`.
- **Format:** `format`, `format_map`, f-strings; PEP 750 t-strings.
- **Classify:** `isalpha`, `isdigit`, `isalnum`, `isspace`, `isupper`, ...
- **Encode:** `str.encode(encoding='utf-8', errors='strict')`.

Bytes side: `bytes.decode(encoding='utf-8', errors='strict')`, plus the same
search/split/replace method family on `bytes`/`bytearray`.
(Source: <https://docs.python.org/3/library/stdtypes.html#bytes-methods>)

Module-level/functional: `re.match/search/fullmatch/findall/finditer/sub/split`;
`unicodedata.normalize` and `unicodedata.category`.

Built-ins: `len`, `ord(c)` (returns code point), `chr(i)` (returns
length-1 string), `str(obj)`, `repr(obj)`.
(Source: <https://docs.python.org/3/howto/unicode.html#the-string-type>)

## 4. Error representation

Python is **exception-based**, with a few deliberate sentinel returns:

| Situation | Behavior | Source |
| --- | --- | --- |
| Item index out of range `s[i]` | `IndexError` | stdtypes #typesseq-common note 8 |
| Substring not found, `find`/`rfind` | returns `-1` (sentinel) | #string-methods |
| Substring not found, `index`/`rindex` | raises `ValueError` | #string-methods |
| `sequence.index` on a generic sequence | raises `ValueError` | #typesseq-common |
| Non-string in `join(iterable)` | `TypeError` (includes `bytes`) | #string-methods |
| Decoding invalid bytes, `errors='strict'` | `UnicodeDecodeError` (a `UnicodeError`) | #bytes-methods |
| Encoding unrepresentable char, `errors='strict'` | `UnicodeEncodeError` | #string-methods |
| Invalid escape / bad regex | `SyntaxWarning` now, `SyntaxError` later; regex → `re.PatternError` | #re-docs |

The `errors` argument gives a **policy** instead of an exception:
`'strict'`, `'ignore'`, `'replace'` (U+FFFD on decode, `?` on encode),
`'backslashreplace'`, `'xmlcharrefreplace'`, `'namereplace'`, and any handler
registered with `codecs.register_error()`.
(Sources: <https://docs.python.org/3/howto/unicode.html#converting-to-bytes>,
<https://docs.python.org/3/library/stdtypes.html#bytes-methods>)

## 5. Ownership semantics

Python has **no ownership/borrow system**; the relevant semantics are
immutability, value-copy-on-slice and GC:

- `str` is immutable: "Strings are immutable sequences of Unicode code points."
  (Source: #textseq)
- "There is also no mutable string type."
  (Source: #textseq)
- **Slicing copies.** For an immutable sequence, "Concatenating immutable
  sequences always results in a new object", and a slice of `str` is a new
  `str`. There is **no borrowed `&str`-style substring type** in the stdlib.
  (Source: #typesseq-common note 6)
- The only zero-copy "view" in the stdlib is `memoryview` over a
  buffer-protocol object like `bytes`/`bytearray` — not a text view.
  (Source: #memory-views)
- Identity vs equality: `is` compares object identity, `==` value equality;
  `str` is hashable and usable as a `dict` key.
  (Source: #comparisons, #immutable-sequence-types)

(Assessment: derived from #textseq and #typesseq-common — Python replaces the
owned/borrowed split with *immutability + cheap copying*, and replaces the
builder with an explicit IO/list pattern, see Q9.)

## 6. Blocking / non-blocking

String operations are **pure CPU-bound, synchronous and never block** — there is
no I/O in `str`/`bytes`. The blocking concept appears only at the IO boundary:

- Text streams (`io.TextIOBase`, `TextIOWrapper`, `open()`) can raise
  `BlockingIOError` if the underlying raw stream is non-blocking and the read
  cannot complete immediately.
  (Source: <https://docs.python.org/3/library/io.html#io.TextIOBase>)
- `BufferedIOBase.write` raises `BlockingIOError` (with
  `characters_written`) when a non-blocking raw stream would block; `read`
  returns the data so far or `None`.
  (Source: <https://docs.python.org/3/library/io.html#io.BufferedIOBase>)
- The CPython GIL means two Python threads cannot run string computations in
  parallel. The third-party `regex` module is an explicit exception: it "releases
  the GIL during matching on instances of the built-in (immutable) string
  classes". (Source: <https://pypi.org/project/regex/>)

## 7. Text model (encoding, length, indexing)

**`str` is a sequence of Unicode code points; indexing and `len` count code
points, not bytes and not graphemes.**

- "Textual data in Python is handled with `str` objects … Strings are immutable
  sequences of Unicode code points." (Source: #textseq)
- "Since there is no separate 'character' type, indexing a string produces
  strings of length 1" — `s[0] == s[0:1]` for non-empty `s`. (Source: #textseq)
- `len(s)` is the number of code points, and `s[i]` is the code point at
  position `i`. (Source: #typesseq-common: `s[i]` "ith item of s, origin 0";
  `len(s)` "length of s")
- **Encoding is not part of `str`.** "The default encoding for Python source
  code is UTF-8"; the runtime `str` is not bytes. The byte↔text bridge is
  `str.encode` / `bytes.decode` (Q9). (Source:
  <https://docs.python.org/3/howto/unicode.html#the-string-type>)
- Internally, PEP 393 gives `str` a **flexible representation**: 1 byte
  (Latin-1), 2 bytes (UCS-2) or 4 bytes (UCS-4) "depending on the character with
  the largest Unicode ordinal", with `length` defined as the "number of code
  points in the string". So indexing is O(1) and `len` is code points
  regardless of the in-memory width.
  (Source: <https://peps.python.org/pep-0393/>)
- **Grapheme clusters are not a `str` concept.** A single user-perceived
  character may be several code points; the HOWTO's own example: `'ê'` is
  either one code point U+00EA or the two code points U+0065 U+0302, "one is a
  string of length 1 and the other is of length 2".
  (Source: <https://docs.python.org/3/howto/unicode.html#comparing-strings>)
  Graphemes need `unicodedata` + third-party libraries or `regex`'s `\X`.
- `bytes` is a different model entirely: "immutable sequences of single bytes",
  "each value … restricted such that `0 <= x < 256`", and `b[0]` is an
  **integer** while `b[0:1]` is a `bytes` of length 1 — the opposite of `str`.
  (Source: #bytes-objects)

Position definition: a position is a **code-point index**; slices are
half-open `[i:j)` in that unit (Q8 for bounds).

## 8. Bounds, invalid input and errors

- **Out-of-range item index:** "An `IndexError` is raised if *i* is outside the
  sequence range." Negative indices are resolved as `len(s) + i`, and "`-0` is
  still `0`". (Source: #typesseq-common notes 3 and 8)
- **Slices never raise.** Bounds are clamped: omitted → `0` / `len(s)`;
  `< -len(s)` → `0`; `> len(s)` → `len(s)`; `i >= j` → empty. A slice therefore
  can never split outside the range; since the unit is a code point, a slice
  **can never land inside** a code point either.
  (Source: #typesseq-common note 4)
- **Empty/zero-length edges:** empty `str` is falsy; `''.join([])` is `''`;
  `'x'.split(',')` → `['x']`; `''.split(',')` → `['']`; `''.splitlines()` →
  `[]`. (Source: #string-methods for split/splitlines; truthiness from
  <https://docs.python.org/3/library/stdtypes.html#truth>)
- **Invalid UTF-8 on input:** only exists at the decode step.
  `b'\x80abc'.decode('utf-8', 'strict')` raises `UnicodeDecodeError`;
  `'replace'` → `'\ufffdabc'`; `'ignore'` → `'abc'`.
  (Source: <https://docs.python.org/3/howto/unicode.html#converting-to-bytes>)
- **Encode errors:** `u.encode('ascii')` raises `UnicodeEncodeError`;
  `'replace'` inserts `?`, `'xmlcharrefreplace'` inserts `&#40960;`, etc.
  (Source: <https://docs.python.org/3/howto/unicode.html#converting-to-bytes>)
- **Lone surrogates are representable** in a `str` via the `surrogateescape`
  handler, which "will decode any non-ASCII bytes as code points in a special
  range running from U+DC80 to U+DCFF" and turns them back into the same bytes.
  So a Python `str` is *not* guaranteed to be encodable to UTF-8.
  (Source:
  <https://docs.python.org/3/howto/unicode.html#files-in-an-unknown-encoding>)
- **Comparison is code-point-lexicographic; normalization is explicit.**
  Canonically equivalent strings compare unequal unless normalized:
  `normalize('NFD', s1) == normalize('NFD', s2)`. Case-insensitive comparison
  should use `casefold()`, and the HOWTO's robust recipe is
  `NFD(NFD(s).casefold())`. (Source:
  <https://docs.python.org/3/howto/unicode.html#comparing-strings>)

(Assessment: derived from the sources above — Python's rule is the clean one:
item indexing raises, slicing clamps, code-point boundaries make "slice on a
non-boundary" impossible for `str`, and all encoding hazards are pushed to the
explicit encode/decode step.)

## 9. Owned type, borrowed view and builder layer

Python provides **one** of the three layers as a *text* type, and fills the
other two with patterns rather than types:

- **Owned text type:** `str` (immutable) and `bytes`/`bytearray` (binary).
- **Borrowed text view:** **none in the stdlib.** Slicing `str` copies. The
  closest things are `memoryview` (binary, zero-copy, "without copying") and the
  fact that `str` objects are referenced rather than copied at the variable
  level. (Sources: #memory-views, #typesseq-common note 6)
- **Builder layer:** **no `StringBuilder` type.** The stdlib's documented answer
  is the *list + join* or *io.StringIO* pattern:
  - `str.join()`: "if concatenating `str` objects, you can build a list and use
    `str.join()` at the end or else write to an `io.StringIO` instance and
    retrieve its value when complete". (Source: #typesseq-common note 6)
  - `io.StringIO` is documented as an in-memory text stream.
    (Source: <https://docs.python.org/3/library/io.html#io.StringIO>)
  - For bytes, `bytearray` is explicitly the mutable builder: "`bytearray`
    objects are mutable and have an efficient overallocation mechanism".
    (Source: #typesseq-common note 6)
  - Why it matters: "building up a sequence by repeated concatenation will have
    a **quadratic runtime cost** in the total sequence length".
    (Source: #typesseq-common note 6)
- **Byte ↔ text bridge:** `str.encode(encoding, errors)` → `bytes` and
  `bytes.decode(encoding, errors)` → `str`. Default encoding is `'utf-8'`.
  There is **no implicit conversion**: `str` methods don't accept `bytes` and
  vice versa; `str + bytes` is a `TypeError`; `str.join` over `bytes` raises.
  (Sources: <https://docs.python.org/3/howto/unicode.html#converting-to-bytes>,
  #string-methods, #bytes-methods, and
  <https://docs.python.org/3/howto/unicode.html#tips-for-writing-unicode-aware-programs>:
  "There is no automatic encoding or decoding: if you do e.g. `str + bytes`, a
  `TypeError` will be raised.")

(Assessment: derived from the sources above — the three-layer picture maps to
Python as *one type + two idioms*: immutable `str`, no borrowed view, builder
by convention.)

## 10. Interesting design decisions

1. **Code points, not bytes and not graphemes.** Because both `len` and indexing
   use code points, indexing is O(1) (PEP 393) and slicing can never split a
   character — at the cost that `len` disagrees with user perception and with
   the byte count. (Sources: #textseq, <https://peps.python.org/pep-0393/>)
2. **Flexible internal representation (PEP 393).** 1/2/4-byte kinds chosen from
   the largest ordinal, with UTF-8 as "the recommended way of exposing strings
   to C code". This keeps ASCII cheap while giving full UCS-4 semantics.
   (Source: <https://peps.python.org/pep-0393/>)
3. **`str`/`bytes` split instead of a flag or a view.** Two concrete types with
   an explicit codec boundary; no encoding is carried by the value.
   (Source: <https://docs.python.org/3/howto/unicode.html#the-string-type>)
4. **Sentinel vs raise is a user choice for search:** `find` → `-1`, `index` →
   `ValueError`. (Source: #string-methods)
5. **The `errors` policy argument** turns a decode failure into a configurable
   policy (replace/ignore/backslashreplace), instead of one hard-coded behavior.
   (Source: <https://docs.python.org/3/howto/unicode.html#converting-to-bytes>)
6. **`sep.join(parts)` inverts the usual receiver.** The separator owns the
   operation, which is why joining is the efficient builder primitive.
   (Source: #string-methods)
7. **`casefold()` is separate from `lower()`** for caseless matching.
   (Source: <https://docs.python.org/3/howto/unicode.html#comparing-strings>)
8. **Normalization is a library call, not implicit.** Equality stays
   code-point-exact; NFC/NFD choose the user's intent.
   (Source: <https://docs.python.org/3/howto/unicode.html#comparing-strings>)
9. **No separate `char` type:** one-character slices give length-1 `str`;
   `ord`/`chr` are the code-point bridge.
   (Source: #textseq, <https://docs.python.org/3/howto/unicode.html#the-string-type>)

## 11. Decisions NOT to copy

- **Code-point length as *the* length.** It is principled but it is not what a
  low-vision reader means by "characters"; Mojo already answers this with three
  separate measurements (`byte_length()`/`count_codepoints()`/
  `count_graphemes()`). Do not collapse them into one `len`.
  (Mojo facts from `mojov1/types/bool-and-strings`.)
- **No borrowed view.** Copy-on-slice is a real cost for a parser/serializer
  library; Mojo's `StringSpan` is the better shape and should be preferred over
  a "slice copies" rule. (Owned/view fact from `mojov1/types/bool-and-strings`.)
- **Builder by convention only.** "build a list and `join`, or use StringIO" is
  a documentation rule a user must remember; an explicit builder with an
  append/flush contract is testable and discoverable. (Source:
  #typesseq-common note 6.)
- **Implicit encoding defaults that depend on the environment.** `open()`'s
  default encoding is locale-specific, and the docs tell you to always pass
  `encoding="utf-8"`; that footgun is worth not reproducing (Python is moving to
  UTF-8 Mode by default in 3.15). (Source:
  <https://docs.python.org/3/library/io.html#text-encoding>, PEP 686)
- **Sentinel `-1` for search.** It hides "not found" in an `Int`; an
  `Optional[Int]` (`None`) or a `raises` variant is more type-safe and Mojo
  already has the `Optional` idiom. (Sources: #string-methods,
  `mojov1/idioms/patterns`.)
- **Lone surrogates representable in the text type.** `surrogateescape` lets a
  `str` hold U+D800–U+DFFF, so the type is not "valid Unicode on construction".
  Mojo enforces UTF-8 validity at construction
  (`String(from_utf8_lossy=…)`, `String(unsafe_from_utf8=…)`) and should keep
  that guarantee. (Source:
  <https://docs.python.org/3/howto/unicode.html#files-in-an-unknown-encoding>;
  Mojo facts from `mojov1/types/bool-and-strings`.)
- **In-place mutation of a "string" via `bytearray`.** For a text primitive the
  byte/text boundary should stay a separate type, not a mutable twin with
  inherited text methods. (Assessment: derived from #bytearray-objects.)

## 12. Ideas fitting Mojo

- **Keep the three explicit lengths and make them the headline.**
  `byte_length()` / `count_codepoints()` / `count_graphemes()` is exactly the
  Python lesson taken further: measure what you mean.
  (Mojo already has this per `mojov1/types/bool-and-strings`.)
- **An explicit builder with an append/flush contract** to replace Python's
  list+`join`/`StringIO` idiom, plus a `join(parts)`/variadic-`String()` fast
  path. Python's own docs prove the need (quadratic concatenation).
  (Sources: #typesseq-common note 6; `mojov1/types/bool-and-strings` on the
  variadic `String(...)` constructor being cheaper than `+` chains.)
- **`Optional[Int]` search returns and a `raises`-variant for `index`-style
  strictness** — take both Python behaviors but make them explicit in the type.
  (Source: #string-methods.)
- **A configurable decode/encode error policy** — Python's
  `strict`/`replace`/`ignore`/`backslashreplace` family maps directly onto
  Mojo's `from_utf8_lossy`/`unsafe_from_utf8` spectrum and is worth surfacing as
  named modes for the byte↔text bridge.
  (Sources: <https://docs.python.org/3/howto/unicode.html#converting-to-bytes>;
  Mojo facts from `mojov1/types/bool-and-strings`.)
- **Normalization + `casefold` as explicit primitives** (`normalize(form)`,
  `casefold()`) so equality stays predictable and caseless matching is a
  deliberate call. (Source:
  <https://docs.python.org/3/howto/unicode.html#comparing-strings>.)
- **Grapheme segmentation as a first-class operation** (UAX #29), which Python
  only gets from third-party libraries / `regex`'s `\X` — a real gap `string`
  can own. (Sources: <https://pypi.org/project/regex/>,
  <https://pypi.org/project/grapheme/>.)
- **Boundary-checked slicing** — Python gets safety for free by using code
  points; Mojo stores UTF-8 bytes, so the deliberate rule (refuse or snap to a
  codepoint boundary) is a design decision the library must state. (Assessment:
  derived from #typesseq-common note 4 + Mojo's UTF-8 storage in
  `mojov1/types/bool-and-strings`.)

## Sources

- Built-in Types (Python 3.14.7), incl. *Text Sequence Type — str*, *String
  Methods*, *Binary Sequence Types*, *Common Sequence Operations*:
  <https://docs.python.org/3/library/stdtypes.html>
- Unicode HOWTO: <https://docs.python.org/3/howto/unicode.html>
- PEP 393 – Flexible String Representation:
  <https://peps.python.org/pep-0393/>
- `io` — Core tools for working with streams:
  <https://docs.python.org/3/library/io.html>
- `re` — Regular expression operations:
  <https://docs.python.org/3/library/re.html>
- PEP 750 – Template Strings (t-strings):
  <https://peps.python.org/pep-0750/>
- PEP 686 – Make UTF-8 mode default:
  <https://peps.python.org/pep-0686/>
- Third-party `regex` module: <https://pypi.org/project/regex/>
- Third-party `grapheme`: <https://pypi.org/project/grapheme/>
- Third-party `graphemeu`: <https://pypi.org/project/graphemeu/>
- Third-party `ugrapheme`: <https://pypi.org/project/ugrapheme/>
- Third-party `pyuegc`: <https://pypi.org/project/pyuegc/>
- Third-party `graphemex`: <https://pypi.org/project/graphemex/>
- Third-party `grapheme-cluster-break`:
  <https://pypi.org/project/grapheme-cluster-break/>
- UAX #29 Unicode Text Segmentation (referenced by `regex` and the grapheme
  libraries): <https://www.unicode.org/reports/tr29/>
- Mojo side (buch, not internet): `mojov1/types/bool-and-strings`,
  `mojov1/idioms/patterns`.
