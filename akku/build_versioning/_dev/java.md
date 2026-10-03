# build_versioning research: java

Scope: version parsing, comparison and version-range constraints on the JVM.
Java has **no SemVer type in the standard library**; version handling is
dominated by the build tools (Maven, Gradle) and by the community `semver4j`
library. Questions follow the workflow order; Q5, Q7 and Q9 are the
domain-adapted ones from `_dev/README.md`. The mandatory spec source is SemVer
2.0.0 (<https://semver.org/>).

## 1. Standard library support

Java's standard library has **no general-purpose version parser or comparator**.
What exists is narrowly scoped:

- **`java.lang.Runtime.Version`** (since Java 9) — "A representation of a
  version string for an implementation of the Java SE Platform." It parses the
  JEP 223 / JEP 322 version-string grammar (`$VNUM(-$PRE)?...`, where `$VNUM`
  is a dot sequence of numerals, with pre-release and build/optional
  segments), implements `Comparable`, and is used for the JDK's own version
  string. It is **not** a SemVer parser: the version number has arbitrary
  length, no `+build` metadata in the SemVer sense (`+` introduces a numeric
  build plus an optional segment), and it explicitly models JDK releases.
  Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.
- **`java.lang.module.ModuleDescriptor.Version`** (since Java 9) — parses the
  module-version grammar (a version number plus optional pre-release and build
  segments, `+` allowed), also `Comparable`. Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/module/ModuleDescriptor.Version.html>.
  Again not SemVer: no fixed major.minor.patch and no SemVer precedence rules.
- **No `java.util` version type.** There is no `Version` in `java.base` outside
  the two above, and no range/specifier API at all. (Assessment: derived from
  the Java SE 17 API index, which lists only these two version classes.)

The key stdlib fact for this library: both JDK classes implement a
**numeric-segment, arbitrary-length** model, which is incompatible with
SemVer's fixed three-segment core and with SemVer's prerelease precedence
rules. A SemVer library cannot be built on `Runtime.Version`.

## Relevant standard-adjacent APIs

- `Comparable<T>` / `Comparator<T>` define the ordering contracts a version
  type should honour; `Comparable` is the JVM-wide convention for "natural
  order". Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Comparable.html>.
- `Optional<T>` is the JVM idiom for "no result"; `Runtime.Version` returns
  `Optional<Integer>` from `build()` and `Optional<String>` from `pre()`.
  Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.

## 2. Relevant community libraries

- **`maven-artifact` — `org.apache.maven.artifact.versioning.ComparableVersion`**
  (Apache Software Foundation, Apache-2.0). The Maven version-comparison
  algorithm: unlimited components, mixed `.`/`-` separators, well-known
  qualifiers. Source:
  <https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>.
  This is a *generic* version comparator, not a SemVer implementation.
- **`semver4j` (`org.semver4j:semver4j`, MIT, active fork of vdurmont's
  original)** — a Java library implementing the semver.org spec, with
  `Semver`, `Semver.parse()`, `Semver.coerce()`, range checking in node-semver,
  CocoaPods and Ivy formats, and a processor architecture. Source:
  <https://github.com/semver4j/semver4j>.
- **Gradle `org.gradle.util.VersionNumber` / `GradleVersion`** (Gradle, Apache-2.0)
  — Gradle's own version model with up to five components (Major, Minor, Micro,
  Patch, Qualifier). Sources:
  <https://docs.gradle.org/current/javadoc/org/gradle/util/GradleVersion.html>,
  <https://www.baeldung.com/java-comparing-versions>.
- **Jackson `com.fasterxml.jackson.core.Version`** (Apache-2.0) — carries
  major/minor/patchLevel plus snapshot info, groupId and artifactId; used for
  Jackson's own `@since` metadata, not a general SemVer engine. Source:
  <https://www.baeldung.com/java-comparing-versions>.

(Assessment: for a *SemVer 2.0.0* library, `semver4j` is the only Java library
in this list that targets the spec; Maven and Gradle are deliberately broader
"generic version" comparators. Baeldung's comparison article is a useful
secondary survey of all four. Source:
<https://www.baeldung.com/java-comparing-versions>.)

## 3. Exposed APIs

**`ComparableVersion` (Maven)** — source:
<https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>:

| API | Purpose |
| --- | --- |
| `ComparableVersion(String version)` | Parse a version string. |
| `parseVersion(String version)` | Re-parse into the same instance. |
| `int compareTo(ComparableVersion o)` | Ordering. |
| `String getCanonical()` | Canonical form. |
| `String toString()` | The original-ish string. |
| `boolean equals(Object)` / `int hashCode()` | Equality/hash. |
| `static void main(String...)` | CLI to test parsing/comparison. |

**`GradleVersion` (Gradle)** — source:
<https://docs.gradle.org/current/javadoc/org/gradle/util/GradleVersion.html>:
`static version(String)`, `static current()`, `getVersion()`,
`getMajorVersion()`, `getBaseVersion()` (pre-release target, e.g. base of
`7.1-rc-1` is `7.1`), `isSnapshot()`, `isFinal()` (incubating), `compareTo`.

**`semver4j Semver`** — source: <https://github.com/semver4j/semver4j>:
`new Semver(String)`, `Semver.parse(String) -> Semver|null`,
`Semver.coerce(String) -> Semver|null`, `isStable()`, `isGreaterThan`,
`isLowerThan`, `isEqualTo` (exact, build-sensitive), `isEquivalentTo`
(ignores build), `diff(...)`, `satisfies(RangeList)`, `withIncMajor/Minor/Patch`,
`withClearedPreRelease()`, `withClearedBuild()`, `nextMajor/Minor/Patch()`,
`Semver.builder()`, `Semver.of(major,minor,patch)`, `Semver.create(...)`, and
`format(Function)`.

**`Runtime.Version` (JDK)** — source:
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>:
`static parse(String)`, `feature()`, `interim()`, `update()`, `patch()`,
`pre() -> Optional<String>`, `build() -> Optional<Integer>`,
`optional() -> Optional<String>`, `version() -> List<Integer>`,
`compareTo`, `compareToIgnoreOptional`, `equals`, `equalsIgnoreOptional`,
`toString`.

## 4. Error representation

Java uses **exceptions and `null`**; there is no `Result` type in the stdlib.

- `Runtime.Version.parse(s)` throws `IllegalArgumentException` for an invalid
  version string, `NullPointerException` for `null`, and
  `NumberFormatException` when an element exceeds `Integer`. Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.
- `GradleVersion.version(String)` throws `IllegalArgumentException` on an
  unrecognized version string. Source:
  <https://docs.gradle.org/current/javadoc/org/gradle/util/GradleVersion.html>.
- `ComparableVersion`'s constructor never fails — it accepts arbitrary strings
  and simply tokenizes them (invalid input becomes qualifiers). Source:
  <https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>.
  (Assessment: this "parse-never-fails" stance is exactly what a SemVer library
  must not copy.)
- `semver4j` returns **`null`** from `Semver.parse()` and `Semver.coerce()`
  when parsing fails ("returns null, cannot parse this version"). Source:
  <https://github.com/semver4j/semver4j>.
- `Optional` is used for genuinely optional *components*, not for parse errors:
  `Runtime.Version.pre()` returns `Optional<String>`. Source: same JDK
  reference.

(Assessment: three distinct error styles coexist on the JVM — throw,
`null`, and never-fail. A Mojo library must pick one; the buch's typed-error
model favours `raises`.)

## 5. Ownership semantics (adapted: value-returning vs. in-place)

Parsing is **value-returning** on the JVM; objects are heap-allocated and
GC-managed.

- `new ComparableVersion(String)` / `Semver.parse(String)` return a new object;
  nothing is written into a caller buffer. Sources:
  <https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>,
  <https://github.com/semver4j/semver4j>.
- `ComparableVersion.parseVersion(String)` is the exception: it mutates the
  existing instance in place. Source: same Maven reference. (Assessment: a
  mutable parse step on an otherwise value-like type; not worth copying.)
- `semver4j`'s `Semver` is **immutable**; modification methods return new
  instances (`withIncMajor()` etc.). Source:
  <https://github.com/semver4j/semver4j>.
- The JDK's `Runtime.Version` is explicitly a **value-based class**:
  "programmers should treat instances that are equal as interchangeable".
  Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.
- The input string is never mutated (`String` is immutable); ownership of the
  returned object is ordinary GC ownership. (Assessment: derived from the
  value-based/immutable statements above.)

## 6. Blocking / non-blocking

Not applicable. All cited APIs are pure, synchronous, CPU-only transforms of a
short string. `Runtime.Version.parse` performs no I/O;
`ComparableVersion.compareTo` is a pure function. Sources:
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>,
<https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>.
(Assessment: derived from the absence of any I/O or async surface in the
documented APIs.) Gradle's *dependency resolution* is asynchronous and
long-running, but that is a build-engine concern outside the version type.

## 7. Version-identity model (adapted: how the spec / version identity is modelled)

**Maven's model is explicitly not SemVer 2.0.0.** The POM reference states:

> "Important: This is only true for Semantic Versioning *1.0.0*. The Maven
> version order algorithm is not compatible with Semantic Versioning *2.0.0*.
> In particular, Maven does not special case the plus sign or consider build
> identifiers."

Source: <https://maven.apache.org/pom.html#version-order-specification>.

Maven's identity model:

- Split into tokens between `.`, `-`, `_`, and digit↔character transitions.
  A transition is equivalent to a hyphen; empty tokens become `0`. Example:
  `1-1.foo-bar1baz-.1` → `1-1.foo-bar-1-baz-0.1`. Source: same reference.
- Trailing "null" values (`0`, `""`, `final`, `ga`) are trimmed, repeatedly at
  each hyphen from the end: `1.0.0` → `1`, `1.ga` → `1`, `1.0.0-foo.0.0` →
  `1-foo`. Source: same reference.
- Shorter sequences are padded with separator-specific nulls; `.qualifier` =
  `-qualifier` < `-number` < `.number`. Source: same reference.
- Known qualifier order: `alpha < beta < milestone < rc = cr < snapshot <=
  final = ga = release < sp`; unknown qualifiers sort after, lexically. Source:
  same reference.
- **Case-insensitive** comparison: "In Maven, 3.2-ALPHA1 compares equal to
  3.2-alpha1", whereas SemVer is case-sensitive. Source: same reference.

**`Runtime.Version` model** (JEP 223/322): `$FEATURE.$INTERIM.$UPDATE.$PATCH`,
arbitrary length, no trailing zeros, pre-release (`$PRE`) and build
(`$BUILD` + optional `$OPT`); comparison order is version numbers, then
pre-release identifiers (numeric < non-numeric; numeric compared numerically,
non-numeric lexically), then build numbers, then optional info. Source:
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.

**SemVer 2.0.0 model** (what the Mojo library must model): exactly
`major.minor.patch` (no leading zeros) plus optional `-<prerelease>` and
`+<build>`; `+build` is ignored for precedence. Source:
<https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>.

**Can one abstraction cover everything?** No.

- Maven permits unlimited components and arbitrary separators; SemVer fixes
  three components. Maven's `1.0` equals `1` but a SemVer parser must reject
  `1.0`.
- Maven is case-insensitive; SemVer is case-sensitive.
- Maven does not special-case `+`, so SemVer build metadata is not modelled.
- `Runtime.Version`'s pre-release is a single string token, not the
  dot-separated SemVer identifier list, and its `+build` is a numeric build,
  not SemVer's alphanumeric identifier list.

(Assessment: the Mojo library should model strictly `major.minor.patch` +
semver prerelease + semver build, and must not inherit Maven's token
padding/trimming or `Runtime.Version`'s arbitrary-length core.)

## 8. Timeouts

Not applicable. Parsing and comparison are bounded string/sequence operations.
(Assessment: derived from the pure API surfaces above.) The adjacent
regex-DoS concern discussed in `js-ts.md` §8 applies to node-semver, but
**not** to Maven: `ComparableVersion.parseVersion` is a hand-written character
scanner, not a regex parser. It is a single `for` loop over the lowercased
string that advances a `startIndex`, branches on `.`, `-` and
`Character.isDigit(c)`, and pushes/pops `ListItem` frames on an `ArrayDeque`
(no `java.util.regex` import appears anywhere in the file). Source:
<https://github.com/apache/maven/blob/maven-3.9.6/maven-artifact/src/main/java/org/apache/maven/artifact/versioning/ComparableVersion.java>
(the `parseVersion` method).

## 9. Prerelease / build metadata + constraints (adapted)

**Maven version requirements** use interval notation, not SemVer operators
(source: <https://maven.apache.org/pom.html#dependency-version-requirement-specification>):

- `1.0` — soft requirement.
- `[1.0]` — hard requirement for exactly 1.0.
- `(,1.0]` — hard requirement for any version `<= 1.0`.
- `[1.2,1.3]` — inclusive between.
- `[1.0,2.0)` — `1.0 <= x < 2.0`.
- `[1.5,)` — `>= 1.5`.
- `(,1.0],[1.2,)` — union of two ranges, comma-separated.

Maven picks the highest version satisfying all hard requirements; if none
does, the build fails. Source: same reference.

Maven's documented gotcha for prereleases: "As `2.0-rc1` < `2.0`, the version
requirement `[1.0,2.0)` excludes `2.0` but includes version `2.0-rc1`, which is
contrary to what most people expect." Source: same reference.

**`semver4j` ranges** support three dialects: node-semver (comparators,
hyphen, X-, tilde `~`, caret `^`), CocoaPods (`~> 1.0`), and Ivy
(`[1.0,2.0]`, `[1.0,2.0[`, `]1.0,2.0]`, `(,2.0]`, …), plus a fluent internal
builder `eq(...).and(...).or(...)`. The factory takes an
`includePreRelease` flag. Source: <https://github.com/semver4j/semver4j>.

**`semver4j` build-metadata handling** is the cleanest JVM statement of SemVer
clause 10: `isEqualTo("1.2.3+sha123")` is **false** (exact, build differs) while
`isEquivalentTo("1.2.3+sha123")` is **true** (ignores build). Source:
<https://github.com/semver4j/semver4j>. SemVer clause 10 requires build
metadata to be ignored for precedence, so `isEquivalentTo` is the spec-correct
comparison and `isEqualTo` is the stricter string-equality variant.

(Assessment: Java offers no single dominant constraint dialect; Maven's
interval syntax and node-semver's operator syntax are both widespread. A Mojo
SemVer library should choose one and document it; node-semver matches the
spec's own examples.)

## 10. Interesting design decisions

- **Maven's separator-aware token model.** Separators are recorded and affect
  ordering, and digit↔character transitions act as hyphens — a very general,
  forgiving model. Source:
  <https://maven.apache.org/pom.html#version-order-specification>.
- **Maven's "prefer fewer components" guidance.** The docs recommend
  `1.0.0-RC1` over `1.0.0.RC1` and discourage `CR`, `final`, `ga`, `release`,
  `SP`, non-ASCII and uppercase. Source: same reference. It is useful as a list
  of things a *strict* library can simply reject.
- **`Runtime.Version` as an explicitly value-based class.** Equality is
  structural, instances are interchangeable, and there are paired
  `compareTo`/`compareToIgnoreOptional` and `equals`/`equalsIgnoreOptional`
  methods that stay consistent. Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.
- **`compareToIgnoreOptional` / `equalsIgnoreOptional` as a pattern.** Offering
  two explicitly named comparison modes (with vs. without build metadata) is a
  clean way to expose SemVer's clause 10. Source: same reference.
- **`semver4j`'s `diff()` -> `VersionDiff` enum** (`NONE`, `MAJOR`, `MINOR`,
  `PATCH`, `PRE_RELEASE`, `BUILD`) and `isStable()` (major > 0 and no
  prerelease). Source: <https://github.com/semver4j/semver4j>.
- **`semver4j`'s `Processor` extension point.** Range formats are pluggable
  (`IvyProcessor`, `TildeProcessor`, `CompositeProcessor.all()`), so a project
  can add its own range dialect without forking. Source:
  <https://github.com/semver4j/semver4j>.
- **Gradle's five-component `VersionNumber`** (Major, Minor, Micro, Patch,
  Qualifier) with a `getBaseVersion()` that strips the pre-release to the
  target version. Source:
  <https://docs.gradle.org/current/javadoc/org/gradle/util/GradleVersion.html>.

## 11. Decisions NOT to copy

- **Maven's generic, non-SemVer token model.** Unlimited components, separator
  sensitivity, case-insensitivity and trimming of `final`/`ga` are all
  incompatible with SemVer 2.0.0 and must not leak into a SemVer library.
  Sources: <https://maven.apache.org/pom.html#version-order-specification>,
  <https://semver.org/>.
- **Parse-never-fails (`ComparableVersion`).** Accepting arbitrary strings as
  versions is the opposite of SemVer validation. Source:
  <https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>.
- **`null`-on-invalid (`semver4j`).** Loses the reason; Mojo uses typed
  `raises`. Source (buch): `mojov1/errors/error-model`.
- **Mutable re-parse (`parseVersion`).** An in-place mutation on a value-like
  type is a needless aliasing hazard; Mojo should parse into a fresh value.
  Source:
  <https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>.
- **`equals` conflated with precedence.** In SemVer, `1.0.0+a` and `1.0.0+b`
  are equal by precedence but distinct strings; a single `equals` cannot serve
  both. Expose `compare`/`equivalent` (precedence) and `exact`/`same_string`
  separately. Precedent: `semver4j`'s `isEqualTo` vs `isEquivalentTo`.
- **Multiple range dialects in one core.** Supporting node-semver + CocoaPods
  + Ivy simultaneously is scope creep for an initial library; pick one.
  Source: <https://github.com/semver4j/semver4j>.
- **`Runtime.Version`'s arbitrary-length JDK model** as a base. It is a
  platform-release counter, not a package version. Source:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.

## 12. Ideas fitting Mojo

- **`struct Version` with `major`, `minor`, `patch: Int`, owned prerelease
  identifiers, owned build string.** Mirrors SemVer exactly and matches the
  JVM value-based-class guidance. Source (buch): `mojov1/keywords/struct`;
  JDK precedent:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>.
- **`parse(slice) -> Version raises VersionError`.** Java's `IllegalArgumentException`
  and `null` both become a typed `raises` in Mojo. Sources:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>;
  buch `mojov1/errors/error-model`.
- **Two named comparison modes.** Copy the `compareTo` /
  `compareToIgnoreOptional` idea: `compare(a, b)` implements clause 11 (build
  ignored), and a separate `total_order(a, b)`/`compare_build` breaks ties
  using build metadata. Sources:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>,
  <https://semver.org/#spec-item-10>.
- **`diff(a, b) -> VersionDiff`** with a `comptime` member enumeration for the
  change kind (NONE/MAJOR/MINOR/PATCH/PRERELEASE/BUILD), following `semver4j`.
  Precedent: <https://github.com/semver4j/semver4j>; Mojo `comptime` members:
  buch `mojov1/keywords/comptime`.
- **Explicit `is_stable()`** (major > 0 and no prerelease) as a one-line
  convenience, taken from `semver4j`. Source:
  <https://github.com/semver4j/semver4j>.
- **Component constructor without a string.** Mirror `semver4j`'s
  `Semver.of(1,2,3)` / packaging's `from_parts`: build from integers directly.
  Source: <https://github.com/semver4j/semver4j>.
- **A pluggable constraint parser only if needed later.** `semver4j` shows the
  `Processor` extension point works on the JVM, but for a first Mojo cut a
  single documented dialect (node-semver-style comparators) is enough. Source:
  <https://github.com/semver4j/semver4j>.
- **Reject Maven-only forms deliberately.** Keep `1.0`, `1.0.0.post1`,
  `final`/`ga`/`sp`, uppercase qualifiers and arbitrary separators out of the
  strict parser; a Mojo `Version` should have exactly three integer components.
  Source: <https://maven.apache.org/pom.html#version-order-specification>.

## Sources

- Semantic Versioning 2.0.0 (mandatory spec): <https://semver.org/>
  - BNF grammar: <https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>
  - clause 10 build metadata: <https://semver.org/#spec-item-10>
  - clause 11 precedence: <https://semver.org/#spec-item-11>
- JDK `java.lang.Runtime.Version` (Java SE 17):
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Runtime.Version.html>
- JDK `java.lang.module.ModuleDescriptor.Version`:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/module/ModuleDescriptor.Version.html>
- JDK `java.lang.Comparable`:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Comparable.html>
- Maven `ComparableVersion` (3.9.6 API):
  <https://maven.apache.org/ref/3.9.6/maven-artifact/apidocs/org/apache/maven/artifact/versioning/ComparableVersion.html>
- Maven `ComparableVersion` source (3.9.6 tag; `parseVersion` hand-written
  character scanner, no regex):
  <https://github.com/apache/maven/blob/maven-3.9.6/maven-artifact/src/main/java/org/apache/maven/artifact/versioning/ComparableVersion.java>
- Maven POM reference — dependency version requirements and version order:
  <https://maven.apache.org/pom.html#dependency-version-requirement-specification>
  and <https://maven.apache.org/pom.html#version-order-specification>
- Gradle `GradleVersion`:
  <https://docs.gradle.org/current/javadoc/org/gradle/util/GradleVersion.html>
- Baeldung, "Version Comparison in Java" (survey of Maven, Gradle, Jackson,
  semver4j):
  <https://www.baeldung.com/java-comparing-versions>
- semver4j: <https://github.com/semver4j/semver4j>
- npm `node-semver` (range dialect cross-reference):
  <https://github.com/npm/node-semver>
- Mojo buch (local): `mojov1/errors/error-model`, `mojov1/keywords/comptime`,
  `mojov1/keywords/struct`
- Repo: `.repo/todo/build_versioning.yml`
