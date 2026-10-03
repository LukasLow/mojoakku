# format research: Mojo (pointer note — facts come from the `mojov1` buch)

Per `AGENTS.md` and `NewLibPhase1Research.md`, Mojo facts are **read from the
`mojov1` buch, never from the internet and never from memory**. This file only
records *which* buch pages answer the standardized question set and *which
questions they leave open*. It duplicates no facts.

## Buch pages consulted

- `mojov1/stdlib/format` — the `format` package: `Writable`, `Writer`, `repr`,
  `TString`, idioms, pitfalls, stability.
- `mojov1/types/bool-and-strings` — the `String` family, `String.format()`,
  raw/t-strings, the three length measurements, operators.
- `mojov1/basics/literals` — string and t-string literal syntax, escaping,
  `TString` laziness.
- `mojov1/stdlib/builtin` — `Error`, `Writable`/`Writer` mention, `format_int`
  (`hex`/`oct`/`bin`), variadics.
- `mojov1/stdlib/collections` — `String.format()` usage example.
- `mojov1/stdlib/io` — `Writable`/`Writer` pair re-exported.
- `mojov1/stdlib/traits` — `Writable`, `Writer` listed.
- `mojov1/versions/1.1.0` — t-strings compile faster; `TString` no longer
  parameterized on its format string.

## What the buch answers

| Q | Buch answer (page) |
| --- | --- |
| Q1 stdlib | `format` package + `String` family (`mojov1/stdlib/format`, `types/bool-and-strings`) |
| Q2 community | Not applicable — Mojo's formatting is stdlib-first (buch covers only std) |
| Q3 APIs | `Writable.write_to`/`write_repr_to`, `Writer.write_string`/`write`, `repr`, `TString`, `String.format()` (`mojov1/stdlib/format`); `hex`/`oct`/`bin` (`mojov1/stdlib/builtin`) |
| Q4 errors | Not answered for formatting (see Open questions) |
| Q5 ownership | `String` owned, `StringSpan`/`StaticString`/`StringLiteral` views; `Writable` writes through `mut writer` (`mojov1/types/bool-and-strings`, `stdlib/format`) |
| Q6 blocking | Not answered (formatting is in-memory; buch silent on I/O) |
| Q7 spec | `t"…"` interpolation; `format()` manual (`{0} {1} {0}`) and automatic (`{}`) indexing; **no width/precision/alignment mini-language documented** (`mojov1/types/bool-and-strings`, `basics/literals`) |
| Q8 bounds/errors | Not answered for formatting (see Open questions) |
| Q9 layers | Owned `String` + borrowed views + `Writer` as the builder/destination layer (`mojov1/stdlib/format`, `types/bool-and-strings`) |
| Q10 design | Reflection-based `Writable` default; `t"…"` lazy and preferred over `format()`; `write_to` vs `write_repr_to` (`mojov1/stdlib/format`) |
| Q11 not to copy | Not a Mojo question — see the reference-language files |
| Q12 Mojo fit | Traits already fit: `Writable`/`Writer`, `raises`, `var`/`borrowed`, `comptime` (`mojov1/stdlib/format`, `mojov1/errors/error-model`, `mojov1/errors/raising-and-propagation`) |

## Open questions the buch leaves (the gap premise)

These are the unanswered parts that justify a `text_format` library. They are
**buch gaps**, not internet gaps; if a later pass finds the answer in official
docs, `buch_update` should record it.

1. **No documented width/precision/alignment/sign/radix mini-language.** The buch
   documents `{}` and `{n}` indexing for `String.format()`, and it *does* document
   the `{!r}` conversion specifier (`Writable.write_repr_to`;
   `mojov1/stdlib/format`). What it leaves open is **width, precision, alignment,
   fill, sign, radix (base) and digit-grouping** specifiers for `format()`. Whether
   `format()` supports those is the open question.
   (`mojov1/types/bool-and-strings`, `mojov1/stdlib/format`)
2. **No documented error representation** for a malformed format string, a missing
   or extra argument, or a type mismatch. The buch does not say whether
   `String.format()` raises, aborts, or renders a marker.
3. **No documented format-string injection / bounds contract.** Whether a runtime
   format string is safe or a hazard is not stated.
4. **No documented locale support.** The buch never mentions locale-aware number
   or date formatting; `format()`'s locale behaviour is unknown.
5. **No documented brace-escaping rule for `String.format()`.** Literal-brace
   doubling is documented for t-strings (`{{`/`}}`) but not for `format()`.
6. **`Writable`/`Writer` stability is unmarked.** The buch records no
   `@stable(since=…)` on the `format` package, so it is unstable by default; a
   library cannot yet rely on the signatures being frozen.
7. **No general `Writable` for all numeric formats.** Only `hex`/`oct`/`bin`
   helpers are documented (`mojov1/stdlib/builtin`); there is no documented
   decimal-width/precision API, no sign/grouping control, no float precision
   control.
8. **No builder type documented.** `Writer` is the destination trait, but a
   standard `StringBuilder` is not the documented stdlib type (the buch shows a
   custom `StringBuilder` only as an example). Whether a builder should be added
   or is already available is an open question.
