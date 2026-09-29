<!--
Design record for mojoakku/text_string — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state of Phase 5 (docs), derived from the
approved Phase-2 research and from the checked-in probe artifact
`_dev/std_probe.mojo` + `_dev/std_probe.log` (Mojo 1.1.0; see `## Overview`,
"Empirical std surface"). The 16 API blocks below use the same seven-field set
in the same order: Status, Signature, Semantics, Errors, Tests, Implementation
status, Rationale.
-->

# text_string — Design Record

## Purpose

`mojoakku/text_string` is the MojoAkku **text primitives** library: the one predictable
string layer every parser and protocol library above it (`url`, `mime`, `json`,
`parser`, `regex`, `path`, `html`, `csv`, `toml`, `yaml`, …) can rely on. It is a
**leaf library** (`depends_on: []`) and sits on the critical path of the whole
catalogue, so its shape decides the ergonomics of 36 dependent libraries.

It is designed for a low-vision user: **one error model**, **one naming scheme**,
**no sentinels**, borrowed inputs, owned outputs, and explicit behaviour at every
edge. The Mojo standard library already ships a rich string family — `String`,
`StringSpan`, `StaticString`, three length measurements, grapheme iteration,
`find`, `split`, `strip`, `lower`/`upper`, `replace`, `startswith`/`endswith` and
`removeprefix`/`removesuffix` — so the library's job is **not** to rebuild that.
It fills the four gaps `std` leaves (established empirically in `## Overview`):

1. a **builder** for efficient incremental construction (`StringBuilder`), with
   an explicit append/reserve/finish contract;
2. **typed-absence search and split** — `find`/`rfind` returning `Optional[Int]`
   instead of `std`'s `-1` sentinel, and `split_once`/`rsplit_once` returning the
   `(before, after)` pair `std` lacks;
3. **boundary-safe slicing** — `is_char_boundary`, a checked raising `slice`, and
   an `Optional`-returning `try_slice`, because `std` indexing aborts on a
   non-codepoint boundary rather than reporting it;
4. a **small, closed text error type** (`StringError`/`StringErrorKind`) and an
   allocation-free `is_valid_utf8`, so the byte ↔ text bridge reports a *value*
   instead of a panic.

This file is the **design record**, not end-user documentation. End-user docs
live inline in the `*.mojo` files after Phase 7.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 16 entries in this document are `planned` at Phase 5; every entry's
`Implementation status:` is `not implemented` until Phase 11.

## Dependencies

`text_string` has **no dependency edge to any sibling MojoAkku library**. It is a leaf
in the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Every signature is built from the Mojo standard library (`String`, `StringSpan`, `StaticString`, `Span[UInt8, _]`, `Codepoint`, `List`, `Optional`, `Tuple`, `Int`, `Bool`, `UInt8`, `Some[Writer]`). No signature mentions a stream, socket, file, buffer, URL or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `text_string` needs none; every parameter and
  return type comes from the standard library. Adding an edge would create
  coupling without a technical reason, which the dependency rules forbid.
- **No physical nesting.** `mojoakku/text_string/` is a flat sibling under
  `mojoakku/`; no library is nested inside it and it is never nested elsewhere.
- **Direction of future edges.** `url`, `json`, `parser`, `path`, `html` and the
  other 35 dependents point *to* `text_string`, never the reverse. That does not change
  this document.
- **The stdlib relationship.** MojoAkku `text_string` does **not** reimplement the
  stdlib string family. Where `std` already exposes an operation (`find`, `split`,
  `strip`, `lower`/`upper`, `replace`, `startswith`/`endswith`,
  `removeprefix`/`removesuffix`, `bytes`/`codepoints`/`codepoint_slices`,
  `String(from_utf8…)`, `String.join`, `StringBuilder`-free mutation via
  `+=`/`append`/`reserve`), `text_string` **wraps or extends** it — it never rebuilds
  it. The exact probed `std` surface is in `## Overview`.

## Overview

MojoAkku `text_string` is a pure, in-process, deterministic text library. It does not
introduce a new string type: the substrate is the stdlib's
`String`/`StringSpan`/`StaticString` triple, and the library adds only the layers
`std` leaves open. The API is grouped into five themes:

1. **Error surface** — `StringErrorKind`, `StringError`. One closed discriminant
   and one typed error carrying a `position`; used by `slice` and `replace_n`.
2. **Builder layer** — `StringBuilder`. An owning incremental text buffer with
   `append`/`append_codepoint`/`append_bytes`/`reserve`/`clear`/`byte_length`/
   `to_string`/`finish`, plus `Writer` conformance for formatted output.
3. **Search and split** — `find`, `rfind` (both `Optional[Int]`, replacing the
   `-1` sentinel), `split_once`, `rsplit_once` (the `(before, after)` pair).
4. **Trim, case and replace** — `trim` (Unicode-whitespace aware, with an explicit
   char-set overload), `capitalize`, `to_ascii_lower`, `to_ascii_upper`, and
   `replace_n` (the counted variant `std.replace` lacks).
5. **Boundary and byte bridge** — `is_char_boundary`, `slice` (checked, raising),
   `try_slice` (`Optional`), `is_valid_utf8` (allocation-free predicate).

Cross-cutting shape:

- **One typed error** (`StringError`) with a closed `StringErrorKind`
  discriminant — no `-1` sentinel for absence, no panic-as-error.
- **Absence is `Optional`**, never a sentinel: `find`/`rfind`/`try_slice`/
  `split_once`/`rsplit_once` all return `Optional`.
- **Borrowed in, owned out.** Every query borrows a `StringSpan` and returns a
  `StringSpan` view or a plain value; every transform that allocates returns an
  owned `String` (or the builder's owned `String`).
- **No hidden global state.** Nothing mutates process-global state; there is no
  ambient locale and no default encoding switch.
- **Pure Mojo.** No Python dependency, no FFI, no `unsafe_*` in the public
  surface.

### Empirical std surface (Mojo 1.1.0, probed)

The API set below is **auditable**: it is the direct reading of the probe
artifact checked into this directory — `std_probe.mojo` (the program) and
`std_probe.log` (its captured output, plus the per-line negative-check errors).
Re-run it with:

```
smd mojo run mojoakku/text_string/_dev/std_probe.mojo
```

The probe was run in the `smd` container on **Mojo 1.1.0 (8189361e)**. Every `✓`
row is one `print` line in `std_probe.mojo`; every `✗` row is a one-line snippet
in the artifact's NEGATIVE CHECKS block, whose exact compiler error is in
`std_probe.log`. This is the empirical basis for "wrap/extend, not rebuild" and
for the gap list.

| Area | Present in `std` (wrap/extend) | Absent in `std` (this library's gap) |
| --- | --- | --- |
| Length | `byte_length()`, `count_codepoints()`, `count_graphemes()`; `len(s)` is a compile error by design | — |
| Search | `find(substr, start) -> Int` (`-1`), `rfind(substr, start) -> Int` (`-1`), `count(substr)`, `startswith(prefix, start, end)`, `endswith(...)`, `in` | `Optional`-returning find/rfind; `split_once`/`rsplit_once` |
| Split | `split(sep)`, `split(sep, maxsplit)`, `split(None)` (whitespace runs), `splitlines(keepends)`; all return `List[StringSpan]` | `rsplit`; `partition`/`rpartition` returning the separator |
| Trim | `strip()`, `strip(chars)`, `lstrip()`, `lstrip(chars)`, `rstrip()`, `rstrip(chars)` (ASCII whitespace only; NBSP/U+3000 are **not** stripped) | Unicode-whitespace `trim`; the `trim`/`trim_start`/`trim_end` names |
| Case | `lower()`, `upper()` (full Unicode, return owned `String`) | `capitalize`, `titlecase`, `casefold`; ASCII fast path |
| Replace | `replace(old, new)` (all occurrences) | `replace_n`, `replace_first`, `replace_last` |
| Affix | `removeprefix`, `removesuffix` (return views) | `strip_prefix`/`strip_suffix` names; `has_prefix`/`has_suffix` names |
| Indexing / slicing | `s[byte=i]`, `s[byte=a:b]`, `s[codepoint=i]`, `s[codepoint=a:b]`; `StringSpan` also `s[grapheme=a:b]`; **aborts** on an out-of-range index or a mid-codepoint byte slice | `is_char_boundary`; checked `slice`; `try_slice`; `byte_at`/`codepoint_at` helpers |
| Views / iteration | `bytes()`, `codepoints()`, `codepoint_slices()`, grapheme iteration (`for c in s`) | — |
| Construct / bridge | `String(from_utf8=Span[UInt8])` (raises), `String(from_utf8_lossy=…)`, `String(unsafe_from_utf8=…)`, `String(capacity_bytes=…)`, `String(ptr, len)`, variadic `String(a, b, …)` (a `Writable` formatter, **not** a byte bridge), `TString`, `format()` | allocation-free `is_valid_utf8` |
| Builder-ish | `String()`, `+=`, `append(Codepoint)`, `reserve_bytes`, `resize`, `capacity_bytes()`; no `clear`, `push_back`, `pop`, `shrink_to_fit`; no `StringBuilder` type in `std` | the whole explicit builder layer |

The stdlib calls are **unstable by default** (no `@stable` marker); `String`
itself is marked stable since 1.0.0, but member signatures are not promised. This
is exactly why `text_string` wraps them behind its own documented surface.

## Goals

1. **Fill exactly the four gaps the probed `std` leaves** (builder, typed-absence
   search/split, boundary-safe slicing, typed error + byte-bridge validation).
   Do not rebuild the stdlib string family.
2. **One predictable convention set** a low-vision user memorises once: byte
   offsets for positions, half-open `[start, end)` ranges, `Optional` for
   absence, typed errors for bad input, `snake_case` names.
3. **No sentinels and no panic-as-error.** Absence is `Optional`; a bad index,
   range or encoding is a `StringError`; nothing silently truncates or aborts.
4. **Borrowed in, owned out, no hidden global state.** Queries borrow a
   `StringSpan`; allocating transforms return an owned `String`; no ambient
   locale, no default-encoding switch, no package-global mutable state.
5. **Implementable in pure Mojo.** No Python, no FFI, no `unsafe_*` in the
   public surface; deterministic and fully testable with `mojo run`.
6. **A real builder with an explicit flush contract.** `StringBuilder` owns its
   buffer, exposes its byte length and capacity, and materialises through
   `to_string` (borrow-copy) or `finish` (consume-and-transfer).

## Non-Goals

Decisions deliberately **not** copied from the reference languages, or
deliberately not shipped in release 1. Each names the reference and why it does
not fit Mojo. Researched-but-unshipped **API candidates** are mirrored in
`mojoakku/text_string/_dev/TODO.md`; decisions that are *not wanted* stay only here.

- **`-1` as the "not found" index.** MojoAkku rejects Go's `Index`/`Java's
  `indexOf`/C++'s `npos` sentinel because it hides absence in arithmetic;
  `find`/`rfind` return `Optional[Int]` (`go.md` §11, `java.md` §11,
  `cpp.md` §11). Note the stdlib itself still returns `-1`; the library wraps it.
- **UTF-16 code-unit semantics.** MojoAkku rejects JS/TS and Java's UTF-16 code
  units and the `.length`/`slice` trap because Mojo is UTF-8 with three explicit
  lengths (`js-ts.md` §11, `java.md` §11). Positions here are **byte offsets**,
  except where a codepoint view is requested.
- **Slicing that can split a codepoint silently.** MojoAkku rejects Go's
  boundary-unaware `s[i:j]`, C++'s unchecked `substr` and JS's lone-surrogate
  `slice` because they produce malformed text; `slice` reports
  `NOT_A_BOUNDARY` and `try_slice` returns `None` (`go.md` §11, `cpp.md` §11,
  `js-ts.md` §11).
- **Grapheme-cluster indexing for every operation.** MojoAkku rejects Swift's
  grapheme-only index space because it makes indexing O(n); the library keeps
  O(1) byte offsets and leaves grapheme slicing to the stdlib's
  `[grapheme=…]` view (`swift.md` §11).
- **Canonical-equivalence `==`.** MojoAkku rejects Swift's normalization-aware
  `==` because byte-different strings comparing equal is dangerous for protocol
  and cache keys; normalization stays a separate, explicit operation
  (`swift.md` §11).
- **A builder-less "list + join" or `io.StringIO` idiom.** MojoAkku rejects
  Python's convention-only builder and JS's total lack of one because repeated
  concatenation is documented quadratic; the library ships an explicit
  `StringBuilder` (`python.md` §11, `js-ts.md` §11).
- **The `iodata` nested-shape builder as the primary API.** MojoAkku rejects
  Elixir's deferred nested list because Mojo has a real ownership model and
  consumers need one append/flush contract; `iodata` stays a Deferred idea
  (`elixir.md` §11).
- **A package-global or per-object encoding/case switch.** MojoAkku rejects C's
  ambient locale and Java/Go default-locale case/collation coupling; there is no
  ambient state (`c.md` §11, `java.md` §11, `go.md` §11).
- **Full-Unicode `casefold`, `titlecase`, normalization, collation.** MojoAkku
  defers these because they require Unicode property/normalization tables that
  are not in `std` and are separate concerns; the release-1 case surface is
  `capitalize` plus the deterministic ASCII fast path (`python.md` §11,
  `java.md` §11). They stay in `_dev/TODO.md`.
- **Wrapping `std` operations that already exist under the required name.**
  MojoAkku does **not** re-export `startswith`/`endswith`, `split`, `strip`,
  `lower`/`upper`, `replace` or `removeprefix`/`removesuffix`: the probe shows
  `std` already exposes them on both `String` and `StringSpan`, so a wrapper adds
  a name without adding behaviour (`go.md` §11, `elixir.md` §11).
- **A free `join` function.** MojoAkku does not add one because
  `String(sep).join(parts)` already exists in `std` and takes any
  `Span[T: Writable & Copyable]`; a second spelling would not be learnable
  (`go.md` §3, `python.md` §3).
- **Sentinel or silently-lenient trimming.** MojoAkku rejects Java's legacy
  `trim()` (`<= U+0020`, kept for compatibility and fixed only in `strip()`) and
  Python's implicit whitespace class; `trim` uses the explicit Unicode whitespace
  set and a char-set overload (`java.md` §11, `python.md` §3).
- **Undefined behaviour on non-UTF-8 input.** MojoAkku rejects Rust's UB-on-
  invalid-`str` and Julia's invalid-byte `String` default; `is_valid_utf8`
  reports validity and the builder raises `INVALID_UTF8` (`rust.md` §11,
  `julia.md` §11).

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Optional-returning search | Rust `str::find -> Option<usize>`, `rfind`; Swift `firstIndex(of:) -> Optional`; Julia `findfirst -> nothing` | `rust.md` §3, §4; `swift.md` §3, §8; `julia.md` §3 |
| Split-once / cut | Go `strings.Cut(s, sep) (before, after, found)`; Rust `split_once`; Python `partition` | `go.md` §3, §10; `rust.md` §3; `python.md` §3 |
| Builder with append/flush | Go `strings.Builder` (`Write*`, `Grow`, `Reset`, `String`, `Len`, `Cap`); Java `StringBuilder` (`append`, `capacity`, `ensureCapacity`); Julia `IOBuffer`+`takestring!`; Elixir `iodata` | `go.md` §3, §9; `java.md` §3, §9; `julia.md` §9; `elixir.md` §9 |
| Checked + non-panicking slicing | Rust `str::get(range) -> Option<&str>` and `split_at_checked`; Julia `get(s, i, default)`; Python slice clamping | `rust.md` §3, §4; `julia.md` §3, §8; `python.md` §8 |
| Boundary predicate / repair | Rust `is_char_boundary`, `floor_char_boundary`, `ceil_char_boundary`; Julia `isvalid(s, i)`, `thisind`, `nextind`, `prevind`; Elixir `String.valid?` | `rust.md` §3, §7; `julia.md` §3, §8; `elixir.md` §3, §8 |
| Two error kinds (bounds vs boundary) | Julia `BoundsError` vs `StringIndexError` (reports valid nearby indices); Elixir `{:error,…}` vs `{:incomplete,…}` | `julia.md` §4, §10; `elixir.md` §4 |
| Typed error + closed kind | Rust `Utf8Error`/`DecodeError`; Java `CharsetDecoder` `CodingErrorAction`; MojoAkku `io` `IoError`/`IoErrorKind`; MojoAkku `bit` `BitError`/`BitErrorKind` | `rust.md` §4; `java.md` §4; `mojoakku/io_core/_dev/DESIGN.md`; `mojoakku/prim_bit/_dev/DESIGN.md` |
| ASCII-only fast case path | Rust `to_ascii_lowercase`/`to_ascii_uppercase`; Go `ToLower`/`ToUpper` (full) + ASCII path in practice | `rust.md` §3; `go.md` §3 |
| Unicode whitespace trimming | Python `str.strip()` (Unicode `isspace`); Java `strip()` (`Character.isWhitespace`); Elixir `String.trim/1` | `python.md` §3; `java.md` §11; `elixir.md` §3 |
| Capitalize / first-letter case | Python `str.capitalize`; Java `indent`/text blocks; Elixir `String.capitalize` | `python.md` §3; `java.md` §12; `elixir.md` §3 |
| Counted replace | Python `str.replace(old, new, count)`; Rust `replacen`; Go `Replace(s, old, new, n)` | `python.md` §3; `rust.md` §3; `go.md` §3 |
| Allocation-free validity predicate | Elixir `String.valid?/2`; Go `utf8.ValidString`; Rust `str::from_utf8` (checked) | `elixir.md` §3, §8; `go.md` §3, §8; `rust.md` §3 |
| Mojo language anchors | `String`/`StringSpan`/`StaticString`; `Span[UInt8,_]`; `Optional`; `Tuple`; `Codepoint`; typed `raises`; `deinit self`; `Writer`; origin-parameterised `StringSpan[o]` | `mojov1/types/bool-and-strings`; `mojov1/stdlib/format`; `mojov1/errors/error-model`; check-in probe artifact `_dev/std_probe.mojo` + `_dev/std_probe.log` (Mojo 1.1.0) |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order.

**Error surface**

1. `StringErrorKind` — closed failure discriminant: `INDEX_OUT_OF_BOUNDS`,
   `BAD_RANGE`, `NOT_A_BOUNDARY`, `INVALID_UTF8`.
2. `StringError` — the one typed error: `kind: StringErrorKind`,
   `position: Int`.

**Builder layer**

3. `StringBuilder` — an owning incremental text buffer with
   `append`/`append_codepoint`/`append_bytes`/`reserve`/`clear`/`byte_length`/
   `to_string`/`finish` and `Writer` conformance.

**Search and split**

4. `find` — first occurrence of a needle as `Optional[Int]` (byte offset), the
   `-1`-free wrapper of `std.find`.
5. `rfind` — last occurrence of a needle at or after `start` as `Optional[Int]`.
6. `split_once` — split at the first separator into
   `Optional[(before, after)]`.
7. `rsplit_once` — split at the last separator into
   `Optional[(before, after)]`.

**Trim, case and replace**

8. `trim` — remove leading/trailing Unicode whitespace, or an explicit char set.
9. `capitalize` — uppercase the first codepoint, lowercase the rest.
10. `to_ascii_lower` — deterministic ASCII-only lowercase fast path.
11. `to_ascii_upper` — deterministic ASCII-only uppercase fast path.
12. `replace_n` — replace the first `count` occurrences (or all) of a needle.

**Boundary and byte bridge**

13. `is_char_boundary` — is a byte index a valid UTF-8 codepoint start (or the
    end)?
14. `slice` — checked byte-range extraction raising `StringError`.
15. `try_slice` — checked byte-range extraction returning `Optional`.
16. `is_valid_utf8` — allocation-free validity predicate over raw bytes.

## Error Surface

One error type, `StringError`, with a closed four-value `StringErrorKind`. Which
API raises what:

| API | Raises | Kinds |
| --- | --- | --- |
| `StringBuilder.append_bytes` | `StringError` | `INVALID_UTF8` (bytes are not valid UTF-8) |
| `replace_n` | `StringError` | `BAD_RANGE` (`old` is empty) |
| `slice` | `StringError` | `INDEX_OUT_OF_BOUNDS` (`start < 0` or `end > byte_length`), `BAD_RANGE` (`start > end`), `NOT_A_BOUNDARY` (`start` or `end` is not a codepoint boundary) |
| `find`, `rfind`, `split_once`, `rsplit_once`, `trim`, `capitalize`, `to_ascii_lower`, `to_ascii_upper`, `is_char_boundary`, `try_slice`, `is_valid_utf8` | none | — (absence is `Optional`; a total predicate returns `Bool`) |
| `StringErrorKind`, `StringError`, `StringBuilder` construction and `to_string`/`finish` | none | — |

Recoverability: every `StringError` is a recoverable **data** error. The caller
can clamp the index, pick a boundary from `is_char_boundary`, repair the bytes, or
supply a non-empty needle. No operation is fatal, and none aborts the process.
`StringError` conforms to `Writable`, so `print(err)` yields a readable
`kind` + `position` message.

## Conventions

- **Positions are byte offsets** into the UTF-8 buffer, zero-based. `find`,
  `rfind`, `slice`, `try_slice`, `is_char_boundary` and `StringError.position`
  are all byte offsets. Codepoint/grapheme indexing stays the stdlib's
  `s[codepoint=…]` / `s[grapheme=…]` view.
- **Ranges are half-open `[start, end)`** in bytes, matching `std`'s
  `s[byte=a:b]`, Python slicing and Rust ranges (`python.md` §7, `rust.md` §7).
  `start == end` is the empty slice; `start > end` is `BAD_RANGE`.
- **Absence is `Optional`, never a sentinel.** `find`/`rfind`/`try_slice`/
  `split_once`/`rsplit_once` use `Optional`; there is no `-1`, no `None`-vs-`""`
  split (`elixir.md` §11 rejected).
- **Borrowed in, owned out.** A query takes `StringSpan[o]` and returns a view
  (`StringSpan[o]`) or a value; an allocating transform returns `String`.
- **No hidden global state.** No ambient locale, no default encoding, no
  package-global mutable variable (`c.md` §11, `go.md` §11).
- **Names are `snake_case`** for functions and methods, `CamelCase` for types,
  `SCREAMING_CASE` for `comptime` constants — the Mojo style guide.
- **`trim` is Unicode-whitespace aware** (unlike `std`'s ASCII-only `strip`),
  matching Python `str.strip` and Java `strip`; the char-set overload makes the
  accepted set explicit (`python.md` §3, `java.md` §11).

## Ownership and Lifecycle

- **`StringBuilder` is an owning value type.** It owns a `String` buffer,
  conforms to `Deinitable`, `Writable` and `Writer`, and is **not** implicitly
  copyable (`String` is likewise not implicitly copyable in 1.x). `to_string()`
  returns a copy (the builder keeps its content); `finish(deinit self)` transfers
  the buffer out and consumes the builder, so the call site must transfer with
  `^` (`b^.finish()`) — the Go `String()`/Java `toString()` and Julia
  `takestring!` split (`go.md` §3, `java.md` §9, `julia.md` §9).
- **The caller owns every result.** An owned `String` returned by `capitalize`,
  `to_ascii_lower`, `to_ascii_upper`, `replace_n` or the builder is freshly
  allocated and owned by the caller. The library retains no reference after
  return.
- **Views borrow.** `find` returns a plain `Int`; `trim`, `slice`, `try_slice`
  and `split_once`/`rsplit_once` return `StringSpan[o]` views whose origin is the
  caller's input. Every view-returning function uses the same read-only origin
  parameter `[o: Origin[mut=False]]`, which the lifetime checker ties to the
  input (probed on Mojo 1.1.0; the `mut=False` spelling is required by the
  multi-view tuple form and is accepted by the single-view forms too).
- **`StringError` is `Copyable` but not `ImplicitlyCopyable`,** so a re-raise
  must transfer with `raise e^` — the `BitError`/`IoError` convention.
  `StringErrorKind` is `Equatable, ImplicitlyCopyable, Deinitable, Writable`.
- **ASAP destruction.** No library type holds a resource with a destructor side
  effect; there is no `close`.

## Open Questions

None block this design. Points that must be settled during Phase 7 (scaffold)
rather than blocking this phase:

- *`String(from_utf8=Span[UInt8])` raises the untyped built-in `Error`, not
  `StringError`.* `append_bytes` must translate it to `StringError(INVALID_UTF8)`
  in an `except` block; the probe confirmed this compiles. If a cleaner checked
  constructor appears, `append_bytes` uses it instead.
- *The exact Unicode whitespace set for `trim`.* Release 1 uses the fixed set
  `U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029,
  U+202F, U+205F, U+3000` (Python/Java `isspace`/`isWhitespace`-equivalent). No
  Unicode property table is required.
- *`capitalize` case mapping.* Release 1 maps the first codepoint with the
  stdlib's `upper` and the remainder with `lower`; full titlecase (word-based)
  is deferred (`_dev/TODO.md`).

---

## Semantics

#### Terminology

- **Byte offset** — a zero-based index into the UTF-8 byte buffer.
- **Codepoint boundary** — a byte index that is the first byte of a UTF-8
  sequence, or `byte_length()` (the end). A continuation byte (`0b10xxxxxx`) is
  not a boundary.
- **Char set** — a `StringSpan` whose codepoints are the members to strip or
  search against.
- **Needle** — the substring to find or split on.
- **Builder buffer** — the `String` a `StringBuilder` owns.

All ranges are half-open `[start, end)` in bytes unless a function says
otherwise. All indices are byte offsets.

---

### `StringErrorKind`

Status: planned

Signature:

```mojo
struct StringErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime INDEX_OUT_OF_BOUNDS = StringErrorKind(0)
    comptime BAD_RANGE           = StringErrorKind(1)
    comptime NOT_A_BOUNDARY      = StringErrorKind(2)
    comptime INVALID_UTF8        = StringErrorKind(3)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `StringError.kind`; never passed by a
  caller to a string operation. The type is **opaque**: the four `comptime`
  members are the complete public set; `_id` and its `@doc_hidden` initializer
  are implementation details (Mojo has no access control — `mojov1/keywords/
  struct`).
- **Return / meaning:** the machine-testable reason a string operation failed.
  - `INDEX_OUT_OF_BOUNDS` — an index lies outside `[0, byte_length]`. Julia's
    `BoundsError`, expressed as a value (`julia.md` §4, §10).
  - `BAD_RANGE` — a range is specified backwards (`start > end`) or a required
    needle is empty. Julia's "reverse range rejected" and Elixir's documented
    empty-`match` `ArgumentError` (`julia.md` §8, `elixir.md` §8).
  - `NOT_A_BOUNDARY` — an in-range byte index is not a codepoint start. Julia's
    `StringIndexError`, the distinct second failure kind (`julia.md` §4, §10).
  - `INVALID_UTF8` — input bytes are not valid UTF-8. Rust's `Utf8Error`
    analogue (`rust.md` §4).
- **Ownership:** value type; compile-time constants copied into the error value.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: a text primitive performs
  no I/O, so none of those conditions can arise (`mojo.md`, Q6 answered N/A).

Errors: none — it is a discriminant, not an operation.

Tests:

- `test_string_error_kind_distinct_ids` — each of the four `comptime` members has
  a distinct `_id`.
- `test_string_error_kind_eq` — `==` compares `_id` only.
- `test_string_error_kind_writable` — `write_to` prints the symbolic name, never
  the number.

Implementation status:

not implemented

Rationale:

`MojoAkku uses a closed StringErrorKind because Julia's two distinct index
failures (BoundsError vs StringIndexError) prove that "out of range" and "not a
boundary" are different mistakes a low-vision user must be able to tell apart
(julia.md §4, §10), and MojoAkku io and bit already taught one small closed
kind shape (mojoakku/io_core/_dev/DESIGN.md, mojoakku/prim_bit/_dev/DESIGN.md). A `-1`
sentinel (java.md §11) and a bare panic (go.md §11) are rejected.`

---

### `StringError`

Status: planned

Signature:

```mojo
@fieldwise_init
struct StringError(Copyable, Deinitable, Writable):
    var kind: StringErrorKind
    var position: Int

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library on failure; read in
  an `except` block. `kind` is the discriminant above; `position` is the byte
  offset in the **original input** at which the failure was detected. For
  `INDEX_OUT_OF_BOUNDS` and `NOT_A_BOUNDARY` it is the offending index; for
  `BAD_RANGE` it is `start` (or `0` when the fault is an empty needle); for
  `INVALID_UTF8` it is the byte offset of the first invalid sequence.
- **Return / meaning:** raised, never returned. Every condition is recoverable:
  clamp the index, choose a boundary, fix the bytes, or pass a non-empty needle.
- **Ownership:** value type; `Copyable` and `Deinitable`, deliberately **not**
  `ImplicitlyCopyable`, so a re-raise transfers with `raise e^`
  (`mojov1/errors/raising-and-propagation`).
- **Stream I/O:** not applicable; a text primitive has no descriptor, no
  blocking call and no external handle.

Errors: it **is** the error; constructing it cannot fail.

Tests:

- `test_string_error_writable` — `print(err)` yields kind + position.
- `test_string_error_reraise_transfer` — a caught error re-raises with `raise e^`.
- `test_string_error_position_original_input` — `position` points into the input.

Implementation status:

not implemented

Rationale:

`MojoAkku uses one typed error StringError with kind+position because Julia's
StringIndexError prints the invalid index and nearby valid indices, proving the
position is part of a usable diagnostic (julia.md §4, §10), and Rust funnels all
text/encoding failures through typed errors (rust.md §4). A per-operation
exception hierarchy is rejected as noise for a low-vision user (java.md §11).`

---

### `StringBuilder`

Status: planned

Signature:

```mojo
struct StringBuilder(Deinitable, Writable, Writer):
    var _buf: String

    def __init__(out self)
    def __init__(out self, capacity_bytes: Int)

    def append(mut self, text: StringSpan)
    def append_codepoint(mut self, codepoint: Codepoint)
    def append_bytes(mut self, bytes: Span[UInt8, _]) raises StringError

    def reserve(mut self, capacity_bytes: Int)
    def clear(mut self)

    def byte_length(self) -> Int
    def capacity(self) -> Int

    def to_string(self) -> String
    def finish(deinit self) -> String

    def write_string(mut self, string: StringSpan)   # Writer conformance
    def write_to(self, mut writer: Some[Writer])     # Writable conformance
```

Semantics:

- **Parameters / preconditions:** `__init__()` starts empty; `__init__(
  capacity_bytes=…)` pre-allocates a growth hint (not a logical length — the
  builder is still empty). `append`/`append_codepoint`/`append_bytes` add at the
  end; `reserve`/`clear` manage capacity and content. A negative
  `capacity_bytes` is a caller programming error and is clamped to 0 (total,
  non-raising, like the `io`/`base64` sizing functions).
- **Return / meaning:**
  - `append(text)` appends the UTF-8 bytes of `text` (a view is borrowed, never
    copied by the caller).
  - `append_codepoint(cp)` appends one `Codepoint` — the `WriteRune`/`appendCodePoint`
    analogue (`go.md` §3, `java.md` §3).
  - `append_bytes(bytes)` appends raw bytes, validating UTF-8; invalid input
    raises `INVALID_UTF8` and **appends nothing** (atomic, no partial write).
  - `reserve`/`clear` are growth and reset hints; `clear` keeps capacity.
  - `byte_length()` is the current content length in bytes; `capacity()` is the
    buffer's addressable bytes.
  - `to_string()` returns a copy and leaves the builder usable; `finish(deinit
    self)` transfers the buffer out and consumes the builder. Because `finish`
    takes `deinit self`, the call site must **transfer** the builder with `^`:
    `var out = b^.finish()`, never `b.finish()` (which would try to copy a
    non-`ImplicitlyCopyable` value and not compile). After the call the builder
    is dead and may not be used again — this is what makes the flush mandatory.
    The `finish` contract is the explicit flush the README's gap item 2 asks
    for; the same `^`-transfer convention applies to `StringError` re-raises
    (`raise e^`).
  - `Writer` conformance (`write_string`) lets `builder.write(a, b, c)` receive
    formatted output directly, the `mojov1/stdlib/format` pattern.
- **Ownership:** the builder owns its `String`. `to_string` borrows and copies;
  `finish` consumes. The builder is not implicitly copyable. No hidden global
  state.
- **Stream I/O:** EOF/EINTR/EAGAIN/close do not apply: an in-memory builder has
  no descriptor and no blocking point. It is **not** a stream adapter; wrapping
  it as an `io.Writer` is a consumer concern and a Deferred idea
  (`_dev/TODO.md`, origin `elixir.md` §9, §12).

Errors: `append_bytes` raises `StringError` `INVALID_UTF8`; every other method is
non-raising.

Tests:

- `test_string_builder_append` — repeated `append`/`+=` semantics.
- `test_string_builder_append_codepoint` — a non-ASCII codepoint round-trips.
- `test_string_builder_append_bytes_valid` — valid bytes append.
- `test_string_builder_append_bytes_invalid_raises` — `INVALID_UTF8`, nothing
  appended.
- `test_string_builder_reserve_capacity` — capacity grows, `byte_length` does not.
- `test_string_builder_clear_keeps_capacity` — `clear` resets content.
- `test_string_builder_to_string_borrows` — `to_string` leaves the builder usable.
- `test_string_builder_finish_consumes` — `b^.finish()` returns the buffer and
  consumes `b` (a plain `b.finish()` does not compile).
- `test_string_builder_writer_conformance` — `builder.write(a, b)` formats in.
- `test_string_builder_writable` — `print(builder)` uses `write_to`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses an explicit StringBuilder because Go's strings.Builder
(Write*/Grow/Reset/String/Len/Cap) and Java's StringBuilder
(append/capacity/ensureCapacity) both prove that an append/reserve/finish
contract is testable and discoverable, while Python's list+join and JS's lack of
any builder leave a documented quadratic-concatenation risk (go.md §3, §9;
java.md §3, §9; python.md §11; js-ts.md §11). It is a separate type rather than a
mutated String because the README's builder gap asks for an explicit flush, and
Rust's fused owned+builder gives no flush contract (rust.md §11). The
borrow-to_string / consume-finish split mirrors Julia's takestring! and Go's
String() (julia.md §9; go.md §3).`

---

### `find`

Status: planned

Signature:

```mojo
def find(text: StringSpan, needle: StringSpan, start: Int = 0) -> Optional[Int]
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed haystack; `needle` is
  the borrowed substring to find; `start` is the byte offset at which the search
  begins (`start < 0` is treated as 0, `start > byte_length` yields `None`). An
  empty `needle` matches at `start` (the Go/C empty-needle convention,
  `go.md` §8, `c.md` §8).
- **Return / meaning:** the **byte offset** of the first occurrence at or after
  `start`, or `None`. This is `std.find`'s result with the `-1` sentinel
  translated to `Optional` — Rust `str::find` and Swift `firstIndex(of:)`
  (`rust.md` §3, `swift.md` §3).
- **Ownership:** returns a plain `Int`; `text` and `needle` stay borrowed.
- **Stream I/O:** not applicable (pure in-memory transform).

Errors: none — absence is `None`, not an error.

Tests:

- `test_find_first_occurrence` — the first offset.
- `test_find_absent_is_none` — `None`, not `-1`.
- `test_find_start_offsets_search` — `start` skips earlier matches.
- `test_find_empty_needle` — matches at `start`.
- `test_find_start_past_end_is_none` — `None`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses find returning Optional[Int] because Rust's Option and Swift's
Optional make absence type-safe, while Go's -1, C++'s npos and Java's -1 hide it
in arithmetic (rust.md §3, §4; swift.md §3, §8; go.md §11; cpp.md §11; java.md
§11). The stdlib already returns -1, so this is a wrap, not a rebuild.`

---

### `rfind`

Status: planned

Signature:

```mojo
def rfind(text: StringSpan, needle: StringSpan, start: Int = 0) -> Optional[Int]
```

Semantics:

- **Parameters / preconditions:** as `find`. `start` is the lowest byte offset a
  returned match may have (matches wholly below `start` are ignored).
- **Return / meaning:** the **byte offset** of the highest occurrence at or after
  `start`, or `None`. Rust `rfind` (`rust.md` §3).
- **Ownership:** returns a plain `Int`; inputs stay borrowed.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_rfind_last_occurrence` — the last offset.
- `test_rfind_absent_is_none` — `None`.
- `test_rfind_start_lower_bound` — matches below `start` ignored.

Implementation status:

not implemented

Rationale:

`MojoAkku uses rfind returning Optional[Int] for the same reason as find; the
stdlib returns -1 and is wrapped (rust.md §3; go.md §11).`

---

### `split_once`

Status: planned

Signature:

```mojo
def split_once[o: Origin[mut=False]](
    text: StringSpan[o], separator: StringSpan
) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input; `separator` is
  the borrowed delimiter. An empty `separator` has no defined split and yields
  `None` (the Elixir empty-pattern case is explicitly avoided, `elixir.md` §8).
- **Return / meaning:** `Some((before, after))` at the **first** separator, where
  `before` is `text[0:i]` and `after` is `text[i + len(separator):]`; `None`
  when the separator is absent. Both halves are **views** into `text`, so the
  split allocates nothing — Go's `strings.Cut` returns the same three facts, and
  Rust has `split_once` (`go.md` §3, §10; `rust.md` §3).
- **Ownership:** both returned views borrow `text`; the explicit
  `[o: Origin[mut=False]]` parameter ties them to the input's origin.
- **Stream I/O:** not applicable.

Errors: none — absence is `None`.

Tests:

- `test_split_once_basic` — `("a=b", "=") -> ("a", "b")`.
- `test_split_once_absent_is_none` — `None`.
- `test_split_once_first_separator` — a second separator stays in `after`.
- `test_split_once_empty_separator_is_none` — `None`.
- `test_split_once_preserves_bytes` — `before`/`after` are views of `text`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses split_once returning Optional[(before, after)] because Go's Cut
returns (before, after, found) allocation-free and Rust's split_once returns
Option of a pair (go.md §3, §10; rust.md §3); Python's partition inserts the
separator into the tuple, which is a third element a low-vision user does not
need (python.md §3). Optional replaces Go's separate found flag.`

---

### `rsplit_once`

Status: planned

Signature:

```mojo
def rsplit_once[o: Origin[mut=False]](
    text: StringSpan[o], separator: StringSpan
) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]
```

Semantics:

- **Parameters / preconditions:** as `split_once`, but the split happens at the
  **last** separator.
- **Return / meaning:** `Some((before, after))` at the last separator, `None`
  when absent. Rust's `rsplit_once` analogue (`rust.md` §3).
- **Ownership:** views borrowing `text`.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_rsplit_once_basic` — `("a=b=c", "=") -> ("a=b", "c")`.
- `test_rsplit_once_absent_is_none` — `None`.
- `test_rsplit_once_empty_separator_is_none` — `None`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses rsplit_once returning Optional[(before, after)] to complete the
split-once pair, mirroring Rust's rsplit_once and the go.md §3 Cut/CutLast pair
(rust.md §3; go.md §3). It is a view-returning split like split_once, so it
allocates nothing.`

---

### `trim`

Status: planned

Signature:

```mojo
def trim[o: Origin[mut=False]](text: StringSpan[o]) -> StringSpan[o]
def trim[o: Origin[mut=False]](text: StringSpan[o], chars: StringSpan) -> StringSpan[o]
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input. The one-argument
  form strips leading and trailing **Unicode whitespace** from the fixed set
  `U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029,
  U+202F, U+205F, U+3000`. The two-argument form strips any leading/trailing
  codepoint whose byte sequence is one of the codepoints in `chars` — a **set**,
  not a prefix/suffix (`python.md` §3's documented `strip(chars)` rule).
- **Return / meaning:** a **view** into `text` with the matching bytes removed
  from both ends; an all-whitespace input returns the empty view. Both forms
  allocate nothing. Python's `str.strip()` and Java's `strip()` strip Unicode
  whitespace; Go's `TrimSpace` is the same (`python.md` §3, `java.md` §11,
  `go.md` §3).
- **Ownership:** the returned view borrows `text`.
- **Stream I/O:** not applicable.

Errors: none — trimming cannot fail.

Tests:

- `test_trim_ascii_whitespace` — spaces, tabs, CR/LF.
- `test_trim_unicode_whitespace` — NBSP and U+3000 are stripped.
- `test_trim_all_whitespace_empty` — empty view.
- `test_trim_no_whitespace_unchanged` — identity.
- `test_trim_chars_set` — an explicit char set, not a prefix.
- `test_trim_chars_empty_is_identity` — an empty set strips nothing.

Implementation status:

not implemented

Rationale:

`MojoAkku uses trim with a Unicode-whitespace default because Python's str.strip
and Java's strip remove Unicode whitespace, while the probed std strip removes
only ASCII whitespace (NBSP and U+3000 survive) (python.md §3; java.md §11). The
chars overload follows Python's documented set semantics, not a prefix test
(python.md §3). Java's legacy trim (<= U+0020) is explicitly rejected (java.md
§11).`

---

### `capitalize`

Status: planned

Signature:

```mojo
def capitalize(text: StringSpan) -> String
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input; it may be empty
  (an empty input returns an empty `String`).
- **Return / meaning:** an owned `String` with the first codepoint upper-cased
  and every following codepoint lower-cased. Python's `str.capitalize` and
  Elixir's `String.capitalize` (`python.md` §3, `elixir.md` §3). Word-based
  titlecasing is deliberately **not** this function and is deferred.
- **Ownership:** the returned `String` is newly allocated and owned by the
  caller; `text` stays borrowed.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_capitalize_basic` — `"abc" -> "Abc"`.
- `test_capitalize_upper_tail` — the tail is lower-cased.
- `test_capitalize_empty` — `""` unchanged.
- `test_capitalize_first_non_ascii` — a non-ASCII first codepoint.
- `test_capitalize_returns_owned` — the result is independent of the input.

Implementation status:

not implemented

Rationale:

`MojoAkku uses capitalize returning an owned String because Python and Elixir
both ship it as a first-letter operation separate from word-titlecasing
(python.md §3; elixir.md §3); the probed std has neither. Word titlecase needs a
Unicode word-boundary pass and is left to _dev/TODO.md.`

---

### `to_ascii_lower`

Status: planned

Signature:

```mojo
def to_ascii_lower(text: StringSpan) -> String
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input. Only the ASCII
  letters `A–Z` are mapped to `a–z`; every other byte is copied unchanged, so the
  result is always valid UTF-8 and the byte length is unchanged.
- **Return / meaning:** an owned `String` with the deterministic ASCII-only
  mapping. Rust's `to_ascii_lowercase` is the reference (`rust.md` §3). It is a
  fast, locale-free, allocation-of-exactly-`byte_length` path that never touches
  Unicode case tables.
- **Ownership:** the returned `String` is owned by the caller; `text` stays
  borrowed.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_to_ascii_lower_letters` — `"AbC" -> "abc"`.
- `test_to_ascii_lower_non_ascii_unchanged` — non-ASCII bytes copied.
- `test_to_ascii_lower_length_preserved` — byte length unchanged.
- `test_to_ascii_lower_returns_owned` — the result is independent.

Implementation status:

not implemented

Rationale:

`MojoAkku uses to_ascii_lower as a separate fast path because Rust ships
to_ascii_lowercase next to the full-Unicode to_lowercase (rust.md §3); the std
lower does full Unicode case mapping and has no ASCII-only variant. Keeping both
makes the cost explicit and the result byte-deterministic.`

---

### `to_ascii_upper`

Status: planned

Signature:

```mojo
def to_ascii_upper(text: StringSpan) -> String
```

Semantics:

- **Parameters / preconditions:** as `to_ascii_lower`, mapping `a–z` to `A–Z`.
- **Return / meaning:** an owned `String` with the deterministic ASCII-only
  uppercase mapping; byte length unchanged, always valid UTF-8. Rust's
  `to_ascii_uppercase` (`rust.md` §3).
- **Ownership:** owned by the caller; `text` stays borrowed.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_to_ascii_upper_letters` — `"AbC" -> "ABC"`.
- `test_to_ascii_upper_non_ascii_unchanged` — non-ASCII bytes copied.
- `test_to_ascii_upper_length_preserved` — byte length unchanged.

Implementation status:

not implemented

Rationale:

`MojoAkku uses to_ascii_upper for symmetry with to_ascii_lower and because Rust
ships both ASCII variants beside the Unicode ones (rust.md §3); the std upper is
full Unicode and has no ASCII-only path.`

---

### `replace_n`

Status: planned

Signature:

```mojo
def replace_n(
    text: StringSpan, old: StringSpan, new: StringSpan, count: Int
) raises StringError -> String
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input; `old` is the
  borrowed needle; `new` is the borrowed replacement; `count` is the maximum
  number of leftmost non-overlapping occurrences to replace — `count < 0` means
  replace all, `count == 0` returns `text` unchanged. `old` must be **non-empty**;
  an empty `old` raises `BAD_RANGE`, because Go's "empty old matches at every
  boundary" and Python's interspersal are surprising for a low-vision user
  (`go.md` §3, `python.md` §3).
- **Return / meaning:** an owned `String` with the first `count` occurrences (or
  all) replaced. Python's `str.replace(old, new, count)`, Rust's `replacen` and
  Go's `Replace(s, old, new, n)` are the references (`python.md` §3, `rust.md`
  §3, `go.md` §3). The std `replace` is all-only; this is the counted extension.
- **Ownership:** the returned `String` is owned by the caller; inputs stay
  borrowed.
- **Stream I/O:** not applicable.

Errors: `BAD_RANGE` when `old` is empty; recoverable.

Tests:

- `test_replace_n_counted` — the first `count` occurrences only.
- `test_replace_n_negative_all` — `count < 0` replaces all.
- `test_replace_n_zero_unchanged` — `count == 0` is identity.
- `test_replace_n_nonoverlapping` — leftmost non-overlapping matching.
- `test_replace_n_empty_old_raises` — `BAD_RANGE`.
- `test_replace_n_returns_owned` — the result is independent.

Implementation status:

not implemented

Rationale:

`MojoAkku uses replace_n with count because Python, Rust and Go all ship a
counted replace (python.md §3; rust.md §3; go.md §3) and the probed std has only
the all-occurrences form; an empty old raises BAD_RANGE instead of Go's
boundary-splice or Python's interspersal, which are documented surprises (go.md
§3; python.md §3).`

---

### `is_char_boundary`

Status: planned

Signature:

```mojo
def is_char_boundary(text: StringSpan, index: Int) -> Bool
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input; `index` is a byte
  offset. `index == byte_length()` is the end and is a boundary; `index < 0` or
  `index > byte_length()` is `False` (defined, never a panic). A byte whose top
  two bits are `10` (a UTF-8 continuation byte) is not a boundary.
- **Return / meaning:** `Bool` — whether `index` starts a codepoint or is the
  end. Rust's `is_char_boundary` returns `false` for an index greater than the
  length rather than panicking (`rust.md` §3, §8); Julia's `isvalid(s, i)` is the
  same O(1) test (`julia.md` §3, §8).
- **Ownership:** plain `Bool`; `text` stays borrowed.
- **Stream I/O:** not applicable.

Errors: none — an out-of-range index is `False`, not an error.

Tests:

- `test_is_char_boundary_start_true` — index 0.
- `test_is_char_boundary_end_true` — `byte_length()`.
- `test_is_char_boundary_ascii_all` — every ASCII index.
- `test_is_char_boundary_continuation_false` — a mid-codepoint byte.
- `test_is_char_boundary_negative_false` — `-1` is `False`.
- `test_is_char_boundary_past_end_false` — beyond the end is `False`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses is_char_boundary because Rust and Julia both expose an O(1)
boundary test (rust.md §3, §8; julia.md §3, §8), and the probed std aborts on a
mid-codepoint byte slice instead of reporting it; a predicate is the recoverable
form a low-vision user needs before slicing.`

---

### `slice`

Status: planned

Signature:

```mojo
def slice[o: Origin[mut=False]](
    text: StringSpan[o], start: Int, end: Int
) raises StringError -> StringSpan[o]
```

Semantics:

- **Parameters / preconditions:** `text` is the borrowed input; `[start, end)` is
  a half-open byte range. `start < 0` or `end > byte_length()` raises
  `INDEX_OUT_OF_BOUNDS`; `start > end` raises `BAD_RANGE`; `start` or `end` not on
  a codepoint boundary raises `NOT_A_BOUNDARY` (position = the offending index).
  `start == end` is legal and yields the empty view.
- **Return / meaning:** a **view** of the requested bytes, guaranteed to be
  valid UTF-8. This is Rust's `str::get`/slice but with a raising checked form,
  and Julia's boundary-checked `s[i:j]` without the O(n) index arithmetic
  (`rust.md` §3, §4; `julia.md` §7, §8). It differs from `std`'s `s[byte=a:b]`
  only in that a bad range is a reportable error instead of an abort.
- **Ownership:** the returned view borrows `text`; the explicit
  `[o: Origin[mut=False]]` ties them together.
- **Stream I/O:** not applicable.

Errors: `INDEX_OUT_OF_BOUNDS`, `BAD_RANGE`, `NOT_A_BOUNDARY`; all recoverable.

Tests:

- `test_slice_basic` — a mid-string byte range.
- `test_slice_empty_range` — `start == end` yields empty.
- `test_slice_full_range` — the whole string.
- `test_slice_out_of_bounds_raises` — `INDEX_OUT_OF_BOUNDS`.
- `test_slice_reversed_raises` — `BAD_RANGE`.
- `test_slice_non_boundary_raises` — `NOT_A_BOUNDARY` with the offending position.
- `test_slice_result_is_view` — mutating the owner is visible through the view.

Implementation status:

not implemented

Rationale:

`MojoAkku uses a raising checked slice because Rust offers a checked get() and
Julia refuses to split a codepoint, both making a boundary failure a defined
outcome (rust.md §3, §4; julia.md §7, §8), while the probed std s[byte=a:b]
aborts. One typed error with a position is the low-vision-user-friendly form.`

---

### `try_slice`

Status: planned

Signature:

```mojo
def try_slice[o: Origin[mut=False]](
    text: StringSpan[o], start: Int, end: Int
) -> Optional[StringSpan[o]]
```

Semantics:

- **Parameters / preconditions:** as `slice`, but no range or boundary condition
  raises.
- **Return / meaning:** `Some(view)` for a valid range, `None` for any invalid
  range (out of bounds, reversed, or off-boundary). Rust's `str::get(range) ->
  Option<&str>` is the direct reference (`rust.md` §3, §4); it is the total
  sibling of `slice`, so a caller who expects a miss can avoid `try`/`except`.
- **Ownership:** the returned view borrows `text`.
- **Stream I/O:** not applicable.

Errors: none — every invalid range is `None`.

Tests:

- `test_try_slice_valid` — `Some` view.
- `test_try_slice_out_of_bounds_none` — `None`.
- `test_try_slice_reversed_none` — `None`.
- `test_try_slice_non_boundary_none` — `None`.
- `test_try_slice_empty_range_some` — the empty view is `Some`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses try_slice returning Optional because Rust's non-panicking get()
is a first-class counterpart to the panicking form (rust.md §3, §4); shipping
both slice and try_slice gives a raising and a total spelling instead of one
ambiguous operator, the exact separation cpp.md §12 recommends.`

---

### `is_valid_utf8`

Status: planned

Signature:

```mojo
def is_valid_utf8(bytes: Span[UInt8, _]) -> Bool
```

Semantics:

- **Parameters / preconditions:** `bytes` is a borrowed raw byte span; it may be
  empty (an empty span is valid). No allocation is performed.
- **Return / meaning:** `Bool` — whether the span is well-formed UTF-8 under RFC
  3629 (1–4 byte sequences, no overlong forms, no surrogates, no values above
  U+10FFFF). Go's `utf8.ValidString` and Elixir's `String.valid?` are the
  references (`go.md` §3, §8; `elixir.md` §3, §8). It is the allocation-free
  companion to `String(from_utf8=…)`, which raises rather than returning `Bool`.
- **Ownership:** plain `Bool`; `bytes` stays borrowed.
- **Stream I/O:** not applicable. Incremental/streaming validity (the Elixir
  `incomplete`-vs-`invalid` distinction) is a Deferred idea, not release 1
  (`_dev/TODO.md`, origin `elixir.md` §12).

Errors: none — invalid input is `False`.

Tests:

- `test_is_valid_utf8_ascii` — ASCII is valid.
- `test_is_valid_utf8_multibyte` — 2/3/4-byte sequences are valid.
- `test_is_valid_utf8_overlong_false` — an overlong form is invalid.
- `test_is_valid_utf8_surrogate_false` — a surrogate is invalid.
- `test_is_valid_utf8_truncated_false` — a truncated sequence is invalid.
- `test_is_valid_utf8_empty_true` — the empty span is valid.
- `test_is_valid_utf8_matches_from_utf8` — agrees with `String(from_utf8=…)` on
  a table of inputs.

Implementation status:

not implemented

Rationale:

`MojoAkku uses is_valid_utf8 because Go and Elixir both expose an allocation-free
validity predicate and Rust needs a checked from_utf8 (go.md §3, §8; elixir.md
§3, §8; rust.md §3), while the std constructor raises the untyped built-in Error
and offers no Bool query. Validation without allocation is the byte-bridge
primitive the 36 dependent parser libraries need.`

---
