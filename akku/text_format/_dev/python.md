# format research: Python

## 1. Standard library support

Formatting is a **core language feature** plus the `string` module:
- `str.format()` (PEP 3101) and the `format()` builtin invoking `__format__`.
- **f-strings** (`f"…"`, PEP 498) and, since 3.14, **t-strings** (`t"…"`,
  `string.templatelib.Template`).
- `%`-formatting (old-style printf, still supported).
- `string.Formatter` — a class to subclass/customize; `string.Template`
  (`$`-substitution, PEP 292, i18n-oriented).
Sources: <https://docs.python.org/3/library/string.html>,
<https://docs.python.org/3/reference/lexical_analysis.html#f-strings>.

## 2. Relevant community libraries

None needed; the stdlib covers general use. The `string` docs present
`Template` as the i18n-oriented simpler alternative and `Formatter` as the
customizable engine. Source:
<https://docs.python.org/3/library/string.html>.

## 3. Exposed APIs

`str.format(*args, **kwargs)`, `format(value, format_spec)`, the `Formatter`
class: `format(fmt, *args, **kwargs)`, `vformat(fmt, args, kwargs)`, `parse(fmt)`,
`get_field`, `get_value`, `check_unused_args`, `format_field`, `convert_field`.
`Template` class: `substitute`, `safe_substitute`, `is_valid`, `get_identifiers`.
Sources: <https://docs.python.org/3/library/string.html>,
<https://docs.python.org/3/library/functions.html#format>.

## 4. Error representation

- `str.format`: missing positional/keyword argument → `IndexError`/`KeyError`;
  malformed format string → `ValueError`; bad attribute/index → the underlying
  error. Source: <https://docs.python.org/3/library/string.html>.
- `string.Template.substitute`: missing key → `KeyError`; invalid placeholder like
  `$100` → `ValueError`. `safe_substitute` never raises for missing/malformed,
  leaving placeholders intact. Source: ibid.
- f-string expression errors propagate at evaluation. (Assessment: derived from
  <https://docs.python.org/3/reference/lexical_analysis.html#f-strings>.)

## 5. Ownership semantics

Strings are **immutable**; every formatting call returns a **new `str`**. There is
no borrowed view or in-place buffer in the public model. (Assessment: derived
from Python's `str` type and the immutable-string design described at
<https://docs.python.org/3/library/stdtypes.html#textseq>.)

## 6. Blocking / non-blocking

Pure in-memory formatting; no I/O, no async in the formatting API. (Assessment:
derived from the API descriptions at
<https://docs.python.org/3/library/string.html>.)

## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)

`{}` **replacement fields**:
`replacement_field := "{" [field_name] ["!" conversion] [":" format_spec] "}"`,
`field_name := arg_name ("." attribute_name | "[" element_index "]")*`.
`{{`/`}}` escape braces. **arg_name** is a number or keyword; bare `{}` auto-numbers.
**conversion** `!s`, `!r`, `!a`. Source:
<https://docs.python.org/3/library/string.html>.

Standard **format-spec** mini-language:
`[[fill]align][sign]["z"]["#"]["0"][width][grouping][.precision][grouping][type]`,
align `< > = ^` (`=` only numeric), sign `+ - space`, grouping `,` or `_`,
precision, type `b c d e E f F g G n o s x X %`. Source: ibid.

Distinctive: **nested replacement fields inside a format_spec** allow dynamic
width/precision, and the precision for strings is the maximum number of
characters. Source: ibid.

**Locale**: the `n` presentation type is locale-aware for digit grouping, but
"the default locale is not the system locale" — you must call
`locale.setlocale(LC_NUMERIC, …)` first. Source: ibid.

## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)

- Malformed spec, missing key, or wrong index → exceptions (`ValueError`,
  `KeyError`, `IndexError`), never UB. Source:
  <https://docs.python.org/3/library/string.html>.
- **Type mismatch** is handled dynamically: an invalid format type for a value
  raises `ValueError`/`TypeError` from `__format__`. (Assessment: derived from
  PEP 3101 and the `format()` builtin at
  <https://docs.python.org/3/library/functions.html#format>.)
- A **str passed as a format string is fine** — Python checks at runtime; there is
  no injection memory hazard because there is no raw-pointer varargs.
- `Template.safe_substitute` is the "never raise" escape hatch. Source: ibid.

## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)

- **Owned result**: `str` (immutable).
- **Borrowed view**: none in the public formatting model; `memoryview` exists but
  is unrelated to formatting.
- **Builder**: `io.StringIO` + `write`, or repeated `+=`/`str.join` of parts;
  `Formatter.parse` yields (literal, field, spec, conversion) tuples so a custom
  Formatter can stream parts. Source:
  <https://docs.python.org/3/library/string.html>.

## 10. Interesting design decisions

- **Separate `parse`/`get_field`/`format_field`/`convert_field` hooks** make the
  whole formatter subclassable and auditable — a good extension seam.
- **`str.format` is dynamic (runtime-checked) while f-strings are lexical**; PEP
  3101 predates f-strings. Source:
  <https://docs.python.org/3/library/string.html>.
- **Nested format specs** give dynamic width without the C/Go `*` trick.
- **`Template.safe_substitute`** — a documented "best-effort, never raise" mode,
  rare among formatting systems. Source: ibid.
- **Two unrelated things called "template string"** (`$`-Template vs 3.14
  t-strings) — a naming caution. Source: ibid.

## 11. Decisions NOT to copy

- **Runtime-only checking of `str.format`** — Mojo prefers compile-time for
  `t"…"` and typed runtime errors for a checked template API.
- **`!a` (ascii) conversion** and `safe_substitute`'s silent malformed handling
  hide errors; Mojo should report.
- **`%=`-style old `%`-formatting** — a legacy duplicate to avoid.
- **Locale via process-global `setlocale`** is a footgun; if locale is supported,
  pass it explicitly (cf. C++/Java).

## 12. Ideas fitting Mojo

- **f-string / t-string parity**: Python's f-strings and Mojo's `t"…"` are the
  same family; Python's separate `str.format` for runtime templates is the model
  for a possible Mojo runtime-checked formatter.
- **`Formatter`-style hook decomposition** (parse → resolve field → convert →
  format field) is a clean internal design for a Mojo formatter, even if Mojo's
  public surface stays `Writable`.
- **Nested/dynamic format specifications** are expressive; consider as a backlog
  item once a spec mini-language exists.
- **`safe_substitute` as an explicit method**, not a mode, is a reasonable
  low-surprise addition for template use (i18n).
- **`Template` for i18n** is a distinct use case worth keeping separate from
  general formatting.

## Sources

- `string` module: <https://docs.python.org/3/library/string.html>
- PEP 3101 (Advanced String Formatting):
  <https://peps.python.org/pep-3101/>
- PEP 292 (Simpler String Substitutions):
  <https://peps.python.org/pep-0292/>
- f-strings (lexical analysis):
  <https://docs.python.org/3/reference/lexical_analysis.html#f-strings>
- `format()` builtin: <https://docs.python.org/3/library/functions.html#format>
