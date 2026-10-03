# build_versioning research: C

## 1. Standard library support

- **The C standard library has no Semantic Versioning support.** There is no
  `<semver.h>`, no version type, no parse/compare function in ISO C
  (Assessment: derived from the absence of any such name in the C library
  headers; the relevant headers are `<string.h>` and `<stdlib.h>`).
- **`strverscmp()` is the only standardised-adjacent version comparator, and it
  is *not* SemVer.** It is a GNU extension declared in `<string.h>` under
  `#define _GNU_SOURCE`; `int strverscmp(const char *s1, const char *s2)`.
  Standard: **GNU**. It compares digit runs numerically but treats leading
  zeros as if a decimal point preceded them, so its order is
  `000, 00, 01, 010, 09, 0, 1, 9, 10` — that is deliberately *not* the SemVer
  model (man7 `strverscmp(3)`). It is MT-Safe and does not use `LC_COLLATE`
  (man7 `strverscmp(3)`).
- **The only reusable primitives are generic ones:** `strtoul`/`strtoull` for
  numeric components, `strlen`/`strchr`/`strspn`/`memchr` for splitting, and
  manual ASCII classification from `<ctype.h>` (`isdigit`, `isalnum`). None of
  them knows anything about versions (Assessment: derived from their standard
  signatures).
- **SemVer 2.0.0 is a specification, not a header.** The canonical grammar and
  precedence rules live only in the spec (semver.org, *Backus–Naur Form Grammar*
  and *Specification Items 2, 9, 10, 11*). A C implementation must encode them
  by hand.
- CMake, which ships in many C/C++ toolchains, implements a *component-wise
  integer* version comparison as a language builtin, not a library:
  `if(<lhs> VERSION_LESS <rhs>)` with format
  `major[.minor[.patch[.tweak]]]`, omitted components treated as zero, and any
  non-integer trailing part truncating the string (CMake `if` docs, *Version
  Comparisons*). This model is **CalVer/tool-version-flavoured, not SemVer**: it
  has a 4th (`tweak`) field, ignores prerelease/build semantics, and truncation
  is silent (CMake `if` docs).

## 2. Relevant community libraries

- **`h2non/semver.c`** — "Semantic version v2.0 parser and render written in
  ANSI C with zero dependencies", MIT licence, no regexp (ANSI C lacks it)
  (h2non/semver.c README). Features: version metadata parsing, prerelease
  parsing, comparison helpers, comparison operators, render, bump, sanitizer,
  numeric conversion, 100 % test coverage (README). The `v0` branch is
  deprecated; `v1` is current (README, *Versions*).
- **The C ecosystem is thin on purpose:** glibc supplies only `strverscmp`, and
  most C projects either hand-roll comparison or embed a small parser like
  `semver.c` (Assessment: derived from §1 and the fact that the fetched
  reference implementation advertises itself as the zero-dependency drop-in).
- `GUESS:` no other mature, widely used pure-C SemVer library was identified in
  this run beyond `semver.c`; no second C source was fetched. The reason no
  source exists is that the search was limited to the fetched README and man
  page; the claim is therefore stated as a guess rather than a fact.

## 3. Exposed APIs

From `h2non/semver.c` (README, *API*):

- Data type: `struct semver_t { int major, int minor, int patch, char *prerelease,
  char *metadata }` (README).
- Parsing/validation: `int semver_parse(const char *str, semver_t *ver)`;
  `int semver_is_valid(char *str)`; `int semver_clean(char *str)` (README).
- Comparison: `int semver_compare(semver_t a, semver_t b)`;
  `semver_eq`, `semver_ne`, `semver_gt`, `semver_lt`, `semver_gte`, `semver_lte`
  (README).
- Constraints: `int semver_satisfies(semver_t a, semver_t b, char *operator)`
  with operators `=`, `>=`, `<=`, `<`, `>`, `^`, `~`; plus
  `semver_satisfies_caret`, `semver_satisfies_patch` (README).
- Rendering/bump/lifetime: `semver_render(semver_t*, char *dest)`;
  `semver_numeric(semver_t*)` (packs to a single `int` "useful for ordering and
  filtering" — lossy, see §11); `semver_bump`, `semver_bump_minor`,
  `semver_bump_patch`; `semver_free(semver_t*)` (README).
- From libc: `int strverscmp(const char*, const char*)` (man7 `strverscmp(3)`).

## 4. Error representation

- **Out-parameter + integer status is the C idiom here.**
  `semver_parse` writes into the caller's `semver_t` and returns `-1` on invalid
  semver or parse error, `0` on success (README). There is no `errno`, no
  exception, no error type.
- `semver_compare` returns `-1` lower / `0` equal / `1` higher; the boolean
  predicates return `1`/`0`; `semver_satisfies` returns `1` satisfied / `0` not
  (README).
- **Invalid and "less than" are conflated** in `semver_compare`: a parse failure
  yields `-1`, the same value as "a is lower than b" (Assessment: derived from
  the documented return values in README). A caller cannot distinguish the two
  from the return value alone.
- `strverscmp` returns an `int` less than / equal to / greater than zero; it
  defines no error for malformed input, because it accepts arbitrary strings
  (man7 `strverscmp(3)`).

## 5. Ownership semantics (adapted: value-returning vs. in-place)

*Adapted for versioning (see `_dev/README.md`): whether parsing is in-place or
value-returning, and who owns the parsed value/string.*

- **Hybrid: numeric components by value, strings by heap copy, struct written
  through a caller pointer.** `semver_parse(const char *str, semver_t *ver)`
  takes the input as a borrowed `const char*` and writes the result into a
  struct the **caller** owns (README). The three numeric fields are plain values;
  `prerelease` and `metadata` are `char*` that the parser allocates (README:
  "Free allocated memory when we're done" via `semver_free`).
- **The caller owns the string lifetime and must call `semver_free(&v)`** when
  done (README). The input `str` is only read during parsing and is not retained.
- Comparison takes `semver_t` **by value** (`semver_compare(semver_t a, semver_t b)`),
  so the pointers inside are shared, not copied, during the call (README).
- `semver_render` writes into a caller-supplied destination buffer (README);
  `semver_clean` mutates the caller's `char*` in place (README: "Removes invalid
  semver characters in a given string"), so its input must be writable.

## 6. Blocking / non-blocking

- **Not applicable: the whole layer is pure computation.** Parsing, comparison
  and rendering perform no I/O, do not block, and have no async/concurrency
  model (man7 `strverscmp(3)`; h2non/semver.c README — all functions are pure
  string/number functions).
- `strverscmp` is **MT-Safe**, i.e. safe to call from multiple threads
  (man7 `strverscmp(3)`, *ATTRIBUTES*). `semver.c` advertises no threading
  guarantees; like any function over caller-owned memory it is only as
  thread-safe as the buffers passed in (Assessment: derived from the by-value/
  pointer signatures in README).

## 7. Version-identity model (adapted: how the spec / version identity is modelled)

*Adapted for versioning (see `_dev/README.md`): how the spec/version identity is
modelled (major.minor.patch, prerelease, build metadata, optional `v` prefix) and
whether one abstraction covers it all.*

- **Identity model: three `int`s + two optional owned strings.**
  `semver_t { int major, minor, patch; char *prerelease, metadata; }` (README).
  It covers MAJOR.MINOR.PATCH, prerelease and build metadata.
- **Build metadata is modelled but does not participate in precedence** per the
  spec: "Build metadata MUST be ignored when determining version precedence"
  (semver.org, item 10). The struct stores it for rendering, but the spec's
  comparison model is the three numbers plus prerelease (semver.org, item 11;
  README separates "Version metadata parsing" from "Version comparison helpers").
- **No optional/partial components.** `semver_parse` requires a full `X.Y.Z`;
  `1` or `1.2` are invalid (semver.org item 2 requires all three; the example
  tests reject `1` and `1.2` — Zig's corpus of the same spec lists them invalid,
  `zig.md` §7).
- **No `v` prefix support documented.** `v1.2.3` is explicitly *not* a semantic
  version (semver.org FAQ, *Is "v1.2.3" a semantic version?*); a parser that
  accepts it would have to strip it. `semver.c`'s documented operator set does
  not mention prefix stripping; `semver_clean` removes "invalid semver
  characters" (README), so normalization is a separate, lossy step.
- **No single abstraction covers everything.** The struct covers strict SemVer;
  partial/wildcard forms (`1.x`, `~1.2`, `^1`) are handled only as *range
  syntax* inside `semver_satisfies`, driven by a runtime operator string, not by
  the type (README).

## 8. Timeouts

- **Not applicable.** Version parsing and comparison are pure value mappings:
  no blocking operation, no wait, no deadline, no cancellation point
  (man7 `strverscmp(3)`; h2non/semver.c README).
- The only timeout-like concerns in a real program (reading a version from a
  socket/file) belong to the surrounding I/O layer, not to the version functions
  (Assessment: derived from the pure signatures in README).

## 9. Prerelease / build metadata + constraint ranges (adapted)

*Adapted for versioning (see `_dev/README.md`): how prerelease/build metadata and
constraint ranges are handled.*

- **Prerelease:** stored as a raw string; precedence implements semver.org
  item 11: "a pre-release version has lower precedence than a normal version"
  and dot-separated identifiers compared numerically, lexically in ASCII, with
  numeric identifiers lower than non-numeric (semver.org item 11).
- **Build metadata:** stored, but "MUST be ignored when determining version
  precedence" (semver.org item 10). Two versions differing only in build
  metadata therefore compare equal.
- **Constraint ranges are a bolt-on, not SemVer.** SemVer 2.0.0 does **not**
  define ranges (semver.org defines only precedence; the npm README likewise
  notes "a version range is a set of comparators"). `semver.c` adds npm-style
  operators `^` (caret) and `~` (tilde) in `semver_satisfies`, explicitly citing
  the npm documentation (README, links to the npm semver docs;
  <https://docs.npmjs.com/cli/v10/using-npm/semver>).
- Caret semantics are version-zero-sensitive: `^1.2.3` allows `<2.0.0` but
  `^0.2.5` only allows `<0.3.0` and `^0.0.4` only `<0.0.5` (npm README, *Caret
  Ranges*; the npm rules are what `semver.c` cites).
- **No prerelease-aware range policy is documented** in `semver.c` (unlike npm,
  which by default excludes prereleases from a range unless the range names a
  prerelease — npm README, *Prerelease Tags*). `GUESS:` the library applies the
  operator to full precedence including prerelease; the README does not state a
  policy, so this is not sourced.

## 10. Interesting design decisions

- **Zero dependencies and no regex**, because ANSI C has no regex; the parser is
  a hand-written scanner (README). This makes the library trivially embeddable.
- **Out-parameter parse + `int` status** keeps the ABI simple and avoids
  allocation of the struct itself; only the two strings are heap-allocated
  (README).
- **`semver_numeric` packs the version into one `int`** for cheap
  sorting/filtering (README) — a lossy but fast single-key comparison. It cannot
  represent full 64-bit components or distinguish build metadata.
- **Explicit `semver_free`** exists precisely because the parse allocates the
  qualifier strings; ownership is visible in the API (README).
- **`semver_clean` mutates the input buffer in place** to sanitize a version
  string (README) — zero-copy but destroys the caller's original.
- CMake's alternative shows a *different* design axis: a **four-field**
  component comparison with silent truncation and omitted-components-as-zero,
  which is convenient for tool versions but wrong for SemVer's strict
  three-field/no-truncation rules (CMake `if` docs; semver.org item 2).

## 11. Decisions NOT to copy

- **No-regex parsing is a constraint of C, not a virtue.** A new library can use
  a real scanner; copying "hand-rolled because the language lacks regex" would
  import an accidental limitation (README).
- **`int` components** cap versions at 32 bits and invite overflow; SemVer
  numbers are unbounded non-negative integers (semver.org item 2). Mojo should
  use a wide, explicit integer (e.g. `UInt64`) and raise on overflow.
- **`semver_numeric` packing is lossy** and collapses distinct versions
  (README); it must not become the primary ordering key.
- **Conflating "invalid" with "lower"** in `semver_compare` (`-1` for both) is a
  silent-error trap (README). A new API should separate parse failure from
  ordering — e.g. parse returns a typed result; comparison is only called on
  valid values.
- **Manual `semver_free` and raw `char*` ownership** (README) are C-specific
  hazards; in Mojo the value/owned-string semantics remove the free entirely (§5).
- **Bolt-on, undocumented range/prerelease policy** (README) — a range engine
  must state its prerelease policy explicitly rather than leave it implicit
  (contrast npm README, *Prerelease Tags*).
- **Silent truncation of non-integer components** (CMake `if` docs) must never
  be copied: SemVer parse must reject, not truncate (semver.org item 2).

## 12. Ideas fitting Mojo

- **Parse as a value-returning, `raises` operation**, not an out-parameter:
  `def parse(text: StringSpan) raises VersionError -> Version`. This removes the
  C out-param/`int`-sentinel pattern and maps errors to typed exceptions
  (mojov1 buch, `mojov1/appendix/cheat-sheet` — `raises` / typed raising).
- **A `Version` struct with explicit wide numeric fields plus prerelease/build**,
  mirroring `semver_t`'s shape but with owned `String`/borrowed `StringSpan`
  (mojov1 buch, `mojov1/types/overview` — value semantics and structs).
- **A separate `try_parse` returning an Optional-like result** for the
  `semver_try_*` style, so callers choose raising vs non-raising (mojov1 buch,
  `mojov1/appendix/cheat-sheet` — optionals).
- **One `compare` returning an ordering enum** (`less`/`equal`/`greater`)
  replaces the `-1/0/1` convention and avoids the invalid/less conflation
  (Assessment: derived from §4).
- **Range/constraint matching as a dedicated type** with an explicit prerelease
  policy, rather than a bare operator string (Assessment: derived from §9;
  npm README, *Prerelease Tags*).
- **`comptime`-friendly data**: the semver.org BNF limits and the
  prerelease/build character classes are compile-time constants
  (semver.org, *BNF*; mojov1 buch, `mojov1/appendix/cheat-sheet` — `comptime`).
- **No manual lifetime management**: because a Mojo `Version` owns or borrows its
  qualifier strings under the language's rules, the `semver_free` step disappears
  entirely (Assessment: derived from §5 and Mojo ownership, mojov1 buch,
  `mojov1/types/overview`).

## Sources

- <https://semver.org/> — SemVer 2.0.0 spec: items 2, 9, 10, 11; BNF grammar;
  `v1.2.3` FAQ; official regexes; "Build metadata MUST be ignored".
- <https://man7.org/linux/man-pages/man3/strverscmp.3.html> — GNU `strverscmp`,
  `_GNU_SOURCE`, non-SemVer leading-zero ordering, MT-Safe, standards: GNU.
- <https://github.com/h2non/semver.c> — `semver.c` README: `semver_t`, parse /
  compare / satisfies / render / bump / numeric / free, operators, MIT,
  no-regex, v0 deprecated.
- <https://cmake.org/cmake/help/latest/command/if.html> — CMake `VERSION_LESS` /
  `VERSION_GREATER` / `VERSION_EQUAL`, 4-field component compare, truncation.
- <https://docs.npmjs.com/cli/v10/using-npm/semver> — npm range syntax (caret,
  tilde, wildcards, hyphen) and prerelease range policy (used as cross-language
  evidence; referenced by `semver.c`).
