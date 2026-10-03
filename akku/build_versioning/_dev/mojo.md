# build_versioning research: Mojo

Mojo facts are not researched from the internet: they are read from the
`mojov1` buch, the self-sufficient Mojo 1.x reference. This file only links the
buch pages that matter for `build_versioning`; it does not duplicate them.

## What Mojo already provides (1.1.0, from the buch)

- **No SemVer type, parser or comparator in the standard library.** The gap
  this library fills is exactly the identity model plus parse/compare. Source
  (absence, confirmed by the buch's type and stdlib indexes): `mojov1/types/overview`,
  `mojov1/stdlib/prelude`.
- **Text family:** `String` (owned/mutable), `StringSpan` (non-owning view),
  `StaticString`, `StringLiteral`; the 1.x name is `StringSpan`
  (`StringSlice` is a compatibility alias). Relevant for holding parsed
  prerelease/build identifiers as owned text and for parsing from a view.
  Source: `mojov1/types/bool-and-strings`.
- **String scanning:** `find`/`rfind` (return `-1`, not `Optional`),
  `startswith`/`endswith`, `removeprefix`/`removesuffix`, `split`/`split(None)`
  (there is **no** `split_once`/`partition`), `strip`/`lstrip`/`rstrip`
  (ASCII-only), and `join`. Sources: `mojov1/types/string-operations`,
  `mojov1-string-operations`.
- **Collections and absence:** `List` (growable), `Array` (fixed inline),
  `Dict`, `Set`, `Tuple`, `Optional`; list expressions build an `Array` by
  default. Relevant for a prerelease-identifier list. Source:
  `mojov1/types/collections`, `mojov1/types/optionals-and-nullability`.
- **Numeric model:** every fixed-width number is a one-lane `SIMD`; `Int` is
  `Scalar[DType.int]`, with explicit widths such as `UInt64` for bounded
  components. Source: `mojov1/types/integers-and-floats`,
  `mojov1/concurrency/vectorization-and-simd`.

## Consequence for the design

The stdlib gives the raw text and collection ingredients but **no version
value, no validation, no clause-11 precedence and no constraint matcher**. A
Mojo implementation must define all of those itself, on top of the existing
`String`/`StringSpan` surface.

No Mojo API decision is made in Phase 1.

## Where each area is read (buch pages)

| Area | Buch page |
| --- | --- |
| Version as an owned value struct | `mojov1/keywords/struct` |
| Parse input as a borrowed view, owned output | `mojov1/types/bool-and-strings`, `mojov1/memory/ownership-and-lifetimes` |
| String scanning / splitting / trimming | `mojov1/types/string-operations`, `mojov1-string-operations` |
| Prerelease identifier list / optional build | `mojov1/types/collections`, `mojov1/types/optionals-and-nullability` |
| Errors as alternate return values, typed `raises` | `mojov1/errors/error-model` |
| Raising, `try`/`except`, re-raise copying | `mojov1/errors/raising-and-propagation` |
| Compile-time constants, `comptime` members | `mojov1/keywords/comptime` |
| Numeric width for components | `mojov1/types/integers-and-floats` |
| Text / `Writable` output for rendering | `mojov1/types/bool-and-strings`, `mojov1/stdlib/format` |
| Package/re-export layout and `__init__.mojo` | `mojov1/intro/packages-and-modules` |
| Test module and assertions | `mojov1/stdlib/testing` |
| ASCII / `Boolable` behaviour | `mojov1/types/bool-and-strings` |

## Dependency edge

`build_versioning` declares `depends_on: [text_string]`
(`.repo/todo/build_versioning.yml:4`). The parser needs trimming, ASCII
case-folding and split-once, which are public APIs in the `text_string` sibling,
rather than reimplementing them. Source: `.repo/todo/build_versioning.yml`,
`akku/text_string/`.

## Sources

- `mojov1/keywords/struct`
- `mojov1/keywords/comptime`
- `mojov1/errors/error-model`
- `mojov1/errors/raising-and-propagation`
- `mojov1/memory/ownership-and-lifetimes`
- `mojov1/types/bool-and-strings`
- `mojov1/types/string-operations`
- `mojov1/types/collections`
- `mojov1/types/optionals-and-nullability`
- `mojov1/types/integers-and-floats`
- `mojov1/types/overview`
- `mojov1/stdlib/prelude`, `mojov1/stdlib/format`, `mojov1/stdlib/testing`
- `mojov1/intro/packages-and-modules`
- `mojov1-string-operations`
- Repo: `.repo/todo/build_versioning.yml`, `akku/text_string/`
