<!--
Design record for akku/build_versioning — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 3 (API design).
-->

# build_versioning — Design Record

## Purpose

`akku/build_versioning` is the MojoAkku **Semantic Versioning 2.0.0** library:
a small, predictable toolkit that parses a strict SemVer 2.0.0 string into a
value and orders two version values by the specification's precedence rules.

Release 1 is deliberately the **core** of SemVer 2.0.0 and nothing more: parse
a version, compare two versions, and answer two kind questions
(`is_prerelease`, `is_stable`). Constraint **ranges** (caret, tilde, hyphen,
X-ranges, NPM/Go/Cargo dialects, Maven brackets, PEP 440 specifiers) are
explicitly **not** in this release; they remain in `_dev/TODO.md` as the
single largest deferred theme.

It is designed for a low-vision user: **one value type**, **one typed error**
with a closed kind, **one precedence function** with a `-1`/`0`/`+1` result,
explicit strictness (no hidden `v`-stripping, no silent normalization), value
semantics throughout, and no magic sentinels.

The Mojo standard library provides the text and collection ingredients
(`String`, `StringSpan`, `Optional`, `Some[Writer]`) but **no version type, no
validator, no precedence rule and no range matcher** (see `mojo.md`). The
parser additionally builds on the sibling `akku/text_string`, the only
dependency edge (see `## Dependencies`).

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 8 entries in this document were `planned` at Phase 3; `Implementation
status:` is `not implemented` until Phase 11.

## Dependencies

`build_versioning` has **exactly one sibling dependency edge**:
`build_versioning -> text_string`. It is declared in the catalogue
(`.repo/todo/build_versioning.yml:4`) and is technically justified below.

| Library | Edge | Justification |
| --- | --- | --- |
| `text_string` | depends-on | The parser must split a version string **once** on `+`, **once** on `-`, and twice on `.`, treating absence as a value. `akku/text_string.split_once` returns `Optional[(before, after)]` views with zero allocation. The Mojo standard library provides only `find`/`rfind` (returning the `-1` **sentinel**) and `split` (all occurrences, allocating), and has **no** `split_once`/`partition` (`mojov1/types/string-operations`, "There is no `rsplit`, `split_once` / `partition` on the probe"). `text_string` fills exactly that gap. |

- **Why the edge and not a rebuild.** `split_once` is already public, tested
  and typed-absence (no `-1`); reimplementing once-splitting inside this library
  would duplicate a sibling API for no technical gain.
- **No physical nesting.** `akku/build_versioning/` is a flat sibling under
  `akku/`; the edge is conceptual, never a parent/child directory.
- **Direction of the edge.** `build_versioning` points *to* `text_string`;
  `text_string` never points back. No other sibling is needed and none is
  declared.
- **Internal shared core, not a sibling edge.** `akku/build_versioning/_internal/version_core.mojo`
  holds the private Clause-11 comparison and the shared identifier validation so
  `SemVer.__eq__` and `precedence` do not import each other (see `## Overview`).
  `_internal/` is private to this library and is **not** a dependency edge; it
  is the same convention as `akku/net_ip/_internal/ip_core.mojo`.
- **No stdlib/Python build dependency.** The library is pure Mojo: no FFI, no
  Python interop, no hidden global state (`mojov1/intro/packages-and-modules`).

## Overview

`akku/build_versioning` is a pure, in-process, deterministic library with a
**single value type and one precedence function**, plus a private shared core:

1. **The version value — `SemVer`.** Private fields `_major`, `_minor`, `_patch`
   (`Int`) and `_prerelease`, `_build` (owned `String`, empty when absent),
   exposed through accessor methods `major()`, `minor()`, `patch()`,
   `prerelease()`, `build()`. It is constructed only through a validating
   component constructor or through `parse`, so a `SemVer` that exists is
   always a well-formed version.
2. **The strict parser — `parse` / `try_parse`.** `parse` implements the
   semver.org BNF exactly and raises a typed `VersionError` on any violation;
   `try_parse` is its non-raising twin returning `Optional[SemVer]`.
3. **Precedence — `precedence`.** Implements SemVer clause 11 and returns
   `-1`, `0` or `+1`; build metadata is ignored. It delegates to the private
   core.
4. **Kind predicates — `is_prerelease`, `is_stable`.** Two one-line boolean
   questions about a value.
5. **Private shared core — `_internal/version_core.mojo`.** The Clause-11
   precedence algorithm and the shared identifier validation live here as pure
   functions over the raw fields, so `precedence.mojo` and `SemVer.__eq__` call
   one implementation without importing each other (the
   `akku/net_ip/_internal/ip_core.mojo` convention). This is not a public API
   entry and not a sibling dependency edge.

Cross-cutting shape:

- **One typed error** (`VersionError`) with a small, **closed**
  `VersionErrorKind` discriminant (`EMPTY`, `INVALID_FORMAT`, `BAD_NUMBER`,
  `LEADING_ZERO`, `OVERFLOW`, `OTHER`) — no OS errno, no sentinel, no
  panic-as-error.
- **Strict by design.** No `v` prefix, no `=` prefix, no surrounding
  whitespace, no partial versions (`1`, `1.2`), no silent normalization. Those
  lenient forms stay backlog (`_dev/TODO.md`).
- **Private fields protect the invariant.** Mojo has no access control
  (`mojov1/keywords/struct`), so `SemVer` follows the MojoAkku convention
  (`akku/net_ip/ipv4_address.mojo`: private `_b` plus accessor `octets()`):
  fields are `_`-prefixed and the only initializer is `@doc_hidden`, so the
  public surface cannot build an unvalidated value. Validation lives in the one
  constructor and in `parse` (see `## Ownership and Lifecycle`).
- **Equality equals precedence.** `SemVer.__eq__` delegates to the private core
  (`_internal/version_core.mojo`), the same comparison `precedence` exposes, so
  build metadata never affects equality (clause 10) and the two cannot drift
  apart. A build-sensitive equality/total order is backlog.
- **Value semantics, no hidden global state.** `SemVer`, `VersionError`,
  `VersionErrorKind` are value types with Mojo lifecycle conformance.

Every reference language implements version handling, so the value of this
library is not "another SemVer parser". It is a *predictable, consistent and
easy-to-read* surface for a low-vision user. The research shows the references
**converge** on the identity model (`major.minor.patch` plus optional
prerelease and build), on build metadata being precedence-neutral, and on a
`-1/0/+1` (or `:lt/:eq/:gt`) comparator; they **diverge** on strictness
(`v`-prefix, partial forms, coercion), on how the qualifiers are stored
(owned list, joined string, borrowed slice), and on whether ranges live in the
same type. This library picks one model and justifies each pick below.

## Goals

- **G1 — Strict SemVer 2.0.0 core only:** parse and precedence, no ranges, no
  lenient dialects, no normalization. Ranges are the explicit next commitment,
  not part of release 1.
- **G2 — One predictable convention set** a low-vision user can memorise once:
  one `SemVer` value, one `VersionError`, one `precedence` returning `-1`/`0`/
  `+1`, `snake_case` functions and `CamelCase` types.
- **G3 — No magic values.** A bad version is a typed error with a closed kind;
  absence in `try_parse` is `Optional`, never a sentinel.
- **G4 — Spec-faithful comparison.** Clause 11 is implemented in full,
  including the numeric-vs-alphanumeric prerelease rules; build metadata is
  ignored, as clause 10 requires.
- **G5 — Value semantics and no hidden global state.** Everything is a value
  type; parsing takes a borrowed `StringSpan` and returns an owned value.
- **G6 — Implementable in pure Mojo**, no Python/FFI dependency, deterministic
  and fully testable with `mojo run`.

## Non-Goals

Decisions deliberately **not** copied from the reference languages (from the
`§11 Decisions NOT to copy` sections of the research files). Each names the
reference and why it does not fit Mojo. Concrete, Mojo-feasible candidates are
mirrored in `_dev/TODO.md` and referenced below.

- **The PEP 440 model (epoch, `.postN`, `.devN`, local `+label` with a defined
  order, variable-length release)** — `python.md` §7, §11. PEP 440 is a
  *different version scheme*; accepting it would make a library that is not
  SemVer. The strict parser rejects `1.0` and `1.0.0.post1` rather than
  normalizing them. Deferred to `_dev/TODO.md`.
- **Silent, lossy normalization** (`00`→`0`, `1.1RC1`→`1.1rc1`) — `python.md`
  §11. A strict library rejects invalid input; normalization, if ever wanted,
  must be an explicitly named, separate operation (`clean`/`coerce` in
  `_dev/TODO.md`).
- **Maven's generic token model (unlimited components, `.`/`-`/`_` separators,
  digit↔character transitions, null-padding, case-insensitive qualifiers)** —
  `java.md` §7, §11. Maven is explicitly *not* compatible with SemVer 2.0.0;
  none of it may leak into a SemVer library. Deferred to `_dev/TODO.md`.
- **Parse-never-fails** (`ComparableVersion` accepts arbitrary strings) —
  `java.md` §4, §11. The opposite of SemVer validation; `parse` always
  validates and raises.
- **The node-semver range grammar (caret, tilde, hyphen, X-ranges, `||`,
  `simplifyRange`, `subset`)** — `js-ts.md` §11. It is a large surface and
  SemVer 2.0.0 defines no ranges; ranges are deferred, not smuggled into the
  core. All range forms stay in `_dev/TODO.md`.
- **`null`/sentinel as the only failure signal** (`node-semver`, `semver4j`
  `null`, `x/mod/semver` empty string, C `-1`) — `js-ts.md` §11, `java.md` §11,
  `go.md` §11, `c.md` §11. It carries no reason; `parse` raises a typed
  `VersionError`, and `try_parse` uses `Optional`.
- **C's `strverscmp` natural order and its leading-zero model** — `c.md` §9,
  §11. It is deliberately *not* SemVer; only the actual `X.Y.Z` grammar is
  implemented.
- **C's 32-bit `int` components / packed `semver_numeric` ordering key** —
  `c.md` §11. Components are `Int` with explicit overflow rejection; a lossy
  packed key must not become the ordering model.
- **Conflating "invalid" with "lower" in comparison** (`semver_compare` returns
  `-1` for both; `x/mod/semver` folds invalid to "less") — `c.md` §4, `go.md`
  §4, §11. Invalid input never becomes a `SemVer`; `precedence` is only called
  on valid values.
- **`v`-prefix stripping inside the strict parser** — `js-ts.md` §11,
  `python.md` §7. semver.org says `v1.2.3` is not a semantic version; the
  strict parser rejects it. A separate lenient helper is backlog.
- **`loose` mode behind a boolean on the same parser** — `js-ts.md` §11. Two
  grammars behind one flag are hard to reason about; lenient parsing, if added,
  is a distinct named function (backlog).
- **Coercion / `clean`** — `go.md` §11, `js-ts.md` §11, `cpp.md` §11. Silent
  extraction of a version from arbitrary text is a separate, explicitly lossy
  operation; it must not be the parser. Backlog.
- **The `===` arbitrary-equality escape hatch** — `python.md` §11. It bypasses
  version semantics; not part of a SemVer core.
- **A total order that includes build metadata on the same type** (Rust `Ord`
  including build vs `cmp_precedence`; node `compareBuild`) — `rust.md` §11,
  `js-ts.md` §11. Two orderings on one type invite bugs; release 1 has one
  precedence rule (build ignored) and a build-sensitive `compare_with_build` is
  backlog.
- **`serde`/JSON/SQL serialization surface** — `rust.md` §11, `go.md` §11.
  Optional integration is scope creep for a first cut; backlog.
- **A mutable in-place re-parse** (`ComparableVersion.parseVersion`) —
  `java.md` §11. `parse` returns a fresh value; no aliasing hazard.
- **Exception taxonomies** (`std::out_of_range`, `InvalidVersion`,
  `VersionFormatException`) — `cpp.md` §11, `python.md` §11, `kotlin.md` §11.
  Mojo errors are typed return values; one `VersionError` replaces the
  hierarchy.
- **A 14-digit / `u64` component cap as an unqualified rule** — `elixir.md`
  §11, `rust.md` §10. The width is `Int` with explicit `OVERFLOW`; the cap is a
  property of the representation, not a magic constant.
- **`Must*` panicking helpers** — `go.md` §11. A data error must be a `raise`,
  never a crash.
- **Custom prefix stripping** (`WithPrefix`, `deployment-`) — `go.md` §11. A
  release-tag prefix is not part of a version; backlog.
- **Requiring a leading `v`** (`x/mod/semver`) — `go.md` §11. It contradicts
  semver.org; the strict parser requires the spec form.

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Version identity model | Rust `Version { major, minor, patch, pre, build }`; Elixir `%Version{major, minor, patch, pre, build}`; Zig `std.SemanticVersion`; node `SemVer` struct; kotlin-semver `Version` | `rust.md` §3,§7; `elixir.md` §3,§7; `zig.md` §1,§7; `js-ts.md` §7; `kotlin.md` §7 |
| Strict parse to a value | Rust `Version::parse -> Result`; Elixir `Version.parse/1`; Zig `SemanticVersion.parse -> !Version`; C `semver_parse`; C++ `parse`/`from_string` | `rust.md` §3,§4; `elixir.md` §3; `zig.md` §3; `c.md` §3; `cpp.md` §3 |
| Non-raising parse twin | Elixir `{:ok, v} | :error`; C++ `try_parse -> optional`; Rust `Result`; node/Java `null`; Go `(value, error)`; Kotlin `toVersionOrNull` | `elixir.md` §3,§4; `cpp.md` §3; `rust.md` §4; `js-ts.md` §4; `java.md` §4; `go.md` §4; `kotlin.md` §4 |
| Precedence comparator | Rust `cmp_precedence -> Ordering`; Elixir `Version.compare/2 -> :gt|:eq|:lt`; node `compare`; Go `x/mod/semver.Compare`; C `semver_compare` | `rust.md` §3,§9; `elixir.md` §3; `js-ts.md` §3; `go.md` §3; `c.md` §3 |
| Clause 11 prerelease rules | semver.org item 11; Zig `order`; Rust `Prerelease` total ordering; Elixir `compare` docs | `zig.md` §9; `rust.md` §9; `elixir.md` §7,§9 |
| Build metadata ignored for precedence | semver.org item 10; Rust `cmp_precedence`; Elixir `("2.0.1+build0","2.0.1") -> :eq`; node non-capturing build | `rust.md` §9; `elixir.md` §7; `js-ts.md` §7 |
| Typed error + closed kind | Rust `semver::Error` / `Result<T, Error>` with enumerated causes; MojoAkku `prim_bit`/`prim_endian` `*Error`/`*ErrorKind`; Elixir `InvalidVersionError`; Zig `error.InvalidVersion`/`error.Overflow` | `rust.md` §4,§10; `akku/prim_bit/_dev/DESIGN.md`; `akku/prim_endian/_dev/DESIGN.md`; `elixir.md` §4; `zig.md` §4 |
| Component constructor without a string | Python `Version.from_parts`; Java `Semver.of(1,2,3)`; kotlin-semver `Version(major,minor,patch,...)`; C++ `version(1,2,3)` | `python.md` §10; `java.md` §12; `kotlin.md` §3; `cpp.md` §3 |
| `is_stable` / `is_prerelease` predicates | semver4j `isStable()`; kotlin-semver `.isStable`, `.isPreRelease`; C++ `is_prerelease` | `java.md` §12; `kotlin.md` §12; `cpp.md` §3 |
| Owned qualifier storage | Rust owned `Prerelease`/`BuildMetadata`; Elixir owned `:pre` list / `:build` string; Kotlin joined `String`s | `rust.md` §7,§10; `elixir.md` §7,§11; `kotlin.md` §11 |
| Reject borrowed qualifiers | Zig `?[]const u8` slices into the input | `zig.md` §5,§11 |
| Mojo language anchors | typed `raises`; value `struct`; `StringSpan`/`String`/`Optional`; `Writable`/`Writer`; `text_string.split_once` | `mojov1/errors/error-model`; `mojov1/errors/raising-and-propagation`; `mojov1/keywords/struct`; `mojov1/types/bool-and-strings`; `mojov1/types/optionals-and-nullability`; `mojov1/stdlib/format`; `akku/text_string/` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in the per-entry blocks. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order (one file per entry).

1. `SemVer` — a parsed version value: private `_major`, `_minor`, `_patch`
   (numeric) and `_prerelease`, `_build` (owned strings) exposed by
   `major()`/`minor()`/`patch()`/`prerelease()`/`build()`; precedence-based
   equality.
2. `VersionErrorKind` — closed discriminant for `VersionError`: `EMPTY`,
   `INVALID_FORMAT`, `BAD_NUMBER`, `LEADING_ZERO`, `OVERFLOW`, `OTHER`.
3. `VersionError` — the one typed error: `kind: VersionErrorKind`, `op: String`,
   `detail: String`.
4. `parse` — strict SemVer 2.0.0 parser; returns a `SemVer` or raises
   `VersionError`.
5. `try_parse` — non-raising parser; returns `Optional[SemVer]`.
6. `precedence` — SemVer clause 11 ordering: `-1`, `0` or `+1`; build
   metadata ignored.
7. `is_prerelease` — does the version carry a prerelease.
8. `is_stable` — is the version stable (`major > 0` and no prerelease).

## Error Surface

One error type, `VersionError`, with a closed `VersionErrorKind`. Which API
raises what:

| API | Raises | Kinds |
| --- | --- | --- |
| `SemVer` (component constructor) | `VersionError` | `BAD_NUMBER` (negative component), `INVALID_FORMAT`, `LEADING_ZERO` (bad qualifier) |
| `VersionErrorKind` | none | — |
| `VersionError` (construction) | none | — |
| `parse` | `VersionError` | `EMPTY`, `INVALID_FORMAT`, `BAD_NUMBER`, `LEADING_ZERO`, `OVERFLOW` |
| `try_parse` | none | — (absence is `Optional`) |
| `precedence` | none | — |
| `is_prerelease` | none | — |
| `is_stable` | none | — |

Recoverability: every `VersionError` is a recoverable **data** error — the
caller passed a malformed string or component. No operation is fatal and none
aborts. `OTHER` is reserved and carries its context in the opaque `detail`
string; no release-1 operation raises it.

## Conventions

- **Strict input.** `parse` accepts exactly the semver.org BNF: no leading or
  trailing whitespace, no `v`/`=` prefix, no partial versions, no leading
  zeros, no empty identifiers (`js-ts.md` §11, `cpp.md` §11, `python.md` §7).
- **One value vocabulary.** A version is a `SemVer`; its two qualifiers are
  owned `String`s that are **empty** when absent — never `Optional`, never a
  sentinel, never a borrowed slice (`zig.md` §11).
- **One comparison.** `precedence` returns an `Int` in `{-1, 0, +1}`; build
  metadata is ignored, exactly as clause 10 requires (`rust.md` §9,
  `elixir.md` §7).
- **Equality is precedence.** `SemVer.__eq__` is true iff `precedence == 0`;
  two versions differing only in build metadata are equal. Consequence: `==`
  does **not** distinguish `1.2.3+a` from `1.2.3+b`, and `Writable` may render
  two equal values differently. A build-sensitive equality/total order is
  backlog (`compare_with_build`, `same_build`; `rust.md` §11, `js-ts.md` §11).
- **`Int` components.** `major`/`minor`/`patch` are `Int` (non-negative,
  machine-word on supported targets) with explicit `OVERFLOW` rejection; no
  32-bit trap (`c.md` §11) and no magic 14-digit cap (`elixir.md` §11).
- **Names are `snake_case`** for functions and fields, `CamelCase` for types,
  `SCREAMING_CASE` for `comptime` constants — the Mojo style guide.
- **No hidden global state.** Nothing mutates process state, locale or a
  global format.

## Ownership and Lifecycle

- **All types are value types.** `SemVer` conforms to
  `Equatable, Copyable, Deinitable, Writable`; `VersionErrorKind` to
  `Equatable, ImplicitlyCopyable, Deinitable, Writable`; `VersionError` to
  `Copyable, Deinitable, Writable`.
- **The `SemVer` invariant is protected by private fields.** Mojo has no access
  control, so — like `akku/net_ip/ipv4_address.mojo` (private `_b`, accessor
  `octets()`) — `SemVer` stores `_major`/`_minor`/`_patch`/`_prerelease`/
  `_build` and exposes plain accessor methods. The only initializer is
  `@doc_hidden` (the `mojov1/decorators/doc-hidden` convention already used by
  `prim_bit`/`prim_endian` kinds), so the public surface cannot set an
  unvalidated field; every value comes from the single validating constructor
  or from `parse`. Because there is no way to reach the fields directly, the
  "every `SemVer` is well-formed" invariant holds (`mojov1/keywords/struct`).
- **One private comparison, two thin callers.** The Clause-11 algorithm lives
  once in `_internal/version_core.mojo` as a pure function over the raw fields;
  `precedence.mojo` and `SemVer.__eq__` delegate to it. This removes the
  circular import `semver.mojo <-> precedence.mojo` — the shared-core
  convention of `akku/net_ip/_internal/ip_core.mojo` (`mojov1/intro/packages-and-modules`).
- **`SemVer` is `Copyable` but not `ImplicitlyCopyable`.** It owns two `String`
  fields, so an implicit copy could hide allocation; `ImplicitlyCopyable`
  should only be used when copying is inexpensive and side-effect-free
  (`mojov1/keywords/struct`). Callers copy explicitly with `.copy()` or pass
  by the default immutable reference.
- **`VersionError` is `Copyable` but not `ImplicitlyCopyable`**, so a re-raise
  must transfer with `raise e^` — the `prim_bit`/`prim_endian` convention
  (`mojov1/errors/raising-and-propagation`).
- **The parser borrows its input.** `parse(text: StringSpan)` and
  `try_parse(text: StringSpan)` borrow the caller's text for the duration of
  the call and never retain it. The returned `SemVer` **owns** its qualifiers,
  so it outlives the input buffer — the fix for Zig's borrowed-slice lifetime
  trap (`zig.md` §11).
- **EOF / EINTR / EAGAIN / close / timeouts are not applicable.** There is no
  stream, no blocking call, no interruption point and no owned handle; every
  operation is a pure in-memory computation over an already-owned string or
  value (`rust.md` §6, `zig.md` §8).
- **ASAP destruction.** No library type holds a resource with a destructor
  side effect; the owned strings are freed at the value's last use.

## Open Questions

None block this design. The points below are settled and recorded so a later
phase does not reopen them:

- *Does `SemVer.__eq__` consider build metadata?* → **No.** Equality is
  precedence equality (build ignored), so `__eq__` agrees with
  `precedence(a, b) == 0`, per SemVer clause 10 (`rust.md` §9, `elixir.md` §7).
  A build-sensitive equality/total order is a backlog candidate
  (`_dev/TODO.md`).
- *Which comparison shape?* → a free function `precedence(a, b) -> Int`
  returning `-1`/`0`/`+1`, not a `VersionOrder` type and not a method. An `Int`
  comparator composes with sort helpers and matches Go/C/Rust's `int`/`Ordering`
  result (`go.md` §3, `c.md` §3, `rust.md` §3); Elixir's atoms (`elixir.md` §10)
  and the JVM `Comparable` convention (`java.md` §10) both reduce to the same
  three-way result.
- *Is `try_parse` in release 1?* → **Yes.** Every mandatory reference language
  exposes a non-raising/tuple/optional parse path (`elixir.md` §4,
  `cpp.md` §3, `rust.md` §4, `go.md` §4, `js-ts.md` §4, `java.md` §4,
  `kotlin.md` §4); Mojo maps it to `Optional[SemVer]` in one line over `parse`.
  It is parsing, not a range, so it stays inside the release-1 scope.
- *Are the qualifiers stored as a list like Elixir?* → **No, release 1 stores
  each as one owned `String`.** This keeps the value type small and
  `Writable`-friendly and round-trips exactly; the comparison re-splits the
  prerelease on `.` at compare time. Accepting Kotlin's opaque-joined-string
  weakness (`kotlin.md` §11) in exchange for a simpler value; a pre-split
  identifier list / identifier accessor is a backlog candidate
  (`_dev/TODO.md`).

---

### `SemVer`

Status: planned

Signature:

```mojo
struct SemVer(Equatable, Copyable, Deinitable, Writable):
    var _major: Int
    var _minor: Int
    var _patch: Int
    var _prerelease: String
    var _build: String

    @doc_hidden
    def __init__(
        out self,
        major: Int,
        minor: Int,
        patch: Int,
        prerelease: String = "",
        build: String = "",
    ) raises VersionError

    def major(self) -> Int
    def minor(self) -> Int
    def patch(self) -> Int
    def prerelease(self) -> StringSpan
    def build(self) -> StringSpan

    def __eq__(self, other: Self) -> Bool

    def __ne__(self, other: Self) -> Bool

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Fields / meaning:** `_major`, `_minor`, `_patch` are the three numeric core
  components; `_prerelease` is the dot-joined prerelease identifier string
  (`"alpha.1"`), empty when the version has no prerelease; `_build` is the
  dot-joined build-metadata string (`"build.5"`), empty when absent. An empty
  `String` is the one absence representation — there is no `Optional` field and
  no sentinel (`zig.md` §11, `elixir.md` §7).
- **Private fields, public accessors.** Following
  `akku/net_ip/ipv4_address.mojo` (private `_b`, accessor `octets()`), the
  fields are `_`-prefixed and read through `major()`/`minor()`/
  `patch()` (returning `Int`) and `prerelease()`/`build()` (returning a
  borrowed `StringSpan` view into the value). The value owns the two
  `String`s; the accessors do not copy. This is how a no-access-control
  language still keeps the always-valid invariant: nothing outside the module
  can write a field.
- **Construction — component path.** The `@doc_hidden __init__` is the
  parser-free constructor (`python.md` §10: `from_parts`; `java.md` §12:
  `Semver.of`): it validates `major`/`minor`/`patch >= 0` (else `BAD_NUMBER`)
  and validates the two qualifier strings against the SemVer identifier grammar
  (else `INVALID_FORMAT` or `LEADING_ZERO`). It is the only initializer, so a
  `SemVer` that exists is always well-formed — the Rust newtype invariant
  (`rust.md` §10) reached through a validating `@doc_hidden` constructor,
  because Mojo has no access control and hides internals by the `_`/`@doc_hidden`
  convention (`mojov1/decorators/doc-hidden`, `mojov1/keywords/struct`).
- **Construction — string path.** `parse(text)` builds the same value after
  full string validation; `try_parse(text)` returns it inside an `Optional`.
- **Equality.** `__eq__` delegates to the private core comparison
  (`_internal/version_core.mojo`), the same Clause-11 algorithm `precedence`
  exposes; it is true iff `precedence(self, other) == 0`, i.e. the three
  numerics and the prerelease are equal and **build metadata is ignored**
  (clause 10; `rust.md` §9, `elixir.md` §7). `__ne__` is its negation. There is
  no build-sensitive equality in release 1 (backlog `same_build`).
- **Rendering.** `write_to` prints the canonical strict form
  `major.minor.patch`, then `-` + prerelease when non-empty, then `+` + build
  when non-empty. It is the exact inverse of `parse` for any value built by
  `parse`.
- **Ownership.** The value owns its two qualifier `String`s; it can be returned
  from a function, stored in a `List`, and outlive the parsed input buffer
  (`zig.md` §11). It is `Copyable` (explicit `.copy()`), not
  `ImplicitlyCopyable`.

Errors:

- `BAD_NUMBER` — a numeric component is negative.
- `LEADING_ZERO` — a numeric identifier inside `prerelease` has a leading zero
  (`"01"`).
- `INVALID_FORMAT` — `prerelease` or `build` is non-empty but not a valid
  dot-separated identifier list, or contains an empty identifier.

Tests:

- `test_semver_construct_valid` — `SemVer(1, 2, 3)` has empty qualifiers.
- `test_semver_construct_rejects_negative` — a negative component raises
  `BAD_NUMBER`.
- `test_semver_construct_rejects_bad_prerelease` — `"alpha..1"` raises
  `INVALID_FORMAT`.
- `test_semver_construct_rejects_leading_zero_prerelease` — `"01"` raises
  `LEADING_ZERO`.
- `test_semver_accessors_major_minor_patch` — the three accessors return the
  constructed components.
- `test_semver_accessors_prerelease_build` — `prerelease()`/`build()` return
  the qualifier strings (empty `StringSpan` when absent).
- `test_semver_eq_ignores_build` — `1.2.3+a == 1.2.3+b`.
- `test_semver_eq_uses_precedence` — `1.2.3-alpha != 1.2.3`.
- `test_semver_writable_roundtrip` — parse then print returns the strict form.

Implementation status:

not implemented

Rationale:

`MojoAkku uses one SemVer value with owned prerelease/build Strings because
Rust stores owned validated qualifiers (rust.md §7, §10) and Elixir stores the
struct fields as the identity itself (elixir.md §7), while Zig's borrowed
`?[]const u8` slices create a use-after-free coupling to the input buffer and
are rejected (zig.md §11). MojoAkku stores prerelease and build as single
joined Strings rather than Elixir's identifier list because it keeps the value
small and Writable-friendly for release 1, accepting Kotlin's joined-string
weakness knowingly (kotlin.md §11); a pre-split identifier list plus identifier
accessors are backlog (_dev/TODO.md). MojoAkku uses private `_`-prefixed fields
with public accessors because Mojo has no access control (mojov1/keywords/struct)
and this is the established house convention for a value with an invariant
(akku/net_ip/ipv4_address.mojo, private `_b` + `octets()`); the single
`@doc_hidden` constructor is the only way to build a value, mirroring Rust's
newtype invariant (rust.md §10) and the prim_bit/prim_endian hidden-kind
convention. MojoAkku uses Int for the three components because Int is Mojo's
machine-word default and the project convention
(mojov1/types/integers-and-floats); Rust's u64 with checked overflow (rust.md
§10) is mirrored by validating Int and raising OVERFLOW in parse, and C's
32-bit int trap (c.md §11) is explicitly avoided. MojoAkku uses a validating
component constructor because Python from_parts (python.md §10) and Java
Semver.of (java.md §12) show programmatic construction is needed.`

---

### `VersionErrorKind`

Status: planned

Signature:

```mojo
struct VersionErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    def __eq__(self, other: Self) -> Bool

    comptime EMPTY          = VersionErrorKind(0)
    comptime INVALID_FORMAT = VersionErrorKind(1)
    comptime BAD_NUMBER     = VersionErrorKind(2)
    comptime LEADING_ZERO   = VersionErrorKind(3)
    comptime OVERFLOW       = VersionErrorKind(4)
    comptime OTHER          = VersionErrorKind(5)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `VersionError.kind`; never passed by
  a caller to a parse. The type is **opaque**: the six `comptime` members are
  the complete public set; `_id` and its `@doc_hidden` initializer are
  implementation details (Mojo has no access control,
  `mojov1/decorators/doc-hidden`). `__eq__` is an intentional override
  mirroring `BitErrorKind`/`EndianErrorKind`.
- **Return / meaning:** the machine-testable reason a version operation failed.
  - `EMPTY` — the input was empty.
  - `INVALID_FORMAT` — a structural violation: not exactly three core
    components, an empty identifier, an unexpected/duplicated `+`/`-`, a
    disallowed character in a qualifier, a `v`/`=` prefix, or surrounding
    whitespace.
  - `BAD_NUMBER` — a core component (or numeric prerelease identifier) is not
    all decimal digits, or a component passed to the constructor is negative.
  - `LEADING_ZERO` — an all-digit identifier has a leading zero (`"01"`), which
    SemVer clause 2/9 forbids for the core and for numeric prerelease
    identifiers.
  - `OVERFLOW` — a numeric component does not fit `Int` (distinct from a syntax
    error; `zig.md` §4 documents `error.Overflow` separately from
    `error.InvalidVersion`).
  - `OTHER` — any other condition; the opaque `VersionError.detail` holds it.
    Reserved in release 1: no release-1 operation raises it.
- **Why these six and no more.** Every kind maps to a real branch in `parse` or
  the constructor; unreachable kinds are not carried (contrast `prim_endian`,
  which dropped an unreachable `RANGE`).
- **`write_to`** prints the symbolic name, never the number.

Errors:

none — it is a discriminant, not an operation.

Tests:

- `test_error_kind_distinct_ids` — each `comptime` member has a distinct `_id`.
- `test_error_kind_eq` — `==` compares `_id` only.
- `test_error_kind_writable` — `write_to` prints the symbolic name, never the
  number.

Implementation status:

not implemented

Rationale:

`MojoAkku uses a closed VersionErrorKind because Zig splits InvalidVersion
from Overflow (zig.md §4) and Rust funnels all parse failures through one
`Error` type with enumerated causes (rust.md §4, §10), so a single error type
with a small closed discriminant is enough; prim_bit/prim_endian already
taught the low-vision user one kind+op+detail shape
(akku/prim_bit/_dev/DESIGN.md, akku/prim_endian/_dev/DESIGN.md); a Python
exception class hierarchy (python.md §11) or a numeric errno is rejected as
noise. The set is deliberately as small as the reachable failures: each of
EMPTY, INVALID_FORMAT, BAD_NUMBER, LEADING_ZERO and OVERFLOW corresponds to a
documented semver.org rule, and OTHER is reserved.`

---

### `VersionError`

Status: planned

Signature:

```mojo
@fieldwise_init
struct VersionError(Copyable, Deinitable, Writable):
    var kind: VersionErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library on failure; read
  in an `except` block (or `try`/`except`) after `parse` or a constructor call.
  Fields: `kind` (see `VersionErrorKind`), `op` (a short operation name, e.g.
  `"parse"`, `"SemVer"`), and `detail` (opaque human-readable context, e.g. the
  offending input or identifier; must not be parsed). The `op` list is
  illustrative, not a closed enum.
- **Return / meaning:** raised, never returned. Recoverable by passing a
  well-formed input (`EMPTY`/`INVALID_FORMAT`/`BAD_NUMBER`/`LEADING_ZERO`) or a
  smaller number (`OVERFLOW`); no other failure exists in release 1.
- **`write_to`** prints a readable
  `VersionError(<kind>, op=..., detail=...)` message. Because `VersionError` is
  `Copyable` but not `ImplicitlyCopyable`, a re-raise transfers with `raise e^`
  (`mojov1/errors/raising-and-propagation`).

Errors:

none — `VersionError` *is* the error; constructing it cannot fail.

Tests:

- `test_error_writable` — `print(e)` yields kind + op + detail.
- `test_error_reraise_transfer` — a caught error re-raises with `raise e^`.
- `test_error_op_names_call` — `op` is `"parse"` for a parse failure and
  `"SemVer"` for a constructor failure.
- `test_error_detail_is_opaque` — `detail` carries the offending input and is
  not required to be machine-parsable.

Implementation status:

not implemented

Rationale:

`MojoAkku uses one typed error VersionError because Rust funnels all parse
failures through a single `semver::Error` (rust.md §4: "`Result<T, Error>` is
the only error channel; no panics and no sentinels") and Java likewise exposes
one exception path per parse (java.md §4), and prim_bit/prim_endian
established the kind+op+detail shape (akku/prim_bit/_dev/DESIGN.md,
akku/prim_endian/_dev/DESIGN.md); it replaces both Python's InvalidVersion
exception and node's null (python.md §11, js-ts.md §11) with Mojo's
alternate-return-value model (mojov1/errors/error-model), and a separate error
type per failure kind is rejected as a taxonomy the low-vision user does not
need.`

---

### `parse`

Status: planned

Signature:

```mojo
def parse(text: StringSpan) raises VersionError -> SemVer
```

Semantics:

- **Input.** `text` is a borrowed `StringSpan`; it is read for the duration of
  the call and never retained. The function accepts **exactly** the semver.org
  grammar — including no leading/trailing whitespace, no `v`/`=` prefix, and no
  partial versions (`js-ts.md` §11, `python.md` §7, `cpp.md` §11).
- **Grammar implemented (semver.org).**
  - `<version core>` is **exactly three** dot-separated numeric identifiers
    `<major>.<minor>.<patch>`; `1`, `1.2` and `1.2.3.4` are rejected
    (`INVALID_FORMAT`).
  - A **numeric identifier** is `0` or `[1-9][0-9]*` — a leading zero is
    forbidden (`LEADING_ZERO`); a non-digit character in a core component is
    `BAD_NUMBER`.
  - An **identifier that does not fit `Int`** is `OVERFLOW`.
  - An optional prerelease follows a single `-`: `<core>-<pre>`, where `<pre>`
    is dot-separated identifiers. A prerelease identifier is either a numeric
    identifier (no leading zero) or an alphanumeric identifier that contains at
    least one non-digit and only `[0-9A-Za-z-]`. An empty identifier
    (`1.2.3-`, `1.2.3-a..b`), a disallowed character, or a leading-zero numeric
    identifier is rejected (`INVALID_FORMAT`/`LEADING_ZERO`).
  - An optional build follows a single `+`: `<core>[+<build>]` or
    `<core>-<pre>+<build>`. `<build>` is dot-separated identifiers over
    `[0-9A-Za-z-]`; leading zeros **are** allowed in build identifiers and are
    preserved. An empty build identifier is rejected (`INVALID_FORMAT`).
  - `-` and `+` are mutually ordered: build only after prerelease; a `+` before
    a `-`, or a second `+`/`-`, is `INVALID_FORMAT`.
- **Splitting.** The parser splits **once** on `+`, **once** on `-` and twice
  on `.` using `akku/text_string.split_once`, whose `Optional[(before, after)]`
  result makes absence a value and avoids the stdlib `find` `-1` sentinel
  (`mojov1/types/string-operations`; `akku/text_string/split_once.mojo`).
- **Return.** A fully validated, owned `SemVer`; the input `StringSpan` may be
  dropped immediately afterwards.
- **Build metadata** is stored and preserved but never affects precedence
  (clause 10); it is carried only for round-tripping.
- **Total failure model.** Every malformed input raises exactly one
  `VersionError` with a closed kind; nothing aborts, nothing returns a sentinel,
  and invalid input never becomes a `SemVer` (`c.md` §4, `go.md` §4, `zig.md`
  §4).

Errors:

- `EMPTY` — `text` is empty.
- `INVALID_FORMAT` — structural violation (see grammar above).
- `BAD_NUMBER` — a core/prerelease numeric identifier contains a non-digit.
- `LEADING_ZERO` — an all-digit identifier has a leading zero.
- `OVERFLOW` — a numeric component does not fit `Int`.

Tests:

- `test_parse_basic` — `"1.2.3"` yields major=1, minor=2, patch=3.
- `test_parse_prerelease` — `"1.2.3-alpha.1"` sets `prerelease="alpha.1"`.
- `test_parse_build` — `"1.2.3+build.5"` sets `build="build.5"`.
- `test_parse_prerelease_and_build` — `"1.2.3-alpha+build"` sets both.
- `test_parse_rejects_empty` — `""` raises `EMPTY`.
- `test_parse_rejects_partial` — `"1"`/`"1.2"` raise `INVALID_FORMAT`.
- `test_parse_rejects_four_components` — `"1.2.3.4"` raises `INVALID_FORMAT`.
- `test_parse_rejects_v_prefix` — `"v1.2.3"` raises `INVALID_FORMAT`.
- `test_parse_rejects_whitespace` — `" 1.2.3"` raises `INVALID_FORMAT`.
- `test_parse_rejects_leading_zero_core` — `"01.2.3"` raises `LEADING_ZERO`.
- `test_parse_rejects_leading_zero_prerelease` — `"1.2.3-01"` raises
  `LEADING_ZERO`.
- `test_parse_rejects_bad_char` — `"1.2.x"` raises `BAD_NUMBER`.
- `test_parse_rejects_empty_identifier` — `"1.2.3-"`, `"1.2.3+"`,
  `"1.2.3-a..b"` raise `INVALID_FORMAT`.
- `test_parse_rejects_double_separator` — `"1.2.3+1-2"`, `"1.2.3-a+b+c"` raise
  `INVALID_FORMAT`.
- `test_parse_rejects_overflow` — a component above `Int` range raises
  `OVERFLOW`.
- `test_parse_accepts_build_leading_zero` — `"1.2.3+01"` is valid.
- `test_parse_roundtrip` — `parse(text)` then `print` equals `text` for every
  valid corpus entry.
- `test_parse_error_op_is_parse` — the raised error's `op` is `"parse"`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses a strict parse(text: StringSpan) raises VersionError because
Rust Version::parse returns Result (rust.md §3, §4), Zig parse returns
!Version (zig.md §3) and Elixir parse/1 returns a tagged tuple (elixir.md §3)
— all value-returning parsers with a single error channel; Mojo's raises is the
native form (mojov1/errors/error-model). MojoAkku rejects node-semver's lenient
v/=-stripping and loose mode (js-ts.md §11) and C++ clean/coerce (cpp.md §11)
because semver.org says v1.2.3 is not a semantic version; lenient parsing must
be a distinct, explicitly named operation, not the parser. MojoAkku rejects
Go's silent coercion (go.md §11) and Python/PEP-440 normalization (python.md
§11) so invalid input never succeeds quietly. MojoAkku uses
text_string.split_once for the -/+/.-splitting because the stdlib has no
split_once/partition and find returns the -1 sentinel
(mojov1/types/string-operations), which the dependency edge to text_string
covers; the parser is a hand-written byte scanner over StringSpan, not a regex,
avoiding the regex-DoS class node-semver must harden against (js-ts.md §8).`

---

### `try_parse`

Status: planned

Signature:

```mojo
def try_parse(text: StringSpan) -> Optional[SemVer]
```

Semantics:

- **Input.** The same strict grammar, input type and strictness as `parse`;
  `text` is borrowed and never retained.
- **Return.** `Some(SemVer)` when `text` is a valid strict SemVer, `None`
  otherwise. It never raises and never aborts: absence of a parse result is a
  value, not a sentinel (`java.md` §11, `js-ts.md` §11).
- **Relationship to `parse`.** `try_parse` is the non-raising twin: it is
  `parse` wrapped in a `try`/`except` that maps any `VersionError` to `None`.
  The error's `kind`/`detail` is deliberately discarded, because the "no
  version here" use case does not need it; callers that need the reason call
  `parse` (`mojov1/errors/raising-and-propagation`).
- **Ownership.** The returned `Optional[SemVer]` owns a fresh `SemVer`; the
  input may be dropped immediately.

Errors:

none — absence is `None`.

Tests:

- `test_try_parse_valid` — `"1.2.3"` yields `Some` with the expected fields.
- `test_try_parse_invalid_none` — `"not-a-version"` yields `None`.
- `test_try_parse_empty_none` — `""` yields `None`.
- `test_try_parse_matches_parse` — for a corpus, `try_parse` is `Some` iff
  `parse` does not raise.
- `test_try_parse_never_raises` — no input raises.

Implementation status:

not implemented

Rationale:

`MojoAkku uses try_parse(text) -> Optional[SemVer] because every mandatory
reference language exposes a non-raising parse result alongside the raising
one: Elixir's tagged tuple and parse! pair (elixir.md §3, §4), C++ try_parse ->
std::optional (cpp.md §3), Rust Result (rust.md §4), Go's (value, error)
(go.md §4), node's and semver4j's null (js-ts.md §4, java.md §4) and
kotlin-semver's toVersionOrNull (kotlin.md §4); Mojo's Optional is the
type-safe equivalent of that null/absence path
(mojov1/types/optionals-and-nullability), and it is a one-line wrapper over
parse, so it stays inside the release-1 parsing scope.`

---

### `precedence`

Status: planned

Signature:

```mojo
def precedence(a: SemVer, b: SemVer) -> Int
```

Semantics:

- **Parameters / preconditions:** `a` and `b` are two valid `SemVer` values
  (both borrow only). There is no precondition failure: every pair of `SemVer`
  values has a defined precedence.
- **Return / meaning:** `-1` when `a` has lower precedence, `0` when they have
  equal precedence, `+1` when `a` has higher precedence. It is the SemVer
  clause 11 algorithm:
  1. Compare `major`, then `minor`, then `patch` **numerically**; the first
     difference decides.
  2. If the three numerics are equal, a version **with** a prerelease has
     **lower** precedence than one without (so `1.2.3-alpha < 1.2.3`).
  3. If **both** have a prerelease, split each on `.` and compare identifiers
     left to right:
     - two numeric identifiers compare **numerically**;
     - two alphanumeric identifiers compare **lexically in ASCII order**;
     - a numeric identifier always has **lower** precedence than an
       alphanumeric identifier;
     - if all compared identifiers are equal, the set with **fewer**
       identifiers has lower precedence (so `alpha < alpha.1`).
  4. **Build metadata is ignored entirely** (clause 10): `1.2.3+a` and `1.2.3+b`
     and `1.2.3` all compare `0`.
- **Totality.** `precedence` cannot fail and raises nothing; it is a pure
  function from two values to `Int` (`zig.md` §4: `order` is not fallible
  because invalid values cannot exist).
- **One implementation.** `precedence.mojo` is a thin wrapper over the private
  `_internal/version_core.mojo` Clause-11 function; `SemVer.__eq__` calls the
  same core, so there is exactly one comparison implementation and no
  `semver.mojo <-> precedence.mojo` import cycle (the
  `akku/net_ip/_internal/ip_core.mojo` convention).
- **Relation to `__eq__`.** `SemVer.__eq__` is exactly `precedence(a, b) == 0`;
  the two are guaranteed consistent because they share the core.
- **Sorting.** A caller can sort by mapping `precedence` to a key; a dedicated
  `sort` helper is backlog (`_dev/TODO.md`).

Errors:

none — total for every pair of valid values.

Tests:

- `test_precedence_numeric_order` — `1.0.0 < 2.0.0`, `2.0.0 < 2.1.0`,
  `2.1.0 < 2.1.1`.
- `test_precedence_equal` — `1.2.3` vs `1.2.3` is `0`.
- `test_precedence_prerelease_lower` — `1.0.0-alpha < 1.0.0`.
- `test_precedence_numeric_identifiers` — `1.0.0-2 < 1.0.0-10`.
- `test_precedence_alphanumeric_ascii` — `1.0.0-alpha < 1.0.0-beta`;
  uppercase sorts before lowercase.
- `test_precedence_numeric_below_alphanumeric` — `1.0.0-1 < 1.0.0-alpha`.
- `test_precedence_fewer_identifiers_lower` — `1.0.0-alpha < 1.0.0-alpha.1`.
- `test_precedence_spec_chain` — the spec's example chain
  `1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta <
  1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0`.
- `test_precedence_ignores_build` — `1.2.3+a` vs `1.2.3+b` is `0`; `1.2.3` vs
  `1.2.3+b` is `0`.
- `test_precedence_antisymmetric` — `precedence(a,b) == -precedence(b,a)`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses precedence(a, b) -> Int returning -1/0/+1 because Rust
cmp_precedence -> Ordering (rust.md §3, §9), Go x/mod/semver.Compare
(go.md §3) and C semver_compare (c.md §3) all expose an integer/ordering
comparator, and Elixir Version.compare/2 returns the same three-way result as
:gt/:eq/:lt (elixir.md §3); an Int composes with sort helpers and keeps the
result simple for a low-vision user (elixir.md §10). MojoAkku implements clause
11 in full — numeric-vs-numeric numerically, alphanumeric ASCII-lexically,
numeric below alphanumeric, fewer identifiers lower (semver.org item 11,
zig.md §9) — because partial prerelease rules would silently mis-order real
versions. MojoAkku ignores build metadata because clause 10 requires it and
Rust cmp_precedence, Elixir compare and node all document the same behaviour
(rust.md §9, elixir.md §7, js-ts.md §7); a build-sensitive total order
(compare_with_build / Rust Ord / node compareBuild) is rejected inside one
comparator and stays backlog (rust.md §11, js-ts.md §11).`

---

### `is_prerelease`

Status: planned

Signature:

```mojo
def is_prerelease(v: SemVer) -> Bool
```

Semantics:

- **Parameter / precondition:** any valid `SemVer`, borrowed. Cannot fail.
- **Return / meaning:** `True` iff `v.prerelease()` is non-empty, i.e. the
  version carries a prerelease identifier string. It never inspects
  `v.build()`.
- **Relation to precedence:** `is_prerelease(v)` is exactly the condition in
  clause 11 that makes `v` compare lower than its release counterpart; it is
  offered as a named predicate so callers do not re-derive it from the string.
- **No mutation, no allocation.** It reads the public accessor only.

Errors:

none — total.

Tests:

- `test_is_prerelease_true` — `1.2.3-alpha` is prerelease.
- `test_is_prerelease_false_for_release` — `1.2.3` is not.
- `test_is_prerelease_false_for_build_only` — `1.2.3+build` is not a
  prerelease.
- `test_is_prerelease_agrees_with_precedence` — a prerelease compares lower
  than the same core without a prerelease.

Implementation status:

not implemented

Rationale:

`MojoAkku uses is_prerelease(v) because semver4j exposes isStable() and Kotlin
exposes .isPreRelease (java.md §12, kotlin.md §12) and C++ exposes
is_prerelease (cpp.md §3); it is a one-accessor predicate that names the
clause-11 condition instead of forcing the caller to test an empty string,
which is the predictability goal for a low-vision user. MojoAkku keeps it a
free function rather than a method so each public API entry maps to one file,
the LibraryLayout convention; it reads the public `prerelease()` accessor, so
it does not depend on the private fields.`

---

### `is_stable`

Status: planned

Signature:

```mojo
def is_stable(v: SemVer) -> Bool
```

Semantics:

- **Parameter / precondition:** any valid `SemVer`, borrowed. Cannot fail.
- **Return / meaning:** `True` iff `v.major() > 0` **and** `v.prerelease()` is
  empty. This is a documented **convention**, not a semver.org rule: the spec
  defines precedence, not stability (`java.md` §11, `kotlin.md` §11).
- **Consistency:** `is_stable(v)` implies `not is_prerelease(v)` and
  `v.major() > 0`; a `0.x.y` release and any prerelease are not stable.
- **No mutation, no allocation.** It reads public accessors only.

Errors:

none — total.

Tests:

- `test_is_stable_major_positive` — `1.0.0` is stable.
- `test_is_stable_zero_major` — `0.1.0` is not stable (pre-1.0 convention).
- `test_is_stable_prerelease` — `1.0.0-rc.1` is not stable.
- `test_is_stable_implies_not_prerelease` — consistency with `is_prerelease`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses is_stable(v) = major > 0 and no prerelease because semver4j
isStable() and kotlin-semver .isStable define exactly this convention
(java.md §12, kotlin.md §12), and it is a one-field query useful to release
tooling; MojoAkku documents it explicitly as a convention rather than a
semver.org rule because the spec is silent on stability (java.md §11). It stays
a free function for the one-file-per-entry layout, matching is_prerelease.`
