# build_versioning research: Go

## 1. Standard library support

- **The Go standard library has no SemVer implementation.** The closest package
  is `go/version`, which operates on **Go toolchain version syntax** — strings
  like `"go1.20"`, `"go1.21.0"`, `"go1.22rc2"`, `"go1.23.4-custom"` — not
  SemVer 2.0.0 (go/version package docs, *Overview*). It exposes only
  `Compare(x, y string) int`, `IsValid(x string) bool`, and `Lang(x string) string`
  (go/version docs).
- `go/version.Compare` returns `-1/0/+1`; invalid versions compare less than
  valid ones and equal to each other; `"go1.21"` compares less than `"go1.21rc1"`
  and `"go1.21.0"` (go/version docs). This is a *toolchain* ordering, not the
  SemVer precedence model (semver.org item 11).
- **The module system's SemVer support lives outside the standard library** in
  the `golang.org/x/mod/semver` package (pkg.go.dev, `golang.org/x/mod/semver`,
  BSD-3-Clause, imported by 1,930 packages).
- Generic building blocks in stdlib: `strconv.ParseUint`/`ParseInt` for numeric
  components, `strings.Split`/`Cut`/`TrimPrefix` for structure, `sort.Sort` /
  `sort.Slice` for ordering. `debug.BuildInfo` carries a module version string
  but does not parse SemVer. `GUESS:` `runtime.Version()` returns a Go toolchain
  string, not a SemVer value; no fetched stdlib function parses SemVer. Reason:
  the SemVer role is filled by `x/mod/semver` and third-party modules.

## 2. Relevant community libraries

- **`golang.org/x/mod/semver`** — Go-team-maintained, BSD-3-Clause, "implements
  comparison of semantic version strings" (pkg.go.dev). It follows SemVer 2.0.0
  with **two deliberate exceptions**: it *requires* a leading `"v"`, and it
  accepts `vMAJOR` and `vMAJOR.MINOR` as shorthand for `vMAJOR.0.0` and
  `vMAJOR.MINOR.0` (package docs, *Overview*).
- **`github.com/Masterminds/semver/v3`** — MIT, 4,026 importers, "the stable and
  active version" focused on constraint compatibility with other ecosystems; API
  similar to v1 (README, *Package Versions*). v2 was built for `dep`; v1 is
  unmaintained (README).
- **`github.com/hashicorp/go-version`** — MPL-2.0, 6,106 importers, "parsing
  versions and version constraints, and verifying versions against a set of
  constraints", can sort, handles prerelease/beta, can increment (README).
  "Versions used with go-version must follow SemVer" (README).
- **`blang/semver`, `coreos/go-semver`** — widely used but not fetched in this
  run; `GUESS:` they exist and provide comparable parse/compare APIs. Reason no
  source: the run fetched the three libraries above and did not fetch these two.

## 3. Exposed APIs

**`golang.org/x/mod/semver`** (pure functions over strings) (pkg.go.dev):

- `IsValid(v string) bool`; `Canonical(v string) string` (fills missing
  `.MINOR`/`.PATCH`, discards build metadata); `Compare(v, w string) int`;
  `Major(v) string`; `MajorMinor(v) string`; `Prerelease(v) string`;
  `Build(v) string`; `Sort(list []string)`;
  `type ByVersion []string` implementing `sort.Interface`; `Max(v, w)` is
  **deprecated** in favour of `Compare` (pkg.go.dev).
- Semantics: an invalid version string is considered **less than** a valid one,
  and all invalid strings compare equal (pkg.go.dev, `Compare`).

**`github.com/Masterminds/semver/v3`** (pkg.go.dev):

- `type Version struct { /* unexported */ }`;
  `NewVersion(v string) (*Version, error)` (coerces),
  `StrictNewVersion(v string) (*Version, error)` (strict SemVer 2),
  `MustParse(v string) *Version`,
  `New(major, minor, patch uint64, pre, metadata string) *Version`
  (does not validate pre/metadata).
- Methods: `Major/Minor/Patch() uint64`; `Prerelease()/Metadata() string`;
  `Original() string`; `String() string`; `Compare(o) int`;
  `Equal/LessThan/LessThanEqual/GreaterThan/GreaterThanEqual(o) bool`;
  `IncMajor/IncMinor/IncPatch() Version`; `SetPrerelease/SetMetadata(...)
  (Version, error)`; `MarshalJSON/MarshalText/UnmarshalJSON/UnmarshalText`,
  `Scan`, `Value` (database/SQL integration).
- Constraints: `type Constraints struct { IncludePrerelease bool }`;
  `NewConstraint(c string) (*Constraints, error)`; `Check(v) bool`;
  `Validate(v) (bool, []error)`; `MarshalText`/`UnmarshalText`.
- `type Collection []*Version` implementing `sort.Interface`.
- Limits/errors: `MaxVersionLen = 256`, `MaxConstraintLen = 512`,
  `MaxConstraintGroups = 32`; exported `ErrInvalidSemVer`, `ErrEmptyString`,
  `ErrInvalidCharacters`, `ErrSegmentStartsZero`, `ErrInvalidMetadata`,
  `ErrInvalidPrerelease`, `ErrVersionTooLong`; globals `CoerceNewVersion = true`,
  `DetailedNewVersionErrors = true`.

**`github.com/hashicorp/go-version`** (pkg.go.dev):

- `NewVersion(v string, opts ...Option) (*Version, error)`,
  `NewSemver(v string) (*Version, error)` (strict), `Must(...)`,
  `WithPrefix(prefix) Option` (strips a known release prefix like
  `deployment-`).
- Methods: `Compare(other) int`; `Equal/GreaterThan/GreaterThanOrEqual/
  LessThan/LessThanOrEqual(o) bool`; `Segments() []int`;
  `Segments64() []int64`; `Core() *Version` (MAJOR.MINOR.PATCH only);
  `Original() string`; `Prefix() string`; `Prerelease()/Metadata() string`;
  `String()` (canonicalising); `MarshalText/UnmarshalText`, `Scan`, `Value`.
- Constraints: `NewConstraint(v string) (Constraints, error)` (comma-separated),
  `Constraint.Check/Equals/Prerelease/String`, `MustConstraints`;
  `Collection []*Version` implements `sort.Interface`.

## 4. Error representation

- **`(value, error)` tuples are the dominant Go idiom.**
  `NewVersion(...) (*Version, error)`, `StrictNewVersion(...) (*Version, error)`,
  `NewConstraint(...) (*Constraints, error)` (pkg.go.dev, both libraries).
- **Sentinel `error` values** in Masterminds: the package exports typed error
  variables (`ErrInvalidSemVer`, `ErrEmptyString`, `ErrInvalidCharacters`,
  `ErrSegmentStartsZero`, `ErrInvalidMetadata`, `ErrInvalidPrerelease`,
  `ErrVersionTooLong`) so callers can compare with `errors.Is` (pkg.go.dev).
- **`Must*` helpers panic instead of returning an error** for compile-time-like
  or trusted inputs: `MustParse`, `Must`, `MustConstraints` (pkg.go.dev).
- **`x/mod/semver` does not report errors at all.** It uses sentinel empty
  strings: "If v is an invalid semantic version string, `Build` returns the empty
  string", likewise `Major`, `MajorMinor`, `Prerelease`; `IsValid` exists to
  check separately, and `Compare` folds invalid strings to "less" rather than
  erroring (pkg.go.dev).
- **Constraint validation can return per-clause reasons:**
  `Validate(v) (bool, []error)` returns "a slice of reasons" like
  "1.3 is greater than 1.2.3" (Masterminds README, *Validation*).

## 5. Ownership semantics

*Adapted for versioning (see `_dev/README.md`): whether parsing is in-place or
value-returning, and who owns the parsed value/string.*

- **Pure Go, garbage-collected: no manual ownership.** Constructors return a
  pointer (`*Version`) or value; the GC owns the backing storage, and the two
  qualifier strings are ordinary Go `string`s (immutable, shared safely)
  (pkg.go.dev, both libraries).
- **`x/mod/semver` is string-in / string-out and allocates freely.** It has no
  version object at all; `Canonical` returns a new string, and comparisons only
  read their arguments (pkg.go.dev).
- **Masterminds keeps the original text alongside the parsed fields:**
  `Original()` returns "the original value passed in to be parsed" (useful when
  `NewVersion` coerced it) while `String()` returns the canonical form
  (pkg.go.dev). The parsed `Version` owns its fields; the original string is
  retained for round-tripping.
- **hasicorp `Segments`/`Segments64` return freshly allocated slices** of the
  numeric parts; `Core()` returns a new `*Version` (pkg.go.dev). Nothing is
  borrowed or freed by the caller.
- Parsing copies the input into the struct; the input string is not retained by
  reference in a way the caller must manage (Assessment: derived from the
  pointer-returning constructors and Go string immutability).

## 6. Blocking / non-blocking

- **Not applicable: pure computation, no I/O.** All three libraries parse and
  compare strings/values with no blocking calls and no async model
  (pkg.go.dev, all three; §1).
- **Values are immutable after parsing** except where explicit setters return a
  *new* value (`SetPrerelease`, `SetMetadata`, `IncMajor` return `Version`, not
  mutate) (pkg.go.dev). Immutability makes concurrent reads safe without locks
  (Assessment: derived from the value-returning method signatures).
- `x/mod/semver` functions are pure; `Compare`/`Sort` are safe to call
  concurrently on distinct data (Assessment: derived from pure signatures).

## 7. IPv4 / IPv6

*Adapted for versioning (see `_dev/README.md`): how the spec/version identity is
modelled and whether one abstraction covers it all.*

- **Three incompatible identity models across the ecosystem:**
  - **String-only** (`x/mod/semver`): no type; the version *is* a string, with
    `Major`/`MajorMinor`/`Prerelease`/`Build` as string-slicing helpers and
    `Canonical` as the normaliser (pkg.go.dev).
  - **Struct of fields** (Masterminds, hashicorp): `major/minor/patch` as
    `uint64` or `[]int` segments, plus `pre`/`metadata` strings, plus the original
    text (pkg.go.dev).
- **`v` prefix policy differs sharply:**
  - `x/mod/semver` **requires** a leading `v` (package docs, *Overview*).
  - Masterminds makes it **optional** (`NewVersion` coerces a leading `v` and
    missing parts; `StrictNewVersion` accepts only valid v2 strings) (README,
    *Parsing Semantic Versions*).
  - hashicorp accepts an optional `v` and additionally a **custom prefix** via
    `WithPrefix` ("deployment-v1.2.3-beta+metadata") which is stripped and not
    part of the canonical value (README, *Version Parsing and Comparison with
    Prefixes*).
- **Partial versions:**
  - `x/mod/semver` accepts `vMAJOR` and `vMAJOR.MINOR` as documented shorthand
    (package docs, *Overview*).
  - Masterminds `NewVersion` coerces `1.2` → `1.2.0`; `StrictNewVersion` rejects
    it (README, *Parsing Semantic Versions*).
  - hashicorp `NewVersion` accepts partial forms and `String()` canonicalises
    them (`1.0` → `1.0.0`, `v1.0.0` → `1.0.0`, `1.04.0` → `1.4.0`) so
    "ambiguities ... will be made into a canonicalized form" (pkg.go.dev,
    `String`).
- **No single abstraction covers everything.** The richer libraries add
  ranges (`Constraints`), prefixes, SQL/JSON marshalling and sorting as separate
  layers; the identity core is just the fields (pkg.go.dev).
- **CalVer is tolerated as an accident of coercion**, not modelled: Masterminds'
  `CoerceNewVersion = true` "allows leading 0 in a major, minor, or patch part.
  This enables the use of CalVer in versions even when not compliant with
  SemVer" (pkg.go.dev, `CoerceNewVersion`).

## 8. Timeouts

- **Not applicable.** Parsing/comparison are pure and bounded by the input
  length; the libraries impose **input-length limits** instead of deadlines:
  `MaxVersionLen = 256`, `MaxConstraintLen = 512` (Masterminds pkg.go.dev,
  constants), "This guards against unbounded input causing excessive memory
  allocations during parsing" (pkg.go.dev, `MaxVersionLen`).
- No cancellation, no context, no scheduler interaction exists in any of the
  three APIs (Assessment: derived from the pure signatures).

## 9. TLS

*Adapted for versioning (see `_dev/README.md`): how prerelease/build metadata and
constraint ranges are handled.*

- **Prerelease and build metadata are stored; precedence follows semver.org
  item 11 and build metadata is ignored for precedence** (semver.org item 10;
  Masterminds README, *Working With Prerelease Versions*; pkg.go.dev, `Compare`:
  "Build metadata is ignored. Prerelease is lower than the version without a
  prerelease").
- **The crucial design point: comparison and constraint matching use *different*
  rules and the library says so explicitly.** "When two versions are compared
  using functions such as `Compare`, `LessThan`, ... it will follow the
  specification and always include pre-releases"; but "when constraint checking
  is used ... it will follow a different set of rules that are common for ranges
  with tools like npm/js and Rust/Cargo. This includes considering pre-releases
  to be invalid if the ranges does not include one." (Masterminds README,
  *Checking Version Constraints*).
- **Prerelease opt-in in ranges:** `Constraints.IncludePrerelease` forces
  prereleases into results; otherwise "`>=1.2.3` will skip pre-releases" and
  "`>=1.2.3-0` will evaluate and find pre-releases" — the `-0` idiom
  (Masterminds README, *Working With Prerelease Versions*).
- **ASCII ordering caveat is documented:** sorting is ASCII, so `A-Z` precedes
  `a-z`, hence `>=1.2.3-BETA` returns `1.2.3-alpha` (Masterminds README).
- **Range grammar (npm/Cargo-style):** basic comparators `= != > < >= <=`;
  AND by space/comma, OR by `||`; hyphen ranges `1.2 - 1.4.5`; wildcards
  `x`/`X`/`*`; tilde `~` and caret `^` with version-zero-sensitive rules
  (`^0.2.3` → `>=0.2.3 <0.3.0`, `^0.0.3` → `>=0.0.3 <0.0.4`) (Masterminds README,
  *Basic Comparisons*, *Hyphen Range*, *Wildcards*, *Tilde*, *Caret*).
  SemVer itself defines no ranges (semver.org; npm README).
- hashicorp's `Constraint.Prerelease()` reports "true if the version underlying
  this constraint contains a prerelease field" (pkg.go.dev) — an explicit,
  minimal prerelease signal.

## 10. Interesting design decisions

- **A pure string API for the common case** (`x/mod/semver`): no allocation of a
  struct type, comparison is a function over `string`, and `Canonical` is the
  normaliser (pkg.go.dev). The go tool ecosystem leans on this for module paths.
- **Documented deviation from the spec:** requiring `v` and accepting
  `vMAJOR`/`vMAJOR.MINOR` shorthand is called out as the two exceptions
  (pkg.go.dev, *Overview*) — the API is honest about being "SemVer-ish".
- **Strict vs coercing parsers side by side** (`StrictNewVersion` vs
  `NewVersion`; `NewSemver` vs `NewVersion`) with a package-level switch
  `CoerceNewVersion` and `DetailedNewVersionErrors` (pkg.go.dev; README).
- **Comparison and ranges are separate concepts with separate semantics**, and
  the separation is explicitly documented rather than hidden (Masterminds README).
- **`Validate` returns human-readable failure reasons** instead of a bare bool
  (Masterminds README, *Validation*).
- **Input-length caps as exported constants** (`MaxVersionLen`, `MaxConstraintLen`,
  `MaxConstraintGroups`) bound the parse (pkg.go.dev).
- **Original-text retention** (`Original()`) preserves the input when coercion
  changed it (pkg.go.dev) — important for lockfiles that must not be rewritten.
- **Prefix stripping as an opt-in `Option`** (`WithPrefix`) handles
  K8s/release-tag prefixes without polluting the version model (hashicorp
  README).
- **Canonicalisation on `String()`** is deliberate and documented (`1.0` →
  `1.0.0`, `v1.0.0` → `1.0.0`) (hashicorp pkg.go.dev, `String`).

## 11. Decisions NOT to copy

- **String-only representation** (`x/mod/semver`) re-parses on every call and
  gives no place to attach validation state; a typed value is better for a Mojo
  library that wants predictable errors (Assessment: derived from §3/§7).
- **Requiring `v`** contradicts semver.org, which says `v1.2.3` "is not a
  semantic version" (semver.org FAQ; pkg.go.dev, `x/mod/semver` Overview). A
  general SemVer library must not bake that in.
- **Silent coercion by default** (`CoerceNewVersion = true`, `clean`, truncating
  coercion "reads from the start, ignores trailing text") makes invalid input
  succeed quietly (pkg.go.dev; README). A new library should default to strict
  and make coercion an explicit, named call.
- **Three overlapping libraries' worth of surface** (coercion, ranges, prefix,
  SQL/JSON, diff) is too much for a first, low-vision-friendly API
  (Assessment: derived from §3).
- **Panicking `Must*` helpers** are convenient but turn a data error into a
  crash; in Mojo a `raises` contract is cleaner (pkg.go.dev;
  mojov1 buch, `mojov1/appendix/cheat-sheet` — typed raising).
- **Conflating invalid with "lower"** (`x/mod/semver.Compare`; and the C
  library's `-1`, `c.md` §4) must not be copied: parse failure must be
  distinguishable from ordering.
- **Canonicalisation silently dropping build metadata** (`Canonical` "discards
  build metadata", pkg.go.dev) loses information; a round-trip-preserving design
  is preferable.

## 12. Ideas fitting Mojo

- **Typed `Version` first, string helpers second** (the opposite of
  `x/mod/semver`): parse once into a value and compare values (semver.org item 11;
  mojov1 buch, `mojov1/types/overview` — value semantics).
- **Strict `parse` (raising) + explicit `coerce` + `try_parse`**, mirroring the
  strict/coercing split but with one error channel (mojov1 buch,
  `mojov1/appendix/cheat-sheet` — `raises` / optionals).
- **`compare` and range-matching as distinct operations with documented
  different prerelease rules** — the clearest lesson from Masterminds
  (Masterminds README, *Checking Version Constraints*).
- **An `IncludePrerelease`-style explicit policy and the `-0` idiom** for
  opting into prereleases in ranges (Masterminds README; npm README).
- **Retain the original input** for round-tripping and lockfiles, alongside the
  canonical form (pkg.go.dev, `Original`).
- **Exported input-length limits** as design constants against unbounded input
  (pkg.go.dev, `MaxVersionLen`; contrast `cpp.md` §10).
- **`Validate`-style structured failure reasons** rather than a bare bool
  (Masterminds README, *Validation*).
- **`comptime` validation of literal versions** analogous to `Must*` but at
  compile time, so bad constants never reach runtime (pkg.go.dev, `MustParse`;
  mojov1 buch, `mojov1/appendix/cheat-sheet` — `comptime`).

## Sources

- <https://semver.org/> — SemVer 2.0.0 spec (items 2, 9, 10, 11; `v` FAQ).
- <https://pkg.go.dev/go/version> — Go stdlib `go/version`: `Compare`, `IsValid`,
  `Lang`; Go toolchain syntax (contrast, not SemVer).
- <https://pkg.go.dev/golang.org/x/mod/semver> — string-only SemVer: `IsValid`,
  `Canonical`, `Compare`, `Major`, `MajorMinor`, `Prerelease`, `Build`, `Sort`,
  `ByVersion`, `Max` (deprecated); requires `v`, accepts shorthands.
- <https://pkg.go.dev/github.com/Masterminds/semver/v3> — `Version`,
  `NewVersion`/`StrictNewVersion`/`MustParse`, compare/inc/set methods,
  `Constraints`/`NewConstraint`/`Check`/`Validate`, `MaxVersionLen`/`MaxConstraintLen`/
  `MaxConstraintGroups`, error vars, `CoerceNewVersion`.
- <https://github.com/Masterminds/semver> — README: parsing/coercion, prerelease
  comparison vs constraint rules, hyphen/wildcard/tilde/caret ranges, `-0`,
  validation reasons, ASCII caveat.
- <https://pkg.go.dev/github.com/hashicorp/go-version> — `NewVersion`/`NewSemver`,
  `Compare`, `Segments`/`Segments64`, `Core`, `Original`, `Prefix`, `WithPrefix`,
  `String` canonicalisation, `Constraint`s.
- <https://docs.npmjs.com/cli/v10/using-npm/semver> — npm range syntax and
  prerelease range policy (cross-language evidence).
