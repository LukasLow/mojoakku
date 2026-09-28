# string research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `string`.

## What the library is

`mojoakku/string` provides **text primitives**: characters, bytes, slicing and
comparison. It is a leaf library (no sibling dependencies, `depends_on: []`) and
sits on the critical path of the whole catalogue — 36 other libraries declare
`string` as a dependency (`url`, `mime`, `json`, `parser`, `regex`, `path`,
`html`, `csv`, `toml`, `yaml` …), so its shape decides the ergonomics of the
libraries above it.

## Positioning fact (found during phase setup)

Mojo 1.x **already ships a rich string family** in the standard library, and the
`mojov1` buch documents it (`mojov1/types/bool-and-strings`). Facts that frame
the gap premise:

- `String` is the **owned, mutable, heap-allocated UTF-8** type;
  `StringSpan`/`StaticString`/`StringLiteral` are the **non-owning views**
  (`StringSlice` is the deprecated pre-1.0 alias). UTF-8 validity is enforced at
  construction (`String(from_utf8_lossy=…)`, `String(unsafe_from_utf8=…)`).
- Three **disagreeing length measurements** exist on purpose:
  `byte_length()`, `count_codepoints()`, `count_graphemes()`.
- **Iteration yields grapheme clusters** by default since 1.0; the lower-level
  views are `codepoints()`, `codepoint_slices()` and `bytes()`.
- `String.__len__()` is deprecated in 1.x (write the measurement you mean).
- Operators exist: `+`, `*`, `<`/`==`, `in` (substring membership), `format()`,
  `TString` (`t"…"`, lazy, preferred over `format()`).

Consequence: the *basic owned type and its operators* are a **stdlib-first
case** (wrap or extend), not a reason to rebuild them. The library's real reason
to exist is what `std` does **not** provide, and the research must establish that
gap against the reference languages:

1. **search / split / replace / trim / case / prefix-suffix** — the everyday
   string operations (`find`, `rfind`, `split`, `join`, `replace`, `trim`,
   `starts_with`, `ends_with`, `to_lower`/`to_upper`) if `std` does not already
   expose them on `String`/`StringSpan`;
2. a **builder** for efficient incremental construction (the
   `StringBuilder` / `strings.Builder` / `Vec<u8>` model) with an explicit
   append/flush contract, if `std` lacks one;
3. a principled **byte ↔ text bridge** and the **boundary-safety rules** —
   char/byte indexing, slicing on codepoint or grapheme boundaries, and what
   happens at an invalid boundary.

Mojo facts are read from `mojov1`; they are never guessed and never researched
from the internet.

## Selected languages (frozen)

Text exists in every language, so presence is not a discriminator. The languages
below are the ones whose **text model differs in a way worth studying** — in
particular their *length/encoding model* (bytes vs code units vs codepoints vs
graphemes), their *owned-vs-view split*, and their *builder* model.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | C has **no string type at all** (NUL-terminated `char*`, manual length, `strlen`/`memchr`) — the raw floor; C++ adds `std::string` + `std::string_view` (the ancestral owned/view split) and SSO |
| systems-modern | 1 | Go, Rust, Swift | Go's string is **immutable UTF-8** with `[]rune`/`[]byte` dual views and `strings.Builder`; Rust's `String`/`&str` enforces UTF-8 and is the closest ancestor of Mojo's model; Swift's `String` is **grapheme-cluster-based** — the sharpest contrast to byte/codepoint models and the closest match to Mojo's 1.0 iteration semantics |
| scripting-web | 1 | Python, JS/TS | Python splits `str` (codepoint-indexed, immutable) from `bytes`; JS/TS strings are **UTF-16 code units** — the famous length/index trap and a distinct model from UTF-8 |
| managed-JVM | 1 | Java | `java.lang.String` is **UTF-16, immutable**, with `StringBuilder`/`StringBuffer` and explicit codepoint APIs (`codePointAt`, `offsetByCodePoints`) — the canonical code-unit model with a mature builder |
| functional/BEAM | 1 | Elixir | binaries and bitstrings are **arbitrary-length byte sequences**; `String` adds Unicode (`String.length`, `graphemes`) on top of the binary — a distinct "binary vs text" split with excellent Unicode handling |
| data/science | 1 | Julia | `String` (UTF-8) with `SubString` views and **byte-indexed but boundary-checked** indexing (`thisind`, `nextind`) — the strongest "indexing that refuses to split a codepoint" reference |

All six groups are selected this run (6 researchers, the upper bound). Groups
that were trimmed within their roster and the reason:

- **C#, Zig, Odin** (systems-modern) dropped: C# is UTF-16 like Java and adds no
  new *model* over Java + JS/TS; Zig/Odin add no distinct text model over C/C++.
- **Perl, PHP, Dart** (scripting-web) dropped: they largely mirror Python/JS
  semantics without a distinct length/ownership model.
- **Kotlin** (managed-JVM) dropped: it delegates to `java.lang.String`.
- **OCaml, F#, Haskell** (functional/BEAM) dropped: Elixir already carries the
  functional/BEAM string story and a distinct binary-vs-text split.
- **R** (data/science) dropped: Julia carries the numeric/array string-view
  story; R's string handling adds no new model over it.

## Question set (adapted for string)

The standard 12 questions apply in order. The socket-specific questions are
replaced by text equivalents; everything else is unchanged:

- Q7 (was IPv4/IPv6) → the **text model**: what a "character" is (byte vs
  UTF-16 code unit vs codepoint vs grapheme cluster), which encoding is assumed,
  how length is measured, and how indexing/slicing defines a position.
- Q8 (was timeouts) → **bounds, invalid input and errors**: out-of-range index,
  invalid UTF-8 on input, slicing on a non-boundary, empty/zero-length edges,
  and what is defined vs panic/undefined.
- Q9 (was TLS) → the **three layers** and how the language divides them: the
  owned string type, the borrowed view/span, and the builder/mutating layer;
  plus the byte ↔ text bridge. Which of the three the language's stdlib actually
  provides.

Q1–Q6, Q10–Q12 are kept verbatim.

## Writing contract

Each researcher writes its language files **directly** into
`mojoakku/string/_dev/<lang>.md`, one file per language of its group, using
exactly this section structure:

```
# string research: <lang>
## 1. Standard library support
## 2. Relevant community libraries
## 3. Exposed APIs
## 4. Error representation
## 5. Ownership semantics
## 6. Blocking / non-blocking
## 7. Text model (encoding, length, indexing)
## 8. Bounds, invalid input and errors
## 9. Owned type, borrowed view and builder layer
## 10. Interesting design decisions
## 11. Decisions NOT to copy
## 12. Ideas fitting Mojo
## Sources
```

There is no reporting-project and no `docs` materialization pass. Every factual
claim cites a source (URL, RFC number, or `repo/path:line`). Derived statements
are marked `(Assessment: derived from <sources>)`; unsourced statements are
marked `GUESS:` with the reason no source exists.

The Mojo side is **not** a researcher-written file: the facts live in the
`mojov1` buch (`mojov1/types/bool-and-strings`). `mojo.md` is a small pointer
note that records what the buch answers and which parts of the question set it
does not — those unanswered parts are the library's gap premise.

## Status

| lang | group | file | state |
| --- | --- | --- | --- |
| C | systems-lowlevel | `c.md` | done |
| C++ | systems-lowlevel | `cpp.md` | done |
| Go | systems-modern | `go.md` | done |
| Rust | systems-modern | `rust.md` | done |
| Swift | systems-modern | `swift.md` | done |
| Python | scripting-web | `python.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Elixir | functional/BEAM | `elixir.md` | done |
| Julia | data/science | `julia.md` | done |
| Mojo | (buch) | `mojo.md` → `mojov1/types/bool-and-strings` | covered by buch |

Researchers started: **6** (one per selected group; the upper bound).

All ten language files were written directly by their group's researcher: 6
researchers, one per selected group. Phase 1 is complete; the review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.
