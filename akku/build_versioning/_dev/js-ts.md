# build_versioning research: js-ts

Scope: semantic-version parsing, comparison and range/constraint matching in
JavaScript/TypeScript. The de-facto reference is the `semver` npm package
(`npm/node-semver`), which is the canonical JS implementation of SemVer
2.0.0; JavaScript itself has no stdlib version API. Questions follow the
workflow order; Q5, Q7 and Q9 are the domain-adapted ones from
`_dev/README.md`. The mandatory spec source is SemVer 2.0.0
(<https://semver.org/>).

## 1. Standard library support

**JavaScript/TypeScript have no standard-library SemVer API** — neither the
ECMAScript language nor `Intl`/`Number`/`String` provides a version type or
comparison. Version handling is entirely a package-ecosystem concern.

- `Intl` provides locale-aware number and collation, but no semantic version
  parsing or ordering. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl>.
  (Assessment: derived from the documented `Intl` namespace, which contains no
  version API.)
- The nearest stdlib primitive is `String.prototype.localeCompare`, which
  compares strings, not versions — e.g. it would order `1.10.0` before
  `1.9.0` in a naive ASCII comparison. Source:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/localeCompare>.
- Node.js exposes `process.versions` as a plain object of dependency version
  strings; it does not parse or compare them. Source:
  <https://nodejs.org/api/process.html#processversions>.
- npm itself embeds the `semver` package as its range engine; the package is
  the ecosystem's reference, not the runtime. Source:
  <https://github.com/npm/node-semver>.

## 2. Relevant community libraries

- **`semver` (`npm/node-semver`, maintained by npm / Isaac Z. Schlueter,
  MIT license)** — a JavaScript implementation of the semver.org 2.0.0
  specification; ships both a Node module API and a CLI. Source:
  <https://github.com/npm/node-semver>. This is the reference the whole JS
  ecosystem uses (npm, yarn, pnpm all depend on it).
- **`@types/semver` (DefinitelyTyped)** — TypeScript type declarations for
  `semver`, separately maintained. Source:
  <https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/semver>.
- **`compare-versions` (community, MIT)** — a small, dependency-free
  alternative that compares version strings and supports a subset of range
  operators. Source: <https://github.com/omichelsen/compare-versions>.
- **`semver-compare`** — minimal lexical tuple comparison, intentionally not
  spec-complete. Source: <https://github.com/substack/semver-compare>.

(Assessment: despite the alternatives, `npm/node-semver` is the only one that
tracks the semver.org spec and range grammar in full, and the only one an agent
should treat as authoritative.)

## 3. Exposed APIs

`npm/node-semver` exposes three layers, all documented in one README:

**Version functions** (source: <https://github.com/npm/node-semver#functions>):

| API | Purpose |
| --- | --- |
| `valid(v)` | Return the parsed version string, or `null`. |
| `parse(v)` | Return a `SemVer` object or `null`. |
| `clean(v)` | Trim/normalize a string to a valid semver, or `null`. |
| `inc(v, release, ...)` | Increment by `major`/`minor`/`patch`/`pre*`/`release`. |
| `prerelease(v)` | Array of prerelease components, or `null`. |
| `major(v)` / `minor(v)` / `patch(v)` | Component accessors. |
| `truncate(v, releaseType)` | Drop components lower than `releaseType`. |
| `coerce(v, options)` | Forgiving extraction of a semver from arbitrary text. |
| `diff(v1, v2)` | Most significant difference type, or `null`. |
| `compare(v1, v2)` | `-1` / `0` / `1`. |
| `rcompare(v1, v2)` | Reverse compare. |
| `compareBuild(v1, v2)` | Like `compare` but also orders build metadata. |
| `compareLoose(v1, v2)` | `compare(..., { loose: true })`. |
| `sort(versions)` / `rsort(versions)` | Sort by `compareBuild`. |
| `gt`, `gte`, `lt`, `lte`, `eq`, `neq`, `cmp` | Boolean comparison shorthands. |

**Range functions** (source: <https://github.com/npm/node-semver#ranges>):
`validRange`, `satisfies`, `maxSatisfying`, `minSatisfying`, `minVersion`,
`gtr`, `ltr`, `outside`, `intersects`, `simplifyRange`, `subset`.

**Classes** importable standalone: `SemVer`, `Comparator`, `Range` (e.g.
`require('semver/classes/range')`), plus one module per function
(`semver/functions/*`, `semver/ranges/*`). Source:
<https://github.com/npm/node-semver#exported-modules>.

**Constants**: `RELEASE_TYPES` and `SEMVER_SPEC_VERSION` (= `2.0.0`). Source:
<https://github.com/npm/node-semver#constants>.

The documented version rule: "A leading `=` or `v` character is stripped off
and ignored." Source: <https://github.com/npm/node-semver#versions>.

## 4. Error representation

`npm/node-semver` deliberately avoids exceptions: the primary parse entry
points return **`null`** on invalid input rather than throwing.

- `semver.valid('a.b.c') // null`; `semver.parse('invalid')` returns `null`.
  Source: <https://github.com/npm/node-semver#usage>.
- `cmp` "Throws if an invalid comparison string is provided." Source:
  <https://github.com/npm/node-semver#comparison>. So invalid *operator*
  input is the one exception path.
- `coerce()` returns a semver or `null` ("Only text which lacks digits will
  fail coercion"). Source: <https://github.com/npm/node-semver#coercion>.
- Invalid comparators inside a range make the range fail to parse, and
  `validRange` then returns `null`. Source:
  <https://github.com/npm/node-semver#ranges>.

(Assessment: `null`-on-invalid is a JS-idiomatic sentinel; it does not carry a
reason, which is the main drawback versus a typed error.)

## 5. Ownership semantics (adapted: value-returning vs. in-place)

Parsing is **value-returning**; there is no caller-supplied output buffer:

- `parse(v)` returns a new `SemVer` object (or `null`); `valid(v)` returns the
  normalized string. Source: <https://github.com/npm/node-semver#functions>.
- The `SemVer` instance owns its component fields (`major`, `minor`, `patch`,
  `prerelease`, `build`) and a cached `version` string. Source:
  <https://github.com/npm/node-semver/blob/main/classes/semver.js>.
- Strings are immutable and GC-managed; the input string is not mutated. There
  is no explicit free.
- `semver/functions/parse` and friends are exposed as separate modules, so a
  consumer can load only what it uses — a bundle-size ownership decision, not a
  memory-ownership one. Source:
  <https://github.com/npm/node-semver#exported-modules>.

(Assessment: JS has no borrow/move distinction; ownership maps cleanly onto a
Mojo value type that owns its component arrays and borrows only the parse
input.)

## 6. Blocking / non-blocking

Not applicable. Parsing, comparison and range matching are pure, synchronous,
CPU-only transformations; no I/O, promises, timers or async primitives appear
anywhere in the API. The npm registry's async work happens in the *client*
(`npm`/`pacote`), not in `semver` itself. Source:
<https://github.com/npm/node-semver#usage>. (Assessment: derived from the
absence of any async surface in the documented API.)

## 7. Version-identity model (adapted: how the spec / version identity is modelled)

`npm/node-semver` models exactly the SemVer 2.0.0 identity and encodes it as
token regexes (`internal/re.js`):

- **Numeric identifier** — `0|[1-9]\d*` (no leading zeroes). Source:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>.
- **Non-numeric identifier** — `\d*[a-zA-Z-][a-zA-Z0-9-]*`. Source: same file.
- **Main version** — three dot-separated numeric identifiers. Source: same
  file.
- **Prerelease identifier** — non-numeric identifier first, then numeric
  identifier (order matters, because non-numeric can be longer). Source: same
  file.
- **Prerelease** — hyphen followed by dot-separated identifiers. Source: same
  file.
- **Build metadata** — plus sign followed by dot-separated `[a-zA-Z0-9-]+`
  identifiers. Source: same file.

Two identity details encoded in the regexes:

- **`v` prefix.** `FULLPLAIN` is `v?${MAINVERSION}...` — a single leading `v`
  is accepted and stripped; the README states this is "kept for compatibility
  with `v1.0.0` of the SemVer specification but should not be used anymore".
  Sources: <https://github.com/npm/node-semver/blob/main/internal/re.js>,
  <https://github.com/npm/node-semver#versions>. Under semver.org 2.0.0 the
  `v` is not part of the version (FAQ). Source:
  <https://semver.org/#is-v123-a-semantic-version>.
- **Build is non-capturing.** The comment in `re.js` states the build metadata
  "is not a capturing group, because it should not ever be used in version
  comparison" — a direct implementation of SemVer clause 10. Source:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>.

**Can one abstraction cover everything?** For the SemVer 2.0.0 spec, yes: a
single `SemVer` struct with `major`, `minor`, `patch`, an identifier list for
prerelease, and a string for build describes the whole grammar. The two
escapes from strict identity are separate, opt-in features: `loose` mode
(accept `1.0.0alpha1`, `=1.2.3`) and `coerce` (extract a version from arbitrary
text). Sources: <https://github.com/npm/node-semver#functions>,
<https://github.com/npm/node-semver/blob/main/internal/re.js>. A Mojo library
should model the strict struct as the core and make loose/coerce explicitly
separate operations.

## 8. Timeouts

Not applicable to a version library: matching is a bounded computation over
parsed values. (Assessment: derived from the pure, synchronous API surface.)
Note one adjacent concern that is real but out of scope: node-semver protects
itself against **regular-expression denial of service** by rewriting greedy
regex tokens into bounded repetitions (`makeSafeRegex`, e.g. `\s*` →
`\s{0,1}`, `\d*` → `\d{0,MAX_LENGTH}`, `[a-zA-Z0-9-]*` →
`…{0,MAX_SAFE_BUILD_LENGTH}`) and by normalizing inputs first. Source:
<https://github.com/npm/node-semver/blob/main/internal/re.js>. That is a
complexity/DoS bound, not a timeout.

## 9. Prerelease / build metadata + constraint ranges (adapted)

**Default prerelease policy** (the single most distinctive JS decision):

> If a version has a prerelease tag (for example, `1.2.3-alpha.3`) then it will
> only be allowed to satisfy comparator sets if at least one comparator with
> the same `[major, minor, patch]` tuple also has a prerelease tag.

Source: <https://github.com/npm/node-semver#prerelease-tags>. Passing
`includePrerelease: true` suppresses this and treats prereleases as normal
versions. Source: same reference. The rationale given is twofold: prereleases
change fast and may break, and a user who opted into one prerelease has not
opted into the next set. Source: same reference.

**Comparator grammar:**

- Primitives: `<`, `<=`, `>`, `>=`, `=` (equality is default when omitted).
  Source: <https://github.com/npm/node-semver#ranges>.
- A **comparator set** is comparators joined by whitespace; satisfied by their
  **intersection**. Ranges are comparator sets joined by `||`; satisfied if
  **any** set is satisfied. Source: same reference.
- `>1` desugars to `>=2.0.0`. Source: same reference.

**Advanced range syntax** (source: <https://github.com/npm/node-semver#advanced-range-syntax>):

| Form | Meaning |
| --- | --- |
| Hyphen `1.2.3 - 2.3.4` | inclusive `>=1.2.3 <=2.3.4`. |
| X-range `1.2.x`, `1.X`, `1.2.*`, `*` | wildcard on numeric tuple parts. |
| Tilde `~1.2.3` | `>=1.2.3 <1.3.0-0`; `~1.2` same; `~1` → `<2.0.0-0`. |
| Caret `^1.2.3` | `>=1.2.3 <2.0.0-0`; `^0.2.3` → `<0.3.0-0`; `^0.0.3` → `<0.0.4-0`. |

A missing patch/minor in caret ranges desugars to `0` but keeps flexibility
within that value (e.g. `^0.0.x` → `>=0.0.0 <0.1.0-0`). Source: same reference.

**Build metadata in ranges** is accepted in the grammar qualifier
(`( '-' pre )? ( '+' build )?`) but, per clause 10, ignored for precedence.
Sources: <https://github.com/npm/node-semver#range-grammar>,
<https://semver.org/#spec-item-10>. The README gives the BNF for ranges in
full. Source: <https://github.com/npm/node-semver#range-grammar>.

## 10. Interesting design decisions

- **`null`-on-invalid, not exceptions.** Keeps control flow explicit and lets
  callers distinguish "not a version" from a programming error; `cmp` is the
  documented exception that throws on a bad operator. Source:
  <https://github.com/npm/node-semver#functions>.
- **Layering: parse → compare → range.** `SemVer`/`Comparator`/`Range` classes
  underpin the flat function API, so both use styles are available and the
  flat API is built from the classes. Source:
  <https://github.com/npm/node-semver#exported-modules>.
- **Prerelease opt-in via the version's own tuple.** Rather than a global
  switch, the default policy ties prerelease admission to whether the range
  mentions that exact `[major,minor,patch]`. This is subtle but preserves
  SemVer's "prerelease has lower precedence" while avoiding surprise upgrades.
  Source: <https://github.com/npm/node-semver#prerelease-tags>.
- **`compareBuild` as a separate function.** The spec says build metadata is
  ignored for precedence, but tools sometimes want a deterministic tie-break;
  node-semver offers it as a distinct function and uses it for `sort`.
  Sources: <https://github.com/npm/node-semver#comparison>,
  <https://semver.org/#spec-item-10>.
- **Regex-DoS hardening.** Bounded repetition rewrite plus input normalization
  before matching. Source:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>.
- **Coercion as a first-class, documented fallback.** `coerce('v2') → '2.0.0'`,
  `coerce('42.6.7.9.3-alpha') → '42.6.7'` with an LTR/RTL option. Source:
  <https://github.com/npm/node-semver#coercion>.
- **Modular entry points.** Every function is a standalone module
  (`semver/functions/*`), so bundlers can tree-shake; the main export lazily
  loads parts via getters. Source:
  <https://github.com/npm/node-semver#exported-modules>.

## 11. Decisions NOT to copy

- **`null` as the only failure signal.** It carries no reason and forces
  callers to conflate "invalid" with "absent"; Mojo has typed errors
  (`raises`). Source (buch): `mojov1/errors/error-model`.
- **`v`-prefix stripping in the strict parser.** semver.org explicitly says
  `v1.2.3` is not a semantic version; the node-semver README itself calls the
  support legacy ("should not be used anymore"). A strict Mojo parser should
  reject it; a separate lenient helper may strip it. Sources:
  <https://semver.org/#is-v123-a-semantic-version>,
  <https://github.com/npm/node-semver#versions>.
- **`loose` mode inside the same parser.** Loose acceptance (`1.0.0alpha1`)
  mixes two grammars behind a boolean; a typed API should make lenient
  parsing a distinct entry point. Source:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>.
- **Regex-driven parsing as the primary mechanism.** Powerful for JS, but a
  Mojo library can parse with an explicit byte scanner, avoid the
  regex-DoS class entirely, and use `comptime` for a fixed grammar version.
  Source of the JS approach:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>; Mojo
  `comptime`: buch `mojov1/keywords/comptime`.
- **Build metadata silently dropped from equality.** `eq('1.2.3+a','1.2.3+b')`
  is true under clause 10, which surprises users; Mojo should keep `compare`
  spec-correct but offer an explicit `same_build`/`compare_build` where the
  distinction is needed. Sources: <https://semver.org/#spec-item-10>,
  <https://github.com/npm/node-semver#comparison>.
- **The full node-semver range dialect as a starting scope.** Hyphen, X,
  tilde, caret, `||`, `simplifyRange`, `subset` etc. are a large surface;
  starting with comparators only and adding sugar later keeps the core small.
  Source: <https://github.com/npm/node-semver#advanced-range-syntax>.

## 12. Ideas fitting Mojo

- **`struct Version` with `major`, `minor`, `patch: Int`, an owned
  prerelease-identifier list and an owned build string** — the exact SemVer
  identity. Value semantics map directly; parse returns the struct by value.
  Source (buch): `mojov1/keywords/struct`.
- **`parse(slice) -> Version raises VersionError`** plus a separate `coerce`/
  `try_parse` returning `Optional[Version]` for the `null`-style lenient path.
  Precedent: <https://github.com/npm/node-semver#coercion>; buch
  `mojov1/errors/error-model`.
- **`compare(other) -> Int` implementing clause 11**, with `prerelease`
  comparison by identifier: numeric-vs-numeric numerically, alphanumeric
  lexically in ASCII, numeric lower than non-numeric, longer identifier set
  wins. Source: <https://semver.org/#spec-item-11>.
- **A `Comparator`/`Range` value layer** where a range is a list of
  comparator sets OR-ed together; a `satisfies(version)` method. Precedent:
  <https://github.com/npm/node-semver#ranges>. In Mojo the parsed range can be
  a value type, avoiding node-semver's class hierarchy.
- **`comptime`-known range literals.** For `satisfies(v, comptime ">=1.2.0")`
  the parser could run at compile time and materialize a constant comparator
  set, eliminating runtime parsing. Source (buch):
  `mojov1/keywords/comptime`.
- **Explicit, documented prerelease policy.** Adopt node-semver's
  "same-tuple prerelease admission" as the default and expose an
  `include_prerelease` flag, rather than an implicit rule. Source:
  <https://github.com/npm/node-semver#prerelease-tags>.
- **Build metadata: precedence-neutral by default, ordering on request.**
  Keep `compare()` per clause 10 and expose a separate total-order key
  (node-semver's `compareBuild`) for deterministic sorting. Sources:
  <https://semver.org/#spec-item-10>,
  <https://github.com/npm/node-semver#comparison>.
- **`text_string` reuse for the byte-level work.** ASCII case-folding,
  trimming and split-once live in the existing `text_string` sibling, which is
  already this library's declared dependency. Sources:
  `.repo/todo/build_versioning.yml:4`, `akku/text_string/`.

## Sources

- Semantic Versioning 2.0.0 (mandatory spec): <https://semver.org/>
  - clause 10 build metadata: <https://semver.org/#spec-item-10>
  - clause 11 precedence: <https://semver.org/#spec-item-11>
  - BNF grammar: <https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>
  - "Is v1.2.3 a semantic version?": <https://semver.org/#is-v123-a-semantic-version>
- npm `node-semver` README:
  <https://github.com/npm/node-semver>
  - versions + `v`/`=` stripping: <https://github.com/npm/node-semver#versions>
  - ranges and comparators: <https://github.com/npm/node-semver#ranges>
  - advanced range syntax: <https://github.com/npm/node-semver#advanced-range-syntax>
  - range grammar (BNF): <https://github.com/npm/node-semver#range-grammar>
  - prerelease tags: <https://github.com/npm/node-semver#prerelease-tags>
  - functions: <https://github.com/npm/node-semver#functions>
  - comparison: <https://github.com/npm/node-semver#comparison>
  - coercion: <https://github.com/npm/node-semver#coercion>
  - constants: <https://github.com/npm/node-semver#constants>
  - exported modules: <https://github.com/npm/node-semver#exported-modules>
- npm `node-semver` token regexes (identity model, regex-DoS hardening):
  <https://github.com/npm/node-semver/blob/main/internal/re.js>
- npm `node-semver` SemVer class:
  <https://github.com/npm/node-semver/blob/main/classes/semver.js>
- `@types/semver`: <https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/semver>
- `compare-versions`: <https://github.com/omichelsen/compare-versions>
- `semver-compare`: <https://github.com/substack/semver-compare>
- MDN `Intl`: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl>
- MDN `String.prototype.localeCompare`: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/localeCompare>
- Node.js `process.versions`: <https://nodejs.org/api/process.html#processversions>
- Mojo buch (local): `mojov1/errors/error-model`, `mojov1/keywords/comptime`,
  `mojov1/keywords/struct`, `mojov1-string-operations`
- Repo: `.repo/todo/build_versioning.yml`, `akku/text_string/`
