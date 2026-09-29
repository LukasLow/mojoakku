# string research: Julia

Reference version: Julia 1.13 (docs generated 2026-09-09), plus `master`
features noted as Julia 1.14 (`Base.StringView`). Line numbers in `repo/path:N`
citations come from the "source" links of the official docs (commit
`d1c37793`) unless marked `master`.

## 1. Standard library support

Yes, and it is the whole model — Julia's string support is `Base` + the
`Unicode` stdlib, not an add-on.

- `String` is the built-in concrete string type used by string literals. It is
  "a contiguous byte array … interpreted as being UTF-8 encoded" but "can be
  composed of any byte sequence"; UTF-8 validity is *not* required.
  (`JuliaLang/julia base/strings/string.jl`, `String` docstring)
- All string types subtype the abstract `AbstractString`; packages may define
  more (e.g. other encodings). (`docs.julialang.org/en/v1/manual/strings/`;
  `JuliaLang/julia base/strings/basic.jl:5-40`)
- Characters are first-class: `Char` (32-bit) and the abstract `AbstractChar`.
  (`JuliaLang/julia base/char.jl:5-47`)
- Core index arithmetic is in `Base`: `thisind`, `nextind`, `prevind`,
  `firstindex`, `lastindex`, `eachindex`/`keys`, `isvalid(s,i)`, `codeunit`,
  `codeunits`, `ncodeunits`, `length`, `sizeof`.
  (`docs.julialang.org/en/v1/base/strings/`)
- Unicode work lives in the `Unicode` stdlib: `graphemes`, `normalize`,
  `isequal_normalized`, `textwidth`, `uppercase`/`lowercase`/`titlecase`,
  category predicates. It is implemented over the C library utf8proc.
  (`docs.julialang.org/en/v1/stdlib/Unicode/`;
  `JuliaLang/julia base/strings/unicode.jl`, module header)
- Everyday operations are in `Base`: `findfirst`/`findlast`/`findnext`/
  `findprev`, `occursin`, `replace`, `split`/`rsplit`/`eachsplit`, `join`,
  `repeat`/`^`, `strip`/`lstrip`/`rstrip`, `chop`/`chomp`, `startswith`/
  `endswith`, `uppercase`/`lowercase`, `cmp`/`isless`/`==`.
  (`docs.julialang.org/en/v1/base/strings/`;
  `JuliaLang/julia base/strings/util.jl`)

(Assessment: derived from the manual Strings page and the Base Strings
reference — Julia's stdlib covers owned type, borrowed view and builder; a
Julia-side `string` library would be a *wrap* case, exactly like Mojo's.)

## 2. Relevant community libraries

- **StringViews.jl** — `StringView{T<:AbstractVector{UInt8}} <: AbstractString`,
  a copy-free UTF-8 view over *any* byte vector; "does not take 'ownership' of
  or modify the array". Maintainer: Steven G. Johnson / JuliaStrings
  organisation. MIT. **Merged into Julia 1.14 as `Base.StringView`** (PR 60526);
  package v2 becomes a thin wrapper. 56 stars, active (last push 2026-07-14).
  (`github.com/JuliaStrings/StringViews.jl` README;
  `api.github.com/repos/JuliaStrings/StringViews.jl`;
  `JuliaLang/julia base/strings/string.jl`, `StringView` docstring)
- **InlineStrings.jl** — fixed-width stack-friendly string types `String1/3/7/
  15/31/63/127/255`, byte-compatible with C, plug into radix sort.
  Maintainer: JuliaStrings. Licence: GitHub reports `Other` / SPDX
  `NOASSERTION` (Julia packages are conventionally MIT, but the repo carries no
  SPDX-recognised license file). 49 stars, active (last push 2026-09-23).
  (`github.com/JuliaStrings/InlineStrings.jl` README;
  `api.github.com/repos/JuliaStrings/InlineStrings.jl`)
- **StringBuilders.jl** — a mutable `StringBuilder` wrapping `IOBuffer`, with
  `append!` and `String(sb)`. Maintainer: David Anthoff. MIT. 21 stars, active
  (last push 2026-09-20). (`github.com/davidanthoff/StringBuilders.jl` README +
  `src/StringBuilders.jl`; `api.github.com/repos/davidanthoff/StringBuilders.jl`)
- **LegacyStrings.jl** — `ASCIIString`, `UTF8String`, `UTF16String`,
  `UTF32String`, `ByteString`, `WString`, `RepString` plus converters
  `ascii`/`utf8`/`utf16`/`utf32`/`wstring`. Maintainer: JuliaStrings. Licence:
  GitHub reports `Other` / SPDX `NOASSERTION`. 15 stars, last code push
  2023-05-03 (stable, not heavily developed).
  (`github.com/JuliaStrings/LegacyStrings.jl` README;
  `api.github.com/repos/JuliaStrings/LegacyStrings.jl`)
- `LazyString` / `lazy"…"` is in **Base** since 1.8 — no package needed.
  (`JuliaLang/julia base/strings/lazy.jl:1-65`)

(Assessment: derived from the READMEs and GitHub API metadata above.)

## 3. Exposed APIs

Types:

- `AbstractString`, `String`, `SubString{T}`, `Char`, `AbstractChar`,
  `CodeUnits{UInt8,String}` (a `DenseVector{UInt8}` wrapper), `LazyString`,
  `Regex`/`RegexMatch`, `AnnotatedString`/`AnnotatedChar`, `Base.StringView`
  (1.14). (`docs.julialang.org/en/v1/base/strings/`)
- Errors: `StringIndexError`, `CodePointError`, `InvalidCharError`.
  (`JuliaLang/julia base/strings/string.jl`; `base/char.jl`)

Measurement:

- `ncodeunits(s)` — code units (bytes for UTF-8).
- `sizeof(str)` — bytes = `ncodeunits * sizeof(codeunit)`.
- `length(s)` / `length(s, i, j)` — number of characters (codepoints); linear.
- `Unicode.textwidth(s)` — printed column count.
- `codeunit(s)` / `codeunit(s, i)` — code-unit type / value at index `i`.
- `codeunits(s)` — vector-like raw byte access.
  (`JuliaLang/julia base/strings/basic.jl:45-106,163-177,367-395,807-825`;
  `base/strings/unicode.jl:251-287`)

Indexing / slicing / iteration:

- `s[i]::Char`, `s[i:j]::String` (copy), `SubString(s,i,j)` (view),
  `view(s, r)`, `@views str[i:j]`, `firstindex`, `lastindex`, `begin`/`end`,
  `eachindex`/`keys`, `first(s,n)`, `last(s,n)`.
- `s[k]` (a `Char`) and `s[k:k]` (a `String`) are different things.
- `iterate(s)`, `iterate(s, i)`; `Unicode.graphemes(s)` and
  `graphemes(s, m:n)` for grapheme clusters (UAX #29).
  (`docs.julialang.org/en/v1/manual/strings/`;
  `JuliaLang/julia base/strings/substring.jl:3-24`;
  `docs.julialang.org/en/v1/stdlib/Unicode/`)

Boundary / validity:

- `isvalid(s, i)` — O(1) "is `i` a char-start index", assumes a
  self-synchronizing encoding.
- `isvalid(c)`, `isvalid(T, value)`, `ismalformed(c)`, `isoverlong(c)`.
- `thisind(s, i)` — rewind to the start of the char containing `i`.
- `nextind(s, i, n=1)`, `prevind(s, i, n=1)` — step to neighbouring char starts.
- `get(s, i, default)` — non-throwing indexed access.
  (`JuliaLang/julia base/strings/basic.jl:110-142`; `base/char.jl`;
  `docs.julialang.org/en/v1/base/strings/`)

Operations: `findfirst`, `findlast`, `findnext`, `findprev`, `occursin`,
`replace`, `split`/`rsplit`/`eachsplit`/`eachrsplit`, `join`, `repeat`/`^`,
`strip`/`lstrip`/`rstrip`, `chop`, `chomp`, `startswith`, `endswith`,
`contains`, `uppercase`/`lowercase`/`titlecase`/`uppercasefirst`/`lowercasefirst`,
`cmp`/`isless`/`==`/`hash`, `reverse`/`reverseind`.
(`docs.julialang.org/en/v1/base/strings/`)

Byte ↔ text bridge: `codeunit`/`codeunits`, `Vector{UInt8}(s)`,
`String(v::Vector{UInt8})`, `String(s::SubString{String})`, `unsafe_string`,
`pointer`, `transcode`, `b"…"` byte-array literals, `IOBuffer(str)`.
(`JuliaLang/julia base/strings/string.jl`;
`base/strings/basic.jl:807-825`; `base/strings/cstring.jl:129-160`;
`base/strings/io.jl`)

## 4. Error representation

Exceptions — Julia has no error codes or `Result` for strings:

- `StringIndexError(str, i)` — in-bounds index that is **not** a character
  start. Its `showerror` prints the invalid index *and valid nearby indices*,
  e.g. `invalid index [2], valid nearby indices [1]=>'∀', [4]=>' '`.
  (`JuliaLang/julia base/strings/string.jl`, `StringIndexError`)
- `BoundsError` — index outside `1 ≤ i ≤ ncodeunits(s)` (or a range outside).
  `str[begin-1]` → `BoundsError: attempt to access 14-codeunit String at index [0]`.
  (`docs.julialang.org/en/v1/manual/strings/`;
  `JuliaLang/julia base/strings/basic.jl`, `checkbounds`)
- `ArgumentError` — e.g. `ascii()` on non-ASCII ("invalid ASCII at index 6"),
  negative `repeat`, `map(f,s)` where `f` does not return a `Char`, bad escape
  sequences in `unescape_string`.
  (`JuliaLang/julia base/strings/util.jl:1318-1336`, `repeat`; `base/char.jl`; `base/strings/io.jl`)
- `CodePointError` / `InvalidCharError` — invalid codepoint conversion,
  malformed `Char`. (`JuliaLang/julia base/char.jl`)
- `OutOfMemoryError` — overflow in `repeat` size computation.
  (`JuliaLang/julia base/strings/string.jl`, `repeat`)

Non-throwing alternatives: `get(s, i, default)`, `isvalid`, `try`-free
search (`findfirst` returns `nothing`), `match(r,s)` returns `nothing`.
(`docs.julialang.org/en/v1/base/strings/`)

Two distinct failure kinds for the *same* lookup is the design point: bounds
(byte range) and validity (character boundary) are separate errors.

## 5. Ownership semantics

- `String` is **immutable**; "the value of an `AbstractString` object cannot be
  changed. To construct a different string value, you construct a new string
  from parts of other strings." Memory is GC-managed.
  (`docs.julialang.org/en/v1/manual/strings/`)
- `SubString{T}` **borrows**: it stores `(string, offset, ncodeunits)` and does
  not copy; the parent stays alive through the reference. Slices made via
  `s[i:j]` **copy**, while `SubString`/`@views` do not.
  (`JuliaLang/julia base/strings/substring.jl:3-24`;
  `docs.julialang.org/en/v1/manual/strings/`)
- `String(v::Vector{UInt8})` **takes ownership**: "If `v` is a `Vector{UInt8}`
  it will be truncated to zero length and future modification of `v` cannot
  affect the contents"; zero-copy for `take!(io)`/`read(io,nb)` buffers.
  (`JuliaLang/julia base/strings/string.jl`, `String(v)` docstring)
- `String(s::SubString{String})` **copies** the parent region.
  (`JuliaLang/julia base/strings/substring.jl`)
- `codeunits(s)` is a **non-copying** wrapper; `Vector{UInt8}(s)` copies.
  (`JuliaLang/julia base/strings/basic.jl:807-825`)
- `StringView` borrows an *external mutable* array and "does not take ownership
  of or modify the array"; later mutation of the array is visible in the view.
  (`github.com/JuliaStrings/StringViews.jl` README;
  `JuliaLang/julia master base/strings/string.jl`, `StringView` docstring)
- Unsafe escape hatches, no ownership tracking: `pointer(s)`, `unsafe_string`,
  `unsafe_wrap`, `unsafe_takestring`. (`JuliaLang/julia base/strings/string.jl`)

(Assessment: derived from the sources above — Julia's ownership is GC-based;
"borrowed" is a plain reference, not a lifetime-checked type.)

## 6. Blocking / non-blocking

- String values and all string operations are **pure, synchronous, in-memory,
  CPU-bound**; there is no async/non-blocking variant of indexing, slicing,
  search or concatenation. (`docs.julialang.org/en/v1/base/strings/`)
- Only **I/O** is potentially blocking; Julia's concurrency model is tasks
  (`@async`, `Task`, `Channel`, `@spawn`), not callback/promise strings.
  (`docs.julialang.org/en/v1/manual/asynchronous-programming/`)
- `LazyString` defers *construction/printing* work rather than doing I/O
  asynchronously; it is documented as safe when printed from multiple tasks.
  (`JuliaLang/julia base/strings/lazy.jl:1-65`)
- `IOBuffer`/`sprint` build strings synchronously; no builder API returns a
  future. (`JuliaLang/julia base/strings/io.jl`, `sprint`)

(Assessment: derived from the sources above — the "blocking" axis is nearly
vacuous for a value-type string; it matters only at the IO boundary.)

## 7. Text model (encoding, length, indexing)

**What a "character" is.** Julia distinguishes three layers and does *not*
conflate them:

- **Byte / code unit.** `String` is stored as UTF-8 bytes; the code unit is
  `UInt8`. `codeunit(s, i)` and `codeunits(s)` expose bytes; `ncodeunits`/
  `sizeof` count them. (`JuliaLang/julia base/strings/basic.jl:45-106,807-825`)
- **Codepoint.** `Char` is "a 32-bit primitive type that can represent any
  Unicode character"; it is the element type of `String` and of iteration.
  A `Char` is a *superset* of Unicode: it can losslessly hold malformed and
  overlong UTF-8 sequences. (`JuliaLang/julia base/char.jl:5-47`;
  `docs.julialang.org/en/v1/manual/strings/`)
- **Grapheme cluster.** Not the default. Only `Unicode.graphemes(s)` yields
  extended graphemes (Unicode UAX #29); `length` on that iterator counts them,
  `graphemes(s, m:n)` slices by grapheme number.
  (`docs.julialang.org/en/v1/stdlib/Unicode/`;
  `JuliaLang/julia base/strings/unicode.jl`, `GraphemeIterator`)

So in Julia "one character" in the plain reading = **one Unicode codepoint**,
except that a `Char` may also carry invalid bytes.

**Encoding.** UTF-8 is the default and the only built-in encoding; other
encodings are package territory (LegacyStrings) or via `transcode`.
(`docs.julialang.org/en/v1/manual/strings/`;
`JuliaLang/julia base/strings/cstring.jl:129-160`)

**Length is deliberately plural:**

| function | counts | source |
| --- | --- | --- |
| `ncodeunits(s)` | code units (bytes) | `basic.jl:45-67` |
| `sizeof(s)` | bytes = `ncodeunits × sizeof(codeunit)` | `basic.jl:163-177` |
| `length(s)` | characters / codepoints — **O(n)** | `basic.jl:367-395` |
| `Unicode.textwidth(s)` | printed columns | `unicode.jl:277-287` |

`length("∀") == 1` but `sizeof("∀") == 3`; `textwidth("⛵") == 2`.
(`docs.julialang.org/en/v1/base/strings/`; `unicode.jl:251-264`)

**Indexing/slicing position.** A string index is a **1-based byte index**
(`firstindex` always `1`), and it is only *valid* if it is the first code unit
of a character:

- `s[i]` → `Char` (errors unless `i` is a char-start).
- `s[i:j]` → `String` **copy**, both endpoints must be char-starts.
- `SubString(s,i,j)` / `@views s[i:j]` → borrowed view.
- `lastindex(s) = thisind(s, ncodeunits(s))`, so `length(s) ≤ lastindex(s)`.
- `str[6]` is a `Char`; `str[6:6]` is a `String`.
  (`docs.julialang.org/en/v1/manual/strings/`;
  `JuliaLang/julia base/strings/basic.jl:367-395`;
  `base/strings/substring.jl:3-24`)

Walking valid positions: `nextind`, `prevind`, `thisind`, `eachindex`/`keys`
(a string's `keys` is `EachStringIndex`, yielding only valid char indices).
Example: `collect(eachindex("∀ x ∃ y")) == [1, 4, 5, 6, 7, 10, 11]`.
(`docs.julialang.org/en/v1/manual/strings/`;
`JuliaLang/julia base/strings/basic.jl`, `EachStringIndex`)

## 8. Bounds, invalid input and errors

- **Out-of-range index** → `BoundsError`; `checkbounds` only tests
  `1 ≤ i ≤ ncodeunits(s)`, i.e. byte range, not character boundary.
  (`JuliaLang/julia base/strings/basic.jl`, `checkbounds`;
  `docs.julialang.org/en/v1/manual/strings/`)
- **In-range non-boundary index** → `StringIndexError`, not `BoundsError`; the
  message lists valid nearby indices. `s[2]` on `"∀ …"` throws; `isvalid(s,2)`
  is `false` and O(1) because UTF-8 is self-synchronizing.
  (`JuliaLang/julia base/strings/basic.jl:110-142`; `base/strings/string.jl`)
- **Slicing on a non-boundary** → `StringIndexError` from both endpoints.
  `s[1:2]` on `"∀ …"` throws; `s[1:1]` and `s[1:4]` are fine.
  (`docs.julialang.org/en/v1/manual/strings/`)
- **Index arithmetic is relaxed, not strict**: `thisind`, `nextind`, `prevind`
  "give you the closest valid string index when in-bounds, or when
  out-of-bounds, behave as if there were an infinite number of characters
  padding each side". They can return `0`, `ncodeunits+1`, or even negative /
  larger values as intermediate results — only *retrieving a character* with
  them may throw. (`JuliaLang/julia base/strings/basic.jl:5-40`;
  `thisind`/`prevind`/`nextind` docstrings)
- **Empty / zero-length edges**: `firstindex("") == 1`, `sizeof("") == 0`,
  `length("") == 0`, `thisind("", 0) == 0`, so `lastindex("") == 0`; `getindex`
  of an empty range returns `""`; `SubString` with `i > j` is built as the
  empty substring `(s, 0, 0)`. (Assessment: derived from
  `basic.jl` `firstindex`/`thisind` and `substring.jl`
  `i ≤ j || return new(s, 0, 0)`.)
- **Invalid UTF-8 input is allowed, not rejected**: `String` "can be composed
  of any byte sequence"; `isvalid("DATA\xff…") == false`; overlong and too-high
  sequences are decoded as a single invalid character each; concatenation of
  invalid strings can *merge* bytes into a different character.
  (`docs.julialang.org/en/v1/manual/strings/`;
  `JuliaLang/julia base/strings/string.jl`, `byte_string_classify`)
- **`raw_substring(s, first, n)`** skips the boundary check on purpose: it may
  produce truncated characters — "safe and well-defined for `String`,
  `StringView`, and substrings of these", but accessing a truncated char can
  still throw `StringIndexError`. (`JuliaLang/julia master base/strings/substring.jl`)
- Non-throwing access: `get(s, i, default)`. (`basic.jl`)
- `ascii(s)` converts and *validates* ASCII, throwing `ArgumentError` with the
  byte position of the first non-ASCII byte. (`util.jl:1318-1336`)

## 9. Owned type, borrowed view and builder layer

| layer | Julia provides | source |
| --- | --- | --- |
| owned | `String` (immutable, GC-managed, UTF-8, may hold invalid bytes) | `string.jl` |
| borrowed | `SubString{T}` (`parent` + `offset` + `ncodeunits`), `@views`, `view(s,r)`; `Base.StringView` in 1.14 for arbitrary byte vectors | `substring.jl:3-24`; `StringViews.jl` README |
| builder | **no dedicated type in Base** — `IOBuffer` + `sprint` + `print`/`write`, plus `replace(io, …)` and `join` over `IO`; community `StringBuilders.jl` wraps `IOBuffer` | `io.jl`, `sprint`; `StringBuilders.jl` README |
| byte ↔ text bridge | `codeunit(s,i)`, `codeunits(s)::CodeUnits{UInt8,String} <: DenseVector{UInt8}`, `Vector{UInt8}(s)`, `String(v::Vector{UInt8})`, `String(s::SubString)`, `b"…"`, `pointer`, `unsafe_string`, `transcode` | `basic.jl:807-825`; `string.jl`; `cstring.jl:129-160` |

Builder details:

- `IOBuffer()` is a growable byte buffer used with `write`/`print`;
  `String(take!(io))` flushes and resets, and `takestring!(io)` is the
  preferred non-copying extraction ("Return the content of `io` as a `String`,
  resetting the buffer"; Julia 1.13). (`io.jl`; `iobuffer.jl:808-831`)
- `sprint(f, args...; sizehint)` calls `f(io, args...)` and returns what was
  written — the idiomatic "build a string from a function".
  (`JuliaLang/julia base/strings/io.jl`, `sprint`)
- `join` is implemented over `IO` and can write into a caller's buffer.
  (`io.jl`, `join`)
- `StringBuilders.StringBuilder` keeps `(buffer::IOBuffer, as_string)`, caches
  `String(sb)`, and **does not reset** on `String(sb)` — the opposite of
  `take!`; `append!` accepts any `AbstractString`.
  (`StringBuilders.jl src/StringBuilders.jl`)

`SubString` notes that matter for a Mojo design: slicing a `SubString` of a
`SubString` is flattened back onto the original parent, and
`SubString{String}` can be passed to C without copying via `cconvert`.
(`substring.jl`)

## 10. Interesting design decisions

1. **Indexing that refuses to split a codepoint.** Byte-indexed but
   boundary-checked: `s[i]` throws on a non-boundary, so the representation
   stays cheap while the API never hands out a broken character. This is the
   sharpest contrast to Python/JS and the most relevant reference for Mojo.
   (`basic.jl:5-40`; manual Strings)
2. **Two error kinds, cleanly split**: `BoundsError` (byte range) vs
   `StringIndexError` (character boundary), the latter reporting nearby valid
   indices. (`string.jl`, `StringIndexError`)
3. **`Char` as a lossless superset of Unicode** (32-bit, can hold malformed
   and overlong encodings; `ismalformed`/`isoverlong`; `codepoint` may throw).
   (`char.jl`)
4. **Relaxed index arithmetic** (`thisind`/`nextind`/`prevind`) that tolerates
   out-of-range intermediate indices, so callers avoid edge-case code.
   (`basic.jl:5-40`)
5. **Three honest length functions** (`ncodeunits`/`length`/`textwidth`) with
   `sizeof` as the byte alias, instead of one ambiguous `.length`.
   (`basic.jl`; `unicode.jl`)
6. **`SubString` as parent+offset+length**, flattened on re-slicing, and
   C-passable without a copy. (`substring.jl`)
7. **`@views`** — an opt-in macro that turns every `s[i:j]` in a block into a
   `SubString`, i.e. one syntactic switch between copying and borrowing.
   (`docs.julialang.org/en/v1/manual/strings/`)
8. **`b"…"` byte-array literals** and the explicit distinction between `\xff`
   (one byte) and `\uff` (a codepoint, two bytes) — a precise byte↔text bridge.
   (manual Strings)
9. **Generic `AbstractString` interface** built on five primitives
   (`ncodeunits`, `codeunit`, `isvalid`, `iterate`, `thisind`/`nextind`/
   `prevind`), which is what lets other encodings plug in via LegacyStrings.
   (`basic.jl:5-40`)
10. **`LazyString`** — interpolation is captured but printing deferred, cheap
    in error paths and concurrency-safe. (`lazy.jl:1-65`)
11. **InlineStrings** — fixed-capacity, stack-allocated strings with a
    C-compatible layout and radix-sort integration. (`InlineStrings.jl` README)
12. **`Unicode.textwidth`** — display width as a first-class measurement,
    driving `lpad`/`rpad`/`ltruncate` (changed to width-based in 1.7).
    (`unicode.jl`; `util.jl:483-497,603-625`)

## 11. Decisions NOT to copy

- **`length` being O(n).** The docstring itself notes it is linear "because it
  counts the value on the fly"; a Mojo string should expose the cheap byte
  length (`byte_length()`) and cache or document codepoint/grapheme counts.
  (`basic.jl:367-395`)
- **`lastindex`/`end-1` not being the "second-to-last character".** This is the
  classic trap (`s[end-2]` can throw); Mojo's `count_*` + explicit boundary
  helpers are clearer. (`docs.julialang.org/en/v1/manual/strings/`)
- **Allowing invalid UTF-8 in the general `String` type as the default model.**
  Mojo enforces UTF-8 validity at construction; a Mojo `string` library should
  keep that guarantee and offer an *explicit* lossless/raw path instead of
  silently carrying invalid data (Julia's `Char` complexity follows from this).
  (`string.jl` `String` docstring; `mojo.md` gap premise)
- **Three-way `Char` machinery** (`ismalformed`, `isoverlong`,
  `unsafe_codepoint`, `decode_overlong`, superset codepoints). Correct, but a
  large complexity tax; Mojo's `Codepoint` does not need it unless raw bytes
  must round-trip losslessly. (`char.jl`)
- **Relaxed index arithmetic returning out-of-range values** (`0`, negative,
  `> ncodeunits`) as normal intermediate results — error-prone for callers.
  (`basic.jl` `prevind`/`nextind` docstrings)
- **`SubString{SubString{T}}` and flattening semantics** — nesting and
  flattening add type-level and reasoning cost; a single concrete view type
  (parent + offset + length) is simpler. (`substring.jl`)
- **`*` as the concatenation operator and `^` for repeat** — surprising for
  anyone coming from `+`; Mojo already uses `+`/`*`, so do not import Julia's
  choice. (`docs.julialang.org/en/v1/manual/strings/`)
- **Views over externally-mutable arrays** (`StringView` reflecting later
  mutation) — aliasing surprises; a Mojo borrowed view should be tied to a
  known-immutable owner or to an explicit lifetime. (`StringViews.jl` README)
- **Huge generic `AbstractString` surface** — implementing a new string type
  means satisfying a long method list; a smaller Mojo trait/interface is
  preferable. (`basic.jl:5-40`)
- **No builder in Base.** Relying on `IOBuffer`/`sprint` means the builder API
  is "whatever `IO` happens to support"; a Mojo library should ship an explicit
  append/flush builder. (`io.jl`; `StringBuilders.jl` README)

## 12. Ideas fitting Mojo

- **Boundary-safe indexing as the core value-add.** Provide
  `next_index`/`prev_index`/`index_of_char` analogues of `nextind`/`prevind`/
  `thisind` and an O(1) `is_boundary(s, i)`, so callers never split a codepoint
  — Mojo already has the UTF-8 substrate (`StringSpan`, `codepoints()`), but
  the buch does not document this index-arithmetic layer (`mojo.md`).
  (`basic.jl:110-142`)
- **A concrete borrowed slice type** (parent + offset + byte length) over
  `String`/`StringSpan`, with explicit `view`-like construction, instead of
  relying on implicit slicing — mirroring `SubString` but single-type.
  (`substring.jl:3-24`)
- **`codeunit`/`codeunits` bridge**: expose raw bytes as a borrowable buffer
  view and `from_utf8`/`unsafe_from_utf8`-style zero-copy adoption, with an
  explicit ownership contract like `String(v::Vector{UInt8})` (truncate vs
  copy). (`string.jl`; `basic.jl:807-825`)
- **A real builder**: `StringBuilder`/`StringWriter` with `append`, `write`,
  `finish`/`take`, modelled on `IOBuffer` + `takestring!` but with the
  explicit append/flush contract the Mojo stdlib lacks (`mojo.md`). Borrow
  `StringBuilders.jl`'s cached-`String`/no-reset detail as an option, not the
  default. (`io.jl`; `StringBuilders.jl`)
- **Non-raising accessors beside raising ones**: `char_at(s, i)` that raises vs
  `try_char_at`/`get(s,i,default)` equivalents — Mojo's `raises` makes this
  distinction explicit and cheap. (`basic.jl`, `get`)
- **A distinct boundary error** (analogue of `StringIndexError`) separate from
  an out-of-range error, carrying the nearest valid indices — directly useful
  diagnostics for a low-vision user. (`string.jl`)
- **`text_width`** as a display measurement, if MojoAkku ever does terminal or
  HTML layout; it is currently absent from the Mojo string family.
  (`unicode.jl`; `mojo.md`)
- **Keep the three counts explicit** and align names with Mojo's existing
  `byte_length()`/`count_codepoints()`/`count_graphemes()`, adding only what is
  missing (e.g. display width), rather than a single `length`. (`mojo.md`)
- **Grapheme iteration is already Mojo's default** (1.0), so the library adds
  *navigation and slicing* on graphemes (a `graphemes(s, m:n)` analogue)
  rather than a new iteration model. (`mojo.md`; Unicode stdlib `graphemes(s,m:n)`)

## Sources

- Julia manual, Strings — https://docs.julialang.org/en/v1/manual/strings/
- Julia Base reference, Strings — https://docs.julialang.org/en/v1/base/strings/
- Julia stdlib `Unicode` — https://docs.julialang.org/en/v1/stdlib/Unicode/
- Julia manual, Asynchronous Programming —
  https://docs.julialang.org/en/v1/manual/asynchronous-programming/
- Julia source `base/strings/basic.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/basic.jl
  (line anchors from docs source links at commit `d1c37793`)
- Julia source `base/strings/string.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/string.jl
- Julia source `base/strings/substring.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/substring.jl
- Julia source `base/strings/io.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/io.jl
- Julia source `base/strings/lazy.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/lazy.jl
- Julia source `base/strings/unicode.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/unicode.jl
- Julia source `base/strings/util.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/util.jl
- Julia source `base/strings/cstring.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/strings/cstring.jl
- Julia source `base/char.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/char.jl
- Julia source `base/iobuffer.jl` —
  https://github.com/JuliaLang/julia/blob/master/base/iobuffer.jl
- Julia PR 60526 (`StringView` merged for 1.14) —
  https://github.com/JuliaLang/julia/pull/60526
- StringViews.jl — https://github.com/JuliaStrings/StringViews.jl
- InlineStrings.jl — https://github.com/JuliaStrings/InlineStrings.jl
- StringBuilders.jl — https://github.com/davidanthoff/StringBuilders.jl
- LegacyStrings.jl — https://github.com/JuliaStrings/LegacyStrings.jl
- Unicode Standard Annex #29 (grapheme clusters) —
  https://www.unicode.org/reports/tr29/
- GitHub repo metadata (maintainer/licence/activity) —
  https://api.github.com/repos/JuliaStrings/StringViews.jl,
  https://api.github.com/repos/JuliaStrings/InlineStrings.jl,
  https://api.github.com/repos/davidanthoff/StringBuilders.jl,
  https://api.github.com/repos/JuliaStrings/LegacyStrings.jl
- Mojo gap premise — `mojoakku/text_string/_dev/mojo.md`
