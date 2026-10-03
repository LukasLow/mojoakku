# build_versioning research: kotlin

Scope: semantic-version parsing, comparison and constraint matching in Kotlin.
Kotlin has **no version type in `kotlin-stdlib`**; on the JVM it can use the
Java ecosystem, and for multiplatform it uses a dedicated community library.
Questions follow the workflow order; Q5, Q7 and Q9 are the domain-adapted ones
from `_dev/README.md`. The mandatory spec source is SemVer 2.0.0
(<https://semver.org/>).

## 1. Standard library support

Kotlin's standard library provides **no version parsing, comparison or
constraint API**. There is no `Version` type in `kotlin-stdlib`; the
`kotlin.*` packages cover text, collections, ranges, coroutines-adjacent
utilities and so on, but no semantic-version concept. (Assessment: derived
from the `kotlin-stdlib` package/API listing at
<https://kotlinlang.org/api/core/kotlin-stdlib/>, which contains no version
class comparable to Java's `Runtime.Version`.)

What Kotlin *does* give the domain:

- **Full Java interop on the JVM.** A Kotlin project can use any JVM version
  library from `java.md` — `java.lang.Runtime.Version`,
  Maven's `ComparableVersion`, Gradle's `VersionNumber`, `semver4j`. Kotlin
  can call them directly and can implement `Comparable<Version>`. Source:
  <https://kotlinlang.org/docs/java-interop.html>.
- **Operator overloading for comparison.** A Kotlin `data class` implementing
  `Comparable` gets `<`, `<=`, `>`, `>=`, `==` for free, which is why the
  community libraries model a version as a data class. Source:
  <https://kotlinlang.org/docs/operator-overloading.html#comparison-operators>.
- **`Result<T>`** exists in `kotlin-stdlib` for success/failure encapsulation,
  but the community version libraries use exceptions plus `…OrNull` variants
  instead. Source (stdlib `Result`):
  <https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-result/>.

The `kotlinx` libraries themselves are not on a strict SemVer notation, which
motivated a public debate in the Kotlin ecosystem. Sources:
<https://blog.sellmair.io/the-kotlin-ecosystem-might-not-choose-a-strict-semver-notation>,
<https://youtrack.jetbrains.com/issue/KT-44136/Standardize-the-versioning-scheme>.

## 2. Relevant community libraries

- **`io.github.z4kn4fein:semver` (`z4kn4fein/kotlin-semver`, MIT, Kotlin
  Multiplatform)** — implements "the full semantic version 2.0.0
  specification" with parse/compare/increment and constraint validation. It is
  the most prominent Kotlin-native library. Sources:
  <https://github.com/z4kn4fein/kotlin-semver>,
  <https://z4kn4fein.github.io/kotlin-semver/>.
- **`Osmerion/kotlin-semver` (MIT)** — a fork of the above that "gives up a few
  idiomatic Kotlin design decisions to provide a significantly improved Java
  interoperability and a significantly more flexible API for constraints",
  with Maven/npm/custom constraint parsing and disjunctive-normal-form
  comparator logic. Source: <https://github.com/Osmerion/kotlin-semver> and
  <https://klibs.io/project/Osmerion/kotlin-semver>.
- **`swiftzer/semver` (Kotlin, MIT)** — a Kotlin `data class` for SemVer 2.0.0
  with `Comparable` and Kotlin Serialization support, targeting Kotlin
  Multiplatform. Source: <https://github.com/swiftzer/semver>.
- **`oliverspryn/semver`** — a Kotlin library for parsing and comparing
  semver 2.0.0 versions. Source: <https://github.com/oliverspryn/semver>.
- **`asarkar/jsemver`** — a Kotlin/Java implementation with almost 100 % test
  coverage; `BuildMetadata` is the one non-`Comparable` piece. Source:
  <https://github.com/asarkar/jsemver>.
- **`G00fY2/version-compare` (Apache-2.0)** — lightweight Android/Java/Kotlin
  version-string comparison that need not follow SemVer. Source:
  <https://github.com/G00fY2/version-compare>.

(Assessment: `z4kn4fein/kotlin-semver` is the reference Kotlin-native design;
the JVM libraries from `java.md` remain available through interop.)

## 3. Exposed APIs

`z4kn4fein/kotlin-semver` (source: <https://github.com/z4kn4fein/kotlin-semver>):

| API | Purpose |
| --- | --- |
| `Version(major, minor, patch, preRelease, buildMetadata)` | Build part by part. |
| `Version.parse("3.5.2-alpha+build")` | Strict parse; throws on invalid. |
| `"3.5.2-alpha".toVersion()` | Extension parse; throws on invalid. |
| `"3.5.2-alpha".toVersionOrNull()` | Extension parse; `null` on invalid. |
| `.major`, `.minor`, `.patch`, `.preRelease`, `.buildMetadata` | Public properties. |
| `.isPreRelease`, `.isStable`, `.toString()`, `.withoutSuffixes()` | Kind/format. |
| `.copy(...)` | Immutable update. |
| `nextMajor/minor/patch/preRelease()`, `inc(by = Inc.MAJOR, preRelease = …)` | Increment. |
| `compareTo(other)` / `<` `<=` `>` `>=` / `==` `!=` | Comparison operators. |
| Destructuring `val (major, minor, patch, preRelease, buildMetadata) = version` | Component unpacking. |

Constraints (source: same README and
<https://z4kn4fein.github.io/kotlin-semver/>):

| API | Purpose |
| --- | --- |
| `Constraint.parse(">=1.2.0")`, `"…".toConstraint()`, `"…".toConstraintOrNull()` | Parse a constraint. |
| `version satisfies constraint` / `constraint satisfiedBy version` | Membership. |
| `satisfiesAll` / `satisfiesAny` / `satisfiedByAll` / `satisfiedByAny` | Collection validation. |
| `.toMavenFormat()` / `"…".toMavenConstraint()` | Maven bracket-range dialect. |
| `ConditionParser` / `ConditionFormatter` | Pluggable dialects. |

Supported condition operators: `=` (or none), `!=`, `<`, `<=`, `>`, `>=`,
joined by whitespace (AND) and `||`/`|` (OR). Source:
<https://z4kn4fein.github.io/kotlin-semver/>.

## 4. Error representation

- **Exceptions by default.** `Version.parse` / `.toVersion()` throw
  `VersionFormatException` on an invalid version; `Constraint.parse` throws
  `ConstraintFormatException` on an invalid constraint. Sources:
  <https://github.com/z4kn4fein/kotlin-semver>,
  <https://z4kn4fein.github.io/kotlin-semver/>.
- **`null` as the exception-free alternative.** `toVersionOrNull()` and
  `toConstraintOrNull()` "return `null` when the parsing fails". Source:
  <https://github.com/z4kn4fein/kotlin-semver>.
- **`Result<T>` is available but not used** by the library; the idiomatic
  Kotlin pattern here is throw-or-`null`. Source (stdlib):
  <https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-result/>.
- On the JVM, Java's exception model applies for the `java.md` libraries
  (`IllegalArgumentException`, `NullPointerException`). Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.

(Assessment: Kotlin's version libraries prefer the throw/`null` pair over
`Result`; a Mojo library would map the failing path to `raises` with a typed
error.)

## 5. Ownership semantics (adapted: value-returning vs. in-place)

Parsing is **value-returning** and the value is modelled as an **immutable
data class**:

- `Version` "objects are **immutable**, so each incrementing function creates a
  new `Version`." Source: <https://github.com/z4kn4fein/kotlin-semver>.
- `copy(...)` returns a new instance with selected properties changed, leaving
  the original untouched — the structural-copy idiom of Kotlin `data class`.
  Source: same reference.
- The parsed components are stored as properties (`major`, `minor`, `patch`,
  `preRelease`, `buildMetadata`), owned by the instance; the input `String` is
  immutable and not mutated. Source: same reference.
- Destructuring (`val (major, minor, patch, …) = version`) reads the fields by
  value. Source: same reference.
- On the JVM the objects are GC-managed; on Kotlin/Native they are managed by
  the runtime's memory manager. There is no explicit free and no borrow
  concept. (Assessment: derived from the immutability statement plus Kotlin's
  documented memory models at
  <https://kotlinlang.org/docs/native-memory-manager.html>.)

## 6. Blocking / non-blocking

Not applicable. Parsing, comparison and constraint matching are pure,
synchronous, CPU-only transforms. None of the cited APIs is `suspend`, returns
a `Flow`, or performs I/O. Sources: <https://github.com/z4kn4fein/kotlin-semver>,
<https://kotlinlang.org/api/core/kotlin-stdlib/>. (Assessment: derived from the
absence of any coroutine/async surface in the documented APIs.) Coroutines
would only matter for a *dependency resolver* that fetches metadata, which is
out of scope.

## 7. Version-identity model (adapted: how the spec / version identity is modelled)

`z4kn4fein/kotlin-semver` models exactly the SemVer 2.0.0 identity:

- `major`, `minor`, `patch` — the three numeric core components. Source:
  <https://github.com/z4kn4fein/kotlin-semver>.
- `preRelease` — a `String` holding the dot-joined prerelease identifiers
  (e.g. `"alpha.2"`). Source: same reference.
- `buildMetadata` — a `String` holding the dot-joined build identifiers
  (e.g. `"build"`). Source: same reference.
- `isPreRelease` / `isStable` — kind predicates; `isStable` is false when a
  prerelease is present. Source: same reference.
- `withoutSuffixes()` — the core `major.minor.patch` string without prerelease
  or build. Source: same reference.

**Strict vs. loose identity** is explicit and off by default: "By default, the
version parser considers partial versions like `1.0` and versions starting with
the `v` prefix invalid." With `strict = false`, `v2.3-alpha` → `2.3.0-alpha`,
`2.1` → `2.1.0`, `v3` → `3.0.0`. Source:
<https://github.com/z4kn4fein/kotlin-semver>.

**Comparison semantics** are spec-aligned: `1.0.1-alpha.3 < 1.0.1-alpha.4`,
and the sorted example shows `1.0.1-alpha`, `1.0.1-alpha.2`,
`1.0.1-alpha.3`, `1.0.1-alpha.beta`, `1.0.1`, `1.1.0`, `1.1.0+build` in order —
i.e. build metadata does not change precedence but is stable in the sort.
Source: same reference. Compare with SemVer clause 11's example:
<https://semver.org/#spec-item-11>.

The equivalent JVM model from `java.md` is broader and *not* SemVer: Maven
allows unlimited components and is case-insensitive; `Runtime.Version` uses
arbitrary-length version numbers. Sources:
<https://maven.apache.org/pom.html#version-order-specification>,
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.

**Can one abstraction cover everything?** A single Kotlin `Version` data class
covers SemVer 2.0.0 fully (core + prerelease + build) — that is exactly what
`z4kn4fein/kotlin-semver` does. It cannot cover Maven/PEP-440/JDK formats
without a separate parser; the library exposes Maven bracket ranges only as a
*constraint-format* converter, not as a version-identity model. Source:
<https://z4kn4fein.github.io/kotlin-semver/>.

## 8. Timeouts

Not applicable. All operations are bounded computations over short strings;
there is no I/O or wait state. (Assessment: derived from the pure API
surfaces.) Note again the DoS caveat for regex-based constraint parsers
(node-semver-style bounded repetition), which applies equally here; see
`js-ts.md` §8. Source:
<https://github.com/npm/node-semver/blob/main/internal/re.js>.

## 9. Prerelease / build metadata + constraints (adapted)

**Build metadata.** SemVer clause 10 requires build metadata to be ignored for
precedence. Kotlin-semver's sorted example keeps `1.1.0` and `1.1.0+build` in
that order, i.e. they compare equal but the sort is stable. Source:
<https://github.com/z4kn4fein/kotlin-semver>; spec:
<https://semver.org/#spec-item-10>.

**Constraint dialect.** Operators `=`, `!=`, `<`, `<=`, `>`, `>=`; whitespace
is AND; `||` (or `|`) is OR. Source:
<https://z4kn4fein.github.io/kotlin-semver/>.

**Range sugar** (all translated to comparators), source: same reference:

| Indicator | Translation |
| --- | --- |
| X-Range `1.2.x` | `>=1.2.0 <1.3.0-0` |
| X-Range `1.x` | `>=1.0.0 <2.0.0-0` |
| `*` | `>=0.0.0` |
| Partial `1.2` | `1.2.x` |
| Hyphen `1.0.0 - 1.2.0` | `>=1.0.0 <=1.2.0` |
| Hyphen `1.1.0 - 2` | `>=1.1.0 <3.0.0-0` |
| Tilde `~1.0.1` | `>=1.0.1 <1.1.0-0` |
| Tilde `~1` | `>=1.0.0 <2.0.0-0` |
| Caret `^1.1.2` | `>=1.1.2 <2.0.0-0` |
| Caret `^0.1.2` | `>=0.1.2 <0.2.0-0` |
| Caret `^0.0.2` | `>=0.0.2 <0.0.3-0` |

Note that the `-0` upper bounds are the node-semver trick for excluding
prereleases of the boundary version; see `js-ts.md` §9. Source:
<https://github.com/npm/node-semver#prerelease-tags>.

**Maven-style constraints** are a supported alternative format via
`toMavenFormat()` / `toMavenConstraint()`; the library translates, e.g.
`^1.2.3` → `[1.2.3,2.0.0-0)`. Source:
<https://z4kn4fein.github.io/kotlin-semver/>.

(Assessment: Kotlin offers the richest *constraint* surface of the JVM
languages because it supports both node-semver and Maven bracket dialects, but
that is also scope a first Mojo library should defer.)

## 10. Interesting design decisions

- **`data class` + `Comparable` as the version model.** Equality, `hashCode`,
  `toString`, destructuring and component functions are generated, and
  comparison operators come from `Comparable` — minimal, idiomatic code.
  Sources: <https://github.com/z4kn4fein/kotlin-semver>,
  <https://kotlinlang.org/docs/operator-overloading.html#comparison-operators>.
- **Throw by default, `…OrNull` as the opt-in.** `toVersion()` vs
  `toVersionOrNull()` makes the strictness of the failure path explicit at the
  call site. Source: <https://github.com/z4kn4fein/kotlin-semver>.
- **Strict-by-default with an opt-in `strict = false`.** Partial versions and
  `v` prefixes are rejected unless explicitly allowed. Source: same reference.
- **Immutable update via `copy(...)`.** A single method supports all
  modifications, following the Kotlin `data class` convention. Source: same
  reference.
- **Constraint parsers/formatters are pluggable interfaces.** `ConditionParser`
  has an `orSeparator` and a `regex`, so a project can add a dialect without
  touching the core. Sources: <https://z4kn4fein/kotlin-semver>,
  <https://github.com/Osmerion/kotlin-semver>.
- **Explicit Maven-format bridge.** Rather than a second internal model, the
  library converts between constraint dialects via `toMavenFormat()` /
  `toMavenConstraint()`. Source: <https://z4kn4fein.github.io/kotlin-semver/>.
- **Multiplatform-first.** The same source compiles to JVM, Native, JS and Wasm
  via KMP, with platform-specific artifacts; a version type is pure data and
  therefore an ideal KMP candidate. Sources:
  <https://github.com/z4kn4fein/kotlin-semver>,
  <https://klibs.io/project/Osmerion/kotlin-semver>.
- **Kotlin ecosystem versioning itself is unsettled.** A 2026 blog argues the
  Kotlin ecosystem may not adopt strict SemVer, and JetBrains tracks the issue
  (KT-44136, KT-67261). Sources:
  <https://blog.sellmair.io/the-kotlin-ecosystem-might-not-choose-a-strict-semver-notation>,
  <https://youtrack.jetbrains.com/issue/KT-44136/Standardize-the-versioning-scheme>.

## 11. Decisions NOT to copy

- **Exceptions as the primary API.** `VersionFormatException` /
  `ConstraintFormatException` cannot be represented in a Mojo signature; Mojo
  errors are typed return values. Sources (buch):
  `mojov1/errors/error-model`.
- **`null` alongside exceptions.** Two failure shapes for the same operation
  (`toVersion` throws, `toVersionOrNull` returns `null`) doubles the API; Mojo
  should have one typed `raises` path and derive `Optional` at the boundary.
  Source: <https://github.com/z4kn4fein/kotlin-semver>.
- **Storing prerelease/build as opaque joined `String`s.** `preRelease` is a
  single `"alpha.2"` string, so identifier-wise comparison requires re-splitting
  at compare time; a Mojo core should store the identifier list. Source: same
  reference; spec clause 11.4:
  <https://semver.org/#spec-item-11>.
- **Multiple constraint dialects in the core.** Supporting node-semver +
  Maven + custom parsers is a large surface; pick one dialect first. Sources:
  <https://z4kn4fein.github.io/kotlin-semver/>,
  <https://github.com/Osmerion/kotlin-semver>.
- **Regex `ConditionParser` as the extension mechanism.** A regex-based parser
  inherits the regex-DoS class and is harder to reason about than an explicit
  byte scanner. Source:
  <https://github.com/z4kn4fein/kotlin-semver>; risk source:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>.
- **`isStable` semantics as a hard rule.** Kotlin-semver treats "major > 0 and
  no prerelease" as stable; this is a convention, not spec. Keep such
  predicates explicitly conventional and documented. Source:
  <https://github.com/semver4j/semver4j> (same `isStable` definition in the Java
  sibling).
- **JVM/GC ownership assumptions.** Kotlin/Native and JVM differ; a Mojo
  library should make ownership explicit rather than relying on a GC. Source
  (buch): `mojov1/memory/ownership-and-lifetimes`.

## 12. Ideas fitting Mojo

- **`struct Version` with `major`, `minor`, `patch: Int` plus an owned
  prerelease-identifier list and an owned build identifier list.** This fixes
  the opaque-string weakness of Kotlin-semver while keeping the exact SemVer
  identity. Sources:
  <https://github.com/z4kn4fein/kotlin-semver>,
  <https://semver.org/#spec-item-11>; buch `mojov1/keywords/struct`.
- **Comparison via `compare(a, b) -> Int` implementing clause 11**, with the
  identifier rules (numeric < non-numeric, numeric numeric, longer set wins)
  encoded once and `<`/`<=`/`==` derived from it. Source:
  <https://semver.org/#spec-item-11>.
- **`raises VersionError` / `raises ConstraintError`** as the single failure
  path, replacing Kotlin's throw/`null` pair; optionally a `try_parse` helper
  returning `Optional[Version]`. Sources (buch): `mojov1/errors/error-model`;
  precedent: <https://github.com/z4kn4fein/kotlin-semver>.
- **Strict by default, lenient as a separately named function.** Follow
  Kotlin-semver's default (reject `1.0` and `v1.2.3`) and expose a distinct
  `parse_lenient` rather than a boolean parameter. Source:
  <https://github.com/z4kn4fein/kotlin-semver>.
- **Immutable value with a functional update.** Mojo value semantics give this
  for free; a `with_major(n)`/`with_prerelease(...)` family mirrors Kotlin's
  `copy(...)`/`nextMajor()`. Source:
  <https://github.com/z4kn4fein/kotlin-semver>.
- **One documented constraint dialect first, extension after.** Start with
  node-semver-style comparators (which Kotlin-semver uses) and defer Maven
  brackets and pluggable parsers. Sources:
  <https://z4kn4fein.github.io/kotlin-semver/>,
  <https://github.com/npm/node-semver#ranges>.
- **`comptime`-known constraint literals.** A `satisfies(v, comptime ">=1.2.0")`
  could compile the constraint at compile time; Kotlin resolves everything at
  runtime. Source (buch): `mojov1/keywords/comptime`.
- **`diff(a, b) -> VersionDiff` as a `comptime` member enumeration**, matching
  the `semver4j`/`VersionDiff` idea and Kotlin enums. Sources:
  <https://github.com/semver4j/semver4j>; buch `mojov1/keywords/comptime`.
- **Reuse `text_string` for scanning.** The parser needs ASCII case-folding,
  trimming and split-once, all already public in the `text_string` sibling that
  this library already depends on. Sources: `.repo/todo/build_versioning.yml:4`,
  `akku/text_string/`.

## Sources

- Semantic Versioning 2.0.0 (mandatory spec): <https://semver.org/>
  - clause 10 build metadata: <https://semver.org/#spec-item-10>
  - clause 11 precedence: <https://semver.org/#spec-item-11>
  - BNF grammar: <https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>
- `z4kn4fein/kotlin-semver` (README, API reference):
  <https://github.com/z4kn4fein/kotlin-semver>,
  <https://z4kn4fein.github.io/kotlin-semver/>
- `Osmerion/kotlin-semver`: <https://github.com/Osmerion/kotlin-semver>,
  <https://klibs.io/project/Osmerion/kotlin-semver>
- `swiftzer/semver`: <https://github.com/swiftzer/semver>
- `oliverspryn/semver`: <https://github.com/oliverspryn/semver>
- `asarkar/jsemver`: <https://github.com/asarkar/jsemver>
- `G00fY2/version-compare`: <https://github.com/G00fY2/version-compare>
- Kotlin stdlib API index: <https://kotlinlang.org/api/core/kotlin-stdlib/>
- Kotlin `Result`: <https://kotlinlang.org/api/core/kotlin-stdlib/kotlin/-result/>
- Kotlin operator overloading (comparison):
  <https://kotlinlang.org/docs/operator-overloading.html#comparison-operators>
- Kotlin/Java interop: <https://kotlinlang.org/docs/java-interop.html>
- Kotlin/Native memory manager:
  <https://kotlinlang.org/docs/native-memory-manager.html>
- Kotlin ecosystem SemVer debate:
  <https://blog.sellmair.io/the-kotlin-ecosystem-might-not-choose-a-strict-semver-notation>
- JetBrains YouTrack KT-44136 (standardize versioning scheme):
  <https://youtrack.jetbrains.com/issue/KT-44136/Standardize-the-versioning-scheme>
- JVM version libraries cross-reference (see `java.md`): `Runtime.Version`
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>,
  Maven <https://maven.apache.org/pom.html#version-order-specification>,
  semver4j <https://github.com/semver4j/semver4j>
- npm `node-semver` (range dialect cross-reference):
  <https://github.com/npm/node-semver>
- Mojo buch (local): `mojov1/errors/error-model`, `mojov1/keywords/comptime`,
  `mojov1/keywords/struct`, `mojov1/memory/ownership-and-lifetimes`
- Repo: `.repo/todo/build_versioning.yml`, `akku/text_string/`
