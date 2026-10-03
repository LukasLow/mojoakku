# build_versioning research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `build_versioning`.

Semantic Versioning 2.0.0 is a small, pure, self-contained concept (parse a
version string into a value, compare two versions, and optionally match a
version against a constraint range). It exists in essentially every language,
so presence is not a discriminator: the languages below are the ones in which
version handling differs in a way worth studying. The mandatory spec source for
this run is SemVer 2.0.0 (<https://semver.org/>).

## Selected languages (frozen)

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | C has only GNU `strverscmp` (a *non*-SemVer natural order) and `h2non/semver.c` as the zero-dependency reference; C++ has `Neargye/semver`, the richest header-only API (strict/optional/result error paths, `compare` vs `compare_with_build`, ranges, `consteval` literals) |
| systems-modern | 1 | Go, Rust, Zig | Go's three-way split (`x/mod/semver` string-only + `Masterminds/semver/v3` coercion/ranges + `hashicorp/go-version` segments) shows the widest design spread; Rust's `semver` crate proves the newtype-validated `Prerelease`/`BuildMetadata` and the two-named-orderings model; Zig ships `std.SemanticVersion`, the only selected statically-typed stdlib SemVer with borrowed qualifier slices and a distinct `Order` result |
| scripting-web | 2 | Python, JS/TS | Python contrasts SemVer 2.0.0 (`python-semver`) with PEP 440 (`packaging`), the sharpest spec split in the corpus; node-semver is the de-facto range grammar (caret/tilde/hyphen/X, prerelease opt-in) that most other ecosystems copy |
| managed-JVM | 2 | Java, Kotlin | Java shows the Maven `ComparableVersion` generic token comparator (explicitly *not* SemVer 2.0.0) plus `semver4j`'s three constraint dialects; Kotlin adds `z4kn4fein/kotlin-semver` as an immutable `data class` with node-semver sugar and a Maven bridge |
| functional/BEAM | 2 | Elixir | Elixir is the only selected language with a first-class stdlib `Version` module: `{:ok, v} | :error`, prerelease stored as a *list*, build ignored in compare, and the `~>` pessimistic operator — the closest structural match to Mojo's return-value error model |

Optional group not selected this run: **data/science** (Julia, R) — no distinct
SemVer API signal beyond the selected languages.

Deliberately not selected this run (available in the roster, but dropped with a
reason): C#, Odin, Swift (systems-modern — no distinct SemVer API beyond the
selected three; C# `System.Version` is a four-field numeric compare, not
SemVer 2.0.0), Perl, PHP, Dart (scripting-web — no distinct identity or range
model beyond Python/JS), OCaml, F#, Haskell (functional/BEAM — no distinct
SemVer story beyond Elixir's stdlib module).

Researchers started: **2** (fewer than the limit of 6; the ten language files
were produced by two researchers, each covering several groups). Mojo is read
from the `mojov1` buch, not researched from the internet.

## Question set (adapted for versioning)

The standard 12 questions apply in order. Three socket-specific questions are
replaced by SemVer equivalents; everything else is unchanged:

- Q5 (was ownership/lifetime of socket+handle) → whether parsing is
  value-returning or in-place, and the ownership semantics of the parsed value
  and the input string (borrowed view vs. owned qualifier storage).
- Q7 (was IPv4/IPv6) → how the version identity is modelled
  (`major.minor.patch` + prerelease + build, and the optional `v` prefix) and
  whether a single abstraction covers the whole spec.
- Q9 (was TLS) → how prerelease and build metadata are handled (storage,
  precedence, build-ignored comparison) and how constraint ranges are
  represented and matched.

Q6 (blocking vs async), Q8 (timeouts/cancellation) and Q10-Q12 are kept
verbatim: for a pure value transformation the interesting answers are "not
applicable, and here is why", which is itself evidence.

## Writing contract

Each researcher writes its language files **directly** into
`akku/build_versioning/_dev/<lang>.md`, one file per language of its group,
using exactly the section structure in `.agents/workflows/NewLibPhase1Research.md`.
There is no reporting-project and no `docs` materialization pass.

Besides the source citations, derived statements are marked
`(Assessment: derived from <sources>)`; unsourced statements are marked `GUESS:`
with the reason no source exists.

## Status

| lang | group | file | state |
| --- | --- | --- | --- |
| C | systems-lowlevel | `c.md` | done |
| C++ | systems-lowlevel | `cpp.md` | done |
| Go | systems-modern | `go.md` | done |
| Rust | systems-modern | `rust.md` | done |
| Zig | systems-modern | `zig.md` | done |
| Python | scripting-web | `python.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Kotlin | managed-JVM | `kotlin.md` | done |
| Elixir | functional/BEAM | `elixir.md` | done |
| Mojo | (buch) | `mojo.md` | linked to buch |

Phase 1 is complete: 10 language files, Mojo linked to the `mojov1` buch. The
review happens in `.agents/workflows/NewLibPhase2ResearchReview.md`.
