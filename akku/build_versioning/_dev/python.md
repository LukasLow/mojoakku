# build_versioning research: python

Scope: version parsing, comparison and constraint matching in CPython's
standard library and the relevant Python packaging ecosystem. Questions follow
the workflow order; Q5, Q7 and Q9 are the domain-adapted ones from
`_dev/README.md`. The mandatory spec source is SemVer 2.0.0
(<https://semver.org/>).

## 1. Standard library support

Python's **standard library has no SemVer parser**. Version handling lives in
the packaging ecosystem, not in `stdlib`:

- `distutils.version` (`StrictVersion`/`LooseVersion`) was the historical
  stdlib answer. It is **removed in Python 3.12** (deprecated since 3.10);
  `distutils` is no longer part of the standard library. Source:
  PEP 632, <https://peps.python.org/pep-0632/>. It parsed only loose version
  strings (`LooseVersion` compares by splitting on `.`) and did **not**
  implement SemVer 2.0.0. (Assessment: derived from PEP 632 plus the
  pre-removal `distutils` reference, which lists `LooseVersion` and
  `StrictVersion` only.)
- `importlib.metadata.version(distribution_name)` (since 3.8) returns the
  version string of an installed distribution as a plain `str`; it does not
  parse or order versions. Source:
  <https://docs.python.org/3/library/importlib.metadata.html#distribution-versions>.
  The same module exposes no comparison API. (Assessment: derived from the
  module's documented function list.)
- `sys.version_info` is a named tuple of the interpreter version (major,
  minor, micro, releaselevel, serial). It is specific to the interpreter, not
  a general version-format API. Source:
  <https://docs.python.org/3/library/sys.html#sys.version_info>.

Everything else is third-party. The de-facto standard is PyPA's `packaging`
module (see §2), which implements **PEP 440**, not SemVer 2.0.0. PEP 440 is a
different version scheme; see §7 and §9.

There is a genuine spec split that matters for this library: Python packaging
deliberately does **not** accept SemVer pre-release hyphens or `+` build
metadata in the public version field.

> "Semantic versions containing a hyphen (pre-releases - clause 10) or a plus
> sign (builds - clause 11) are *not* compatible with this specification and
> are not permitted in the public version field."

Source: <https://packaging.python.org/en/latest/specifications/version-specifiers/#semantic-versioning>.

## 2. Relevant community libraries

- **`packaging` (PyPA, maintained)** — the reference implementation of the
  PEP 440 version scheme and version specifiers. This is what `pip`, `setuptools`
  and most tooling depend on. Source:
  <https://packaging.pypa.io/en/stable/version.html>. License: BSD-2-Clause /
  Apache-2.0 (PyPA project).
- **`python-semver` (`semver` package, maintained by the python-semver org)** —
  an implementation of the **semver.org 2.0.0** spec: `VersionInfo.parse`,
  `compare`, `match`. Explicitly separate from PEP 440. Source:
  <https://github.com/python-semver/python-semver>. License: BSD-3-Clause.
- **`poetry-core` / `poetry`** — ships its own `poetry.core.constraints.version`
  / `packaging`-based version handling and a dependency resolver. Source:
  <https://github.com/python-poetry/poetry>.
- **`dephell-versioning`** and similar tools — niche; not evaluated here.

(Assessment: the split between `packaging`/PEP 440 and `python-semver`/SemVer
2.0.0 is the single most important community fact for a SemVer library; a
SemVer-2.0.0 library should follow `python-semver`, not PEP 440.)

## 3. Exposed APIs

`packaging.version` (PEP 440; source
<https://packaging.pypa.io/en/stable/version.html>):

| API | Purpose |
| --- | --- |
| `Version(version: str)` | Parse + normalize; comparison-aware value object. |
| `parse(version)` | Aliased to the `Version` constructor. |
| `Version.from_parts(*, epoch=0, release, pre=None, post=None, dev=None, local=None)` | Build without a string/regex (added 26.1). |
| `Version.__replace__(...)` | Copy with parts replaced (immutable update, added 26.0). |
| `Version.epoch`, `.release`, `.pre`, `.post`, `.dev`, `.local` | Structured components. |
| `Version.public`, `.base_version` | Public / base string projections. |
| `Version.is_prerelease`, `.is_postrelease`, `.is_devrelease` | Kind predicates. |
| `Version.major`, `.minor`, `.micro` | Convenience accessors. |
| `normalize_pre(letter)` | Lowercase/normalize a pre-release letter (26.1). |
| `VERSION_PATTERN` | The regex used to match a valid version; "not anchored at either end". |
| `InvalidVersion` | The parse-failure exception. |

`packaging.specifiers` adds `Specifier` / `SpecifierSet` with the operators
`~=`, `==` (with `.*` prefix matching), `!=`, `<=`, `>=`, `<`, `>`, `===`.
Source: <https://packaging.python.org/en/latest/specifications/version-specifiers/#version-specifiers>.

`python-semver` (SemVer 2.0.0) exposes `VersionInfo` with `.parse()`,
`.major/.minor/.patch/.prerelease/.build`, the `compare()` method, module-level
`compare()`, `max_satisfying()`, and a `match()`/`satisfies()` constraint
helper. Source: <https://github.com/python-semver/python-semver#usage>.

## 4. Error representation

All Python version libraries signal failure with **exceptions**, not error
codes or `Result` values:

- `packaging.version.InvalidVersion` — "Raised when a version string is not a
  valid version." Example: `Version("invalid")` raises
  `packaging.version.InvalidVersion: Invalid version: 'invalid'`. Source:
  <https://packaging.pypa.io/en/stable/version.html#packaging.version.InvalidVersion>.
- `python-semver` raises `ValueError` on an invalid version string. Source:
  <https://github.com/python-semver/python-semver>.
- `importlib.metadata` may raise `PackageNotFoundError` for a missing
  distribution (a lookup error, not a parse error). Source:
  <https://docs.python.org/3/library/importlib.metadata.html>.

There is no sentinel value in the modern APIs. (`distutils`' removed
`LooseVersion` was the exception and returned objects that failed on comparison,
not at parse time.) (Assessment: derived from the cited API references.)

## 5. Ownership semantics (adapted: value-returning vs. in-place)

Parsing is **value-returning** and the parsed object is **immutable**:

- `Version` / `VersionInfo` are constructed from a `str` and own their parsed
  component data. `Version` "is immutable; use `__replace__()` to change part
  of a version." Source:
  <https://packaging.pypa.io/en/stable/version.html#packaging.version.Version>.
- There is no in-place parse into a caller buffer. The input `str` is not
  mutated (Python `str` is immutable); it is either ignored after parsing or
  retained by the object's derived fields. The `local` segment and the
  `release` tuple are stored on the instance. Source: same reference.
- `Version.from_parts(...)` builds the value directly from components,
  bypassing the input string entirely — useful when the value is already
  structured. Source: same reference.
- `__replace__` returns a **new** version ("returns a new version (unless no
  parts were changed)"), so immutability holds across the whole API. Source:
  same reference.

Because everything is a Python value under reference counting/GC, there is no
manual free and no borrow checker; the only lifetime question is whether a
caller holds a reference to the immutable object. (Assessment: derived from
the immutability statement above plus Python's memory model.)

## 6. Blocking / non-blocking

Not applicable. Version parsing, comparison and specifier matching are pure,
synchronous, CPU-only transformations of a short string with no I/O, handles
or awaits. The `packaging` and `python-semver` references describe only value
transformations. Sources:
<https://packaging.pypa.io/en/stable/version.html>,
<https://github.com/python-semver/python-semver>. (Assessment: derived from
the absence of any I/O or async semantics in the cited API descriptions.)

## 7. Version-identity model (adapted: how the spec / version identity is modelled)

Python offers **two incompatible identity models**, and that is the key finding:

**PEP 440 public version identifier** — up to five segments, in this order:

```
[N!]N(.N)*[{a|b|rc}N][.postN][.devN]
```

Source: <https://packaging.python.org/en/latest/specifications/version-specifiers/#public-version-identifiers>.

- **Epoch** `N!` — optional, default `0`. Used to re-order when a project
  changes its numbering scheme. Source: same reference, "Version epochs".
- **Release** `N(.N)*` — one or more non-negative integers, **variable
  length**. `X.Y` and `X.Y.0` are equal after zero-padding. Source: same
  reference, "Final releases".
- **Pre-release** `{a|b|rc}N` — alpha/beta/release-candidate with a number.
  Source: same reference, "Pre-releases".
- **Post-release** `.postN`; **Development release** `.devN`; **Local version**
  `+label` (arbitrary, no semantics except ordering). Sources: same reference,
  "Post-releases", "Developmental releases", "Local version identifiers".
- **Leading `v`** is accepted and normalized away: "versions may be preceded
  by a single literal `v` character … MUST be ignored for all purposes".
  Source: same reference, "Preceding v character".

**SemVer 2.0.0 identity** (as implemented by `python-semver`, and the model
this library must follow) — exactly three numeric identifiers with **no
leading zeroes**, plus optional `-<prerelease>` and `+<build>`:

```
<version core> ::= <major> "." <minor> "." <patch>
<valid semver> ::= <version core>
                 | <version core> "-" <pre-release>
                 | <version core> "+" <build>
                 | <version core> "-" <pre-release> "+" <build>
```

Source: <https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>.

- `major/minor/patch` are non-negative integers, no leading zeros
  (semver.org clause 2).
- **Prerelease** is a dot-separated list of identifiers over `[0-9A-Za-z-]`;
  numeric identifiers are compared numerically and must not have leading
  zeros; a larger set of fields wins if all preceding are equal
  (clauses 9 and 11.4).
- **Build metadata** is a dot-separated list over `[0-9A-Za-z-]` and **MUST be
  ignored** for precedence (clause 10).
- **`v` prefix:** the FAQ is explicit — "No, `v1.2.3` is not a semantic
  version." `v` is a common decoration but is not part of the identity.
  Source: <https://semver.org/#is-v123-a-semantic-version>.

**Can one abstraction cover everything?** No.

- PEP 440 allows an arbitrary-length release tuple, an epoch, and renames
  SemVer's `-alpha` to `aN`, so a `Version` object cannot round-trip a SemVer
  string such as `1.0.0-alpha+build` without translation.
- SemVer forbids leading zeroes and fixes the core at three components; PEP 440
  permits both `1.0` and `1.0.0` (as equal) and variable-length releases.
- The `v` prefix is explicitly **not** a semantic version under SemVer, while
  PEP 440 normalizes it away.
- SemVer's `+build` is semantically inert for precedence; PEP 440's `+local`
  has a defined ordering (numeric > lexicographic, longer wins). Sources:
  <https://semver.org/#spec-item-10>,
  <https://packaging.python.org/en/latest/specifications/version-specifiers/#local-version-identifiers>.

(Assessment: a Mojo library that claims "SemVer 2.0.0" must model exactly the
three-part core + prerelease + build, and must *reject* PEP 440 forms such as
`1.0` or `1.0.0.post1` rather than silently normalize them.)

## 8. Timeouts

Not applicable. Comparisons and specifier matching are bounded computations
over already-parsed values. There is no I/O, wait state or cancellation to
model. (Assessment: derived from the pure value-transformation character of
the cited APIs.) The only unbounded behaviour in the wider Python ecosystem is
the dependency *resolver* in `pip`/`poetry`, which is an external component
and out of scope for a version-string library.

## 9. Prerelease / build metadata + constraint ranges (adapted)

**PEP 440 ordering** of suffixes within one release is fixed and must be
ordered as shown:

```
.devN, aN, bN, rcN, <no suffix>, .postN
```

and local versions sort after the public version. Source:
<https://packaging.python.org/en/latest/specifications/version-specifiers/#summary-of-permitted-suffixes-and-relative-ordering>.
`c` is treated as equivalent to `rc`. Pre-releases are **excluded by default**
from specifier matching unless already installed, explicitly requested, or the
only satisfying version. Source: same reference, "Handling of pre-releases".

**PEP 440 specifiers** are comma-separated clauses joined by logical AND;
operators are `~=` (compatible release), `==` (with optional trailing `.*`),
`!=`, `<=`, `>=`, `<`, `>` and `===` (arbitrary string equality). Source:
<https://packaging.python.org/en/latest/specifications/version-specifiers/#version-specifiers>.
Notable semantics:

- `~= 1.4.5` ≈ `>= 1.4.5, == 1.4.*` — compatible-release sugar. Source: same
  reference, "Compatible release".
- `== 1.1.*` is prefix matching; `== 1.1` is strict. Source: same reference,
  "Version matching".
- `<V` (exclusive ordered) excludes pre-releases of `V` unless `V` is itself a
  pre-release; `>V` excludes post-releases of `V` unless `V` is a post-release.
  Source: same reference, "Exclusive ordered comparison".
- Local version labels are ignored for matching unless the specifier itself
  carries a local label. Source: same reference, "Version matching".

**npm/node-semver** (the JS reference for SemVer ranges; see `js-ts.md`) uses a
different default: a pre-release version satisfies a comparator set only if at
least one comparator with the same `[major, minor, patch]` tuple also has a
pre-release tag; `includePrerelease` suppresses this. Source:
<https://github.com/npm/node-semver#prerelease-tags>.

**`python-semver`** exposes `match(version, match_expr)` supporting `>=`,
`<=`, `>`, `<`, `==`, `!=` and comma-AND, with an `in` operator that is
constraint-aware, and `max_satisfying(iterable, constraint)` for selection.
Source: <https://github.com/python-semver/python-semver#usage>.

(Assessment: because constraint syntax differs sharply between PEP 440,
node-semver and Maven, a Mojo SemVer library must pick one constraint dialect
and document it; node-semver is the dialect that matches the SemVer 2.0.0 spec
most directly.)

## 10. Interesting design decisions

- **Comparison via a normalized key tuple.** PEP 440 defines ordering by
  converting to a canonical tuple (epoch, release padded with zeros,
  pre/post/dev markers); `packaging` does this internally so `<`, `==` and
  `sort()` just work. Source:
  <https://packaging.python.org/en/latest/specifications/version-specifiers/#summary-of-permitted-suffixes-and-relative-ordering>.
- **Immutable value object with functional update.** `Version` is immutable
  and `__replace__`/`from_parts` return new instances — a clean model for Mojo
  value semantics. Source:
  <https://packaging.pypa.io/en/stable/version.html#packaging.version.Version>.
- **A construction path that avoids the parser.** `from_parts(release=...)`
  builds directly from components; the docs frame it as "build a version
  without going though a string and running a regular expression". Source:
  same reference. This is the right shape for a typed language where callers
  may already have the integer components.
- **The regex is embeddable, not anchored.** `VERSION_PATTERN` "is not anchored
  at either end, and is intended for embedding in larger expressions (for
  example, matching a version number as part of a file name)", compiled with
  `re.VERBOSE | re.IGNORECASE`. Source: same reference. SemVer also publishes
  two official regexes (named-group and numbered-group) that are anchored
  (`^…$`). Source: <https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string>.
- **Explicit "loose" vs "strict" modes.** `python-semver` distinguishes strict
  parsing from a permissive one; node-semver exposes a `loose` option. Sources:
  <https://github.com/python-semver/python-semver>,
  <https://github.com/npm/node-semver#functions>. This separates "is this a
  valid SemVer?" from "can I recover a version from messy input?".
- **Build metadata is deliberately non-capturing.** node-semver notes the build
  metadata "is not a capturing group, because it should not ever be used in
  version comparison" — a direct encoding of SemVer clause 10. Source:
  <https://github.com/npm/node-semver/blob/main/internal/re.js>.

## 11. Decisions NOT to copy

- **Conflating SemVer 2.0.0 with PEP 440.** Copying packaging's normalization
  (accepting `1.0`, renaming `-alpha` to `aN`, allowing epochs and `.postN`)
  would make a "SemVer" library that is not SemVer. A Mojo library must reject
  PEP 440-only forms. Sources: <https://semver.org/>,
  <https://packaging.python.org/en/latest/specifications/version-specifiers/#semantic-versioning>.
- **Exception-only error signalling.** `InvalidVersion`/`ValueError` cannot be
  expressed in a Mojo signature; Mojo errors are return values and must be
  typed (`raises VersionError`). Source (buch): `mojov1/errors/error-model`.
- **Silent, lossy normalization.** PEP 440 folds `00` → `0`, `1.1RC1` →
  `1.1rc1`, `1.1.a1` → `1.1a1`. For a spec-strict library this hides invalid
  input; reject instead of normalize (or make normalization an explicit,
  separate function). Source:
  <https://packaging.python.org/en/latest/specifications/version-specifiers/#normalization>.
- **Regex-at-every-call parsing.** Python re-compiles/re-runs the pattern per
  call unless the caller caches; Mojo should parse once and expose a typed
  parser, ideally with a `comptime`-known format version. Source:
  <https://packaging.pypa.io/en/stable/version.html>; Mojo `comptime`:
  buch `mojov1/keywords/comptime`.
- **A mutable-in-spirit legacy API.** `distutils`' removed `LooseVersion`
  compared unparsed strings and exploded at comparison time; Python removed it
  for good reason. Do not copy "parse lazily, validate never". Source:
  <https://peps.python.org/pep-0632/>.
- **The `===` arbitrary-equality escape hatch.** Useful as a packaging
  escape hatch, but it bypasses version semantics and should not be part of a
  SemVer core. Source:
  <https://packaging.python.org/en/latest/specifications/version-specifiers/#arbitrary-equality>.

## 12. Ideas fitting Mojo

- **Typed value struct `Version`** with fields `major`, `minor`, `patch`
  (integers), an optional prerelease-identifier list, and optional build
  metadata — mirroring SemVer clauses 2, 9, 10 exactly. Python's `Version`
  immutability maps directly onto Mojo value semantics; Mojo's `struct` is a
  stack-allocated value type. Source (buch): `mojov1/keywords/struct`.
- **`raises` with a typed `VersionError`** for parse and constraint failures,
  instead of `InvalidVersion`. The buch recommends always naming the error
  type. Source (buch): `mojov1/errors/error-model`.
- **Value-returning `parse(slice) -> Version raises VersionError`** plus a
  component constructor `Version.from_parts(...)`, copying packaging's
  parser-free construction path. Python precedent:
  <https://packaging.pypa.io/en/stable/version.html#packaging.version.Version.from_parts>.
- **`comptime` spec/format constants** such as a `SemVer2` marker, and
  `comptime`-known constraint parsing where the range string is a literal —
  Python resolves these at runtime. Source (buch): `mojov1/keywords/comptime`.
- **Borrowed parsing input.** Mojo can parse from a `StringSlice`/borrowed
  string without copying, then store owned copies only for the prerelease and
  build identifiers that must outlive the input; Python simply interns and
  GCs. This is the ownership decision Q5 asks for. Sources (buch):
  `mojov1/memory/ownership-and-lifetimes`, `mojov1-string-operations`.
- **Explicit ordering key / total order.** Expose a `compare(a, b) -> Int`
  that implements SemVer clause 11, and derive `<`, `<=`, `==`, `>` from it.
  Python's normalized-key approach is the precedent. Source:
  <https://semver.org/#spec-item-11>.
- **A single documented constraint dialect.** Follow the SemVer-aligned
  node-semver grammar for ranges (comparators, `||`, hyphen/tilde/caret/X
  ranges) rather than PEP 440's comma-AND syntax, and document the
  prerelease-by-default choice explicitly. Source:
  <https://github.com/npm/node-semver#ranges>.
- **Use `text_string` as the dependency edge** (`build_versioning`'s
  `depends_on` is already `[text_string]`): trimming, ASCII case-folding and
  split-once are exactly what a parser needs and already exist as public APIs
  there. Source: `.repo/todo/build_versioning.yml:4`, and the `text_string`
  public surface (`akku/text_string/`).

## Sources

- Semantic Versioning 2.0.0 (mandatory spec): <https://semver.org/>
  - clause 2 core: <https://semver.org/#spec-item-2>
  - clause 9 pre-release: <https://semver.org/#spec-item-9>
  - clause 10 build metadata: <https://semver.org/#spec-item-10>
  - clause 11 precedence: <https://semver.org/#spec-item-11>
  - BNF grammar: <https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions>
  - "Is v1.2.3 a semantic version?": <https://semver.org/#is-v123-a-semantic-version>
  - suggested regexes: <https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string>
- Python packaging, version specifiers (PEP 440): <https://packaging.python.org/en/latest/specifications/version-specifiers/>
- PyPA `packaging.version` / `packaging.specifiers`:
  <https://packaging.pypa.io/en/stable/version.html>
- PEP 632 (removal of `distutils`): <https://peps.python.org/pep-0632/>
- PEP 440 (implicitly, via the packaging spec): <https://peps.python.org/pep-0440/>
- CPython `importlib.metadata`: <https://docs.python.org/3/library/importlib.metadata.html>
- CPython `sys.version_info`: <https://docs.python.org/3/library/sys.html#sys.version_info>
- `python-semver`: <https://github.com/python-semver/python-semver>
- npm `node-semver` (cross-reference for range dialect): <https://github.com/npm/node-semver>
- Mojo buch (local): `mojov1/errors/error-model`, `mojov1/keywords/comptime`,
  `mojov1/keywords/struct`, `mojov1/memory/ownership-and-lifetimes`,
  `mojov1-string-operations`
- Repo: `.repo/todo/build_versioning.yml`
