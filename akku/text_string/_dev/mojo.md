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
- **Q6 blocking / non-blocking** — not applicable: string types are pure
  in-memory values with no I/O, so the buch has nothing to say here and the
  question is **answered as N/A**, not open.
- **Q7 text model** — UTF-8; three lengths disagree; iteration yields **grapheme
  clusters** by default since 1.0; `__len__()` deprecated.
- **Q8 bounds / invalid input** — **open in the buch**: the buch does not state
  the out-of-range and empty-edge semantics of `String`/`StringSpan` indexing and
  slicing, nor which operations raise. This is part of the gap premise below.
  The installed-toolchain behaviour *is* now recorded empirically: see the
  checked-in artifact `std_probe.mojo` + `std_probe.log` and the answers below.
- **Q10/Q11/Q12** — operator efficiency (`String(a, b)` variadic beats `+`
  chaining); the `StringSlice` → `StringSpan` rename; `TString` laziness.

## What the probe answers (installed std symbols)

The buch does not enumerate the everyday string operations. That enumeration is
**answered empirically** by the checked-in probe artifact in this directory
(`std_probe.mojo` + `std_probe.log`; run with
`smd mojo run akku/text_string/_dev/std_probe.mojo` on Mojo 1.1.0). The probe
shows the installed `std` already ships these operations on `String`/
`StringSpan`, so the corresponding candidates are **wrap/extend** cases, not
rebuilds:

- search: `find(substr, start) -> Int` and `rfind(substr, start) -> Int` (both
  return the sentinel `-1` on a miss), `count(substr)`, `startswith(prefix,
  start, end)`, `endswith(…)`, and the `in` operator;
- split: `split(sep)`, `split(sep, maxsplit)`, `split(None)` (whitespace runs),
  `splitlines(keepends)` — all returning `List[StringSpan]`;
- trim: `strip()` / `strip(chars)` / `lstrip(...)` / `rstrip(...)`, all
  **ASCII whitespace only** (NBSP and U+3000 survive);
- case: `lower()` / `upper()` with full Unicode mapping;
- replace: `replace(old, new)` (all occurrences, no count argument);
- affix: `removeprefix` / `removesuffix`;
- measurement: `byte_length()`, `count_codepoints()`, `count_graphemes()`;
- indexing/slicing: the annotated `s[byte=…]`, `s[codepoint=…]` forms (plus
  `StringSpan[grapheme=…]`); the operations **abort** on an out-of-range index
  or a mid-codepoint byte slice rather than reporting an error;
- construction/bridge: `String(from_utf8=Span[UInt8])` (raises),
  `String(from_utf8_lossy=…)`, `String(unsafe_from_utf8=…)`,
  `String(capacity_bytes=…)`, and the mutating `+=` / `append(Codepoint)` /
  `reserve_bytes` / `resize`.

The probe also records the symbols `std` does **not** have (the library's real
gap surface): `trim`/`trim_start`/`trim_end`, `capitalize`, `casefold`,
`replace_n`, `rsplit`, `split_once`/`partition`, `is_char_boundary`,
checked `slice`/`try_slice`, `is_valid_utf8`, `clear`, `pop`, `shrink_to_fit`,
and any `StringBuilder` type.

## What the buch does NOT answer (the gap premise)

These are the parts of the question set the buch leaves open, and therefore the
candidate surface of `akku/text_string`:

- the **builder** type for efficient incremental construction (`std` has no
  `StringBuilder`; the probe confirms this);
- the **byte ↔ text bridge** rules and **boundary-safety** (char/byte indexing,
  slicing on codepoint vs grapheme boundaries, invalid-boundary behaviour) —
  `std` **aborts** on a bad boundary instead of reporting it;
- typed-absence **search/split** (`Optional` instead of `std`'s `-1`
  sentinel) and the split-once pair;
- which string operations **raise** and with which error types (the buch leaves
  this open; the probe records where `std` aborts).

The search/split/replace/trim/case/prefix-suffix operations themselves are no
longer an open question: the probe above records which ones `std` already
provides. Those become *wrap/extend* cases (or are deliberately not re-wrapped),
not rebuilds — the same stdlib-first rule that shaped `akku/prim_bit`.

See `README.md` for the frozen run configuration and the status table.
