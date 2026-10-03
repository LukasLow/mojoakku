# build_versioning research: C++

## 1. Standard library support

- **The C++ standard library has no Semantic Versioning type or functions.**
  There is no `<semver>` header; the only header named `<version>` is the C++20
  *language-support* header that supplies implementation feature-test macros and
  is "part of the language support library", not a versioning facility
  (cppreference, *Standard library header `<version>` (C++20)*). It ships
  `__cpp_lib_*` feature macros and implementation version macros, nothing about
  parsing or comparing semantic versions (cppreference, same page).
- **The reusable language pieces are generic:**
  - `std::string_view` (C++17) for a non-owning view over a version string
    (cppreference, `<string_view>`).
  - `charconv`'s `std::from_chars` / `std::to_chars` (C++17) for allocation-free
    integer parsing/formatting of the numeric components (Neargye/semver
    reference, *Parsing* — the library models its result types on these).
  - C++20 three-way comparison `operator<=>` returning `std::strong_ordering` /
    `std::weak_ordering` for total/precedence ordering (cppreference,
    *Comparison operators* — "Three-way comparison (C++20)"; Neargye/semver
    reference, *Comparison*).
- **SemVer 2.0.0 itself is a spec, not standardised in C++** (semver.org). Any
  conforming implementation is third-party or hand-written.
- CMake's `VERSION_LESS` etc. are a CMake-language builtin, not C++: a
  four-field component compare with omitted-as-zero and silent truncation
  (CMake `if` docs, *Version Comparisons*).

## 2. Relevant community libraries

- **`Neargye/semver`** — "Header-only C++17 library for Semantic Versioning
  2.0.0. Parse, validate, compare, format, and increment versions, or match them
  against version ranges. No dependencies." MIT licence (README). Compiler
  support: Clang/LLVM >= 6, Apple Clang >= 10, GCC >= 7, VS >= 2019 (README,
  *Compiler compatibility*). Packaged via vcpkg (`neargye-semver`), Conan,
  CPM, and CMake `find_package` (README, *Integration*).
- **Boost.Endian / Boost.Version** — `boost::version` is not part of the fetched
  material; `GUESS:` a separate Boost version library exists but was not fetched,
  so no API claims are made here. Reason: only `Neargye/semver` was fetched as
  the C++ reference in this run.
- Practical reality: because there is no stdlib support, almost every C++ project
  either uses a header-only library like `Neargye/semver` or hand-rolls a parser
  (Assessment: derived from §1 and the library's own "no dependencies" pitch).

## 3. Exposed APIs

From `Neargye/semver` (reference, *Synopsis*):

- **Type:** `template <typename I1 = std::uint32_t, typename I2 = I1, typename I3 = I1> class version;`
  — unsigned integer component types, possibly different; `version<>` uses
  `std::uint32_t` for all three (reference, *`version`*).
- **Construction:** `version()`, `version(T1 major, T2 minor, T3 patch)`,
  `version(T1, T2, T3, std::string_view prerelease, std::string_view build = {})`;
  default is `0.1.0`; negative/unrepresentable components throw
  `std::out_of_range`, invalid qualifiers throw `std::invalid_argument`
  (reference, *Construction*).
- **Observers:** `major()`, `minor()`, `patch()`, `prerelease_tag()`,
  `build_metadata()`, `is_prerelease()`, `has_build_metadata()`, `to_string()`
  (reference, *Observers*).
- **Transformations:** `bump_major()` / `bump_minor()` / `bump_patch()`,
  `without_prerelease()`, `without_build_metadata()`, `swap` (reference,
  *Transformations*).
- **Parsing:** `parse(std::string_view, version& output)`; `from_chars(first,
  last, version&)`; `try_parse` → `std::optional<version>`; `from_string` →
  throws `std::system_error`; `valid(std::string_view)`; plus `clean` and
  `coerce` → `std::optional` (reference, *Parsing*, *Cleaning and coercion*).
- **Comparison:** all six relational operators; `compare` / `compare_with_build`
  → `int`; C++20 `<=>` → `std::weak_ordering`; `diff` → `version_change` enum
  (`none, major, minor, patch, premajor, preminor, prepatch, prerelease`)
  (reference, *Comparison*).
- **Ranges:** `range_set<I1,I2,I3>` with `contains(value, prerelease_policy)`;
  `parse`/`try_parse_range`; `satisfies`; `min_satisfying` / `max_satisfying`;
  `min_version`; `intersects`; `prerelease_policy { exclude, include }`
  (reference, *Ranges*, *Range utilities*, *Prerelease matching*).
- **Serialization:** `to_chars`, `operator<<`, `std::format` when available,
  `std::hash` (reference, *Serialization*).
- **Incrementing:** `inc(value, version_change, prerelease = {})`
  (reference, *Incrementing*).
- **Literal:** `"1.2.3-alpha"_semver` under `semver::literals` when
  `SEMVER_HAS_CONSTEVAL_LITERAL == 1` (reference, *Literals*).

## 4. Error representation

- **The library offers the full menu, deliberately:**
  - **Result struct (C++17 `from_chars` style):**
    `from_chars_result { const char* ptr; std::errc ec; }` and
    `to_chars_result { char* ptr; std::errc ec; }`, each with
    `explicit operator bool()` true iff `ec == std::errc{}` (reference,
    *Result types*). Error codes include `invalid_argument`,
    `result_out_of_range`, `value_too_large` (reference, *Result types*).
  - **Optional:** `try_parse`, `clean`, `coerce`, `try_parse_range` return
    `std::optional` and `std::nullopt` on failure (reference).
  - **Exceptions:** `from_string` throws `std::system_error`; constructors throw
    `std::out_of_range` / `std::invalid_argument`; `bump_*` throw
    `std::overflow_error` (reference).
- **`parse` / `from_chars` leave `output` unchanged on failure**, so a failed
  parse cannot clobber a previously valid value (reference, *Parsing*).
- **`range.contains` is `noexcept` and takes its policy as an argument**, so range
  matching itself does not throw (reference, *Ranges*).

## 5. Ownership semantics

*Adapted for versioning (see `_dev/README.md`): whether parsing is in-place or
value-returning, and who owns the parsed value/string.*

- **Value type with value semantics.** `version<>` is copyable and movable;
  observers and transformations return by value (`bump_minor() const` returns a
  new version) or by non-owning `std::string_view` (reference, *Construction*,
  *Transformations*, *Observers*).
- **Returned `string_view`s are borrowed from the version:** "Returned string
  views remain valid until the version is modified or destroyed" (reference,
  *Observers*). So `prerelease_tag()` and `build_metadata()` are non-owning views
  into the object; the `version` owns the storage.
- **Parse output is an out-parameter, but the input is a borrowed view.**
  `parse(std::string_view input, version& output)` reads `input` (borrowed) and
  writes into a caller-owned `output` (reference, *Parsing*, *Strict parsing*).
  `try_parse`/`from_string`/`coerce` instead return the value (reference).
- **Parsing may allocate** (the qualifier strings), and allocation errors
  propagate to the caller (reference, *Strict parsing*: "Parsing may allocate;
  allocation errors propagate to the caller").
- `to_chars` writes into a caller-owned buffer "without allocating or adding a
  null terminator"; on success `ptr` points past the written bytes; undersized
  buffer → `value_too_large`, nothing written (reference, *Serialization*).

## 6. Blocking / non-blocking

- **Not applicable: pure computation.** Parsing, comparison and rendering perform
  no I/O, do not block, and expose no async/concurrency model (reference; §1).
- Types are value-semantic and the comparison functions are marked `noexcept`
  (reference, *Comparison*), so they compose safely across threads; the library
  makes no explicit threading claim. `GUESS:` like any header-only value library
  it is safely usable from multiple threads on distinct values; no threaded
  guarantee is documented.

## 7. IPv4 / IPv6

*Adapted for versioning (see `_dev/README.md`): how the spec/version identity is
modelled and whether one abstraction covers it all.*

- **Identity model:** `Version { major, minor, patch, pre: Prerelease,
  build: BuildMetadata }` — three numeric fields plus two qualifier types
  (Rust sibling doc `rust.md` §7 describes the same spec shape; semver.org
  item 2 + 9 + 10).
- **All three numeric components are required** by strict parsing; `from_string`
  throws on `1.0` and `coerce` is the separate opt-in that fills missing minor /
  patch with zero and accepts leading zeros (reference, *Cleaning and coercion*).
- **Optional `v` prefix is handled by `clean`/`coerce`, not by strict parse.**
  `clean` removes outer spaces, an optional `=`, and an optional `v`/`V`, in that
  order; strict `parse` does not (reference, *Cleaning and coercion*; semver.org
  FAQ says `v1.2.3` is not a semantic version).
- **Build metadata is represented but precedence-ignoring:**
  `compare` implements SemVer precedence and ignores build metadata; versions
  differing only in build metadata are equivalent (reference, *Comparison*).
  `compare_with_build` is the explicit opt-in that also compares build metadata
  lexicographically (reference, *Comparison*).
- **One abstraction covers strict versions; *ranges* are a second abstraction.**
  `range_set` models constraints, and SemVer itself does not define ranges
  (reference, *Ranges*: "SemVer 2.0.0 does not define ranges").
- **Partial versions** (`1`, `1.2`) are *not* `version`s; they are valid range
  bounds only (reference, *Ranges*: "`>=`, `<`, `~`, and `^` accept complete or
  partial versions. `>`, `<=`, `=`, and `!=` require complete versions").

## 8. Timeouts

- **Not applicable.** Version work is a pure function of its inputs: no blocking,
  no deadline, no cancellation point (reference; §6).
- The only timeout-like concerns (reading a version over a stream) belong to the
  caller's I/O and to `operator<<` / `to_chars`, not to the version model
  (Assessment: derived from the pure signatures in reference).

## 9. TLS

*Adapted for versioning (see `_dev/README.md`): how prerelease/build metadata and
constraint ranges are handled.*

- **Prerelease precedence** implements semver.org item 11 (numeric identifiers
  numerically, letter/hyphen identifiers in ASCII order, numeric < non-numeric,
  more fields > fewer, prerelease < release) — the library documents the
  `1.0.0-alpha < ... < 1.0.0` chain (semver.org item 11; Rust sibling `rust.md`
  §7 cites the same chain).
- **Build metadata is stored and ignored for precedence** (semver.org item 10;
  reference, *Comparison*).
- **Ranges are first-class and richer than SemVer.** Supported forms: complete
  and partial versions, wildcards `* x X`, comparators `> >= < <= = !=`, tilde
  `~`, caret `^`, AND by whitespace, OR by `||` (reference, *Ranges*). This is
  the npm/Cargo model (semver.org does not define it; npm README, *Ranges*).
- **Explicit prerelease policy is a distinguishing design.** `prerelease_policy
  { exclude, include }`; by default a prerelease must satisfy all constraints in
  a branch that explicitly names a prerelease with the same
  `[major,minor,patch]` (reference, *Prerelease matching*). This matches npm's
  documented behaviour ("it will only be allowed to satisfy comparator sets if at
  least one comparator with the same `[major, minor, patch]` tuple also has a
  prerelease tag" — npm README, *Prerelease Tags*).
- **Bounds use `-0` sentinels**, e.g. `1` → `>=1.0.0 <2.0.0-0` and `^0.2.3` →
  `>=0.2.3 <0.3.0-0` (reference, *Ranges* table), the same `-0` idiom npm
  documents (npm README, *X-Ranges*, *Caret Ranges*).

## 10. Interesting design decisions

- **Const-generic component types** (`version<I1,I2,I3>`) let a caller pick a
  narrower representation while allowing comparisons across different component
  types without narrowing (reference, *`version`*: "Compare versions and match
  ranges across different component types").
- **Result-type family mirrors `<charconv>`**, giving C++ users a familiar,
  non-throwing, no-allocation parse path (`from_chars`) alongside optional- and
  exception-returning variants (reference, *Result types*, *Parsing*).
- **`diff` / `version_change` enum** (`major, minor, patch, premajor, preminor,
  prepatch, prerelease`) reports *what kind of change* happened, not just
  ordering (reference, *Comparison*; npm README, *`diff`*).
- **`compare` vs `compare_with_build`** cleanly separates the spec's precedence
  (build ignored) from a total order that includes build metadata (reference,
  *Comparison*).
- **`range_set` as a set of comparator branches with `min_version` /
  `intersects` / `min_satisfying` / `max_satisfying`** — it solves the real
  package-manager problem ("what is the lowest version this range allows?"),
  including the unrepresentable-bound case (`>255.255.255` has no minimum in a
  `uint8_t` range) (reference, *Range utilities*).
- **Compile-time support is a first-class, configurable feature**:
  `SEMVER_HAS_CONSTEXPR`, `SEMVER_HAS_CONSTEXPR_CORE`, `..._OPTIONAL`,
  `..._RANGES`, `SEMVER_HAS_CONSTEVAL_LITERAL`, and the `"1.2.3"_semver` literal
  fail at constant evaluation for invalid input (reference, *Literals*,
  *Constants and feature flags*).
- **Input limits are configurable and default to 512** (`SEMVER_MAX_INPUT_LENGTH`,
  configurable, default 512) to bound allocation (reference,
  *Constants and feature flags*).
- **`clean` and `coerce` are separate, explicitly lossy operations** (strip
  `=`, `v`, spaces; fill missing components; accept leading zeros) so strict
  parsing stays strict (reference, *Cleaning and coercion*).

## 11. Decisions NOT to copy

- **Three parallel error channels** (result struct, `std::optional`,
  exceptions) multiply the API surface; a new library should pick one primary
  model (Assessment: derived from reference, *Parsing*).
- **`std::out_of_range` / `std::invalid_argument` / `std::overflow_error`
  exception taxonomy** is C++-specific and leaks `<stdexcept>`; Mojo should use
  its own typed errors (reference; mojov1 buch, `mojov1/appendix/cheat-sheet` —
  typed `raises`).
- **Default `0.1.0`** (reference, *Construction*) is an opinionated non-neutral
  default; a parsed version should never acquire a value it was not given.
- **Unbounded configurable input length is a DoS surface**; the default 512 is a
  guard, but the API invites raising it (reference,
  *Constants and feature flags*). A new library should bound input by design
  (contrast Go's `MaxVersionLen = 256`, `go.md` §3).
- **`range_set`'s full npm-compatible grammar plus `coerce` plus `clean` plus
  `diff` plus `inc` is a very large surface.** For a low-vision, predictable
  API, copying all of it at once is the wrong scope; core parse/compare/prerelease
  first, ranges as a deliberate later step (Assessment: derived from reference,
  *Synopsis*).
- **`from_chars`' "longest prefix" semantics** (parse as much as possible and
  return where it stopped) is subtle to get right and easy to misuse; a strict
  whole-string parse should be the default (reference, *Strict parsing*).

## 12. Ideas fitting Mojo

- **A `Version` value struct** mirroring `pre` + `build` qualifier types, with
  value semantics and no manual lifetime (semver.org item 9/10; mojov1 buch,
  `mojov1/types/overview` — value semantics, structs).
- **Three parse flavours, one model:** a strict raising `parse`, a non-raising
  `try_parse` returning an optional, and no exception taxonomy — map
  `std::errc`-style failures to one typed Mojo error
  (mojov1 buch, `mojov1/appendix/cheat-sheet` — `raises`, optionals).
- **`compare` returns an ordering enum and ignores build**, with an explicit
  `compare_with_build` for total ordering — exactly the spec-vs-total-order
  split the C++ library proves useful (semver.org item 10/11; reference,
  *Comparison*).
- **A `version_change`-style `diff` enum** is a cheap, very useful addition for
  release tooling (npm README, *`diff`*; reference, *Comparison*).
- **Const-generic or fixed wide components:** choose `UInt64` (or configurable)
  for the numbers and raise on overflow, learning from the `int` trap in C
  (`c.md` §11) and the const-generic C++ design (reference, *`version`*).
- **Prerelease-aware range type with an explicit policy** (`exclude` default,
  `include` opt-in) instead of an implicit rule (reference, *Prerelease
  matching*; npm README, *Prerelease Tags*).
- **`comptime`-validated literal / constant versions:** Mojo's `comptime`
  supports the C++ `consteval` literal idea — a compile-time-checked version
  constant (reference, *Literals*; mojov1 buch, `mojov1/appendix/cheat-sheet` —
  `comptime`).
- **Input length bound as a design constant**, not a mutable global, closing the
  DoS surface (reference, *Constants and feature flags*; contrast Go's
  `MaxVersionLen`, `go.md` §3).
- **`StringSpan` for zero-copy parse input**, mirroring `std::string_view` but
  without the dangling-view hazard of returned views (reference, *Observers*;
  mojov1 buch, `mojov1/types/overview` — `StringSpan`).

## Sources

- <https://semver.org/> — SemVer 2.0.0 spec: items 2, 9, 10, 11; BNF; `v` FAQ.
- <https://github.com/Neargye/semver> — C++17 header-only reference: features,
  MIT, compiler support, integrations.
- <https://github.com/Neargye/semver/blob/master/doc/reference.md> — full API:
  `version<>`, parsing (`parse`/`from_chars`/`try_parse`/`from_string`/`valid`/
  `clean`/`coerce`), result types, comparison/`diff`, serialization, ranges +
  prerelease policy, incrementing, literals, constants.
- <https://en.cppreference.com/w/cpp/header/version> — `<version>` is the C++20
  language-support/feature-test-macro header, not a semver API.
- <https://en.cppreference.com/w/cpp/language/operator_comparison> — C++20
  `<=>`, `std::strong_ordering` / `std::weak_ordering`.
- <https://cmake.org/cmake/help/latest/command/if.html> — CMake
  `VERSION_LESS` / `VERSION_GREATER`, 4-field truncating compare (contrast).
- Rust `semver` crate docs (used for the shared spec-shape cross-check):
  <https://docs.rs/semver/latest/semver/struct.Version.html>.
