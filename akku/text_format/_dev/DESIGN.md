<!--
Design record for akku/text_format — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo` after Phase 7. This file keeps the developer-facing
reasoning: status bookkeeping, tests, rationale, reference-API comparisons,
non-goals and open questions. It reflects the state of Phase 3 (design), derived
from the approved Phase-1 research in this directory (`mojo.md`, `c.md`, `cpp.md`,
`go.md`, `rust.md`, `python.md`, `js-ts.md`, `java.md`). Every Mojo fact is read
from the `mojov1` buch, never from memory and never from the internet. The 15 API
blocks below use the same seven-field set in the same order: Status, Signature,
Semantics, Errors, Tests, Implementation status, Rationale.
-->

# text_format — Design Record

## Purpose

`akku/text_format` is the MojoAkku **string-formatting** library: it turns typed
values into text in a controlled shape. It is the missing layer between what Mojo
1.x already ships and what every protocol, log, diagnostic and table renderer
(`net_http` headers, `text_pretty`, `format_json` pretty mode, `db_sql` DDL,
`text_i18n`, …) needs:

- Mojo already ships the **formatting traits** (`Writable.write_to`/
  `write_repr_to`, `Writer.write_string`/`write`) and the **interpolation
  literal** `t"…"` (`TString`), plus `String.format()` with `{}`/`{n}` indexing
  and the `{!r}` conversion (buch `mojov1/stdlib/format`,
  `mojov1/types/bool-and-strings`, `mojov1/basics/literals`).
- Mojo does **not** ship a **format-spec mini-language** (width, precision,
  alignment, fill, sign, radix/type, alternate form, grouping), a **runtime
  template** with placeholder binding and escaping over already-evaluated values,
  or an **explicit typed error contract** for malformed templates and arity/type
  mistakes.

This library fills exactly those three gaps and rebuilds nothing that exists. It
is a **pure, in-process, deterministic** library: no I/O, no Python, no FFI, no
hidden global state. It layers on top of `Writable`/`Writer`/`TString` (the
output path is a `Writer`) and depends on `akku/text_string` for boundary-safe
slicing and an owning output builder.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 15 entries in this document are `planned` at Phase 3; every entry's
`Implementation status:` is `implemented` until Phase 11.

## Dependencies

`text_format` has **one dependency edge**: `text_format -> text_string`. It
depends otherwise only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| `text_string` | `text_format -> text_string` | Needed for **boundary-safe codepoint work**: string `precision` truncates to a maximum number of codepoints and must not split a UTF-8 sequence (uses `text_string.is_char_boundary` + `text_string.slice`, both report a typed error instead of aborting); the owned output is accumulated through `text_string.StringBuilder` (which already conforms to `Writer`, so `format_template_to` is a pure `Writer` path). No other sibling is mentioned by any signature. |

- **Why not a leaf.** A plain `std`-only implementation of string precision
  would have to re-derive UTF-8 boundaries or rely on `std`'s aborting
  `s[byte=a:b]` (buch `mojov1/types/bool-and-strings`). `text_string` already
  ships the checked boundary layer (`is_char_boundary`, raising `slice`,
  `StringError`), so reusing it is the technically justified edge.
- **Why no wider edge.** `TString`/`Writable`/`Writer` are stdlib, not siblings.
  `text_format` does **not** build on `format_json`, `text_i18n` or any renderer;
  those are consumers. The direction is always `<renderer> -> text_format ->
  text_string`.
- **No physical nesting.** `akku/text_format/` is a flat sibling under `akku/`.
- **Catalogue agreement.** `.repo/todo/text_format.yml` already declares
  `depends_on: [text_string]`; this design confirms and justifies that edge.

## Overview

The substrate is the stdlib's `String`/`StringSpan`/`Writer` model. The library
adds four small layers:

1. **Error surface** — `FormatErrorKind` and `FormatError`: one closed
   discriminant and one typed error carrying a byte `position`.
2. **Format specification** — the closed discriminants `Alignment`, `SignMode`,
   `FormatType`, `Grouping`, the value type `FormatSpec`, and
   `parse_format_spec` to parse/validate a spec string into a `FormatSpec`.
3. **Apply a spec to one value** — `format_int`, `format_float`, `format_string`
   and `format_bool`, each producing an owned `String` and raising `FormatError`
   on an incompatible presentation.
4. **Runtime template** — `FormatArgs` (an ordered, typed argument list),
   `format_template` (parse a template, bind the arguments, return an owned
   `String`) and `format_template_to` (the same, writing through any `Writer`
   without an intermediate owned `String`).

Cross-cutting shape:

- **One typed error**, `FormatError`, with a closed five-value
  `FormatErrorKind` — no sentinel, no panic-as-error.
- **Runtime strings in, owned `String` out** (or straight to a `Writer`).
  `FormatArgs` owns its arguments; `FormatSpec` is a plain value.
- **Layering, not rebuilding.** Interpolation expressions and `write_to`/
  `write_repr_to` stay the stdlib's job; this library only adds the spec language
  and the runtime template over already-evaluated values.
- **No hidden global state.** No ambient locale, no default width, no mutable
  package-global switch.
- **Pure Mojo.** No Python dependency, no FFI, no `unsafe_*` in the public
  surface.

## Goals

1. **Close exactly the three missing pieces** (spec mini-language, runtime
   template + escaping, typed error contract). Do not rebuild `Writable`,
   `Writer`, `TString`, `String.format()` or `hex`/`oct`/`bin`.
2. **One predictable spec language** a low-vision user memorises once:
   `[[fill]align][sign][#][0][width][grouping][.precision][presentation]`, in the
   same field order as Python and Rust.
3. **Strict, typed errors** for a malformed template/spec, a missing or extra
   argument, and a presentation/type mismatch — never silent corruption (C), a
   `%!` marker in the output (Go) or an ignored extra argument (C++).
4. **One output path for every destination.** `format_template` returns an owned
   `String`; `format_template_to` writes through any `Writer` (a file, a socket,
   a `text_string.StringBuilder`) with no intermediate allocation.
5. **Implementable in pure Mojo** with the traits and value semantics of 1.x,
   deterministic and fully testable with `mojo run`.
6. **Depend only where genuinely useful.** One justified edge to `text_string`
   for the checked boundary/builder layer.

## Non-Goals

Decisions deliberately **not** copied from the reference languages, or
deliberately not shipped in release 1. Researched-but-unshipped **API candidates**
are mirrored in `akku/text_format/_dev/TODO.md`; decisions that are *not wanted*
in Mojo stay only here.

- **`%`-style printf syntax.** MojoAkku rejects C's `%[flags][width]…` because it
  is a second, competing spelling next to the `{}` replacement fields Mojo already
  documents, and its varargs model has no type knowledge (`c.md` §11,
  `mojov1/types/bool-and-strings`). The library uses `{}` fields only.
- **Undefined behaviour on type/arity mismatch.** C leaves a wrong type or too
  few arguments undefined; a wrong specifier is UB (`c.md` §8, §11). MojoAkku
  turns every such case into a typed `FormatError`.
- **Error-marker output (`%!d(string=hi)`, `%!(EXTRA …)`).** Go encodes bad calls
  into the printed text, hiding bugs (`go.md` §4, §11). MojoAkku raises instead.
- **Silent `%!`-style "never fails" printing.** The opposite extreme, Python's
  `safe_substitute`, is also rejected as the default; it is a Deferred explicit
  method (`python.md` §10, `_dev/TODO.md`).
- **Ignored extra arguments.** C++ (`std::format`) and C allow extra arguments;
  MojoAkku is strict (Java's model) and raises `EXTRA_ARGUMENT`, because an unused
  argument is usually a bug (`cpp.md` §8, `java.md` §8, §10).
- **Runtime format-string injection hazards.** There is no `%n`, no pointer
  write, no type-erased varargs; a runtime template is a *checked* interpreter
  that can only fail with `FormatError` (`c.md` §8, `java.md` §8).
- **A literal-only template.** Rust and C++ require the format string to be a
  literal so it can be compile-checked (`rust.md` §8, `cpp.md` §10). MojoAkku
  *also* wants a checked **runtime** path (the reason this library exists), so the
  template is a runtime `StringSpan`; compile-time checking of a `t"…"` stays an
  explicit Deferred idea, not a replacement (`_dev/TODO.md`).
- **Named placeholders `{name}`.** Mojo's runtime variadic pack carries values,
  not keyword bindings; the template binds **positionally** (`{}`, `{n}`).
  `{name}` is a Deferred candidate (`rust.md` §7, `python.md` §7,
  `mojov1/functions/parameters-and-generics`).
- **Attribute and item access in a template (`{0.attr}`, `{0[key]}`).** A
  runtime template over a closed argument set has no reflection over arbitrary
  fields; deferred (`python.md` §7).
- **Nested / dynamic format specs.** Replacement fields inside a spec, and
  `*`/`N$` width from an argument, need a recursive evaluator; deferred
  (`python.md` §7, `c.md` §7, `rust.md` §7).
- **Locale as process-global state.** C's `setlocale` is a footgun every later
  language reversed (`c.md` §11, `python.md` §11). Release 1 is locale-free; an
  explicit locale parameter is a Deferred candidate (`cpp.md` §10, `java.md` §7).
- **Date/time conversions built into the spec (`%tY`).** Java's `%t…` bloats the
  general formatter and Java itself split it out into `DateTimeFormatter`
  (`java.md` §11); date/time formatting is a separate concern and stays out
  (`_dev/TODO.md`).
- **Byte-counted width.** C counts bytes and has no codepoint notion
  (`c.md` §7); Java's `Formatter` has no width concept in code units — its width
  is a character count (`java.md` §7), so only C is a genuine byte-width contrast.
  (Assessment: derived from `c.md` §7 and `java.md` §7.) MojoAkku widths count
  **codepoints** (Go's rune fix), with grapheme/display width deferred
  (`go.md` §7, §10).
- **`g`/`G` general, `%` percent and `a`/`A` hex-float presentations.** They need
  significant-digit selection and hexadecimal-float algorithms not documented in
  `std`; deferred (`go.md` §7, `java.md` §7, `_dev/TODO.md`).
- **`!a` (ASCII-escaping) conversion and `#`-`%`-old formatting.** Python's `!a`
  and legacy `%` formatting hide/duplicate behaviour; deferred/dropped
  (`python.md` §11, `_dev/TODO.md`).
- **A general `to_string` on every type.** Reflection-based `Writable` already
  covers this; the library never adds a second `Writable`-like trait
  (`mojov1/stdlib/format`).

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below. Mojo
language anchors are from the `mojov1` buch.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| `{}` replacement fields, `{{`/`}}` escaping | Python `str.format`/`format_spec`; C++ `std::format`; Rust `format!` grammar | `python.md` §7; `cpp.md` §7; `rust.md` §7 |
| Spec order `[[fill]align][sign][#][0][width][.precision][type]` | Rust `format_spec`; Python standard format-spec; C `%[flags][width][.precision]` | `rust.md` §7; `python.md` §7; `c.md` §7 |
| Alignment `< > ^` and sign-aware `=` | Python/Rust alignment; Java `<`-reuse is different | `python.md` §7; `rust.md` §7; `java.md` §7 |
| Sign control `+`/space/negative-only | Java flags; Go `+`/space; C `+`/space | `java.md` §7; `go.md` §7; `c.md` §7 |
| Zero pad `0` (sign-aware) | Rust `0`; C `0`; Java `0` | `rust.md` §7; `c.md` §7; `java.md` §7 |
| Alternate form `#` | Rust `#` (`0x`/`0o`/`0b`, forced point); Python `#` | `rust.md` §7; `python.md` §7 |
| Grouping `,` / `_` | Python grouping; Java `,`; C POSIX `'` | `python.md` §7; `java.md` §7; `c.md` §7 |
| Integer presentations `b o d x X c` | Go verbs; Python types; Java conversions; Mojo `hex`/`oct`/`bin` | `go.md` §7; `python.md` §7; `java.md` §7; `mojov1/stdlib/builtin` |
| Float presentations `f e E` | Go/C/Java float verbs | `go.md` §7; `c.md` §7; `java.md` §7 |
| Rounding rule | Rust documented round half-to-even | `rust.md` §7, §12 |
| `!s` display / `!r` debug conversion | Python `!s`/`!r`; Mojo `write_to`/`write_repr_to`; Rust Display/Debug | `python.md` §7; `mojov1/stdlib/format`; `rust.md` §10 |
| Explicit one-based/zero-based index | Mojo `String.format()` zero-based; Java one-based; Go one-based | `mojov1/types/bool-and-strings`; `java.md` §7; `go.md` §7 |
| Strict arity/type errors | Java `IllegalFormat*Exception` family; Python `ValueError` | `java.md` §4, §8; `python.md` §4 |
| Typed error value + closed kind | MojoAkku `StringError`/`StringErrorKind`; MojoAkku `BitError`/`BitErrorKind`; Java `IllegalFormatException` | `akku/text_string/_dev/DESIGN.md`; `akku/prim_bit/_dev/DESIGN.md`; `java.md` §4 |
| Writer-based output, no owned intermediate | Mojo `Writer`/`write_string`; Rust `write!`; Go `Fprintf` | `mojov1/stdlib/format`; `rust.md` §9; `go.md` §9 |
| Runtime template vs literal check | Python `str.format` (runtime); Rust/C++ literal-only | `python.md` §7; `rust.md` §8; `cpp.md` §10 |
| Typed/heterogeneous runtime args | Mojo `Variant` (closed union); Python `*args` | `mojov1/glossary`; `mojov1/appendix/comparison-to-python`; `python.md` §3 |
| Boundary-safe string truncation / builder | MojoAkku `text_string.is_char_boundary`/`slice`/`StringBuilder` | `akku/text_string/_dev/DESIGN.md` |
| Three length measures | Mojo `byte_length`/`count_codepoints`/`count_graphemes` | `mojov1/types/bool-and-strings` |

## Public API

Every entry below is listed here with its exact signature and one-line meaning and
is fully specified in the per-API blocks that follow. Names are stable: Phase 5
documents them and Phase 7 stubs them, in this order.

**Error surface**

1. `FormatErrorKind` — closed failure discriminant: `MALFORMED_TEMPLATE`,
   `INVALID_SPEC`, `MISSING_ARGUMENT`, `EXTRA_ARGUMENT`, `TYPE_MISMATCH`.
2. `FormatError` — the one typed error: `kind: FormatErrorKind`,
   `position: Int`, `message: String`.

**Format specification**

3. `Alignment` — closed alignment discriminant: `DEFAULT`, `LEFT`, `RIGHT`,
   `CENTER`, `SIGN_AWARE`.
4. `SignMode` — closed sign discriminant: `NEGATIVE_ONLY`, `ALWAYS`, `SPACE`.
5. `FormatType` — closed presentation discriminant: `DEFAULT`, `BINARY`,
   `OCTAL`, `DECIMAL`, `LOWER_HEX`, `UPPER_HEX`, `CHAR`, `STRING`, `REPR`,
   `FIXED`, `SCIENTIFIC`, `UPPER_SCIENTIFIC`.
6. `Grouping` — closed digit-grouping discriminant: `NONE`, `COMMA`,
   `UNDERSCORE`.
7. `FormatSpec` — the parsed spec value (fill, align, sign, alt form, zero pad,
   width, precision, grouping, presentation).
8. `parse_format_spec(text: StringSpan) raises FormatError -> FormatSpec` —
   parse and validate a spec string into a `FormatSpec`.

**Apply a spec to one value**

9. `format_int(value: Int, spec: FormatSpec) raises FormatError -> String` —
   render an integer under a spec.
10. `format_float(value: Float64, spec: FormatSpec) raises FormatError -> String`
    — render a float under a spec.
11. `format_string(value: StringSpan, spec: FormatSpec) raises FormatError ->
    String` — render a string under a spec (width/precision in codepoints).
12. `format_bool(value: Bool, spec: FormatSpec) raises FormatError -> String`
    — render a bool under a spec.

**Runtime template**

13. `FormatArgs` — an ordered, typed argument list with `push_int`/`push_float`/
    `push_string`/`push_bool` and `count`.
14. `format_template(template: StringSpan, args: FormatArgs) raises FormatError
    -> String` — parse a runtime template, bind the arguments, return an owned
    `String`.
15. `format_template_to(mut writer: Some[Writer], template: StringSpan,
    args: FormatArgs) raises FormatError` — the same binding written straight
    through a `Writer`, with no intermediate owned `String`.

## Error Surface

One error type, `FormatError`, with a closed five-value `FormatErrorKind`.
Which API raises what:

| API | Raises | Kinds |
| --- | --- | --- |
| `parse_format_spec` | `FormatError` | `INVALID_SPEC` (malformed spec) |
| `format_int` | `FormatError` | `TYPE_MISMATCH` (presentation not valid for an integer), `INVALID_SPEC` (inconsistent flags) |
| `format_float` | `FormatError` | `TYPE_MISMATCH` (presentation not valid for a float), `INVALID_SPEC` (grouping on a float) |
| `format_string` | `FormatError` | `TYPE_MISMATCH` (sign/zero-pad/grouping/alt-form on a string) |
| `format_bool` | `FormatError` | `TYPE_MISMATCH` (presentation other than default/string/repr, or a sign/grouping flag) |
| `format_template`, `format_template_to` | `FormatError` | `MALFORMED_TEMPLATE`, `INVALID_SPEC`, `MISSING_ARGUMENT`, `EXTRA_ARGUMENT`, `TYPE_MISMATCH` (from the per-value formatters) |
| `FormatErrorKind`, `FormatError`, `Alignment`, `SignMode`, `FormatType`, `Grouping`, `FormatSpec` construction, `FormatArgs` construction/`push_*`/`count` | none | — |

Recoverability: every `FormatError` is a recoverable **data** error. The caller
can fix the template, supply the missing argument, drop the extra argument, or
choose a presentation compatible with the value; nothing is fatal and nothing
aborts the process. `FormatError` conforms to `Writable`, so `print(err)` yields a
readable `kind`, `position` and `message`. A caught error is re-raised by transfer
with `raise e^` because `FormatError` is deliberately **not**
`ImplicitlyCopyable` (the `StringError`/`BitError` convention).

## Conventions

- **Spec grammar field order** is
  `[[fill]align][sign][#][0][width][grouping][.precision][presentation]` — the same
  order as Python and Rust, so one mnemonic covers both (`python.md` §7,
  `rust.md` §7). `fill` is any single codepoint except `{`/`}`; specifying a fill
  requires an alignment.
- **Template grammar** is `{` `[arg_index]` `[conversion]` `[:` `spec` `]` `}`,
  with `{{` and `}}` escaping literal braces. `arg_index` is **zero-based**
  (`{0}`, `{1}`), matching Mojo's own `String.format()` (`mojov1/types/
  bool-and-strings`, `python.md` §7); Go and Java are one-based and are rejected
  as a second convention.
- **Auto versus manual numbering.** A template uses either all implicit `{}` or
  all explicit `{n}`, never both; mixing raises `MALFORMED_TEMPLATE`
  (`python.md` §7; one indexing rule, `cpp.md` §11).
- **Conversions** are `!s` (display, `write_to`) and `!r` (debug,
  `write_repr_to` / `repr`). `!a` is not supported (`python.md` §11,
  `mojov1/stdlib/format`).
- **Width counts codepoints**, not bytes or UTF-16 units (`go.md` §7, §10);
  Mojo's three measures make the choice explicit (`mojov1/types/bool-and-strings`).
  String precision is a maximum number of codepoints, truncated on a codepoint
  boundary.
- **Default alignment** is left for strings, right for numbers, filled with
  spaces; `SIGN_AWARE` (`=`) is valid **only for numbers**: on a string or bool
  it is `TYPE_MISMATCH` (`python.md` §7, `rust.md` §7).
- **No hidden global state.** No ambient locale, no default width, no package
  global mutable state (`c.md` §11).
- **Names are `snake_case`** for functions/methods and fields, `CamelCase` for
  types, `SCREAMING_CASE` for `comptime` constants — the Mojo style guide
  (`mojov1/idioms/style-guide`).
- **Ownership words:** "borrowed" = a `StringSpan`/`imm` argument; "owned" = a
  freshly allocated `String`; "consumed" = taken by `deinit self`.
- **`FormatArgs` is positional.** Arguments are bound by position, never by name
  (`java.md` §7, `go.md` §7).

## Ownership and Lifecycle

- **`FormatSpec` is a plain value type.** It is `Copyable`, `ImplicitlyCopyable`,
  `Deinitable`, `Equatable` and `Writable`; a no-argument constructor yields the
  neutral spec. It owns no resource and has no destructor side effect.
- **The discriminants (`Alignment`, `SignMode`, `FormatType`, `Grouping`,
  `FormatErrorKind`) are opaque value types** with a private `_id` and `comptime`
  members; they are `Equatable, ImplicitlyCopyable, Deinitable, Writable`
  (`mojov1/keywords/struct`).
- **`FormatError` is `Copyable, Deinitable, Writable` but not
  `ImplicitlyCopyable`**, so a re-raise must transfer with `raise e^`
  (`mojov1/errors/raising-and-propagation`).
- **`FormatArgs` is an owning, move-only value.** It owns a private
  `List[FormatArg]` (the internal closed union of the supported argument kinds)
  and is `Deinitable`; it is not implicitly copyable. `push_*` mutates it; the
  argument strings are owned by the list; `count()` is a plain query.
- **Outputs are owned.** `format_template`, `format_int`, `format_float`,
  `format_string` and `format_bool` each return a freshly allocated `String`
  owned by the caller. `format_template_to` retains nothing and writes only
  through the caller's `Writer`.
- **Inputs are borrowed.** The template is a `StringSpan`; `format_string`'s
  value is a `StringSpan`; neither is retained after return.
- **`FormatArgs` is consumed by the template APIs conceptually** (read-only); it
  stays valid afterwards because the rendering borrows it, but its lifetime must
  outlive the call.
- **ASAP destruction.** No library type holds a resource with a destructor side
  effect beyond freeing its own `List`/`String`; there is no `close`.

## Open Questions

None block this design. Two points must be settled during Phase 7 (scaffold)
rather than blocking this phase, and neither is a public-API candidate:

- *`Variant` accessor spelling for the internal closed argument union.* The
  design stores each argument in a private `_internal/` value built on the
  stdlib's closed union (`Variant[Int, Float64, String, Bool]`,
  `mojov1/glossary`) or, if the accessor spelling is unsettled, a hand-rolled
  `_kind` + payload struct. This is an implementation detail of `FormatArgs`;
  no public signature mentions it.
- *`format_float` fixed/scientific algorithm.* `std` documents no decimal
  precision formatter (buch `mojov1/stdlib/builtin`; gap item 7 in `mojo.md`),
  so `FIXED`/`SCIENTIFIC` scale the value and round in pure Mojo with the Rust
  round-half-to-even rule (`rust.md` §7, §12). The exact digit-generation routine
  is chosen in Phase 11 against the tests; `DEFAULT` uses the stdlib's shortest
  round-trip `String(value)`.

---

## Semantics

#### Terminology

- **Template** — a runtime `StringSpan` with literal text and `{}` replacement
  fields.
- **Field** — one `{…}` placeholder, with an optional zero-based argument index,
  an optional `!s`/`!r` conversion and an optional `: spec`.
- **Spec** — the mini-language text inside a field after `:` (or passed directly
  to `parse_format_spec`).
- **Presentation** — the trailing spec letter that selects the value's form
  (radix, float style, char, string, repr).
- **Literal segment** — the text between fields.
- **Argument kind** — one of the supported value types: `Int`, `Float64`,
  `String`, `Bool`.

All positions are **byte offsets** into the original template (or spec) text,
zero-based. Widths and string precision are measured in **codepoints**.

---

### `FormatErrorKind`

Status: implemented

Signature:

```mojo
struct FormatErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime MALFORMED_TEMPLATE = FormatErrorKind(0)
    comptime INVALID_SPEC       = FormatErrorKind(1)
    comptime MISSING_ARGUMENT   = FormatErrorKind(2)
    comptime EXTRA_ARGUMENT     = FormatErrorKind(3)
    comptime TYPE_MISMATCH      = FormatErrorKind(4)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `FormatError.kind`; never passed by a
  caller to a formatting operation. The type is **opaque**: the five `comptime`
  members are the complete public set; `_id` and its `@doc_hidden` initializer
  are implementation details (Mojo has no access control —
  `mojov1/keywords/struct`).
- **Return / meaning:** the machine-testable reason a formatting operation
  failed.
  - `MALFORMED_TEMPLATE` — unbalanced or bad braces, an empty or bad
    placeholder, an unknown conversion, or mixed auto/manual numbering.
  - `INVALID_SPEC` — the spec text does not follow the grammar (bad fill,
    unknown presentation letter, repeated flag, negative width, `.` with no
    digits).
  - `MISSING_ARGUMENT` — a field references an index for which no argument was
    supplied.
  - `EXTRA_ARGUMENT` — an argument was supplied but never referenced by any
    field.
  - `TYPE_MISMATCH` — the presentation or a flag is not applicable to the
    argument's kind.
- **Ownership:** value type; the `comptime` constants are copied into the error
  value.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: formatting is in-memory
  and has no descriptor and no blocking point (`mojo.md`, Q6 answered N/A).

Errors: none — it is a discriminant, not an operation.

Tests:

- `test_format_error_kind_distinct_ids` — each of the five `comptime` members has
  a distinct `_id`.
- `test_format_error_kind_eq` — `==` compares `_id` only.
- `test_format_error_kind_writable` — `write_to` prints the symbolic name, never
  the number.

Implementation status:

implemented

Rationale:

MojoAkku uses a closed FormatErrorKind because Java's many IllegalFormat*
exceptions prove the distinct failure classes (bad spec, wrong conversion,
missing/extra argument) are worth separating for a caller (`java.md` §4, §8),
while a single closed kind is the shape MojoAkku already taught in
StringError/StringErrorKind and BitError/BitErrorKind
(akku/text_string/_dev/DESIGN.md, akku/prim_bit/_dev/DESIGN.md). Go's
error-marker output and C's undefined behaviour are rejected (go.md §4, §11;
c.md §8, §11).

---

### `FormatError`

Status: implemented

Signature:

```mojo
struct FormatError(Copyable, Deinitable, Writable):
    var kind: FormatErrorKind
    var position: Int
    var message: String

    def __init__(out self, kind: FormatErrorKind, position: Int, message: String)
    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library on failure; read in
  an `except` block. `kind` is the discriminant above; `position` is the **byte
  offset in the original template/spec text** at which the failure was detected.
  For `EXTRA_ARGUMENT` the position is the template's byte length (its end), since
  no field owns the fault; `message` is a short, human-readable explanation with
  the offending text.
- **Return / meaning:** raised, never returned. Every condition is recoverable:
  fix the template/spec, supply the missing argument, drop the extra argument, or
  pick a compatible presentation.
- **Ownership:** value type; `Copyable` and `Deinitable`, deliberately **not**
  `ImplicitlyCopyable`, so a re-raise transfers with `raise e^`
  (`mojov1/errors/raising-and-propagation`).
- **Stream I/O:** not applicable; no descriptor, no blocking call, no handle.

Errors: it **is** the error; constructing it cannot fail.

Tests:

- `test_format_error_writable` — `print(err)` yields kind + position + message.
- `test_format_error_reraise_transfer` — a caught error re-raises with `raise e^`.
- `test_format_error_position_original_template` — `position` points into the
  template, not into a copied buffer.

Implementation status:

implemented

Rationale:

MojoAkku uses one typed error FormatError with kind+position+message because
Java's IllegalFormatExceptions carry the offending index and Python's ValueError
describes the bad spec, proving position and text are part of a usable diagnostic
(java.md §4, §8; python.md §4), and a re-raise by transfer is the established
MojoAkku error convention (akku/text_string/_dev/DESIGN.md,
mojov1/errors/raising-and-propagation).

---

### `Alignment`

Status: implemented

Signature:

```mojo
struct Alignment(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime DEFAULT     = Alignment(0)
    comptime LEFT        = Alignment(1)   # '<'
    comptime RIGHT       = Alignment(2)   # '>'
    comptime CENTER      = Alignment(3)   # '^'
    comptime SIGN_AWARE  = Alignment(4)   # '='

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `FormatSpec.align`; produced by
  `parse_format_spec` from `<`, `>`, `^`, `=`. Opaque, with the five `comptime`
  members as the full set.
- **Return / meaning:**
  - `DEFAULT` — no alignment given; the per-value formatter chooses (left for
    strings and bools, right for numbers).
  - `LEFT` (`<`) — pad on the right.
  - `RIGHT` (`>`) — pad on the left.
  - `CENTER` (`^`) — pad both sides, the extra fill on the right (Python/Rust
    convention).
  - `SIGN_AWARE` (`=`) — insert padding **after the sign** and before the
    digits; valid only for numbers (`python.md` §7, `rust.md` §7).
- **Ownership:** value type; constants copied into the spec.
- **Stream I/O:** not applicable.

Errors: none — it is a discriminant.

Tests:

- `test_alignment_distinct_ids` — five distinct `_id`s.
- `test_alignment_parse_letters` — `<`, `>`, `^`, `=` map to the right members.
- `test_alignment_writable` — symbolic name is printed.

Implementation status:

implemented

Rationale:

MojoAkku uses a closed Alignment because Python and Rust share the exact
< > ^ = alphabet, so one mnemonic covers the whole family (python.md §7;
rust.md §7), and the closed discriminants match the MojoAkku error-kind shape
(akku/text_string/_dev/DESIGN.md). Java's alignment is expressed through
separate flags and is rejected as a second spelling (java.md §7).

---

### `SignMode`

Status: implemented

Signature:

```mojo
struct SignMode(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime NEGATIVE_ONLY = SignMode(0)   # default
    comptime ALWAYS        = SignMode(1)   # '+'
    comptime SPACE         = SignMode(2)   # ' '

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `FormatSpec.sign`; produced by the
  parser from `+`, `-` (explicit negative-only) and a leading space.
- **Return / meaning:**
  - `NEGATIVE_ONLY` — a leading `-` for negative numbers only; positives have no
    sign. This is the default.
  - `ALWAYS` (`+`) — a leading `+` for positive values and `-` for negative.
  - `SPACE` (` `) — a leading space for positives and `-` for negative.
  Valid only for numeric presentations; using it on a string/bool is
  `TYPE_MISMATCH` (`java.md` §7, `go.md` §7).
- **Ownership:** value type; constants copied into the spec.
- **Stream I/O:** not applicable.

Errors: none — it is a discriminant.

Tests:

- `test_sign_mode_distinct_ids` — three distinct `_id`s.
- `test_sign_mode_parse` — `+`, `-`, space parse correctly.
- `test_sign_mode_writable` — symbolic name is printed.

Implementation status:

implemented

Rationale:

MojoAkku uses a closed SignMode because Java, Go and C all expose the same
+ / space / negative-only control (java.md §7; go.md §7; c.md §7) and one value
type makes it testable; the `=` alignment is kept separate from the sign because
the spec grammar places them in different positions (rust.md §7).

---

### `FormatType`

Status: implemented

Signature:

```mojo
struct FormatType(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime DEFAULT            = FormatType(0)
    comptime BINARY             = FormatType(1)    # 'b'
    comptime OCTAL              = FormatType(2)    # 'o'
    comptime DECIMAL            = FormatType(3)    # 'd'
    comptime LOWER_HEX          = FormatType(4)    # 'x'
    comptime UPPER_HEX          = FormatType(5)    # 'X'
    comptime CHAR               = FormatType(6)    # 'c'
    comptime STRING             = FormatType(7)    # 's'
    comptime REPR               = FormatType(8)    # 'r'
    comptime FIXED              = FormatType(9)    # 'f' (and 'F', same output)
    comptime SCIENTIFIC         = FormatType(10)   # 'e'
    comptime UPPER_SCIENTIFIC   = FormatType(11)   # 'E'

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `FormatSpec.presentation`; produced by
  the parser from the presentation letter (the trailing spec character).
- **Return / meaning:** the selected form.
  - `DEFAULT` — natural form: decimal for integers, shortest round-trip for
    floats, the text itself for strings, `true`/`false` for bools.
  - `BINARY`/`OCTAL`/`DECIMAL`/`LOWER_HEX`/`UPPER_HEX` — integer radix
    presentations (`go.md` §7, `python.md` §7; the same forms `hex`/`oct`/`bin`
    already expose individually in `mojov1/stdlib/builtin`).
  - `CHAR` (`c`) — render a Unicode codepoint (an integer) as that character
    (`go.md` §7, `python.md` §7).
  - `STRING` (`s`) — text (for strings, explicit; for other values, the display
    form).
  - `REPR` (`r`) — the debug form via `repr`/`write_repr_to`; for a string it is
    the quoted representation (`mojov1/stdlib/format`; `rust.md` §10).
  - `FIXED` (`f`, and `F` as an alias with identical lowercase output) —
    fixed-point with `precision` digits after the point. `FIXED` is a single
    member, so `F` does **not** upper-case anything: the parser maps both letters
    to the same presentation.
  - `SCIENTIFIC` (`e`) / `UPPER_SCIENTIFIC` (`E`) — scientific notation with
    `precision` digits, lowercase/uppercase `e`.
- **Ownership:** value type; constants copied into the spec.
- **Stream I/O:** not applicable.

Errors: none — it is a discriminant.

Tests:

- `test_format_type_distinct_ids` — twelve distinct `_id`s.
- `test_format_type_parse_letters` — every accepted letter maps correctly,
  including `F` to `FIXED` (same member as `f`).
- `test_format_type_writable` — symbolic name is printed.

Implementation status:

implemented

Rationale:

MojoAkku uses a closed FormatType because Go's verb table and Python's type
letters are closed, finite sets, so an enumeration is both faithful and
exhaustively testable (go.md §7; python.md §7), and the rejected letters
(g/G/%/a/A) are deferred rather than silently accepted (java.md §7). The REPR
member reuses Mojo's existing write_repr_to/`{!r}` split instead of inventing a
new debug path (mojov1/stdlib/format; rust.md §10).

---

### `Grouping`

Status: implemented

Signature:

```mojo
struct Grouping(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime NONE        = Grouping(0)
    comptime COMMA       = Grouping(1)   # ','
    comptime UNDERSCORE  = Grouping(2)   # '_'

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `FormatSpec.grouping`; produced by
  the parser from `,` or `_`.
- **Return / meaning:**
  - `NONE` — no separators (default).
  - `COMMA` (`,`) — group the integer part in threes with `,` (en-US style;
    `python.md` §7, `java.md` §7).
  - `UNDERSCORE` (`_`) — the same grouping with `_` (Python's
    locale-independent form; `python.md` §7).
  Valid only for integer presentations; on a float or a string it raises
  `TYPE_MISMATCH`/`INVALID_SPEC` rather than being silently ignored
  (`java.md` §10). Grouping is **deterministic** and does not consult any locale.
- **Ownership:** value type; constants copied into the spec.
- **Stream I/O:** not applicable.

Errors: none — it is a discriminant.

Tests:

- `test_grouping_distinct_ids` — three distinct `_id`s.
- `test_grouping_parse` — `,` and `_` parse correctly.
- `test_grouping_writable` — symbolic name is printed.

Implementation status:

implemented

Rationale:

MojoAkku uses a closed Grouping because Python and Java both expose comma/other
separator grouping (python.md §7; java.md §7), and making the separator an
explicit value keeps output locale-independent, unlike C's global setlocale
(c.md §11). A locale-aware separator is deferred as an explicit locale parameter
(cpp.md §10, java.md §7).

---

### `FormatSpec`

Status: implemented

Signature:

```mojo
struct FormatSpec(Copyable, ImplicitlyCopyable, Deinitable, Equatable, Writable):
    var fill: Codepoint           # default ' ' (space)
    var align: Alignment          # default Alignment.DEFAULT
    var sign: SignMode            # default SignMode.NEGATIVE_ONLY
    var alt_form: Bool            # default False ('#')
    var zero_pad: Bool            # default False ('0')
    var width: Int                # default 0 (no minimum width)
    var precision: Optional[Int]  # default None
    var grouping: Grouping        # default Grouping.NONE
    var presentation: FormatType  # default FormatType.DEFAULT

    def __init__(out self)
    def __init__(
        out self,
        fill: Codepoint,
        align: Alignment,
        sign: SignMode,
        alt_form: Bool,
        zero_pad: Bool,
        width: Int,
        precision: Optional[Int],
        grouping: Grouping,
        presentation: FormatType,
    )
    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** the no-argument constructor yields the neutral
  spec (the defaults in the field comments above), equivalent to an empty spec
  string. All fields are public and may be set after construction. `width` must be
  `>= 0`; a negative width is a caller programming error and is treated as `0`
  (total, non-raising, like the repo's sizing helpers). `fill` may be any
  codepoint except `{`/`}`.
- **Return / meaning:** the fully-resolved specification a per-value formatter
  consumes. Each field mirrors one grammar element, in grammar order:
  `fill`+`align`, `sign`, `alt_form` (`#`), `zero_pad` (`0`), `width`,
  `grouping`, `precision`, `presentation`.
  - `alt_form` — integer `0b`/`0o`/`0x` prefixes and a forced decimal point for
    floats (`rust.md` §7, `python.md` §7).
  - `zero_pad` — sign-aware zero padding: zeros go after the sign and any radix
    prefix; `0` also implies alignment when no explicit `align` is given
    (`rust.md` §7, `c.md` §7).
  - `precision` — a minimum digit count for integers, digits after the point for
    floats, and a maximum codepoint count for strings (`python.md` §7).
- **Ownership:** a plain value; copyable and implicitly copyable, owns nothing.
- **Stream I/O:** not applicable.

Errors: none — construction cannot fail; `parse_format_spec` is the validating
entry.

Tests:

- `test_format_spec_defaults` — the no-argument spec has the documented defaults.
- `test_format_spec_field_order_roundtrip` — a parsed spec compares equal to the
  same spec built field-wise.
- `test_format_spec_negative_width_clamped` — a negative width behaves as `0`.
- `test_format_spec_writable` — `print(spec)` prints the grammar-like form.

Implementation status:

implemented

Rationale:

MojoAkku uses one FormatSpec value because Rust's format_spec is one grammar
with one parse result and Python's format-spec mini-language is likewise a single
tuple of options (rust.md §7; python.md §7); bundling the nine grammar elements
in one copyable struct keeps the per-value formatters signature-stable and makes
every option independently testable. The C flag bag is rejected as type-erased
varargs (c.md §11) and Java's Formattable receives the options explicitly, which
confirms passing a value is the right model (java.md §12).

---

### `parse_format_spec`

Status: implemented

Signature:

```mojo
def parse_format_spec(text: StringSpan) raises FormatError -> FormatSpec
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed spec content **without**
  the surrounding braces or the leading `:`. An empty `text` is valid and yields
  the neutral spec. The parser consumes exactly the grammar
  `[[fill]align][sign][#][0][width][grouping][.precision][presentation]`; it
  accepts a `fill` only when it is followed by an alignment character.
- **Return / meaning:** the validated `FormatSpec`. Leading `-` is accepted as an
  explicit `NEGATIVE_ONLY` sign; `F` is accepted as an alias of `f`, mapping to
  `FIXED` with identical lowercase output.
  Repeated flags, an unknown presentation letter, a `.` with no digits, a
  negative width, or a second fill/align are `INVALID_SPEC` (`python.md` §7,
  `rust.md` §7). `g`/`G`/`%`/`a`/`A` and nested `{…}` specs are not accepted
  release 1 and raise `INVALID_SPEC`; they are Deferred candidates
  (`go.md` §7, `python.md` §7, `_dev/TODO.md`).
- **Ownership:** returns an owned-by-value `FormatSpec`; `text` stays borrowed.
  `FormatError.position` is the byte offset in `text` of the offending character.
- **Stream I/O:** not applicable.

Errors: `FormatError` `INVALID_SPEC`; recoverable by correcting the spec text.

Tests:

- `test_parse_spec_empty_is_default` — `""` yields the neutral spec.
- `test_parse_spec_align_and_fill` — `"*>10"`, `"^8"`.
- `test_parse_spec_sign_and_zero` — `"+08d"`, `" 5.2f"`.
- `test_parse_spec_alt_and_group` — `"#x"`, `",d"`, `"_d"`.
- `test_parse_spec_precision` — `".3f"`.
- `test_parse_spec_all_letters` — every accepted presentation letter.
- `test_parse_spec_rejects_unknown_letter` — `"q"` -> `INVALID_SPEC`.
- `test_parse_spec_rejects_repeat_flag` — `"++d"` -> `INVALID_SPEC`.
- `test_parse_spec_rejects_nested_brace` — `"{width}"` -> `INVALID_SPEC`.
- `test_parse_spec_rejects_bare_fill` — `"*10"` (fill without align) ->
  `INVALID_SPEC`.
- `test_parse_spec_reports_position` — the offending byte offset.

Implementation status:

implemented

Rationale:

MojoAkku uses a separate parse_format_spec because Rust's format_spec is a
documented standalone grammar and Python's format-spec is parsed independently of
the template (rust.md §7; python.md §7); splitting parse from apply lets the
template reuse the same parser inline and lets callers build/validate a spec on
its own. Parsing the grammar rather than pattern-matching letters keeps the
field order the single source of truth (python.md §7).

---

### `format_int`

Status: implemented

Signature:

```mojo
def format_int(value: Int, spec: FormatSpec) raises FormatError -> String
```

Semantics:

- **Parameters / preconditions:** `value` is the integer to render; `spec` is the
  parsed specification. Allowed presentations: `DEFAULT`, `DECIMAL`, `BINARY`,
  `OCTAL`, `LOWER_HEX`, `UPPER_HEX`, `CHAR`, `REPR`. `precision`, when present,
  is the **minimum number of digits** (the value is left-padded with zeros to at
  least that many digits, after the sign and any radix prefix). `grouping` is
  valid only for `DEFAULT`/`DECIMAL` (threes, sign/prefix aware).
  `SIGN_AWARE` alignment is valid; `alt_form` adds `0b`/`0o`/`0x`/`0X`.
- **Return / meaning:** an owned `String` holding the rendered digits, then
  sign/prefix, grouping, zero-pad and fill/align applied in that order, padded to
  `width` in **codepoints** (digits are ASCII, so codepoints equal bytes here).
  The output matches `hex`/`oct`/`bin` for the plain radix forms (without the
  `#` alternate form) (`go.md` §7, `python.md` §7, `mojov1/stdlib/builtin`).
  `CHAR` renders `chr(value)` for a valid Unicode scalar; an out-of-range
  codepoint is `TYPE_MISMATCH` (`go.md` §7).
- **Ownership:** the returned `String` is newly allocated and owned by the caller;
  `value` is a plain `Int`; `spec` is copied by value.
- **Stream I/O:** not applicable.

Errors: `FormatError` `TYPE_MISMATCH` when the presentation is a float/string
form or `CHAR` receives an invalid codepoint; `INVALID_SPEC` when `grouping` or
`alt_form` is combined with an incompatible presentation. Recoverable.

Tests:

- `test_format_int_default` — `42` -> `"42"`.
- `test_format_int_radix` — `255` with `x`/`X`/`o`/`b` matches `hex`/`oct`/`bin`
  conventions.
- `test_format_int_alt_form` — `#x` -> `"0xff"`, `#b` -> `"0b101"`.
- `test_format_int_sign_always` — `+d` on positives.
- `test_format_int_sign_space` — space sign.
- `test_format_int_zero_pad` — `08d` -> `"00000042"`; negative sign-aware.
- `test_format_int_width_align` — `<`/`>`/`^` and a fill codepoint.
- `test_format_int_sign_aware_pad` — `=010d` puts zeros after the sign.
- `test_format_int_precision_min_digits` — `.6d` -> `"000042"`.
- `test_format_int_grouping_comma` — `,d` -> `"1,234,567"`.
- `test_format_int_grouping_underscore` — `_d`.
- `test_format_int_char` — `c` on `65` -> `"A"`.
- `test_format_int_char_invalid_codepoint` — `TYPE_MISMATCH`.
- `test_format_int_float_presentation_mismatch` — `f` on `Int` ->
  `TYPE_MISMATCH`.
- `test_format_int_repr` — `r` matches the stdlib `repr` form.

Implementation status:

implemented

Rationale:

MojoAkku uses a per-kind format_int as the explicit entry because the
presentation must be checked against the value kind and Mojo has no runtime type
switch over a Writable; Go's verbs and Python's type letters both select a
per-kind formatter, and the radix results must agree with Mojo's existing
hex/oct/bin (go.md §7; python.md §7; mojov1/stdlib/builtin). Grouping and
sign-aware zero-pad follow Rust/Python/Java rather than C's UB on mismatch
(rust.md §7; python.md §7; java.md §10; c.md §11).

---

### `format_float`

Status: implemented

Signature:

```mojo
def format_float(value: Float64, spec: FormatSpec) raises FormatError -> String
```

Semantics:

- **Parameters / preconditions:** `value` is the float to render; `spec` is the
  parsed specification. Allowed presentations: `DEFAULT`, `FIXED` (`f`, or `F`
  as an alias), `SCIENTIFIC` (`e`), `UPPER_SCIENTIFIC` (`E`), `REPR`. `precision` is the number
  of digits after the decimal point for `FIXED`/`SCIENTIFIC` (default `6`, the
  C/Java default); for `DEFAULT` it is not applicable and `precision` must be
  `None` (otherwise `TYPE_MISMATCH`). `sign`, `zero_pad`, `width`,
  `SIGN_AWARE` alignment and `alt_form` (forced trailing decimal point) are
  valid; `grouping` on a float is `INVALID_SPEC` release 1.
- **Return / meaning:** an owned `String`. `DEFAULT` uses the stdlib shortest
  round-trip form. `FIXED`/`SCIENTIFIC` round **half-to-even** at `precision`
  digits (the Rust rule) and render the sign, then digits, then fill/align to
  `width` in codepoints (`go.md` §7; `c.md` §7; `rust.md` §7, §12). `inf`/`nan`
  render as lowercase `inf`/`nan`; `F` is an alias of `f` and never upper-cases
  them (`c.md` §7).
- **Ownership:** the returned `String` is newly allocated and owned by the caller;
  `value`/`spec` are copied by value.
- **Stream I/O:** not applicable.

Errors: `FormatError` `TYPE_MISMATCH` for an integer/string/char presentation or
`precision` on `DEFAULT`; `INVALID_SPEC` for `grouping` on a float. Recoverable.

Tests:

- `test_format_float_default` — shortest round-trip.
- `test_format_float_fixed_precision` — `.2f` on `3.14159` -> `"3.14"`.
- `test_format_float_fixed_default_precision` — `f` -> six digits.
- `test_format_float_scientific` — `e`/`E` with exponent.
- `test_format_float_round_half_even` — a tie rounds to even.
- `test_format_float_sign_always` — `+f`.
- `test_format_float_zero_pad` — `010.2f`, sign-aware.
- `test_format_float_width_align` — fill/align in codepoints.
- `test_format_float_alt_form` — `#.0f` keeps the point.
- `test_format_float_inf_nan` — `inf`/`nan` render lowercase; `F` aliases `f`.
- `test_format_float_grouping_invalid` — `,f` -> `INVALID_SPEC`.
- `test_format_float_int_presentation_mismatch` — `d` on `Float64` ->
  `TYPE_MISMATCH`.

Implementation status:

implemented

Rationale:

MojoAkku uses format_float with f/e/E because Go, C and Java all expose exactly
those float presentations, and Rust documents the round-half-to-even rule that
makes the digits reproducible (go.md §7; c.md §7; java.md §7; rust.md §7, §12).
DEFAULT deliberately falls back to the stdlib shortest form because the buch
documents no precision API, so no separate float formatter exists to reuse
(mojo.md gap item 7; mojov1/stdlib/builtin). g/G/%/a/A are deferred rather than
half-implemented (java.md §7, _dev/TODO.md).

---

### `format_string`

Status: implemented

Signature:

```mojo
def format_string(value: StringSpan, spec: FormatSpec) raises FormatError -> String
```

Semantics:

- **Parameters / preconditions:** `value` is the borrowed text; `spec` is the
  parsed specification. Allowed presentations: `DEFAULT`, `STRING`, `REPR`.
  `precision`, when present, is the **maximum number of codepoints** (the string
  is truncated at a codepoint boundary, never mid-sequence). Only `fill`, `align`
  and `width` are valid; `sign`, `grouping`, `alt_form`, `zero_pad` and
  `SIGN_AWARE` are all `TYPE_MISMATCH` (`zero_pad` on text is never intended, and
  `SIGN_AWARE` padding is meaningful only next to a numeric sign).
- **Return / meaning:** an owned `String`. The text is first truncated to
  `precision` codepoints (using `text_string.is_char_boundary` +
  `text_string.slice` so a multi-byte sequence is never split), then padded to
  `width` codepoints with the fill character according to `align` (default
  `LEFT`) (`go.md` §7, `python.md` §7; `akku/text_string/_dev/DESIGN.md`).
  `REPR` renders the quoted repr form (`'text'`) first, then applies
  width/precision to the result (`mojov1/stdlib/format`).
- **Ownership:** the returned `String` is newly allocated and owned by the caller;
  `value` stays borrowed.
- **Stream I/O:** not applicable.

Errors: `FormatError` `TYPE_MISMATCH` for a numeric presentation, or for a sign,
grouping, zero-pad or `SIGN_AWARE` specification on a string. Recoverable.

Tests:

- `test_format_string_default` — the text unchanged.
- `test_format_string_width_left` — padding on the right.
- `test_format_string_width_center` — padding both sides, extra on the right.
- `test_format_string_fill_codepoint` — a non-ASCII fill.
- `test_format_string_precision_truncates_codepoints` — a multi-byte string
  truncated on a boundary.
- `test_format_string_precision_never_splits_codepoint` — result is valid UTF-8.
- `test_format_string_repr_quotes` — `r` -> single-quoted.
- `test_format_string_sign_invalid` — `+s` -> `TYPE_MISMATCH`.
- `test_format_string_zero_pad_invalid` — `08s` -> `TYPE_MISMATCH`.

Implementation status:

implemented

Rationale:

MojoAkku uses format_string with codepoint width and codepoint precision because
Go deliberately fixed C's byte semantics with rune-based width and Python's string
precision is a character count (go.md §7, §10; python.md §7), while Mojo exposes
three length measures so the choice must be explicit
(mojov1/types/bool-and-strings). Boundary-safe truncation reuses text_string
instead of std's aborting byte slice (akku/text_string/_dev/DESIGN.md). Sign and
grouping on strings are rejected rather than ignored (java.md §10).

---

### `format_bool`

Status: implemented

Signature:

```mojo
def format_bool(value: Bool, spec: FormatSpec) raises FormatError -> String
```

Semantics:

- **Parameters / preconditions:** `value` is the bool; `spec` is the parsed
  specification. Allowed presentations: `DEFAULT`, `STRING`, `REPR`. `fill`,
  `align`, `width` and `precision` (max codepoints of `"true"`/`"false"`) are
  valid; `SIGN_AWARE`, `zero_pad`, `sign`, `grouping` and `alt_form` are
  `TYPE_MISMATCH`.
- **Return / meaning:** an owned `String` — `"true"`/`"false"` (or the stdlib
  repr for `REPR`), then truncated to `precision` codepoints and padded to
  `width` with `align` (default `LEFT`). Booleans are text, so the string rules
  apply (`go.md` §7, `java.md` §7).
- **Ownership:** the returned `String` is newly allocated and owned by the caller;
  `value`/`spec` are copied by value.
- **Stream I/O:** not applicable.

Errors: `FormatError` `TYPE_MISMATCH` for a numeric/char presentation or an
unsupported flag. Recoverable.

Tests:

- `test_format_bool_default` — `True` -> `"true"`.
- `test_format_bool_width_center` — padding.
- `test_format_bool_precision` — truncation of `"false"`.
- `test_format_bool_numeric_presentation_mismatch` — `d` -> `TYPE_MISMATCH`.

Implementation status:

implemented

Rationale:

MojoAkku uses format_bool because Go's %t and Java's %b both treat booleans as
first-class formattable values with width/alignment (go.md §7; java.md §7); the
closed argument union includes Bool, so its formatter is needed for the template
path to be total. Sign and grouping are rejected because they make no sense on a
logical value (java.md §10).

---

### `FormatArgs`

Status: implemented

Signature:

```mojo
struct FormatArgs(Deinitable):
    var _args: List[FormatArg]   # private closed union; not part of the API

    def __init__(out self)
    def push_int(mut self, var value: Int)
    def push_float(mut self, var value: Float64)
    def push_string(mut self, var value: String)
    def push_bool(mut self, var value: Bool)
    def count(self) -> Int
```

Semantics:

- **Parameters / preconditions:** an empty `FormatArgs` is created with the
  no-argument constructor; `push_*` appends one typed argument in order. The kind
  passed to `push_*` decides which per-value formatter the template uses for that
  argument; there is no implicit conversion between kinds. A `String` pushed by
  `push_string` is **owned** by the list (the caller transfers it with `^` or
  passes a fresh `String(value)` from a `StringSpan`).
- **Return / meaning:** an ordered, positional argument list for
  `format_template`/`format_template_to`. `count()` is the number of arguments
  pushed. The internal `FormatArg` (a closed union over `Int`, `Float64`,
  `String`, `Bool`) is private and never named by a public signature.
- **Ownership:** owns its `List[FormatArg]`; move-only (`Deinitable`), not
  implicitly copyable, so it is transferred with `^` when handed to a consuming
  API. This release's template APIs borrow it, so it stays usable after a render.
- **Stream I/O:** not applicable.

Errors: none — pushing and counting cannot fail.

Tests:

- `test_format_args_count` — counts grow with each push.
- `test_format_args_push_int_float_string_bool` — all four kinds retain their
  values.
- `test_format_args_string_owned` — a pushed `String` is independent of the
  caller's buffer.
- `test_format_args_order_preserved` — position is the binding index.

Implementation status:

implemented

Rationale:

MojoAkku uses an explicit ordered FormatArgs because Java's Object... and Go's
a ...any bind positionally and Python's *args is positional, so an index-ordered
list is the shared model (java.md §7; go.md §3; python.md §3); Mojo has no
keyword-argument variadic, so named binding is deferred
(mojov1/functions/parameters-and-generics, rust.md §7). A closed union over the
supported kinds turns a type error into a FormatError instead of dynamic
dispatch (java.md §4; python.md §8).

---

### `format_template`

Status: implemented

Signature:

```mojo
def format_template(
    template: StringSpan, args: FormatArgs
) raises FormatError -> String
```

Semantics:

- **Parameters / preconditions:** `template` is the borrowed runtime template;
  `args` is the ordered argument list. Grammar: literal text plus fields
  `{` `[arg_index]` `[conversion]` `[:` `spec` `]` `}`. `{{`/`}}` escape literal
  braces. `arg_index` is zero-based; all-implicit `{}` or all-explicit `{n}`,
  never mixed. `conversion` is `!s` (display) or `!r` (repr). `spec` is parsed by
  `parse_format_spec`. Every codepoint not part of a field is copied literally.
- **Return / meaning:** an owned `String` with each field replaced by its
  argument rendered under the field's spec/conversion. Rendering goes through a
  `text_string.StringBuilder` (which conforms to `Writer`), then `finish`
  (`akku/text_string/_dev/DESIGN.md`). Implicit fields consume arguments left to
  right; an explicit index may be reused (`{0} {0}`). After all fields, any
  unreferenced argument is `EXTRA_ARGUMENT`; a field index past the end is
  `MISSING_ARGUMENT` (`java.md` §4, §8; `python.md` §4).
- **Ownership:** the returned `String` is newly allocated and owned by the
  caller; `template` stays borrowed; `args` is borrowed for the call.
- **Stream I/O:** not applicable.

Errors: `FormatError` `MALFORMED_TEMPLATE`, `INVALID_SPEC`,
`MISSING_ARGUMENT`, `EXTRA_ARGUMENT`, `TYPE_MISMATCH`; all recoverable and all
carrying a byte `position` in `template`.

Tests:

- `test_format_template_auto_numbering` — `"{} {}"`.
- `test_format_template_explicit_index` — `"{1} {0}"` reorders.
- `test_format_template_reuse_index` — `"{0} {0}"`.
- `test_format_template_literal_braces` — `"{{}}"` -> `"{}"`.
- `test_format_template_inline_spec` — `"{:08d}"`.
- `test_format_template_conversion_repr` — `"{!r}"` on a string is quoted.
- `test_format_template_mixed_numbering_error` — `"{} {0}"` ->
  `MALFORMED_TEMPLATE`.
- `test_format_template_unbalanced_brace_error` — `"{"`.
- `test_format_template_missing_argument_error` — `"{2}"` with two args.
- `test_format_template_extra_argument_error` — one unused argument.
- `test_format_template_type_mismatch_error` — `"{:x}"` on a string.
- `test_format_template_returns_owned` — the result is independent of inputs.
- `test_format_template_non_ascii_literal` — literal text passes through
  unchanged.

Implementation status:

implemented

Rationale:

MojoAkku uses a runtime template formatter because Python's str.format is the
runtime-checked counterpart to f-strings and is the exact missing piece next to
Mojo's t"…" (python.md §7, §12), and Java proves a runtime format string can fail
in a controlled way instead of corrupting memory (java.md §8). It is strict about
mixed numbering (python.md §7; one rule, cpp.md §11), missing/extra arguments and
type mismatch (java.md §4, §8), rather than Go's marker strings or C++'s ignored
extras (go.md §4; cpp.md §8). Literal braces follow the {{/}} rule shared by
Python, Rust and Mojo's own t-strings (python.md §7; rust.md §7;
mojov1/basics/literals).

---

### `format_template_to`

Status: implemented

Signature:

```mojo
def format_template_to(
    mut writer: Some[Writer], template: StringSpan, args: FormatArgs
) raises FormatError
```

Semantics:

- **Parameters / preconditions:** as `format_template`, but the rendered bytes
  are written directly to `writer` (`Writer.write_string`) with no intermediate
  owned `String`. `writer` is mutated in place.
- **Return / meaning:** nothing; the output lands in the writer. This is the
  allocation-free path when the destination is a file, a socket, a
  `text_string.StringBuilder`, or any other `Writer` — the `mojov1/stdlib/format`
  model and Rust's `write!`/Go's `Fprintf` split (`rust.md` §9; `go.md` §9).
- **Ownership:** retains nothing; the caller owns the writer and its buffer. The
  template is borrowed; `args` is borrowed for the call.
- **Stream I/O / flush:** the library performs no flush. The writer's own
  semantics govern blocking and flush; this call is synchronous and in-memory
  with respect to the formatting itself, and blocks only as the writer does
  (`mojo.md`, Q6 N/A for the core).

Errors: the same `FormatError` set as `format_template`; the writer's own errors
are the writer's contract, not surfaced as `FormatError`. **Partial output is
possible.** A template/spec error detected while parsing (before any write)
leaves the writer untouched, but a `TYPE_MISMATCH` in a *later* field can only be
detected after earlier literal segments and fields have already been written, so
the writer then holds the prefix produced so far. Atomicity therefore holds only
up to the first write, not for the whole call.

Tests:

- `test_format_template_to_writer` — a custom `Writer` receives the output.
- `test_format_template_to_string_builder` — output equals `format_template`.
- `test_format_template_to_no_intermediate_string` — the writer sees each segment
  in order.
- `test_format_template_to_raises_before_first_write_on_malformed` — a malformed
  template raises and writes nothing (the parse stage precedes the first write).
- `test_format_template_to_partial_output_on_later_type_mismatch` — an earlier
  field/literal is already in the writer when a later-field `TYPE_MISMATCH`
  raises.

Implementation status:

implemented

Rationale:

MojoAkku uses format_template_to because Mojo's Writer is the documented
destination trait and Rust's write! / Go's Fprintf both expose a
write-through-destination path next to the owned-string one (mojov1/stdlib/format;
rust.md §9; go.md §9). Providing both in one design avoids the owned-string
allocation when a destination already exists, and matches the
text_string.StringBuilder Writer conformance (akku/text_string/_dev/DESIGN.md).

---
