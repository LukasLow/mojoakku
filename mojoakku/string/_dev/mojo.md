# string research: Mojo

The Mojo side is **not** researcher-written. The authoritative facts live in the
`mojov1` buch and are read from there, never guessed and never researched from
the internet.

## Where the buch answers this

- `mojov1/types/bool-and-strings` — the string family, the three length
  measurements, grapheme-cluster iteration, raw/t-strings, operators.

## What the buch answers (question set coverage)

Summarised from the buch page `mojov1/types/bool-and-strings`:

- **Q1 stdlib support** — yes, extensive: `String` (owned, mutable, heap,
  UTF-8), `StringSpan`, `StaticString`, `StringLiteral`, `Codepoint`. UTF-8
  validity enforced at construction.
- **Q3 exposed APIs** — `byte_length()`, `count_codepoints()`,
  `count_graphemes()`; `bytes()`, `codepoints()`, `codepoint_slices()`;
  operator `+`, `*`, `<`, `==`, `in`; `format()`, `TString` (`t"…"`), raw and
  triple-quoted literals, `\u`/`\U` escapes.
- **Q4 error representation** — the buch documents `raises`/`Error` as the model;
  it does **not** enumerate which string operations raise.
- **Q5 ownership semantics** — `String` owns; `StringSpan`/`StaticString` are
  non-owning views; `StringLiteral` materialises to `String` or `StringSpan`.
- **Q7 text model** — UTF-8; three lengths disagree; iteration yields **grapheme
  clusters** by default since 1.0; `__len__()` deprecated.
- **Q10/Q11/Q12** — operator efficiency (`String(a, b)` variadic beats `+`
  chaining); the `StringSlice` → `StringSpan` rename; `TString` laziness.

## What the buch does NOT answer (the gap premise)

These are the parts of the question set the buch leaves open, and therefore the
candidate surface of `mojoakku/string`:

- the **everyday search/split/replace/trim/case/prefix-suffix** operations and
  whether they exist on `String`/`StringSpan` (`find`, `split`, `join`,
  `replace`, `trim`, `starts_with`, `ends_with`, `to_lower`/`to_upper`);
- a **builder** type for efficient incremental construction;
- the **byte ↔ text bridge** rules and **boundary-safety** (char/byte indexing,
  slicing on codepoint vs grapheme boundaries, invalid-boundary behaviour);
- which string operations **raise** and with which error types.

The research must establish this gap against the reference languages before any
API is designed. If any of the above already exists in `std`, the corresponding
entry becomes a *wrap/extend* case, not a rebuild — the same stdlib-first rule
that shaped `mojoakku/bit`.

See `README.md` for the frozen run configuration and the status table.
