# build_versioning — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected
end state.

## Constraint ranges

- `Range` / `VersionReq` — a parsed, reusable constraint value. (origin:
  `rust.md` §3, `elixir.md` §9)
- `satisfies` — does a version satisfy a parsed range. (origin: `js-ts.md` §3,
  `elixir.md` §3)
- `Comparator` — one operator plus a partial version. (origin: `rust.md` §3)
- `Op` — the comparator operator enum (`=`, `!=`, `<`, `<=`, `>`, `>=`).
  (origin: `rust.md` §3, `kotlin.md` §3)
- `!=` inequality comparator. (origin: `kotlin.md` §3)
- `min_version` — the lowest version a range allows. (origin: `cpp.md` §10)
- `intersects` / `subset` — range algebra. (origin: `cpp.md` §3, `js-ts.md` §3)
- `simplify_range` — reduce a range to a canonical comparator set. (origin:
  `js-ts.md` §3)
- Range formatting / round-trip of a parsed range. (origin: `elixir.md` §11)

## Range sugar and dialects

- Caret `^` ranges with version-zero-sensitive bounds. (origin: `js-ts.md` §9,
  `cpp.md` §9)
- Tilde `~` ranges. (origin: `js-ts.md` §9)
- Hyphen ranges `1.2.3 - 2.3.4`. (origin: `js-ts.md` §9)
- X-ranges / wildcards `1.2.x`, `1.X`, `*`. (origin: `js-ts.md` §9)
- `||` OR of comparator sets. (origin: `js-ts.md` §9)
- Elixir `~>` pessimistic operator. (origin: `elixir.md` §9)
- PEP 440 `~=` compatible-release operator. (origin: `python.md` §9)
- PEP 440 `===` arbitrary-equality escape hatch. (origin: `python.md` §9)
- Maven bracket ranges `[1.0,2.0)`, `(,1.0]`. (origin: `java.md` §9,
  `kotlin.md` §9)
- Pluggable constraint dialect parsers. (origin: `java.md` §10,
  `kotlin.md` §10)

## Prerelease policy in matching

- `include_prerelease` — explicit opt-in flag for range matching. (origin:
  `js-ts.md` §12, `cpp.md` §9)
- `match_stable` — range match that excludes prereleases. (origin: `elixir.md`
  §12)
- The `-0` sentinel upper-bound idiom. (origin: `cpp.md` §9, `js-ts.md` §9)

## Build metadata and ordering

- `compare_with_build` / `compare_build` — total order including build
  metadata. (origin: `cpp.md` §10, `rust.md` §10, `js-ts.md` §10)
- `same_build` — explicit build-metadata equality. (origin: `js-ts.md` §11)
- `without_build` / `without_prerelease` — strip qualifiers. (origin:
  `cpp.md` §3)
- `has_build_metadata` / `is_prerelease` predicates. (origin: `cpp.md` §3)
- Build-metadata accessor as identifiers, not only a joined string. (origin:
  `elixir.md` §9)

## Sorting and selection

- `sort` / `sort_by_precedence` — order a sequence of versions. (origin:
  `js-ts.md` §3, `go.md` §3)

## Diff and increment

- `diff` / `VersionDiff` — the kind of change between two versions. (origin:
  `java.md` §10, `cpp.md` §10)
- `increment` / `bump_major` / `bump_minor` / `bump_patch`. (origin: `c.md`
  §3, `cpp.md` §3)
- `next_major` / `next_minor` / `next_patch`. (origin: `kotlin.md` §3)
- `truncate` — drop components lower than a release type. (origin: `js-ts.md`
  §3)
- `set_prerelease` / `set_build` — value-returning qualifier updates. (origin:
  `go.md` §3)
- Functional update family (`with_major`, `with_prerelease`). (origin:
  `kotlin.md` §12)

## Normalization and loose parsing

- `canonical` — canonical string form. (origin: `go.md` §3)
- `clean` — trim outer whitespace, `=` and `v` to a valid version. (origin:
  `js-ts.md` §3, `cpp.md` §3)
- `coerce` — extract a version from arbitrary text. (origin: `js-ts.md` §3,
  `go.md` §10)
- `try_parse` — non-raising parse returning an optional. (origin: `c.md` §12,
  `cpp.md` §12, `go.md` §12)
- `parse_lenient` — accept partial and `v`-prefixed input. (origin: `kotlin.md`
  §12)
- `original` — retain the input text for round-tripping. (origin: `go.md` §10)

## Partial versions and prefixes

- Partial-version parsing (`1`, `1.2`). (origin: `go.md` §7, `c.md` §7)
- `v`-prefix stripping as a separate opt-in. (origin: `js-ts.md` §7,
  `python.md` §7)
- Custom release prefix (`WithPrefix`, e.g. `deployment-`). (origin: `go.md`
  §7)

## Alternative version schemes

- PEP 440 epoch `N!`. (origin: `python.md` §7, §11)
- PEP 440 post-release `.postN`. (origin: `python.md` §7)
- PEP 440 dev release `.devN`. (origin: `python.md` §7)
- PEP 440 local version `+label` with a defined order. (origin: `python.md`
  §7)
- PEP 440 variable-length release (`1.1` equals `1.1.0`). (origin: `python.md`
  §7)
- Maven null-padding and trailing-null trimming. (origin: `java.md` §7)
- Maven case-insensitive qualifier comparison. (origin: `java.md` §7)
- Maven separator / digit-transition token model. (origin: `java.md` §10)
- CalVer tolerance via leading-zero coercion. (origin: `go.md` §7)

## Structured validation and limits

- `validate` — satisfiability with structured, human-readable failure reasons.
  (origin: `go.md` §10)
- Distinct overflow error variant. (origin: `zig.md` §10, `elixir.md` §10)
- Exported input-length limits (`MaxVersionLen`-style). (origin: `go.md` §8,
  `cpp.md` §10)
- `check` — bool-only constraint check. (origin: `go.md` §3)

## Convenience predicates and accessors

- `is_stable` — major > 0 and no prerelease. (origin: `java.md` §12,
  `kotlin.md` §12)
- `is_at_least` — three-valued compatibility query (`Optional[Bool]`). (origin:
  `zig.md` §12)
- `segments` / `core` — component-list and core-only accessors. (origin: `go.md`
  §3)
- `from_parts` — component constructor without a string. (origin: `python.md`
  §3, `java.md` §12)
- `semver_numeric` — lossy packed integer ordering key. (origin: `c.md` §3,
  §11)

## Serialization and interop

- JSON / text marshal and unmarshal. (origin: `rust.md` §10, `go.md` §3)
- Hash / total-order trait for use as a container key. (origin: `rust.md` §3)
- SQL `Scanner`/`Valuer`-style integration. (origin: `go.md` §3)

## Compile-time and component generic

- `comptime`-validated literal versions. (origin: `cpp.md` §10, `rust.md` §12)
- `comptime`-known constraint literals. (origin: `js-ts.md` §12, `kotlin.md`
  §12)
- Compile-time version constant for build gates. (origin: `zig.md` §12)
- Const-generic component widths (`version<I1,I2,I3>`). (origin: `cpp.md` §10,
  §12)
