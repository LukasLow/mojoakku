# format research: C++

## 1. Standard library support

C++20 added the **`<format>` formatting library**: `std::format`,
`std::format_to`, `std::format_to_n`, `std::formatted_size`, `std::vformat`,
`std::vformat_to`, the `std::formatter` customization point, and the exception
type `std::format_error`. C++23 adds `std::formattable`, tuple/range formatters.
C++26 adds `std::dynamic_format`. Source:
<https://en.cppreference.com/w/cpp/utility/format/format>. Before C++20, the only
option was the C printf family (see `c.md`) plus the third-party {fmt}.

## 2. Relevant community libraries

- **{fmt}** (Victor Zverovich, MIT) — the library `std::format` is based on. It
  remains widely used on pre-C++20 compilers. (Assessment: derived from the
  `std::format` page, which describes the C++20 facility and its origin.)
  Source: <https://en.cppreference.com/w/cpp/utility/format/format>.

## 3. Exposed APIs

`template<class... Args> std::string format(std::format_string<Args...> fmt,
Args&&... args)` plus locale overloads; `std::vformat(fmt, std::make_format_args(
args...))` for runtime format strings; `std::format_to(output_iterator, …)` and
`std::format_to_n(…, n, …)`; `std::formatted_size(…)`. Custom types implement
`std::formatter<T, CharT>`. Source:
<https://en.cppreference.com/w/cpp/utility/format/format>.

## 4. Error representation

- **Compile-time**: since P2216R3, `std::format` checks the literal format string
  against the argument types at compile time and emits a **compilation error**
  if invalid. Source: <https://en.cppreference.com/w/cpp/utility/format/format>.
- **Runtime** (`std::vformat`): throws `std::format_error`.
- Allocation failure throws `std::bad_alloc`; a formatter's own exception
  propagates. Source: ibid.
- **More arguments than placeholders is not an error** — extra args are allowed.
  Source: ibid.

## 5. Ownership semantics

`std::format` **returns an owning `std::string`**. `std::format_to` writes
through a caller-owned output iterator; `std::format_to_n` bounds the write.
Arguments are taken by forwarding reference (`Args&&`). `std::vformat` takes a
`std::basic_format_args` view that references the arguments.
Sources: <https://en.cppreference.com/w/cpp/utility/format/format>,
<https://en.cppreference.com/w/cpp/utility/format/vformat>.

## 6. Blocking / non-blocking

Pure in-memory formatting; no I/O. "Blocking" is not applicable. (Assessment:
derived from the function signatures at
<https://en.cppreference.com/w/cpp/utility/format/format>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

`{}` **replacement fields**: `{` arg-id? `}` or `{` arg-id? `:` format-spec `}`.
`{{`/`}}` escape literal braces. Arg-ids are **all-present or all-omitted**;
mixing manual and automatic indexing is an error. For basic/string types the
format-spec is the **standard format specification** (`fill`, alignment
`< > ^`, sign `+ - space`, `#`, `0`, width, `.precision`, type), with per-type
extensions (chrono, ranges, tuple). Source:
<https://en.cppreference.com/w/cpp/utility/format/format> and
<https://en.cppreference.com/w/cpp/utility/format/spec>.

**Locale**: overloads taking `const std::locale& loc` perform locale-specific
formatting (e.g. digit grouping). Source:
<https://en.cppreference.com/w/cpp/utility/format/format>.

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

- Bad placeholder or type mismatch in a **literal** format string → compile-time
  error (P2216R3). Source: <https://en.cppreference.com/w/cpp/utility/format/format>.
- Non-constant format strings **cannot** be passed to `std::format`; use
  `std::vformat`/`std::dynamic_format`, which throw `std::format_error` at run
  time. Source: ibid.
- Extra arguments are ignored (not an error); too few/unmatched → error.
  (Assessment: derived from
  <https://en.cppreference.com/w/cpp/utility/format/format>.)
- `format_to_n` bounds output by design, so no buffer overflow.
  (Assessment: derived from the `format_to_n` signature and description at
  <https://en.cppreference.com/w/cpp/utility/format/format>.)

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

- **Owned result**: `std::string` returned by `std::format`.
- **Borrowed view**: `std::string_view` is the natural borrowed argument type;
  `std::basic_format_args` is a non-owning view of arguments.
- **Builder**: `std::format_to` with an output iterator (e.g. back-inserter into
  a string or a stream), and `std::formatter::format(ctx)` writing through a
  `basic_format_context`. Sources:
  <https://en.cppreference.com/w/cpp/utility/format/format>,
  <https://en.cppreference.com/w/cpp/utility/format/formatter>.

## 10. Interesting design decisions

- **Compile-time validation of the literal format string** (P2216R3) — the single
  biggest improvement over C; C++20 originally threw at runtime. Source:
  <https://en.cppreference.com/w/cpp/utility/format/format>.
- **Separate runtime path** (`vformat`/`dynamic_format`) so dynamic strings are
  still expressible, with a runtime error instead.
- **Customization via a specializable trait** (`std::formatter<T>`) rather than a
  member function — mirrors Mojo's trait-based `Writable`.
- **Locale as an explicit parameter**, not global state. Source:
  <https://en.cppreference.com/w/cpp/utility/format/format>.
- Range/tuple/chrono formatters are composable, so nested types format
  recursively. Source: ibid.

## 11. Decisions NOT to copy

- **Exception-based errors for a text operation.** Mojo uses `raises`/typed
  errors; formatting a string should be non-raising where possible.
- **The `std::formatter` template-specialization complexity** and the
  compile-time/runtime duplication (`format` vs `vformat`) if Mojo can express
  one mechanism (it has `TString`/`Writable`).
- **Mixing manual and automatic indexing being forbidden** is stricter than
  needed for a low-vision API; clearer to have one indexing rule.

## 12. Ideas fitting Mojo

- **Compile-time format-string checking**: Mojo's `comptime` and `t"…"` are a
  natural place to validate placeholders and arity before runtime.
- **Owned-result + writer path in one design**: `String(...)`/`Writable`
  (buch `mojov1/stdlib/format`) already gives the writer path; a compile-checked
  template is the missing piece.
- **Explicit locale object** matches Mojo's value semantics better than a global
  locale; if locale is ever added, pass it, don't set it.
- **Trait-based customization** (`Writable`, `write_to`/`write_repr_to`) is
  already the Mojo model — C++'s `std::formatter` confirms the approach.

## Sources

- std::format: <https://en.cppreference.com/w/cpp/utility/format/format>
- Standard format specification: <https://en.cppreference.com/w/cpp/utility/format/spec>
- std::formatter: <https://en.cppreference.com/w/cpp/utility/format/formatter>
- std::vformat: <https://en.cppreference.com/w/cpp/utility/format/vformat>
- P2216R3 (compile-time check): <https://wg21.link/P2216R3>
