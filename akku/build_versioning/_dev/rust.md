# build_versioning research: Rust

## 1. Standard library support

- **The Rust standard library has no SemVer type.** There is no `std::version`
  module and no parse/compare function; `semver` lives in the Cargo ecosystem as
  a separate crate (Assessment: derived from the crate's own docs.rs page and
  the absence of such items in `std`).
- The relevant stdlib pieces are generic: `str::parse`/`FromStr`,
  `u64::from_str_radix`-style integer parsing, `Option`/`Result`/`Ordering`,
  iterator/slice sorting (`slice::sort_by`), and derived traits (`Clone, Debug,
  Eq, Hash, Ord`). None of them understands versions.
- **`semver` the crate is Cargo's SemVer implementation, not the language's.**
  "A parser and evaluator for Cargo's flavor of Semantic Versioning"; "The
  `semver` crate is specifically intended to implement Cargo's interpretation of
  Semantic Versioning. Where the various tools differ in their interpretation or
  implementation of the spec, this crate follows the implementation choices made
  by Cargo." (docs.rs, `semver` crate page, *Scope of this crate*).
- SemVer 2.0.0 itself is the external spec (semver.org); the crate cites it
  directly ("SemVer version as defined by https://semver.org", `Version` docs).

## 2. Relevant community libraries

- **`semver` (dtolnay)** — the dominant crate: 1.0.28, MIT OR Apache-2.0,
  dependencies only on optional `serde`, owned by `dtolnay` (docs.rs crate
  page). It is vendored into the Rust toolchain for Cargo, which makes it the
  de-facto standard.
- **`semver-parser`** — older, lower-level parser crate used by earlier
  `semver` versions and by `cargo` historically; not fetched in this run.
  `GUESS:` it exposes a `Version`/parse API and is now largely superseded by the
  `semver` crate. Reason no source: not fetched.
- **`version-compare`** — general version-type comparison (not SemVer-specific);
  not fetched. `GUESS:` no claims made.
- Because Cargo requires a version for every dependency, the `semver` crate is
  effectively part of the Rust build story even though it is not in `std`
  (Assessment: derived from the crate page and Cargo's dependency format).

## 3. Exposed APIs

From the `semver` crate (docs.rs):

- **`Version`** — `pub struct Version { pub major: u64, pub minor: u64,
  pub patch: u64, pub pre: Prerelease, pub build: BuildMetadata }`
  (`Version` docs). Associated: `Version::new(major, minor, patch) -> Self`
  (empty pre/build), `Version::parse(text: &str) -> Result<Self, Error>`;
  method `cmp_precedence(&self, other: &Self) -> Ordering` (ignores build).
  Traits: `Clone, Debug, Display, Eq, Ord, PartialEq, PartialOrd, Hash, FromStr`,
  optional `Serialize`/`Deserialize` (docs).
- **`Prerelease`** — opaque `struct Prerelease { /* private */ }`;
  `Prerelease::new(text: &str) -> Result<Self, Error>`, `Prerelease::EMPTY`,
  `as_str() -> &str`, `is_empty() -> bool`, `Deref<Target = str>`; traits
  `Ord/PartialOrd/Eq/Hash/Display/FromStr` (`Prerelease` docs).
- **`BuildMetadata`** — same shape for build metadata (crate page structs list).
- **`VersionReq`** — `pub struct VersionReq { pub comparators: Vec<Comparator> }`;
  `VersionReq::parse(&str) -> Result<Self, Error>`, `matches(&self,
  &Version) -> bool`, associated `VersionReq::STAR`, `Default`, `FromStr`,
  `Display` (`VersionReq` docs).
- **`Comparator`** — "a pair of comparison operator and partial version, such as
  `>=1.2`" (crate page).
- **`Op`** — `enum Op` = `=`, `>`, `>=`, `<`, `<=`, `~`, `^`, `*` (crate page,
  *Enums*).
- **`Error`** — parse error type for versions and requirements (crate page).

## 4. Error representation

- **`Result<T, Error>` is the only error channel; no panics and no sentinels.**
  `Version::parse` and `VersionReq::parse` return `Result<Self, semver::Error>`
  (docs.rs).
- **Parse failures are enumerated and specific.** Documented causes:
  `1.0` (too few components), `1.0.01` (leading zero), `1.0.unknown`
  (unexpected character), `1.0.0-`/`1.0.0+` (qualifier present but empty),
  `1.0.0-alpha_123` (character outside `0-9A-Za-z-.`), and
  `23456789999999999999.0.0` (u64 overflow) (`Version::parse` docs, *Errors*).
- **`VersionReq::parse` errors** include `>a.b` (unexpected characters), `@1.0.0`
  (unrecognised operator), `^1.0.0,` (unexpected end), `>=1.0 <2.0` (missing
  comma between comparators), `*.*` (unsupported wildcard) — i.e. the grammar is
  strict and comma-delimited (`VersionReq` docs, *Errors*).
- **Invalid versions have no "compare" answer**, because you cannot construct an
  invalid `Version` at all: the newtypes enforce the invariant at construction
  (Assessment: derived from `Prerelease::new -> Result` and private fields).

## 5. Ownership semantics

*Adapted for versioning (see `_dev/README.md`): whether parsing is in-place or
value-returning, and who owns the parsed value/string.*

- **Fully owned values; parsing allocates and returns a new `Version`.**
  `Version::parse(&str) -> Result<Version, Error>` borrows the input only for the
  duration of the call and returns an owned value (`Version` docs). There is no
  out-parameter and no in-place mutation.
- **The qualifier fields are owned by the version.** `pre: Prerelease` and
  `build: BuildMetadata` are not borrowed slices; `Prerelease` derefs to `str`
  but owns its contents (private fields, `Deref<Target = str>`; `Prerelease`
  docs). So a `Version` is self-contained and the input `&str` can be dropped
  immediately.
- **`Version` is `Clone` and cheaply movable.** All traits are derived; there is
  no `Rc`/`Arc` sharing requirement, so copies are independent (docs.rs).
- **`VersionReq` owns a `Vec<Comparator>`** of owned partial versions; the
  requirement is likewise self-contained (`VersionReq` docs).
- **`matches(&self, version: &Version)` borrows both**, so constraint checking
  does not consume or copy either operand (`VersionReq` docs).

## 6. Blocking / non-blocking

- **Not applicable: pure computation.** No I/O, no blocking, no async model
  anywhere in the crate (docs.rs; §1).
- **Immutable values → safe concurrent sharing.** `Version` and `VersionReq`
  expose only `&self` query methods (`cmp_precedence`, `matches`, the trait
  impls); auto traits include `Send`, `Sync`, `Unpin` (docs.rs, *Auto Trait
  Implementations*). Shared references are therefore safe across threads without
  locks (Assessment: derived from the `&self` signatures plus `Sync`).
- No cancellation or timeout concept exists (Assessment: derived from the pure
  signatures).

## 7. IPv4 / IPv6

*Adapted for versioning (see `_dev/README.md`): how the spec/version identity is
modelled and whether one abstraction covers it all.*

- **Identity model: three `u64` fields + two validated newtype qualifiers.**
  `Version { major, minor, patch, pre, build }`; the numbers "may be any integer
  0 through `u64::MAX`", written base-10, leading zeros forbidden
  (`Version` docs, *Syntax*).
- **Two type-level abstractions cover the whole spec:** `Version` for a concrete
  version and `VersionReq` for a requirement. `VersionReq` is "the intersection
  of some version comparators"; either `*` or comma-separated comparators of an
  `Op` and a *partial* version (`VersionReq` docs, *Syntax*).
- **Partial versions exist only inside requirements.** `Comparator` holds a
  partial version (`>=1.2`), while `Version` requires exactly three numeric
  components (`VersionReq` docs; `Version::parse` rejects `1.0`).
- **No `v` prefix:** the crate parses strict SemVer; `v1.2.3` is not a semantic
  version (semver.org FAQ). No stripping/coercion API is documented (Assessment:
  derived from the `Version::parse` grammar and the absence of a `clean`/`coerce`
  item in the crate page).
- **Build metadata is modelled, not discarded:** kept in `build: BuildMetadata`
  for round-tripping, but excluded from precedence (semver.org item 10;
  `cmp_precedence` docs: "disregarding build metadata").
- **No single abstraction is overloaded.** Version identity (`Version`),
  requirements (`VersionReq`), one comparison primitive (`Comparator` + `Op`),
  and one precedence operation (`cmp_precedence`) are separate types
  (docs.rs, *Structs*/*Enums*).

## 8. Timeouts

- **Not applicable.** Parsing/comparison have no blocking operation and no
  deadline; the only resource bound is the input string length (Assessment:
  derived from the pure signatures; no length constant is documented in the
  crate).
- The related concern — unbounded input — is left to the caller here, unlike Go's
  exported `MaxVersionLen = 256` (`go.md` §3/§8). `GUESS:` the crate relies on
  `&str` already being in memory and on u64 overflow checks; no fetched source
  documents a length cap.
- No cancellation or scheduler interaction exists (Assessment).

## 9. TLS

*Adapted for versioning (see `_dev/README.md`): how prerelease/build metadata and
constraint ranges are handled.*

- **Prerelease precedence is total and specified.** `Prerelease` docs give the
  ordering and examples: `alpha < alpha.1 < alpha.beta < beta < beta.2 <
  beta.11 < rc.1 < 1.0.0`; numeric identifiers compared numerically
  (`pre.8 < pre.12`), letter/hyphen identifiers in ASCII order
  (`pre12 < pre8`), numeric always less than non-numeric (`pre.1 < pre.x`)
  (semver.org item 11; `Prerelease` docs, *Total ordering*).
- **Build metadata is stored but excluded from precedence.** `cmp_precedence`
  "disregards build metadata"; versions differing only in build are considered
  equal *for precedence* (`Version::cmp_precedence` docs).
- **Important subtlety: `Ord` (total order) is not precedence.** `Version`'s
  `sort()` example totally orders including build metadata
  (`1.20.0 < 1.20.0+bc17664 < 1.20.0+c144a98`) while `cmp_precedence` treats
  those three as equal (`Version` docs, *Total ordering* example). So Rust offers
  *both* a spec-precedence comparison and a total order (Assessment: derived from
  the two documented orders).
- **Requirements (ranges) are not part of SemVer** and the crate implements
  Cargo's dialect: `*`, comparators `= > >= < <= ~ ^`, and partial versions
  (`VersionReq` docs, *Syntax*; `Op` enum). Comparators are comma-separated
  (AND); the error `>=1.0 <2.0` ("missing comma") proves whitespace-AND is *not*
  accepted, unlike npm (`VersionReq` docs, *Errors*).
- **Prerelease-opt-in rule:** `STAR` (`*`) "does not match every possible version
  number. In particular ... in order for any `VersionReq` to match a pre-release
  version, the `VersionReq` must contain at least one `Comparator` that has an
  explicit major, minor, and patch version identical to the pre-release being
  matched, and that has a nonempty pre-release component." (`VersionReq::STAR`
  docs). This is the same rule npm documents (npm README, *Prerelease Tags*) and
  Masterminds notes for Go (`go.md` §9), making it the ecosystem consensus.
- **Cargo caret/tilde semantics** are Cargo's, not the spec's: a bare `1.2.3` is
  treated as `^1.2.3` (Cargo's default), and `^0.2.3` allows `<0.3.0` while
  `^0.0.3` allows `<0.0.4` (`VersionReq` docs; npm README, *Caret Ranges* — same
  rule).

## 10. Interesting design decisions

- **Newtypes enforce invariants by construction.** `Prerelease` and
  `BuildMetadata` have private fields and fallible constructors, so an invalid
  qualifier cannot exist; `Version` can therefore be a plain public-field struct
  while still being always-valid (`Prerelease` docs; crate page structs).
- **Two distinct orderings, both named:** `Ord` (total, includes build) and
  `cmp_precedence` (spec precedence, ignores build). This avoids the
  "equal-but-not-identical" confusion by giving callers an explicit choice
  (`Version` docs).
- **`VersionReq::STAR` is an associated constant and `Default`**, so the
  "any version" requirement is a first-class value, not a parse of `"*"`
  (`VersionReq` docs).
- **Comparators are a typed `Vec<Comparator>` with an `Op` enum**, letting
  callers inspect and construct requirements programmatically rather than only
  parse strings (`VersionReq` docs).
- **A single `Error` type with precise, enumerated causes** keeps the API small
  while the docs spell out each failure mode (`Version`/`VersionReq` *Errors*).
- **Optional `serde` integration** (`Serialize`/`Deserialize`) makes versions
  JSON-serialisable without forcing the dependency (crate page, *Feature flags*).
- **The crate explicitly scopes itself to Cargo's interpretation** rather than
  claiming universal SemVer: "If you are operating on version numbers from some
  other package ecosystem, you will want to use a different semver library"
  (crate page, *Scope of this crate*).
- **u64 components with checked overflow** bound the numeric range explicitly and
  report rather than wrap (`Version` docs, *Errors*: overflow case).

## 11. Decisions NOT to copy

- **Cargo-specific requirement dialect** (comma-AND, bare-version-as-caret) is
  not universal SemVer and differs from npm's whitespace-AND
  (`VersionReq` docs, *Errors*; npm README). A general library should not adopt
  one package manager's grammar as "SemVer ranges"; if ranges are added, say
  which dialect.
- **`Ord` including build metadata while precedence ignores it** is correct but
  subtle; two different orderings on one type invite bugs. A Mojo API should name
  the operations unambiguously (`compare_precedence` vs `compare_total`)
  (Assessment: derived from §9).
- **Bare public fields on `Version`** (`pub major: u64, ...`) allow constructing
  an invalid state only via the *private* newtype fields — that part is safe, but
  a caller can still build `Version { major, minor, patch, .. }` with arbitrary
  numbers. A Mojo type could keep the same guarantee with private fields plus
  constructors (Assessment: derived from `Version` docs).
- **No coercion / no `v`-prefix handling at all** is stricter than most
  ecosystems; copying it wholesale would force every caller with a `v`-prefixed
  tag to pre-strip. A new library should decide the policy explicitly rather than
  silently inheriting Cargo's strictness (Assessment: derived from §7; contrast
  `go.md` §7 where every Go library handles `v` differently).
- **No input-length cap** leaves an unbounded-parse surface that Go and C++
  explicitly guard (`go.md` §3; `cpp.md` §10). Mojo should bound it.
- **`serde` coupling**, optional as it is, shows how much surface a "simple"
  version type can accrue; keep the core small (`cpp.md` §11).
- **`VersionReq`'s `*` not matching prereleases** surprises many users; if Mojo
  ships a `*`/any matcher, the prerelease behaviour must be explicit and
  documented (Assessment: derived from `VersionReq::STAR` docs).

## 12. Ideas fitting Mojo

- **Validated qualifier newtypes** (`Prerelease`/`BuildMetadata`) ensure an
  invalid version cannot exist; map to Mojo structs whose constructors `raise`
  on bad identifiers (mojov1 buch, `mojov1/appendix/cheat-sheet` — typed raising;
  `mojov1/types/overview` — structs and value semantics).
- **`Version` as an owned, self-contained value** with `String` qualifiers and
  `StringSpan` for the parse input, so no input lifetime is retained (mojov1
  buch, `mojov1/types/overview` — `StringSpan`).
- **Two named comparisons:** `compare_precedence` (spec, build ignored) and a
  separate total comparison that includes build metadata (semver.org item 10/11;
  Rust `Version` docs).
- **A typed requirement model** (`VersionReq`-style) with a comparator list and
  an operator enum, plus a first-class `any`/`STAR` value (Rust `VersionReq`
  docs).
- **Prerelease-opt-in matching rule** copied as a documented policy, not an
  accident (Rust `VersionReq::STAR` docs; npm README).
- **`from_str`/`parse`-style single constructor returning `raises`**, replacing
  the `(value, error)` pairs of Go and the out-params of C
  (mojov1 buch, `mojov1/appendix/cheat-sheet`).
- **`comptime` literal versions** with compile-time validation, paralleling the
  C++ `consteval` literal and Rust's zero-cost value model (reference,
  `cpp.md` §12; mojov1 buch, `mojov1/appendix/cheat-sheet` — `comptime`).
- **Explicit u64 component width with overflow checking** (Rust `u64`; contrasts
  the 32-bit `int` trap in `c.md` §11).

## Sources

- <https://semver.org/> — SemVer 2.0.0 spec (items 2, 9, 10, 11; `v` FAQ).
- <https://docs.rs/semver/latest/semver/> — crate page: Cargo flavour, scope,
  structs (`Version`, `VersionReq`, `Prerelease`, `BuildMetadata`, `Comparator`,
  `Error`), enums (`Op`).
- <https://docs.rs/semver/latest/semver/struct.Version.html> — fields, `new`,
  `parse` + error list, `cmp_precedence`, total ordering, traits, auto traits.
- <https://docs.rs/semver/latest/semver/struct.Prerelease.html> — syntax, total
  ordering, `new`/`as_str`/`is_empty`, `Deref<Target = str>`.
- <https://docs.rs/semver/latest/semver/struct.VersionReq.html> — syntax
  (comparators, commas), `parse` errors, `STAR` prerelease rule, `matches`.
- <https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html> —
  Cargo requirement syntax and the caret default (referenced by the crate as the
  extent of Cargo's SemVer support).
- <https://docs.npmjs.com/cli/v10/using-npm/semver> — cross-ecosystem
  comparator/caret/prerelease rules.
