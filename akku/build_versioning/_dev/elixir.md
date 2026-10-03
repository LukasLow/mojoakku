# build_versioning research: elixir

Scope: semantic-version parsing, comparison and requirement matching in the
Elixir/Erlang ecosystem. Elixir ships a first-class `Version` module in its
standard library and is the only selected language with a stdlib SemVer
implementation. Questions follow the workflow order; Q5, Q7 and Q9 are the
domain-adapted ones from `_dev/README.md`. The mandatory spec source is SemVer
2.0.0 (<https://semver.org/>).

## 1. Standard library support

Elixir's **standard library has a full SemVer module: `Version`** in `elixir`
itself (no extra dependency).

> "Functions for parsing and matching versions against requirements. A version
> is a string in a specific format or a `Version` generated after parsing via
> `Version.parse/1`."

Source: <https://hexdocs.pm/elixir/Version.html>.

The module documentation states the spec requirement directly:

> "Although Elixir projects are not required to follow SemVer, they must follow
> the format outlined on [SemVer 2.0 schema]."

Source: <https://hexdocs.pm/elixir/Version.html#module-versions>.

The module provides, per the same reference:

- `%Version{major, minor, patch, pre, build}` — the struct.
- `Version.parse/1`, `Version.parse!/1` — parse a version string.
- `Version.parse_requirement/1`, `Version.parse_requirement!/1` — parse a
  requirement string.
- `Version.compare/2` — order two versions.
- `Version.match?/3` — does a version satisfy a requirement.
- `Version.compile_requirement/1` — optimize a parsed requirement.
- `Version.to_string/1` — render a version.
- The types `major/minor/patch` (non-negative integers), `pre` (list of
  strings and non-negative integers), `build` (string or `nil`),
  `requirement`, `version`, `t`.

An important documented limitation:

> "Each numeric component is limited to at most 14 digits." and "Numeric
> pre-release identifiers are also limited to at most 14 digits."

Source: <https://hexdocs.pm/elixir/Version.html>.

Erlang/OTP itself has no equivalent general SemVer type; version handling there
is stringly (`erlang:system_info(otp_release)` etc.). (Assessment: derived from
the OTP documentation, which exposes no version parser.) Mix, Elixir's build
tool, uses `Version` for dependency requirements. Source:
<https://hexdocs.pm/mix/Mix.Tasks.Deps.html>.

## 2. Relevant community libraries

Because the stdlib is sufficient, the community surface is small:

- **`Version` (Elixir stdlib, `elixir`)** — the reference; see §1.
- **`Version.Parser` / `Version.Requirement` (Elixir stdlib)** — the internal
  requirement parser and opaque requirement struct, both documented under
  `Version`. Source:
  <https://hexdocs.pm/elixir/Version.Requirement.html>.
- **Hex (`hex_core`)** — the package manager builds on `Version` for
  requirement resolution; its requirement semantics differ from the default in
  one documented way: in Hex `:allow_pre` is `false`. Source:
  <https://hexdocs.pm/elixir/Version.html> ("in Hex `:allow_pre` is set to
  `false`").
- **`elixir_semver`-style third-party packages** exist but are largely
  redundant given the stdlib; not evaluated as design references here.
  (Assessment: no widely-used independent Elixir SemVer package competes with
  the stdlib `Version` module.)

(Assessment: for MojoAkku the interesting fact is that Elixir proves a
stdlib-grade SemVer module is small enough to own; the design lessons are in
the stdlib API, not in third-party code.)

## 3. Exposed APIs

From <https://hexdocs.pm/elixir/Version.html>:

| API | Purpose |
| --- | --- |
| `Version.parse(string) :: {:ok, t()} \| :error` | Parse to a struct or the `:error` atom. |
| `Version.parse!(string) :: t()` | Parse, raising on failure. |
| `Version.compare(v1, v2) :: :gt \| :eq \| :lt` | Order two versions. |
| `Version.match?(version, requirement, opts \\ []) :: boolean` | Requirement satisfaction. |
| `Version.parse_requirement(string) :: {:ok, Requirement.t()} \| :error` | Parse a requirement. |
| `Version.parse_requirement!(string)` | Raising variant (since 1.8.0). |
| `Version.compile_requirement(requirement) :: Requirement.t()` | Optimize a requirement (opaque representation). |
| `Version.to_string(version) :: String.t()` | Render (since 1.14.0). |
| `%Version{major, minor, patch, pre, build}` | The struct; read fields. |

Field details (source: same reference):

- `:major`, `:minor`, `:patch` — non-negative integers.
- `:pre` — a list, e.g. `["alpha1"]`.
- `:build` — a string or `nil`.

Documented usage examples (source: same reference):

```
iex> Version.parse("2.0.1-alpha1")
{:ok, %Version{major: 2, minor: 0, patch: 1, pre: ["alpha1"]}}

iex> Version.parse("2.0-alpha1")
:error

iex> Version.parse!("2.0-alpha1")
** (Version.InvalidVersionError) invalid version: "2.0-alpha1"

iex> Version.compare("2.0.1-alpha1", "2.0.0")
:gt

iex> Version.compare("1.0.0-10", "1.0.0-2")
:gt

iex> Version.compare("2.0.1+build0", "2.0.1")
:eq
```

Note the struct guidance: "You can read those fields but you should not create
a new `Version` directly via the struct syntax. Instead use the functions in
this module." Source: same reference.

## 4. Error representation

Elixir models failure with **tagged tuples and exceptions**, exactly the two
shapes its `Version` module uses:

- **`{:ok, value}` / `:error` tagged tuple** from `Version.parse/1` and
  `Version.parse_requirement/1`. Example: `Version.parse("2.0-alpha1")` →
  `:error`. Source: <https://hexdocs.pm/elixir/Version.html>.
- **Raising variants** `parse!/1` and `parse_requirement!/1` for callers that
  want to crash on invalid input. Sources:
  <https://hexdocs.pm/elixir/Version.html>,
  <https://hexdocs.pm/elixir/Version.Requirement.html>.
- **Typed exceptions:** `Version.InvalidVersionError` ("invalid version:
  \"invalid\"") and `Version.InvalidRequirementError` ("invalid requirement:
  \"== == 1.0.0\""). Source: <https://hexdocs.pm/elixir/Version.html>.
- **No `null` sentinel** is used; absence is either `:error` or a raised
  exception. (Assessment: derived from the documented return/raise pairs.)

This is the closest match to Mojo's model in the whole corpus: `{:ok, value} |
:error` is structurally identical to "return value or alternate error value",
and Elixir's `!`-suffixed raising variants correspond to Mojo's
raising/non-raising function split. Sources (buch):
`mojov1/errors/error-model`.

## 5. Ownership semantics (adapted: value-returning vs. in-place)

Parsing is **value-returning** and all values are **immutable**:

- `Version.parse/1` returns a new `{:ok, %Version{...}}` tuple; no output
  buffer is passed and no existing value is mutated. Source:
  <https://hexdocs.pm/elixir/Version.html>.
- Structs are immutable; there is no in-place update API. The docs instruct
  callers to read fields but to construct instances only through the module's
  functions. Source: same reference.
- The parsed `:pre` list and `:build` string are owned by the struct; the input
  binary is not retained by reference in a way the caller can observe (BEAM
  immutability). (Assessment: derived from Elixir's immutable-data model and
  the documented struct construction guidance.)
- No explicit free; memory is managed by the BEAM per-process heap and garbage
  collector. (Assessment: derived from the BEAM memory model.)

In Mojo terms this maps to a value struct returned by value, with owned
`pre`/`build` storage — the same shape the Kotlin and Java sections recommend.

## 6. Blocking / non-blocking

Not applicable. `Version.parse/1`, `Version.compare/2` and `Version.match?/3`
are pure, synchronous functions; they perform no I/O and involve no processes,
messages or `Task`s. Source: <https://hexdocs.pm/elixir/Version.html>.
(Assessment: derived from the absence of any process/`Task`/I/O surface in the
documented module.) BEAM concurrency would only matter for a resolver fetching
package metadata, which is external to the version module.

## 7. Version-identity model (adapted: how the spec / version identity is modelled)

Elixir's `Version` struct is an unusually faithful encoding of SemVer 2.0.0:

- **Core:** `%Version{major, minor, patch}` — three non-negative integers.
  Source: <https://hexdocs.pm/elixir/Version.html>.
- **Prerelease:** `:pre` is a **list**, not a joined string — e.g.
  `%Version{major: 2, minor: 0, patch: 1, pre: ["alpha1"]}`. The struct doc:
  "It contains the fields `:major`, `:minor`, `:patch`, `:pre`, and `:build`
  according to SemVer 2.0, where `:pre` is a list." Source: same reference.
- **Build:** `:build` is a string or `nil`, added by appending `+` and
  dot-separated identifiers. Source: same reference.
- **Numeric limits:** each numeric component and each numeric prerelease
  identifier is capped at 14 digits. Source: same reference.
- **`v` prefix / partial versions:** `Version.parse("2.0-alpha1")` returns
  `:error` — Elixir is strict; there is no documented `v`-prefix stripping in
  `Version` itself. Source: same reference.

The BNF in the module docs matches semver.org: `MAJOR.MINOR.PATCH`, optional
hyphen prerelease, optional plus build. Source:
<https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>.

**Comparison is spec-aligned**, and the docs state the build rule explicitly:

> "Pre-releases are strictly less than their corresponding release versions.
> Patch segments are compared lexicographically if they are alphanumeric, and
> numerically otherwise. Build segments are ignored: if two versions differ
> only in their build segment they are considered to be equal."

Source: <https://hexdocs.pm/elixir/Version.html>. The examples confirm:
`Version.compare("2.0.1+build0", "2.0.1")` → `:eq`. Source: same reference.
This is exactly SemVer clause 10 and clause 11. Sources:
<https://semver.org/#spec-item-10>,
<https://semver.org/#spec-item-11>.

**Can one abstraction cover everything?** For SemVer 2.0.0, yes — a single
struct with integer triple + prerelease list + build string covers the whole
grammar, and Elixir proves it. It does not cover Maven/PEP-440/JDK formats, but
Elixir does not attempt to. Source: <https://hexdocs.pm/elixir/Version.html>.

## 8. Timeouts

Not applicable. All three public operations are bounded, pure computations over
small values; no timeouts, no processes, no cancellation. Source:
<https://hexdocs.pm/elixir/Version.html>. (Assessment: derived from the pure
functional signatures.) The DoS/regex caveat from `js-ts.md` §8 applies to
any regex-based parser but Elixir's `Version` is documented as a hand-rolled
parser with an explicit 14-digit cap, which is itself a bounded-input
defence. Source: <https://hexdocs.pm/elixir/Version.html>.

## 9. Prerelease / build metadata + requirements (adapted)

**Requirements** are the constraint mechanism. Elixir supports the common
comparison operators plus one special operator (source:
<https://hexdocs.pm/elixir/Version.html>):

- `>`, `>=`, `<`, `<=`, `==`, and `~>` — the latter "in detail further below".
- An omitted operator is equivalent to `==`.
- `and` / `or` for complex conditions.

The `~>` (pessimistic) operator translations, per the same reference:

| `~>` | Translation |
| --- | --- |
| `~> 2.0.0` | `>= 2.0.0 and < 2.1.0` |
| `~> 2.1.2` | `>= 2.1.2 and < 2.2.0` |
| `~> 2.1.3-dev` | `>= 2.1.3-dev and < 2.2.0` |
| `~> 2.0` | `>= 2.0.0 and < 3.0.0` |
| `~> 2.1` | `>= 2.1.0 and < 3.0.0` |

The `~>` operand may omit the patch version (unlike the plain operators), and
`~>` "will never include pre-release versions of its upper bound, regardless of
the usage of the `:allow_pre` option". Source: same reference.

**Prerelease handling via `:allow_pre`:**

> "When the `:allow_pre` option is set `false` in `Version.match?/3`, the
> requirement will not match a pre-release version unless the operand is a
> pre-release version. The default is to always allow pre-releases but note
> that in Hex `:allow_pre` is set to `false`."

Source: <https://hexdocs.pm/elixir/Version.html>. The docs give a truth table
for `~>` and `>=` operands with and without prereleases. Source: same
reference. This is the same design axis as node-semver's `includePrerelease`
(see `js-ts.md` §9) and PEP 440's pre-release exclusion (see `python.md` §9),
but Elixir exposes it as one boolean option on `match?/3`.

**Requirements are an opaque struct.** `Version.Requirement` "holds version
requirement information. The struct fields are private and should not be
accessed." `compile_requirement/1` returns an opaque optimized representation.
Sources: <https://hexdocs.pm/elixir/Version.Requirement.html>,
<https://hexdocs.pm/elixir/Version.html>. That encapsulation is worth noting:
callers cannot inspect internals, only ask `match?`.

## 10. Interesting design decisions

- **Tagged-tuple result, not exceptions, as the primary API.** `{:ok, v} |
  :error` is the canonical Elixir success/failure shape and reads directly as
  an alternate return value. Source: <https://hexdocs.pm/elixir/Version.html>.
- **Paired non-raising/raising functions.** `parse/1` vs `parse!/1` and
  `parse_requirement/1` vs `parse_requirement!/1`. Source: same reference.
- **Prerelease stored as a list.** `:pre` is `["alpha1"]`, so clause 11.4
  identifier comparison needs no re-splitting at compare time. Source: same
  reference; spec clause 11.4: <https://semver.org/#spec-item-11>.
- **Build metadata explicitly ignored in comparison**, documented with a test
  case (`("2.0.1+build0", "2.0.1")` → `:eq`). Source:
  <https://hexdocs.pm/elixir/Version.html>.
- **Comparison returns an atom `:gt | :eq | :lt`**, not an integer. Source:
  same reference. (Assessment: expressive, but an integer `-1/0/1` composes
  better with sort/total-order functions; Mojo would likely return an `Int`
  and derive ordering.)
- **Requirement is opaque and compiled.** `compile_requirement/1` produces an
  optimized internal representation so repeated `match?` calls are cheap — a
  performance decision with a clean API boundary. Source: same reference.
- **The `~>` operator is the idiomatic Elixir constraint**, with documented
  desugaring and a guaranteed exclusion of the upper bound's prereleases.
  Source: same reference.
- **A hard 14-digit cap on numeric components.** A simple, explicit bound that
  heads off integer-overflow and unbounded-input concerns. Source: same
  reference.

## 11. Decisions NOT to copy

- **Raising variants as part of the public API.** Mojo's `raises` already makes
  the raising/non-raising split a compile-time property of the signature, so a
  separate `parse!` function is redundant. Source (buch):
  `mojov1/errors/error-model`.
- **Atoms (`:gt`/`:eq`/`:lt`) for ordering.** An integer comparator is more
  composable and is the JVM/Python convention. Sources:
  <https://hexdocs.pm/elixir/Version.html>,
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Comparable.html>.
- **A 14-digit component cap.** Arbitrary and Elixir-specific; Mojo can choose
  a documented integer width and validate overflow explicitly. Source:
  <https://hexdocs.pm/elixir/Version.html>.
- **An opaque requirement struct with no inspection API.** Useful in Elixir,
  but a Mojo design should at least be able to round-trip and compare
  requirement values; hiding everything makes tooling harder. Sources:
  <https://hexdocs.pm/elixir/Version.Requirement.html>.
- **The `~>` operator as the only sugar.** It is idiomatic for Elixir/Mix but
  not a SemVer-standard range; node-semver's `^`/`~`/hyphen vocabulary is more
  portable. Sources: <https://hexdocs.pm/elixir/Version.html>,
  <https://github.com/npm/node-semver#advanced-range-syntax>.
- **`and`/`or` keywords inside constraint strings.** Requires a mini-language
  parser; a first Mojo cut can restrict to whitespace-AND and `||`. Source:
  <https://hexdocs.pm/elixir/Version.html>.
- **`v`-prefix and partial versions being unsupported without a documented
  lenient path.** Elixir is strict here; if Mojo supports lenient parsing at
  all, it should be a separate, explicit function (as Kotlin does), not an
  afterthought. Sources: <https://hexdocs.pm/elixir/Version.html>,
  <https://github.com/z4kn4fein/kotlin-semver>.

## 12. Ideas fitting Mojo

- **`struct Version` with `major`, `minor`, `patch: Int`, `pre` as an owned
  list, and `build` as an owned string or empty/`Optional`.** This is the
  Elixir struct translated to Mojo value semantics and is the strongest
  cross-language consensus in this group. Sources:
  <https://hexdocs.pm/elixir/Version.html>; buch `mojov1/keywords/struct`.
- **Parse returns a value or raises a typed error — no tuple.** Elixir's
  `{:ok, v} | :error` is the structural model; Mojo expresses it as
  `parse(slice) -> Version raises VersionError`. Source (buch):
  `mojov1/errors/error-model`.
- **Store prerelease identifiers as a list, compare per clause 11.4.** Elixir
  already does this; keep it in the Mojo core rather than storing a joined
  string. Sources: <https://hexdocs.pm/elixir/Version.html>,
  <https://semver.org/#spec-item-11>.
- **Build metadata ignored by `compare`, with a test just like Elixir's.**
  `compare("2.0.1+build0", "2.0.1") == 0` should be an explicit, documented,
  tested fact. Sources: <https://hexdocs.pm/elixir/Version.html>,
  <https://semver.org/#spec-item-10>.
- **A compiled/optimized requirement value.** Elixir's
  `compile_requirement/1` suggests parsing a constraint once into a value and
  reusing it — in Mojo this could even be a `comptime`-materialized constant
  for literal constraints. Sources: <https://hexdocs.pm/elixir/Version.html>;
  buch `mojov1/keywords/comptime`.
- **One boolean prerelease policy on the match function.** Mirror `:allow_pre`
  (default on / Hex sets off) as an explicit, documented parameter or a
  distinct `match_stable` helper. Source:
  <https://hexdocs.pm/elixir/Version.html>.
- **Explicit numeric-width policy.** Elixir's 14-digit cap is the precedent for
  bounding components; Mojo should define the integer type and reject
  overflow rather than silently wrap. Source:
  <https://hexdocs.pm/elixir/Version.html>.
- **Reuse `text_string` for scanning and ASCII case-folding.** Elixir's parser
  is hand-rolled; the Mojo equivalent can build on the existing `text_string`
  sibling it already depends on. Sources: `.repo/todo/build_versioning.yml:4`,
  `akku/text_string/`.
- **Keep the constraint dialect small and documented.** Elixir's single `~>`
  plus the comparison operators is a good template for a minimal first cut,
  with node-semver sugar deferred. Source:
  <https://hexdocs.pm/elixir/Version.html>.

## Sources

- Elixir `Version` (hexdocs, v1.20.4): <https://hexdocs.pm/elixir/Version.html>
  - Versions section: <https://hexdocs.pm/elixir/Version.html#module-versions>
  - Requirements section: <https://hexdocs.pm/elixir/Version.html#module-requirements>
  - `compare/2`: <https://hexdocs.pm/elixir/Version.html#compare/2>
  - `parse/1`: <https://hexdocs.pm/elixir/Version.html#parse/1>
  - `match?/3` and `:allow_pre`: <https://hexdocs.pm/elixir/Version.html#match?/3>
- Elixir `Version.Requirement`:
  <https://hexdocs.pm/elixir/Version.Requirement.html>
- Elixir source `lib/elixir/lib/version.ex` (v1.20.4):
  <https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/version.ex>
- Mix dependency requirements (Hex `:allow_pre` = false context):
  <https://hexdocs.pm/mix/Mix.Tasks.Deps.html>
- Semantic Versioning 2.0.0 (mandatory spec): <https://semver.org/>
  - clause 10 build metadata: <https://semver.org/#spec-item-10>
  - clause 11 precedence: <https://semver.org/#spec-item-11>
  - BNF grammar: <https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>
- Cross-references for the other languages in this group: `python.md`,
  `js-ts.md`, `java.md`, `kotlin.md`
- Mojo buch (local): `mojov1/errors/error-model`, `mojov1/keywords/comptime`,
  `mojov1/keywords/struct`
- Repo: `.repo/todo/build_versioning.yml`, `akku/text_string/`
