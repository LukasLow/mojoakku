# string research: C++

## 1. Standard library support

C++ added the **owned string type** that C lacks, and later the **borrowed
view**:

- `std::basic_string<CharT, Traits, Allocator>` (typedefs `std::string`,
  `std::wstring`, `std::u8string` C++20, `std::u16string`/`std::u32string`
  C++11, and the `std::pmr::*` variants C++17). Source:
  <https://en.cppreference.com/w/cpp/string/basic_string>.
- `std::basic_string_view<CharT, Traits>` (C++17; `std::string_view`,
  `std::wstring_view`, `std::u8string_view` C++20, `std::u16string_view`,
  `std::u32string_view`). Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.
- `std::char_traits<CharT>` — the traits class parameterising both, abstracting
  the character operations (`assign`, `eq`, `lt`, `compare`, `length`, `find`,
  `copy`, `move`, `to_int_type`, …). Source:
  <https://en.cppreference.com/w/cpp/string/char_traits>.

`basic_string` is a *class template* over the character type, not a fixed type:
"The class is dependent neither on the character type nor on the nature of
operations on that type. The definitions of the operations are supplied via
the `Traits` template parameter." Source:
<https://en.cppreference.com/w/cpp/string/basic_string>.

Key structural promise (since C++11): elements are stored **contiguously** and
`*(s.begin() + s.size())` has value `CharT()` — i.e. `std::string` is
**null-terminated**, so `c_str()`/`data()` are directly usable by C APIs.
Source: <https://en.cppreference.com/w/cpp/string/basic_string>.

C++ also keeps the whole C library (`<cstring>`, `<cctype>`, `<cwchar>`,
`<cuchar>`) and adds:

- `<charconv>`: `std::to_chars` / `std::from_chars` (C++17), locale-independent,
  non-allocating, non-throwing numeric conversions. Source:
  <https://en.cppreference.com/w/cpp/utility/from_chars>.
- `<format>`: `std::format` (C++20), `std::format_to`, `std::vformat`
  (compile-time-checked format strings since P2216R3). Source:
  <https://en.cppreference.com/w/cpp/utility/format/format>.

(Assessment: derived from the above — C++'s stdlib supplies all three layers
in §9 except a builder.)

## 2. Relevant community libraries

- **{fmt}** — the modern formatting library that inspired `std::format`; safe
  replacement for `printf`, compile-time format-string checking, portable
  Unicode support with UTF-8 and `char` strings, minimal allocations. Source:
  <https://fmt.dev/latest/index.html>.
- **ICU (ICU4C)** — C/C++ Unicode and globalization; `icu::UnicodeString`
  "stores Unicode characters directly and provides similar functionality as
  the Java String and StringBuffer/StringBuilder classes". Source:
  <https://unicode-org.github.io/icu/userguide/strings/>.
- **utf8proc** — C library (usable from C++) for UTF-8 normalization,
  case-folding and graphemes. Source:
  <https://github.com/JuliaStrings/utf8proc>.
- **Boost.StringAlgorithms** / **boost::algorithm** — the classic missing
  operations (trim, split, join, case, starts/ends-with) layered on
  `std::string`. (GUESS: no authoritative doc page fetched; the library exists
  in Boost, hence GUESS on the exact API list.)
- **Abseil (`absl::string_view`, `absl::StrCat`, `absl::StrSplit`)** — Google's
  pre-`std::string_view` view plus append/format helpers. (GUESS: same reason.)
- **`folly::fbstring`** — a 23-char-SSO string. Referenced from
  <https://www.reddit.com/r/cpp/comments/o2p92m/increase_the_size_of_the_small_buffer/>
  (community discussion) and the Folly docs path it cites
  (`folly/docs/FBString.md`).

## 3. Exposed APIs

`std::basic_string`, from
<https://en.cppreference.com/w/cpp/string/basic_string> unless noted:

**Element access** — `at(pos)` (bounds-checked, throws `std::out_of_range`),
`operator[](pos)` (unchecked), `front()`, `back()`, `data()`, `c_str()`,
`operator basic_string_view` (C++17). Sources:
<https://en.cppreference.com/w/cpp/string/basic_string/at>,
<https://en.cppreference.com/w/cpp/string/basic_string/operator_at>,
<https://en.cppreference.com/w/cpp/string/basic_string/c_str>.

**Capacity** — `empty()`, `size()`/`length()`, `max_size()`, `reserve()`,
`capacity()`, `shrink_to_fit()`. Sources:
<https://en.cppreference.com/w/cpp/string/basic_string/size>,
<https://en.cppreference.com/w/cpp/string/basic_string/capacity>.

**Search** — `find`, `rfind`, `find_first_of`, `find_first_not_of`,
`find_last_of`, `find_last_not_of`. Source:
<https://en.cppreference.com/w/cpp/string/basic_string>.

**Modifiers** — `clear`, `insert`, `insert_range` (C++23), `erase`,
`push_back`, `pop_back`, `append`, `append_range` (C++23), `operator+=`,
`replace`, `replace_with_range` (C++23), `copy`, `resize`,
`resize_and_overwrite` (C++23), `swap`. Source:
<https://en.cppreference.com/w/cpp/string/basic_string>;
<https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>.

**Operations** — `compare`, `starts_with` (C++20), `ends_with` (C++20),
`contains` (C++23), `substr`, `subview` (C++26), `npos`. Source:
<https://en.cppreference.com/w/cpp/string/basic_string>;
<https://en.cppreference.com/w/cpp/string/basic_string/npos>.

**Non-member** — `operator+`, `swap`, `erase`/`erase_if` (C++20),
`operator==`…`<=>` (C++20), I/O `operator<<`/`operator>>`, `getline`,
`to_string`/`to_wstring`, `stoi`/`stol`/`stoll`, `stoul`/`stoull`,
`stof`/`stod`/`stold`, `std::hash<std::basic_string>`, `operator""s`.
Source: <https://en.cppreference.com/w/cpp/string/basic_string>.

`std::basic_string_view`, from
<https://en.cppreference.com/w/cpp/string/basic_string_view> unless noted:

`size`/`length`, `max_size`, `empty`; `begin`/`end`/`rbegin`/`rend`;
`operator[]`, `at` (throws), `front`, `back`, `data`; `remove_prefix`,
`remove_suffix`, `swap`; `copy`, `substr`, `subview` (C++26), `compare`,
`starts_with` (C++20), `ends_with` (C++20), `contains` (C++23), `find`, `rfind`,
`find_first_of`, `find_last_of`, `find_first_not_of`, `find_last_not_of`,
`npos`; comparison operators; `std::hash<std::string_view>` (C++20);
`operator""sv`. Sources:
<https://en.cppreference.com/w/cpp/string/basic_string_view>,
<https://en.cppreference.com/w/cpp/string/basic_string_view/at>,
<https://en.cppreference.com/w/cpp/string/basic_string_view/substr>.

**Numeric** — `std::to_chars` / `std::from_chars`: "locale-independent,
non-allocating, and non-throwing", integer and floating-point, returns a
`to_chars_result`/`from_chars_result` with `ptr` + `std::errc`.
Sources: <https://en.cppreference.com/w/cpp/utility/from_chars>,
<https://en.cppreference.com/w/cpp/utility/to_chars>.

**Formatting** — `std::format` returns a `std::string` holding the formatted
result; format strings are compile-time checked via `std::format_string`; errors
in the format string are compile errors, runtime allocation failure throws
`std::bad_alloc`. Source:
<https://en.cppreference.com/w/cpp/utility/format/format>.

## 4. Error representation

C++ has **exceptions** and uses them where C used UB or `errno`:

- **Bounds-checked access throws `std::out_of_range`.** `basic_string::at`:
  "Throws `std::out_of_range` if `pos >= size()`", with the strong exception
  safety guarantee. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/at>.
  `basic_string_view::at` throws the same. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view/at>.
- **Substring / range positions throw.** `string::substr` throws
  `std::out_of_range` if `pos > size()`; the same for `string_view::substr`.
  Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/substr>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/substr>.
- **Length overflow throws `std::length_error`** (e.g. constructing a string
  longer than `max_size()`). Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/basic_string>,
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>.
- **`std::bad_alloc`** on allocation failure. Source:
  <https://en.cppreference.com/w/cpp/utility/format/format>.
- **Search returns a sentinel, not an error.** Not-found is
  `basic_string::npos` = `size_type(-1)`, "the maximum value representable by
  the type `size_type` … generally used either as end of string indicator … or
  as the error indicator by the functions that return a string index". Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/npos>.
- **`<charconv>` uses neither exceptions nor `errno`.** `from_chars` returns
  `std::from_chars_result{ptr, ec}` with `ec == std::errc::invalid_argument`
  (no match) or `std::errc::result_out_of_range` (pattern matched, value not
  representable), and `value` is left unmodified. `to_chars` returns
  `std::errc::value_too_large` on overflow. Both "throw nothing". Sources:
  <https://en.cppreference.com/w/cpp/utility/from_chars>,
  <https://en.cppreference.com/w/cpp/utility/to_chars>.
- **Format-string errors are compile-time.** "Since P2216R3, `std::format` does
  a compile-time check on the format string"; an invalid format string for the
  given argument types is a **compile error**, not `std::format_error` at
  runtime (the latter can still arise via `vformat`/`dynamic_format`). Source:
  <https://en.cppreference.com/w/cpp/utility/format/format>.
- **`operator[]` is not an error channel.** Out of range is UB (before C++26);
  from C++26, in a hardened implementation it is a contract violation. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/operator_at>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/operator_at>.

(Assessment: derived from the above — C++ offers a *choice* of error model per
call: `at` throws, `[]` is unchecked, `find` returns `npos`, `<charconv>`
returns an `errc`, and `format` rejects invalid input at compile time.)

## 5. Ownership semantics

- **`basic_string` owns and manages its buffer** via the `Allocator` template
  parameter; it is copyable and movable, and satisfies `AllocatorAwareContainer`,
  `SequenceContainer` and `ContiguousContainer`. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string>.
- **Move leaves the source "valid but unspecified".** For the moving
  constructors, "when the construction finishes, `other` is in a valid but
  unspecified state". The move constructor is `noexcept` (C++11). Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/basic_string>.
- **`string_view` is non-owning and does not extend lifetime.** "It is the
  programmer's responsibility to ensure that `std::string_view` does not outlive
  the pointed-to character array." The documented bad case:
  `std::string_view bad{"a temporary string"s};` dangles. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.
- **`string_view` is trivially copyable** — a `(pointer, size)` pair with no
  destructor, cheap to pass by value. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.
- **Invalidation is documented precisely.** Any non-const member (except
  `operator[]`, `at`, `data`, `front`, `back`, `begin`, `rbegin`, `end`, `rend`)
  may invalidate references/pointers/iterators into a `basic_string`. The
  `c_str()` pointer may be invalidated by the same operations; writing through
  `c_str()` is UB. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string>,
  <https://en.cppreference.com/w/cpp/string/basic_string/c_str>.
- **`resize_and_overwrite` hands the raw buffer to caller code** and requires
  the operation not to throw (throwing is UB). Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>.

(Assessment: derived from the above — C++ splits ownership into two types and
makes the view's non-ownership explicit but not enforced; dangling is a
contract the programmer must uphold.)

## 6. Blocking / non-blocking

All `basic_string`/`basic_string_view` operations are in-memory, synchronous
and non-blocking; none performs I/O. (Assessment: derived from the function
lists at <https://en.cppreference.com/w/cpp/string/basic_string> and
<https://en.cppreference.com/w/cpp/string/basic_string_view>.)

The C++-specific axes are:

- **No hidden global state.** Unlike C's `strtok`, there is no static tokenizer
  state; searching is const and reentrant. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string>.
- **Locale is opt-in.** `std::format` is locale-independent by default and
  takes `std::locale` only in the explicit overloads; `std::from_chars`/
  `to_chars` are locale-independent with no locale overload. Sources:
  <https://en.cppreference.com/w/cpp/utility/format/format>,
  <https://en.cppreference.com/w/cpp/utility/from_chars>.
- **Allocator calls may block** (a custom allocator can do anything), and
  `std::bad_alloc` propagates. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/basic_string>.
- **Thread-safety of the standard library**: `const` member functions are
  expected to be callable concurrently on the same object (the standard-library
  data-race rule); this is a library-wide guarantee, not a string-specific
  statement. (Assessment: derived from the C++ standard's general
  library thread-safety rule as applied by the const-correct
  `find`/`compare`/`size` API — no page was fetched stating it for
  `basic_string` verbatim, hence Assessment rather than a direct quote.)

## 7. Text model (encoding, length, indexing)

**What a "character" is: a `CharT` code unit — not a byte, not a codepoint,
not a grapheme.** `basic_string` "stores and manipulates sequences of
character-like objects"; `size()` "Returns the number of `CharT` elements in
the string". The cppreference page states the consequence explicitly for
`std::string`:

> For `std::string`, the elements are bytes (objects of type `char`), which are
> not the same as characters if a multibyte encoding such as UTF-8 is used.
> — <https://en.cppreference.com/w/cpp/string/basic_string/size>

**Encoding: not fixed by the type; supplied by the character type and traits.**
`char` = one byte (usually UTF-8 by convention), `wchar_t` = wide
(implementation-defined encoding), `char8_t` = UTF-8 code unit,
`char16_t`/`char32_t` = UTF-16/UTF-32 code unit. Sources:
<https://en.cppreference.com/w/cpp/string/basic_string>,
<https://en.cppreference.com/w/c/string/multibyte/char8_t> (C `char8_t` is
unsigned char; C++'s `char8_t` is the corresponding distinct type used by
`std::u8string`).

**Length is code units, and the manual example makes the disagreement
concrete:** the same 8-codepoint Japanese string is `size() == 8` as
`u32string` and `u16string`, but `size() == 24` as `std::string` and
`u8string` (3 UTF-8 bytes per codepoint). Source:
<https://en.cppreference.com/w/cpp/string/basic_string/size>.

**Indexing/slicing positions are code-unit offsets.** `operator[](pos)` and
`substr(pos, count)` are O(1) and count `CharT` elements; they have **no
awareness of codepoint or grapheme boundaries** in a UTF-8 `std::string`, so
a slice can split a multi-byte character. Sources:
<https://en.cppreference.com/w/cpp/string/basic_string/operator_at>,
<https://en.cppreference.com/w/cpp/string/basic_string/substr>.

**No codepoint or grapheme API in `basic_string`.** There is no
`codepoints()`, no `count_codepoints()`, no grapheme iterator in either
`basic_string` or `basic_string_view` (function lists: see §3 sources). This is
the sharpest contrast to Mojo, whose `count_codepoints()` /
`count_graphemes()` / grapheme-cluster iteration are first-class (source:
`mojov1/types/bool-and-strings`).

**Views define a position the same way.** `string_view` "describes an object
that can refer to a constant contiguous sequence of `CharT`"; `substr` returns
`[pos, pos + rlen)` with `rlen = min(count, size() - pos)`; `remove_prefix(n)` /
`remove_suffix(n)` move the window by `n` code units with no boundary check.
Sources: <https://en.cppreference.com/w/cpp/string/basic_string_view>,
<https://en.cppreference.com/w/cpp/string/basic_string_view/substr>.

**UTF-8 itself.** RFC 3629: 1–4 octets per character, U+0000..U+10FFFF,
ASCII-compatible, surrogate range forbidden. Source:
<https://www.rfc-editor.org/rfc/rfc3629.txt> (§3–§4).

## 8. Bounds, invalid input and errors

- **`operator[]` is unchecked (UB).** For `basic_string`: `pos == size()`
  returns a reference to `CharT()` (since C++11), but `pos > size()` is UB
  (until C++26; then a contract violation in hardened builds). For
  `string_view`: `pos < size()` false is UB (until C++26), and notably
  `operator[](size())` does **not** return `CharT()`. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/operator_at>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/operator_at>.
- **`at()` and `substr()` are checked and defined.** `at`: throws
  `std::out_of_range` if `pos >= size()`. `substr`: throws if `pos > size()`;
  if `count` extends past the end it is clamped to `[pos, size())` — no error.
  Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/at>,
  <https://en.cppreference.com/w/cpp/string/basic_string/substr>.
- **Slicing on a non-boundary is not detected.** `substr`/`remove_prefix` work
  on code units; in a UTF-8 `std::string` they can split a codepoint, and no
  diagnostic exists. (Assessment: derived from the code-unit semantics at
  <https://en.cppreference.com/w/cpp/string/basic_string/size> plus the
  absence of any boundary API in the function lists of §3.)
- **Invalid encoding is not a concept for `basic_string`.** The type does not
  validate UTF-8, so "invalid UTF-8 on input" is simply a byte sequence; the
  error surfaces only when a decoding layer (ICU, utf8proc, manual) is applied.
  (Assessment: derived from the fact that neither
  <https://en.cppreference.com/w/cpp/string/basic_string> nor
  <https://en.cppreference.com/w/cpp/string/basic_string_view> mentions
  validation, and from the `size()` note that `char` elements need not be
  characters.)
- **`nullptr` is rejected at compile time.** Since C++23,
  `basic_string(std::nullptr_t) = delete` and
  `basic_string_view(std::nullptr_t) = delete`; constructing from `nullptr`
  does not compile. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/basic_string>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/basic_string_view>.
- **String-view construction has UB preconditions.** Constructing a view from
  `(s, count)` is UB if `[s, s + count)` is not a valid range; from a
  C string it is UB if `[s, s + Traits::length(s))` is not valid. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view/basic_string_view>.
- **Embedded NULs.** `std::string` may contain `'\0'` and stores `size()`
  independently; but construction from a string literal stops at the first
  NUL unless the `(s, count)` constructor or `operator""s` is used. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/basic_string>.
- **Empty edges are defined.** `find` returns `0` for an empty needle at
  position `<= size()`; `substr(0)` is the whole string; `empty()` is `size()==0`;
  `remove_prefix(0)`/`remove_suffix(0)` are no-ops. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.
- **Numeric parse edges are explicit.** `from_chars`: no match ⇒
  `invalid_argument` and `value` unmodified; out of representable range ⇒
  `result_out_of_range`. `to_chars`: buffer too small ⇒ `value_too_large`.
  Sources: <https://en.cppreference.com/w/cpp/utility/from_chars>,
  <https://en.cppreference.com/w/cpp/utility/to_chars>.

(Assessment: derived from the above — C++ 17/20/23 progressively replaced C's
UB with defined, *choosable* behavior, but the codepoint/grapheme boundary case
remains unaddressed.)

## 9. Owned type, borrowed view and builder layer

- **Owned type: `std::basic_string`.** Owns, allocates, is mutable, contiguous
  and (since C++11) null-terminated, so it bridges to C directly via `c_str()`.
  Sources: <https://en.cppreference.com/w/cpp/string/basic_string>,
  <https://en.cppreference.com/w/cpp/string/basic_string/c_str>.
- **Borrowed view: `std::basic_string_view` (C++17).** A non-owning
  `(const_pointer, size)` pair describing a contiguous `CharT` sequence;
  trivially copyable; convertible from `std::basic_string`. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/basic_string_view>.
  A view over an *owned* string is obtained by the implicit
  `operator basic_string_view`. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string>.
- **Builder: no dedicated builder type.** `basic_string` itself is the builder:
  `append`, `operator+=`, `push_back`, `replace`, `insert`, `resize`,
  `reserve`, and C++23 `resize_and_overwrite` (which exposes the raw buffer to
  a user operation to avoid zero-initialising a large string before a C API
  fills it). `std::stringstream` is the stream-based alternative; {fmt}/
  `std::format`-to-iterator cover the format case. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>,
  <https://en.cppreference.com/w/cpp/string/basic_string>.
- **Byte ↔ text bridge.** `basic_string` supports per-character-type families
  (`string`/`wstring`/`u8string`/`u16string`/`u32string`), and conversion
  between them happens via constructors, `std::codecvt` (historically),
  `std::wstring_convert` (deprecated in C++17), or — practically — ICU/
  utf8proc. `resize_and_overwrite` is the explicit "raw byte buffer ↔ string"
  bridge. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>,
  <https://en.cppreference.com/w/cpp/string/basic_string>.

Contrast to Mojo: the owned/view split (`String`/`StringSpan`) matches exactly;
`basic_string` as its own builder matches the "no separate builder" option; but
C++ has **no codepoint/grapheme layer**, which Mojo already has.

## 10. Interesting design decisions

- **Small String Optimization (SSO).** Implementations store short strings
  inside the object without heap allocation. The threshold is
  implementation-specific: 15 (`libstdc++`/MSVC) or 22–23 (`libc++`); the
  cppreference capacity example prints `"" has capacity 15`, confirming 15 for
  libstdc++. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/capacity>;
  community references: <https://tc-imba.github.io/posts/cpp-sso/> (libstdc++
  `__min_cap = 15 / sizeof(value_type)`), <https://dbj.org/c-small-string-optimizations/>
  ("15 for MSVC and GCC and 23 for Clang"),
  <https://github.com/microsoft/STL/issues/295> ("libc++'s implementation …
  stores up to 22 characters instead of 15"). (Assessment: the *existence* of
  SSO is universal; the exact number is not standardized and must not be relied
  on.)
- **`basic_string` is not `std::vector<char>`.** It carries the null
  terminator, C-interop (`c_str`), string-specific algorithms and SSO; the
  standard explicitly maintains the C-contiguity guarantee. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string>.
- **The view/owned split predates `std::span`.** `string_view` (C++17) is the
  string-shaped view; `std::span<const char>` (C++20) is the generic one.
  Source: <https://en.cppreference.com/w/cpp/string/basic_string_view> (See
  also `span`).
- **Traits-class parameterization.** `char_traits` allows case-insensitive or
  otherwise customised comparison without a new string type — the cppreference
  example implements a `ci_char_traits` and uses
  `traits_cast<ci_char_traits>(s1)`. Source:
  <https://en.cppreference.com/w/cpp/string/char_traits>.
- **Search returns an index sentinel (`npos`) rather than an iterator or an
  optional.** Source: <https://en.cppreference.com/w/cpp/string/basic_string/npos>.
- **`npos` doubles as "to the end".** `substr(pos, npos)` and
  `basic_string(s, pos, npos)` mean "all the way to the end" — one sentinel,
  two meanings. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/npos>,
  <https://en.cppreference.com/w/cpp/string/basic_string/substr>.
- **Compile-time format strings.** `std::format` (and {fmt}) turn an invalid
  format string into a compile error, moving a classic C runtime vulnerability
  to build time. Sources:
  <https://en.cppreference.com/w/cpp/utility/format/format>,
  <https://fmt.dev/latest/index.html>.
- **`resize_and_overwrite` as an escape hatch.** It lets a `std::string` be
  filled by a C API without paying for zero-initialization, at the price of a
  strict no-throw contract and UB if `r ∉ [0, count]`. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>.
- **`char8_t` got its own type (C++20)** so that UTF-8 data is distinguishable
  from "ordinary" `char` at the type level, and `u8string` has it. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string> (typedef table);
  cf. <https://en.cppreference.com/w/c/string/multibyte/char8_t>.
- **Locale-independent core, locale-aware opt-in.** `from_chars`/`to_chars`
  and default `std::format` never touch the locale; only the explicit
  `std::format(const std::locale&, …)` overloads do. Sources:
  <https://en.cppreference.com/w/cpp/utility/from_chars>,
  <https://en.cppreference.com/w/cpp/utility/format/format>.

## 11. Decisions NOT to copy

- **Code-unit length semantics with no boundary safety.** `size()` on a UTF-8
  `std::string` counting bytes, and `substr`/`remove_prefix` slicing through
  codepoints without a check, is exactly the trap Mojo's grapheme-aware 1.0
  design avoids. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/size>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/substr>;
  contrast `mojov1/types/bool-and-strings`.
- **`npos` as a dual-purpose sentinel (index + end-of-string).** A single magic
  value meaning both "not found" and "all the way to the end" is hard to read;
  an explicit `Optional`/range end is clearer. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/npos>.
- **Out-of-range `operator[]` as UB.** The checked/unchecked pair
  (`at` vs `[]`) forces the caller to remember which is which; a single defined
  behavior is safer. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/operator_at>,
  <https://en.cppreference.com/w/cpp/string/basic_string/at>.
- **Dangling views left to programmer discipline.** `string_view` lifetime is
  unenforced; Mojo's `StringSpan` should keep the same borrow discipline but
  document the boundary explicitly, and the library must not hand out views
  that outlive their owner. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.
- **No grapheme/codepoint API.** C++ leaves all Unicode segmentation to third
  parties; Mojo already has `count_codepoints()`, `count_graphemes()` and
  grapheme iteration, so the library must not regress to byte-only operations.
  Source: function lists in §3 vs `mojov1/types/bool-and-strings`.
- **`resize_and_overwrite`'s no-throw UB contract.** Exposing a raw buffer with
  "throwing is UB" is not a contract for a predictable, low-vision-user API.
  Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>.
- **Implementation-defined SSO thresholds leaking into reasoning.** The exact
  15/22/23 number is not portable; an API must not promise SSO behavior.
  Sources: <https://en.cppreference.com/w/cpp/string/basic_string/capacity>,
  <https://dbj.org/c-small-string-optimizations/>.
- **`char_traits` as the extension point.** Requiring a traits class to change
  comparison semantics is heavier than a named function/parameter; Mojo's
  explicit functions are easier to read. Source:
  <https://en.cppreference.com/w/cpp/string/char_traits>.

## 12. Ideas fitting Mojo

- **The owned/view split is confirmed as the right shape.** `std::string` +
  `std::string_view` maps directly onto Mojo's `String` + `StringSpan`; the
  C++ experience says the view must be cheap to copy and implicitly convertible
  from the owned type. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>,
  <https://en.cppreference.com/w/cpp/string/basic_string>; gap reference
  `mojov1/types/bool-and-strings`.
- **Everyday operations already have canonical names to mirror.**
  `starts_with`, `ends_with`, `contains`, `find`, `rfind`, `substr` come
  straight from `basic_string`/`basic_string_view` — the naming for
  `mojoakku/string`'s search/split/replace/trim layer should follow these
  (`mojoakku/string/_dev/mojo.md` lists these as the gap). Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.
- **Checked and unchecked access, both available and named.**
  `at` (defined, throws) next to `[]` (raw) is a useful pattern — Mojo can offer
  a defined `char_at`/`byte_at` pair instead of one ambiguous operator.
  Sources: <https://en.cppreference.com/w/cpp/string/basic_string/at>,
  <https://en.cppreference.com/w/cpp/string/basic_string/operator_at>.
- **Clamping slice semantics.** `substr` clamping `count` to the remaining
  length (instead of erroring or panicking) is a good, forgiving default for
  the slice API. Sources:
  <https://en.cppreference.com/w/cpp/string/basic_string/substr>,
  <https://en.cppreference.com/w/cpp/string/basic_string_view/substr>.
- **Locale-independent conversions by default.** `from_chars`/`to_chars` are
  the model for Mojo's numeric↔text bridge: no allocation, no exceptions, a
  result carrying `(consumed, error)`. Source:
  <https://en.cppreference.com/w/cpp/utility/from_chars>.
- **Compile-time format checking.** {fmt}/`std::format` show that a
  format-string API can reject invalid format strings at compile time; Mojo's
  `TString` (`t"…"`) is the analogous lazy, checked facility. Sources:
  <https://en.cppreference.com/w/cpp/utility/format/format>,
  <https://fmt.dev/latest/index.html>; `mojov1/types/bool-and-strings`.
- **A builder-shaped `resize_and_overwrite` pattern.** The idea of exposing the
  buffer to a fill operation without pre-initializing is worth keeping, but with
  a *defined* error contract rather than UB — this is the gap
  `mojoakku/string/_dev/mojo.md` records for the builder layer. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>.
- **Views must document lifetime at the boundary.** C++'s
  dangling-`string_view` warning is the precedent for the byte↔text bridge
  rules the Mojo library must state. Source:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>.

## Sources

- `std::basic_string`:
  <https://en.cppreference.com/w/cpp/string/basic_string>
- `std::basic_string_view`:
  <https://en.cppreference.com/w/cpp/string/basic_string_view>
- `std::char_traits`: <https://en.cppreference.com/w/cpp/string/char_traits>
- `basic_string::at`:
  <https://en.cppreference.com/w/cpp/string/basic_string/at>
- `basic_string::operator[]`:
  <https://en.cppreference.com/w/cpp/string/basic_string/operator_at>
- `basic_string::size`/`length`:
  <https://en.cppreference.com/w/cpp/string/basic_string/size>
- `basic_string::capacity`:
  <https://en.cppreference.com/w/cpp/string/basic_string/capacity>
- `basic_string::c_str`:
  <https://en.cppreference.com/w/cpp/string/basic_string/c_str>
- `basic_string::npos`:
  <https://en.cppreference.com/w/cpp/string/basic_string/npos>
- `basic_string::substr`:
  <https://en.cppreference.com/w/cpp/string/basic_string/substr>
- `basic_string::resize_and_overwrite`:
  <https://en.cppreference.com/w/cpp/string/basic_string/resize_and_overwrite>
- `basic_string` constructors:
  <https://en.cppreference.com/w/cpp/string/basic_string/basic_string>
- `basic_string_view::at`:
  <https://en.cppreference.com/w/cpp/string/basic_string_view/at>
- `basic_string_view::operator[]`:
  <https://en.cppreference.com/w/cpp/string/basic_string_view/operator_at>
- `basic_string_view::substr`:
  <https://en.cppreference.com/w/cpp/string/basic_string_view/substr>
- `basic_string_view` constructors:
  <https://en.cppreference.com/w/cpp/string/basic_string_view/basic_string_view>
- `std::from_chars`: <https://en.cppreference.com/w/cpp/utility/from_chars>
- `std::to_chars`: <https://en.cppreference.com/w/cpp/utility/to_chars>
- `std::format`: <https://en.cppreference.com/w/cpp/utility/format/format>
- `{fmt}`: <https://fmt.dev/latest/index.html>
- ICU strings: <https://unicode-org.github.io/icu/userguide/strings/>
- utf8proc: <https://github.com/JuliaStrings/utf8proc>
- SSO (libstdc++ / 15): <https://tc-imba.github.io/posts/cpp-sso/>
- SSO (MSVC/GCC 15, Clang 23): <https://dbj.org/c-small-string-optimizations/>
- SSO (libc++ / 22): <https://github.com/microsoft/STL/issues/295>
- C `char8_t` (comparison type):
  <https://en.cppreference.com/w/c/string/multibyte/char8_t>
- RFC 3629 (UTF-8): <https://www.rfc-editor.org/rfc/rfc3629.txt>
- Mojo facts, via buch: `mojov1/types/bool-and-strings`
- Frozen run configuration: `mojoakku/string/_dev/README.md`
- Mojo gap premise: `mojoakku/string/_dev/mojo.md`
