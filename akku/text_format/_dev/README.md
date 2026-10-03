# text_format research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `text_format`.

## What the library is

`akku/text_format` provides **string formatting and interpolation**: turning
typed values into text in a controlled shape — interpolation with a format
template, a format-spec mini-language (width, precision, alignment, sign,
radix/type), placeholders and their argument binding, and the error/bounds
contract around malformed templates.

It sits next to `akku/text_string` (the owned/view/builder primitives) and
builds on Mojo's existing `Writable`/`Writer`/`TString` facilities (buch
`mojov1/stdlib/format`). It is a text-adjacent library and may later be a
dependency of logging, CSV, HTTP-header, JSON and diagnostic-message code.

## Positioning fact (gap premise)

Mojo 1.x **already ships** an interpolation facility and a formatting trait
family, and the `mojov1` buch documents them:

- `Writable` (`write_to`/`write_repr_to`) and `Writer` (`write_string`/`write`)
  are the formatting traits (buch `mojov1/stdlib/format`).
- `t"…"` (`TString`) is the lazy interpolation literal, preferred over
  `String.format()` (buch `mojov1/basics/literals`, `types/bool-and-strings`).
- `String.format()` exists with automatic (`{}`) and manual (`{0} …`) indexing
  (buch `mojov1/types/bool-and-strings`).

The **unanswered** part — the reason to build a library — is the format-spec
mini-language and its error contract. The buch documents **no** width, precision,
alignment, sign, radix, locale, or malformed-template/arity error behaviour. That
gap is recorded in `mojo.md` and is the premise this research tests against the
reference languages. Mojo facts come **only** from `mojov1`; no internet Mojo
sources, no memory.

## Selected languages (frozen)

Mandatory languages, always present: **C, C++, Go, Rust, Python, JS/TS** — plus
**Mojo**, covered by the `mojov1` buch (no researcher).

For this run the selection collapses the usual *one-researcher-per-group* model
into a **single researcher** (this task): the language groups are the mandatory
set plus Java. There is no separate parallel fan-out.

| group | languages | one-line reason |
| --- | --- | --- |
| systems-lowlevel | C, C++ | C's `printf` is the raw `%`-spec floor (and its UB/`%n` hazards); C++ `std::format` is the first stdlib formatter with **compile-time format-string checking** and a returned owning `std::string` |
| systems-modern | Go, Rust | Go's `fmt` verbs + **rune-based width** and error-strings-in-output; Rust's `format!`/`Writable`-like traits and **literal-only, compile-time-checked** templates are the closest ancestors of Mojo's `t"…"`+traits |
| scripting-web | Python, JS/TS | Python's `str.format` mini-language + f-string/t-string split is the richest spec model; JS/TS **tagged templates** are the composable interpolation model with the `TString`-closest design |
| managed-JVM | Java | `java.util.Formatter` is the canonical **strict** printf derivative: unknown conversion or incompatible flag throws, locale is explicit, `Formattable` customizes user types |

## Dropped languages (with one-line reason)

- **Swift** — grapheme model irrelevant to formatting (no distinct formatting API).
- **C#** — delegates to a Java-like model; adds no distinct signal over Java.
- **Kotlin** — delegates to `java.lang.String`/`java.util.Formatter`.
- **Zig** — no distinct formatting model over C/C++.
- **Odin** — no distinct formatting model over C/C++.
- **Perl** — mirrors Python/C `%` semantics without a distinct model.
- **PHP** — printf-like without a distinct model over C/Python.
- **Dart** — no distinct formatting model over JS/Python.
- **Elixir** — niche binary/bitstring formatting; not a general text model.
- **Julia** — numeric/array printing, no distinct general format model.
- **R** — no distinct model over Julia/Python.

Per `NewLibPhase1Research.md` the roster is a pool, not a mandate; each drop is
recorded above with its reason.

## Frozen question set (formatting)

The standardized 12 questions apply in order. Q7–Q9 are adapted for formatting;
Q1–Q6, Q10–Q12 are verbatim.

1. What does the language's standard library provide for this problem, and under
   which module/package names?
2. Which relevant community libraries exist (name, maintainer, maturity,
   license)?
3. Which public APIs do those stdlib/community implementations expose (functions,
   types, methods, constants)?
4. How is an error represented (error codes, exceptions, `Result`/`Either`,
   sentinel values, out-parameters)?
5. What are the ownership/lifetime semantics (who owns the buffer, who owns the
   handle/socket, who frees what)?
6. Is the API blocking or non-blocking, and how are async/concurrency models
   handled?
7. **(was IPv4/IPv6)** The **formatting model**: syntax, placeholders, spec,
   width/precision/alignment, and locale.
8. **(was timeouts)** **Bounds, invalid input and errors**: bad placeholder,
   missing/extra argument, type mismatch, format-string injection.
9. **(was TLS)** **Owned type, borrowed view and builder layer**: how the
   language builds formatted output across the three layers.
10. Which interesting design decisions are worth studying?
11. Which decisions should explicitly NOT be copied into MojoAkku, and why?
12. Which ideas fit Mojo specifically (ownership model, `raises`,
    `var`/`borrowed`, value semantics, compile-time features)?
13. **Sources** — every factual claim cites a source.

## Writing contract

Each language file uses exactly this structure:

```
# format research: <lang>
## 1. Standard library support
## 2. Relevant community libraries
## 3. Exposed APIs
## 4. Error representation
## 5. Ownership semantics
## 6. Blocking / non-blocking
## 7. Formatting model (syntax, placeholders, spec, width/precision/alignment, locale)
## 8. Bounds, invalid input and errors (bad placeholder, missing/extra argument, type mismatch, format-string injection)
## 9. Owned type, borrowed view and builder layer (how the language builds formatted output)
## 10. Interesting design decisions
## 11. Decisions NOT to copy
## 12. Ideas fitting Mojo
## Sources
```

Every factual claim cites a source (URL, RFC, or `repo/path:line`). Derived
statements are marked `(Assessment: derived from <sources>)`; unsourced
statements are marked `GUESS:` with the reason no source exists. No source is
invented.

The Mojo side is **not** a researcher-written fact file: `mojo.md` is a pointer
note recording what the `mojov1` buch answers and which questions it leaves open.
Mojo facts are never taken from the internet or from memory.

## Status

| lang | group | file | state |
| --- | --- | --- | --- |
| C | systems-lowlevel | `c.md` | done |
| C++ | systems-lowlevel | `cpp.md` | done |
| Go | systems-modern | `go.md` | done |
| Rust | systems-modern | `rust.md` | done |
| Python | scripting-web | `python.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Mojo | (buch) | `mojo.md` → `mojov1/stdlib/format`, `types/bool-and-strings`, `basics/literals` | covered by buch |
| — | seed backlog | `TODO.md` | done |

Researchers started: **1** (this task; the frozen selection is the mandatory set
plus Java, handled by one researcher rather than a 6-group fan-out).

Phase 1 is complete; the review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.
